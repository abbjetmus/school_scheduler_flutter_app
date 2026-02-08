# NFC Bluetooth Reader Documentation

## Hardware Specifications

### Device Information
- **Product Name**: NFC Bluetooth Reader
- **Brand**: Okeeyseda
- **Model**: 500748053
- **Part Number**: 500748053
- **Product Type**: NFC read-write device, card reader, encrypted access control decoder
- **Product Dimensions**: 13 x 8.5 x 4 cm; 78 g
- **Material**: Plastic
- **Color**: White
- **Price**: kr 193.12
- **ASIN**: B0DSM49YY9

### Technical Specifications
- **Operating Frequency**:
  - High frequency: 13.56 MHz
  - Low frequency: 125 kHz / 250 kHz / 375 kHz / 500 kHz
- **Connectivity**:
  - USB
  - Bluetooth 5.0 BLE (Bluetooth Low Energy)
- **Communication Modes**:
  - USB
  - Bluetooth 5.0 BLE
- **Hardware Interface**: USB
- **Connector Type**: USB
- **Compatible Devices**: Smartphone
- **Special Features**: Multi-frequency support (Stöd för flera frekvenser)
- **Batteries Required**: Yes
- **Reader Mode**: Keyboard/HID (types card IDs as keystrokes via Bluetooth)

### Supported Card Types
- M1 Cards (Mifare Classic)
- UID Cards
- CUID Cards
- FUID Cards
- GTU Cards
- T5577 / 5200 Cards
- 8265 Cards
- IC cards (13.56 MHz)
- ID cards (125 kHz)

## App Integration

### BLE Service UUIDs
The app scans for the following known service UUIDs:
- **FFE0**: Common HM-10/HM-19 BLE modules
- **6E400001-B5A3-F393-E0A9-E50E24DCCA9E**: Nordic UART Service
- **49535343-FE7D-4AE5-8FA9-9FAFD205E455**: ISSC transparent UART

### BLE Characteristic UUIDs
The app looks for these notification characteristics:
- **FFE1**: HM-10/HM-19 notify characteristic
- **6E400003-B5A3-F393-E0A9-E50E24DCCA9E**: Nordic UART TX
- **49535343-1E4D-4BD9-BA61-23C647249616**: ISSC transparent TX

### Card ID Format
Card IDs are received as text strings typed by the reader (keyboard/HID mode).
The reader types the card ID followed by Enter into the focused text field.

### Reader Operating Mode

**IMPORTANT**: This reader operates in **Keyboard/HID mode** over Bluetooth.
It does NOT send card data via BLE notifications. Instead, it acts as a
Bluetooth keyboard and types the card ID into the currently focused text field.

- BLE service FFE0 is used for connection status only
- Characteristic FFE1 (notify) sends status acks only: `[0xFF, 0x02, 0x01, 0xFF, 0x03, 0x02, 0xFE]`
- Characteristic FFE2 (write) accepts commands but does not change the card data transmission mode
- Card data is sent as HID keyboard keystrokes

## Manufacturer Manual (Translated from Chinese)

### 1. Connect Power
Use a **Type-C data cable** to connect the device to a USB port.
You can charge it using a power bank, phone charger, or a computer USB port.

### 2. WeChat Scan / Mini Program
Use an iPhone or Android phone to open WeChat and scan the **Sun Code (QR code)** on the back of the device to open the mini-program. Follow the prompts to log in and connect the device. You can also scan the mini-program QR code in the manual.

**Note**: This is a Chinese WeChat mini-program — may not be accessible outside China.

### Supported Cards (from manual)
- **ID cards**: 125 kHz – 500 kHz frequency range
- **IC cards**: 13.56 MHz frequency
- Does **NOT** support: magnetic stripe cards, barcode cards, or special chip cards

### Card Reading Tips (from manual)
- Place the card within the device's sensing area
- Some cards may require leaving a small **finger-width gap** and trying again
- Do **NOT** place the device on metal objects (interferes with reading)
- Keep the reader within **5 meters** of the connected phone, away from interference (microwaves, walkie-talkies)

### Troubleshooting (from manual)

