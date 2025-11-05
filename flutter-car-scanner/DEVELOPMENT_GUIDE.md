# Development Guide - Car Scanner App

## iOS Build Instructions

### Prerequisites
- **Mac** (required for iOS builds)
- Xcode (from App Store)
- CocoaPods: `sudo gem install cocoapods`
- Flutter SDK
- Apple Developer Account (for device testing)

### Build Commands
```bash
cd flutter-car-scanner
flutter pub get
cd ios
pod install
cd ..
flutter build ios  # or flutter run
```

### Configuration Status
- ✅ Bundle ID: `com.kahastudio.obd2scanner`
- ✅ Bluetooth permissions configured in `Info.plist`
- ✅ App Transport Security configured (allows HTTP for OBD emulator)
- ✅ Local Network usage description configured

### Testing Options
1. **iOS Simulator**: Works for UI/UX, TCP connection, Demo mode (no real Bluetooth)
2. **Real Device**: Required for BLE connection testing (connect iPhone via USB)

## iOS Migration Notes

### Already Configured
- ✅ App Transport Security (NSAllowsArbitraryLoads) - allows HTTP connections
- ✅ Bluetooth permissions (NSBluetoothAlwaysUsageDescription)
- ✅ Local Network access (NSLocalNetworkUsageDescription)
- ✅ Device ID format differences handled (MAC vs UUID)

### Platform Differences
- **Bluetooth Device ID**: Android uses MAC address, iOS uses UUID (handled automatically)
- **Simulator**: No real Bluetooth support (use Demo mode or TCP)
- **Permissions**: iOS auto-prompts for Bluetooth (no code changes needed)

## Feature Limitations

### Not Feasible Features

#### 1. Security Scan
- ❌ Requires raw CAN bus access (not available via OBD-II)
- ❌ Requires bi-directional control and ECU vulnerability database
- ✅ **Alternative**: Implemented informational Security Scan screen with OBD-II data analysis

#### 2. Comprehensive Service Tools
- ⚠️ Most service resets require manufacturer-specific commands
- ✅ **Implemented**: Basic DTC clear + informational guides for common resets

#### 3. Vehicle-Specific Data (Proprietary)
- ⚠️ Manufacturer-specific PIDs are proprietary and undocumented
- ✅ **Implemented**: Extended standard PIDs detection (0120, 0140, 0160 ranges)

#### 4. Comprehensive Battery Testing
- ❌ No standard OBD-II PID for alternator/charging system analysis
- ❌ Load testing requires bi-directional control and specialized hardware
- ✅ **Implemented**: Real-time voltage monitoring with basic health assessment

## Architecture Constraints

### What the App Can Do
- ✅ Read OBD-II standard PIDs (Mode 01)
- ✅ Read/Clear DTCs (Mode 03, 04, 07, 0A)
- ✅ Freeze Frame data (Mode 02)
- ✅ On-board monitoring (Mode 06)
- ✅ Vehicle info (Mode 09)
- ✅ Real-time data streaming via ELM327

### What the App Cannot Do
- ❌ Send arbitrary CAN bus frames
- ❌ Access raw CAN bus (bypassed OBD-II)
- ❌ Manufacturer-specific proprietary commands (without database)
- ❌ Direct ECU programming/flashing
- ❌ True security vulnerability scanning

## Current Implementation Status

### Completed Features
- ✅ Incident History (VIN Decoder using NHTSA API)
- ✅ AI Mechanic (Rule-based repair suggestions)
- ✅ Repair Cost (DTC cost estimates)
- ✅ Issue Forecast (Trend analysis from historical data)
- ✅ Security Scan (OBD-II data analysis with disclaimers)
- ✅ Vehicle-Specific Data (Extended PIDs detection)
- ✅ Service Tools (DTC clear + informational guides)

## Notes

- Demo mode is essential for testing and should not be removed
- All features work with standard OBD-II protocol
- Features requiring external paid APIs (Carfax, etc.) are clearly marked with disclaimers
- Bundle ID and package names standardized across platforms: `com.kahastudio.obd2scanner`

