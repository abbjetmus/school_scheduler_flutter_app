import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

enum BleReaderState {
  disconnected,
  scanning,
  connecting,
  connected,
  error,
}

class BleReaderService {
  BluetoothDevice? _device;
  StreamSubscription? _connectionSubscription;
  final List<StreamSubscription> _charSubscriptions = [];

  final _stateController = StreamController<BleReaderState>.broadcast();
  final _cardIdController = StreamController<String>.broadcast();

  Stream<BleReaderState> get stateStream => _stateController.stream;
  Stream<String> get cardIdStream => _cardIdController.stream;

  BleReaderState _state = BleReaderState.disconnected;
  BleReaderState get state => _state;

  BluetoothDevice? get connectedDevice => _device;

  bool _autoReconnect = true;

  void _setState(BleReaderState newState) {
    _state = newState;
    _stateController.add(newState);
  }

  /// Scan for nearby BLE devices. Returns discovered devices.
  Future<List<ScanResult>> scanForReaders({
    Duration timeout = const Duration(seconds: 10),
  }) async {
    _setState(BleReaderState.scanning);

    await FlutterBluePlus.startScan(timeout: timeout);

    // Wait for scan to complete
    await FlutterBluePlus.isScanning.where((s) => s == false).first;

    final results = FlutterBluePlus.lastScanResults;
    _setState(BleReaderState.disconnected);

    // Return all devices, including those without advertised names
    return results.toList()
      ..sort((a, b) => b.rssi.compareTo(a.rssi));
  }

  /// Connect to a specific BLE device and subscribe to card data.
  Future<void> connect(BluetoothDevice device) async {
    _setState(BleReaderState.connecting);
    _device = device;
    _autoReconnect = true;

    try {
      await device.connect(
        license: License.free,
        autoConnect: false,
        timeout: const Duration(seconds: 15),
      );

      // Listen for disconnection
      _connectionSubscription?.cancel();
      _connectionSubscription = device.connectionState.listen((state) {
        if (state == BluetoothConnectionState.disconnected) {
          _handleDisconnection();
        }
      });

      // Discover services and subscribe to notifications
      await _discoverAndSubscribe(device);

      _setState(BleReaderState.connected);
    } catch (e) {
      _setState(BleReaderState.error);
      if (_autoReconnect) {
        _scheduleReconnect();
      }
    }
  }

  Future<void> _discoverAndSubscribe(BluetoothDevice device) async {
    final services = await device.discoverServices();

    debugPrint('BLE: Discovered ${services.length} services');
    for (final service in services) {
      debugPrint('BLE:   Service: ${service.serviceUuid} '
          '(${service.characteristics.length} characteristics)');
      for (final c in service.characteristics) {
        debugPrint('BLE:     Char: ${c.characteristicUuid} '
            'props: N=${c.properties.notify} R=${c.properties.read} '
            'W=${c.properties.write} I=${c.properties.indicate}');
      }
    }

    // Subscribe to ALL notify/indicate-capable characteristics
    _cancelCharSubscriptions();
    var subscriptionCount = 0;
    for (final service in services) {
      for (final characteristic in service.characteristics) {
        if (characteristic.properties.notify ||
            characteristic.properties.indicate) {
          await _subscribeToCharacteristic(characteristic);
          subscriptionCount++;
        }
      }
    }

    debugPrint('BLE: Subscribed to $subscriptionCount notify characteristics');
  }

  Future<void> _subscribeToCharacteristic(
    BluetoothCharacteristic characteristic,
  ) async {
    // Set up listener BEFORE enabling notifications (flutter_blue_plus best practice)
    final sub = characteristic.onValueReceived.listen((value) {
      final hex = value
          .map((b) => b.toRadixString(16).padLeft(2, '0').toUpperCase())
          .join(' ');
      debugPrint('BLE: Received ${value.length} bytes from '
          '${characteristic.characteristicUuid}: $hex');
      if (value.isNotEmpty) {
        _handleBleData(value);
      }
    });

    _charSubscriptions.add(sub);

    if (_device != null) {
      _device!.cancelWhenDisconnected(sub);
    }

    await characteristic.setNotifyValue(true);
    debugPrint('BLE: Subscribed to ${characteristic.characteristicUuid}');
  }

  void _handleBleData(List<int> data) {
    // Filter known ack/status responses that are NOT card data
    const ackPattern = [0xFF, 0x02, 0x01, 0xFF, 0x03, 0x02, 0xFE];
    if (_listEquals(data, ackPattern)) return;

    if (data.length >= 2) {
      final hexId = data
          .map((b) => b.toRadixString(16).padLeft(2, '0'))
          .join('')
          .toUpperCase();
      debugPrint('BLE: Card ID received via BLE: $hexId');
      _cardIdController.add(hexId);
    }
  }

  /// Submit a card ID from any source (keyboard input, manual entry, etc.)
  void submitCardId(String cardId) {
    final trimmed = cardId.trim();
    if (trimmed.isNotEmpty) {
      debugPrint('BLE: Card ID submitted: $trimmed');
      _cardIdController.add(trimmed);
    }
  }

  bool _listEquals(List<int> a, List<int> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  void _cancelCharSubscriptions() {
    for (final sub in _charSubscriptions) {
      sub.cancel();
    }
    _charSubscriptions.clear();
  }

  void _handleDisconnection() {
    _cancelCharSubscriptions();
    _setState(BleReaderState.disconnected);

    if (_autoReconnect && _device != null) {
      _scheduleReconnect();
    }
  }

  void _scheduleReconnect() {
    Future.delayed(const Duration(seconds: 3), () {
      if (_state == BleReaderState.disconnected &&
          _device != null &&
          _autoReconnect) {
        connect(_device!);
      }
    });
  }

  Future<void> disconnect() async {
    _autoReconnect = false;
    _cancelCharSubscriptions();
    _connectionSubscription?.cancel();
    await _device?.disconnect();
    _device = null;
    _setState(BleReaderState.disconnected);
  }

  void enableAutoReconnect() {
    _autoReconnect = true;
  }

  void dispose() {
    _autoReconnect = false;
    _cancelCharSubscriptions();
    _connectionSubscription?.cancel();
    _stateController.close();
    _cardIdController.close();
    _device?.disconnect();
  }
}