| Problem | Possible Causes & Solutions |
|---------|---------------------------|
| **Cannot find device** | Check indicator light is on (if not, charge it); ensure within 5m and visible; check WeChat has Bluetooth & location permissions; update phone OS; try a different phone (some older models may not connect) |
| **Card cannot be recognized** | Must be 125K–500K ID card or 13.56 MHz IC card; magnetic/barcode/special chip cards not supported; leave finger-width gap; do not place on metal |
| **Card cannot be used after copying** | Incorrect blank card type used; access control/elevator terminal has anti-copy protection; card type is special and cannot be copied |
| **Original card invalid after copying** | Rolling-code anti-copy system in use; firewall/networked security system in place |

### WeChat Configuration App
The manufacturer provides configuration via a WeChat mini program (QR code on device back). This app may allow:
- Connecting and configuring the device
- Changing reader operating mode (keyboard/HID vs BLE data mode)
- Configuring frequency settings

**This could potentially be used to switch the reader from keyboard/HID mode to BLE data mode**, but requires WeChat access.

## Usage Instructions

### Setup
1. Power on the NFC reader via **Type-C USB** cable (power bank, charger, or computer)
2. Ensure Bluetooth is enabled on your device
3. Navigate to **Reader Setup** in the app
4. Tap **"Scan for Readers"**
5. Select "nfc mini rev" from the list
6. Tap to connect

### Reading Cards
1. Ensure the reader is connected (green "Reader Connected" status)
2. Navigate to the **Attendance** page
3. The "Card ID" text field will be auto-focused
4. Place an NFC card near the reader (hold ~1 finger distance)
5. The reader will type the card ID into the text field and press Enter
6. The card ID is automatically submitted and processed
7. Do not place the reader on metal surfaces

## Troubleshooting

### Reader Not Appearing in Scan Results

#### Common Causes & Solutions

1. **Device Not Broadcasting Name**
   - **Issue**: The scanner filters out devices without advertised names
   - **Solution**: The device might still appear with "Unknown Device" - try connecting to all devices shown
   - **Code Location**: `ble_reader_service.dart:64-68`

2. **Bluetooth Permissions**
   - **Android**: Ensure Location and Bluetooth permissions are granted
   - **iOS**: Ensure Bluetooth permission is granted
   - **Windows**: Ensure the app has Bluetooth access
   - **Solution**: Check app permissions in device settings

3. **Reader Not in Discoverable Mode**
   - **Solution**:
     - Power cycle the reader (turn off/on)
     - Check if there's a pairing button or mode switch
     - Some readers require a specific button press to enter BLE mode

4. **Already Paired/Connected to Another Device**
   - **Solution**:
     - Disconnect from other devices
     - Remove existing Bluetooth pairings for this reader
     - Restart the reader

5. **Signal Range/Interference**
   - **Solution**:
     - Move closer to the reader (within 1-2 meters)
     - Remove other BLE devices from the area
     - Avoid Wi-Fi routers and other interference sources

6. **Platform-Specific Issues**
   - **Windows**:
     - Ensure `flutter_blue_plus_winrt` is properly configured
     - Some BLE devices don't work well on Windows - try Android/iOS
   - **Android**:
     - Enable Location Services (required for BLE scanning on Android < 12)
     - Ensure GPS is turned on
   - **iOS**:
     - Check that NSBluetoothAlwaysUsageDescription is in Info.plist

### Debug Steps

1. **Check BLE State**
   - Verify Bluetooth is turned on
   - Look for error messages in the app

2. **View Debug Logs**
   - **CRITICAL**: Run the app with `flutter run` in terminal to see debug output
   - Or use `flutter logs` in a separate terminal
   - Look for lines starting with "BLE DEBUG:"
   - This will show:
     - Which services and characteristics were discovered
     - Which characteristic was subscribed to
     - Raw data bytes when a card is tapped
     - Parsed card ID

3. **Try Scanning Multiple Times**
   - BLE discovery can be unreliable
   - Wait 10 seconds between scans

