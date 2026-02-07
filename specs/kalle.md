# AI Assistant Requirements — School Scheduler Flutter App (Attendance via NFC Reader)

## 1. Purpose
Extend the existing **school_scheduler_flutter_app** to support attendance registration through an external **NFC Bluetooth card reader**, focusing only on attendance functionality.  
The app must read NFC cards, transmit card IDs to the mobile or desktop application, and register attendance in the backend — including scenarios where the mobile phone is closed or running in the background.

---

## 2. Scope
### Included
- Attendance registration via NFC card scanning
- Integration with Bluetooth NFC reader
- Background processing and backend synchronization
- Optional Flutter Desktop support for attendance scanning via computer

### Excluded
- Non-attendance school scheduler features
- UI unrelated to attendance workflows
- Legacy NFC phone reader functionality unless required for fallback

---

## 3. Hardware Requirements
### NFC Reader
- Brand: Okeeyseda
- Product Type: NFC Bluetooth Reader / Card Reader
- Model: 500748053
- Communication Modes:
  - Bluetooth 5.0 BLE
  - USB
- Supported Devices:
  - Smartphones
  - Computers (via USB/Bluetooth)
- Special Features:
  - Multi-frequency support
  - Encrypted access control decoding
- Physical Size:
  - 90 x 60 x 10 mm

### Connectivity
- Bluetooth Low Energy (BLE)
- USB connection (for desktop usage)

---

## 4. Functional Requirements

### 4.1 NFC Card Reading
- Detect NFC card scans from the external Bluetooth reader
- Extract and capture unique card ID
- Validate data format before sending to the app
- Support encrypted or encoded card data if provided by device

### 4.2 Mobile App Integration
- Connect to Bluetooth NFC reader
- Maintain persistent connection where possible
- Receive card IDs from reader
- Trigger attendance registration automatically
- Provide feedback (success/failure state)

### 4.3 Background Operation
- Attendance must be registered even when:
  - Phone screen is off
  - App is in background
  - App is closed (if OS allows background services)
- Implement background services / headless execution
- Queue attendance events if network unavailable
- Retry failed submissions automatically

### 4.4 Backend Communication
- Send attendance payload:
  - Card ID
  - Timestamp
  - Device ID
  - Teacher/User ID (if available)
- Use secure API calls
- Handle offline caching and sync
- Log failed attempts

### 4.5 Desktop Application (Optional but Required if Feasible)
- Implement Flutter Desktop support (Windows/macOS/Linux if possible)
- Connect to NFC reader via:
  - USB
  - Bluetooth
- Capture card scans and send to backend
- Maintain same attendance logic as mobile
- Provide minimal desktop UI for:
  - Reader connection status
  - Attendance logs

---

## 5. Technical Requirements

### Flutter Development
- Maintain Flutter architecture consistency
- Modular NFC integration layer
- Platform abstraction for mobile and desktop
- Support:
  - Android (primary)
  - iOS (if technically possible)
  - Desktop Flutter targets

### Bluetooth Communication
- BLE device discovery
- Auto-reconnect
- Error handling for disconnections
- Device pairing management

### Background Execution
- Android foreground/background services
- iOS background task limitations handled appropriately
- Event-driven scanning workflow

---

## 6. Security Requirements
- Encrypted communication with backend
- Secure storage of authentication tokens
- Protection against duplicate attendance submissions
- Validation of reader source to prevent spoofing

---

## 7. Reliability Requirements
- Offline mode with queued attendance events
- Automatic retry logic
- Reader reconnection handling
- Logging for debugging and diagnostics

---

## 8. Deliverables
- Updated Flutter mobile app with NFC reader support
- Desktop Flutter version (if technically feasible)
- Documentation covering:
  - Bluetooth integration
  - Background processing
  - Backend API usage
- Setup instructions for NFC reader configuration

---

## 9. Assumptions
- NFC reader provides accessible SDK or standard BLE communication
- Backend API already exists for attendance registration
- Teachers authenticate within the app prior to scanning

---

## 10. Open Questions
- Does the NFC reader provide official SDK/documentation?
- What OS versions must be supported?
- Are encrypted card payloads expected?
- Should multiple readers be supported simultaneously?
- What are the exact backend API specifications?
