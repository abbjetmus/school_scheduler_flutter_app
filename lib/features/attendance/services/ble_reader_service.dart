import 'dart:async';
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
  BluetoothCharacteristic? _notifyCharacteristic;
  StreamSubscription? _connectionSubscription;
  StreamSubscription? _characteristicSubscription;

  final _stateController = StreamController<BleReaderState>.broadcast();
  final _cardIdController = StreamController<String>.broadcast();

  Stream<BleReaderState> get stateStream => _stateController.stream;
  Stream<String> get cardIdStream => _cardIdController.stream;

  BleReaderState _state = BleReaderState.disconnected;
  BleReaderState get state => _state;

  BluetoothDevice? get connectedDevice => _device;

  bool _autoReconnect = true;

  // Known BLE service UUIDs commonly used by NFC card readers
  static const _knownServiceUuids = [
    'ffe0', // Common HM-10/HM-19 BLE modules
    '6e400001-b5a3-f393-e0a9-e50e24dcca9e', // Nordic UART Service
    '49535343-fe7d-4ae5-8fa9-9fafd205e455', // ISSC transparent UART
  ];

  // Known characteristic UUIDs for receiving card data
  static const _knownNotifyUuids = [
    'ffe1', // HM-10/HM-19 notify characteristic
    '6e400003-b5a3-f393-e0a9-e50e24dcca9e', // Nordic UART TX
    '49535343-1e4d-4bd9-ba61-23c647249616', // ISSC transparent TX
  ];

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

    // Filter to devices that advertise a name (likely real devices)
    return results
        .where((r) => r.device.platformName.isNotEmpty)
        .toList()
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

      // Discover services and find the notify characteristic
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

    // First pass: try known NFC reader service/characteristic UUIDs
    for (final service in services) {
      final serviceUuid = service.serviceUuid.toString().toLowerCase();
      final isKnownService =
          _knownServiceUuids.any((uuid) => serviceUuid.contains(uuid));

      if (!isKnownService) continue;

      for (final characteristic in service.characteristics) {
        if (characteristic.properties.notify ||
            characteristic.properties.indicate) {
          final charUuid =
              characteristic.characteristicUuid.toString().toLowerCase();
          final isKnownChar =
              _knownNotifyUuids.any((uuid) => charUuid.contains(uuid));

          if (isKnownChar) {
            await _subscribeToCharacteristic(characteristic);
            return;
          }
        }
      }
    }

    // Second pass: find any notify-capable characteristic on any service
    for (final service in services) {
      for (final characteristic in service.characteristics) {
        if (characteristic.properties.notify ||
            characteristic.properties.indicate) {
          await _subscribeToCharacteristic(characteristic);
          return;
        }
      }
    }

    throw Exception('No suitable NFC data characteristic found on device');
  }

  Future<void> _subscribeToCharacteristic(
    BluetoothCharacteristic characteristic,
  ) async {
    await characteristic.setNotifyValue(true);
    _notifyCharacteristic = characteristic;

    _characteristicSubscription?.cancel();
    _characteristicSubscription =
        characteristic.lastValueStream.listen((value) {
      if (value.isNotEmpty) {
        _handleCardData(value);
      }
    });
  }

  void _handleCardData(List<int> data) {
    // Parse card ID as uppercase hex string (most common format for NFC UIDs)
    final hexId = data
        .map((b) => b.toRadixString(16).padLeft(2, '0'))
        .join('')
        .toUpperCase();

    if (hexId.isNotEmpty) {
      _cardIdController.add(hexId);
    }
  }

  void _handleDisconnection() {
    _characteristicSubscription?.cancel();
    _notifyCharacteristic = null;
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

  /// Disconnect from the current device and stop auto-reconnect.
  Future<void> disconnect() async {
    _autoReconnect = false;
    _characteristicSubscription?.cancel();
    _connectionSubscription?.cancel();
    await _notifyCharacteristic?.setNotifyValue(false);
    await _device?.disconnect();
    _device = null;
    _notifyCharacteristic = null;
    _setState(BleReaderState.disconnected);
  }

  void enableAutoReconnect() {
    _autoReconnect = true;
  }

  void dispose() {
    _autoReconnect = false;
    _characteristicSubscription?.cancel();
    _connectionSubscription?.cancel();
    _stateController.close();
    _cardIdController.close();
    _device?.disconnect();
  }
}