4. **Debugging Card Reading Issues**
   When connected but not receiving card IDs:

   - **Step 1**: Disconnect and reconnect to see service discovery logs
   - **Step 2**: Tap a card and look for "BLE DEBUG: Received data" logs
   - **Step 3**: Check the debug logs for:
     - `Discovered X services` - should see at least 1 service
     - `Subscribing to characteristic` - confirms subscription worked
     - `Received data: X bytes` - confirms data is being received
     - `Parsed card ID: XXXXX` - confirms parsing worked

   - **If no "Received data" logs**: The characteristic isn't sending notifications
     - Some readers need a write command to start sending
     - The wrong characteristic might be selected
     - Check which characteristic was subscribed to in logs

   - **If "Received data" but no card ID**: Data format issue
     - Check "Raw data bytes" in logs
     - May need custom parsing for this specific reader

5. **Check USB Mode**
   - If BLE isn't working, try connecting via USB
   - The reader supports both USB and Bluetooth modes
   - May need to switch modes using a physical button/switch

### Keyboard/HID Mode Issue

**IMPORTANT**: Many NFC readers (including the Okeeyseda) can operate in two modes:

1. **Keyboard/HID Mode** (default): Types card IDs like a keyboard
   - LED blinks and beeps when card is tapped ✅
   - Card ID typed into active text field
   - **Does NOT send data via BLE**

2. **BLE Data Mode**: Sends card IDs via Bluetooth notifications
   - LED blinks and beeps when card is tapped ✅
   - Card ID sent via BLE characteristic
   - **Required for this app**

#### How to Check Which Mode

**Test 1**: Open Notepad or any text editor
- Tap a card on the reader
- **If text appears** → Reader is in Keyboard mode ❌
- **If nothing appears** → Reader might be in BLE mode ✓

#### Switching from Keyboard to BLE Mode

For this specific reader (Okeeyseda), the primary method is:

1. **WeChat Mini Program** (manufacturer's method):
   - Scan the QR code on the back of the device using WeChat
   - The mini program may allow switching between keyboard/HID and BLE data modes
   - **Limitation**: Requires WeChat (Chinese app), may not be accessible outside China

Other methods that may work:

2. **Physical Switch**:
   - Check the reader for a small switch labeled "KB/BLE" or "HID/BLE"
   - Switch to "BLE" mode

3. **Button Combination**:
   - Some readers: Hold button for 5-10 seconds
   - Listen for different beep pattern

4. **AT Commands** (if accessible via USB):
   - Connect via USB
   - Send AT commands to switch modes

#### Our App's Attempted Solutions

The app automatically tries these activation commands:
1. `[0x01]` - Simple start command
2. `[0xAA, 0x00, 0x01, 0x01, 0xAC]` - Enable BLE mode
3. `[0xFF, 0x00, 0x01, 0x82, 0x7E]` - Continuous read mode
4. `[0xAA, 0xBB, 0x01, 0x00, 0x00]` - Start scanning

**If these don't work**, you need to manually switch the reader mode.

### Getting Additional Information

If the device still isn't found:
1. Use a generic BLE scanner app (nRF Connect, LightBlue, etc.)
2. Find the device's advertised name and MAC address
3. Note the service and characteristic UUIDs
4. Add custom UUIDs to `_knownServiceUuids` and `_knownNotifyUuids` in `ble_reader_service.dart`

## Technical Notes

### Auto-Reconnect
The service automatically attempts to reconnect if the connection is lost (3-second delay between attempts).

### Scan Duration
Default scan timeout is 10 seconds. Modify in `ble_reader_service.dart:52` if needed.

### Connection Timeout
Connection attempts timeout after 15 seconds. Modify in `ble_reader_service.dart:81` if needed.

## Related Files
- `lib/features/attendance/services/ble_reader_service.dart` - BLE connection logic
- `lib/features/attendance/pages/reader_setup_page.dart` - UI for scanning and connecting
- `lib/features/attendance/services/attendance_queue_service.dart` - Offline queue handling
- `lib/features/attendance/repositories/attendance_repository.dart` - Attendance data persistence

## References
- flutter_blue_plus documentation: https://pub.dev/packages/flutter_blue_plus
- BLE GATT specifications: https://www.bluetooth.com/specifications/gatt/
