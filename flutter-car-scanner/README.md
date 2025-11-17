# Flutter Car Scanner

Cross-platform OBD-II car scanner application for vehicle diagnostics and monitoring.

## Features

### Core Functionality
- Real-time live data dashboard with gauges and charts - **78 Sensors**
- Diagnostic trouble code (DTC) reading and clearing
- Freeze frame analysis
- MIL (Check Engine) status monitoring
- Component testing (Mode 06)
- O2 sensor diagnostics (8 sensors)
- Battery voltage detection with history
- Acceleration performance tests
- Emission readiness checking
- Multi-vehicle management

### Connection Support
- **TCP/IP**: Connect to emulator or WiFi OBD adapter
- **Bluetooth Low Energy (BLE)**: Wireless OBD connection
- **Demo Mode**: Simulated data for testing without hardware

## Installation

```bash
flutter pub get
flutter run
```

## Project Structure

```
lib/
├── screens/          # Application screens
├── services/         # Business logic (OBD client, connection manager)
├── models/           # Data models
└── widgets/          # Reusable UI components
```

## Key Dependencies

- `syncfusion_flutter_gauges`: Dashboard gauges
- `fl_chart`: Data visualization charts
- `flutter_blue_plus`: Bluetooth Low Energy support
- `hive`: Local database
- `shared_preferences`: Settings storage

## Architecture

- **ConnectionManager**: Centralized connection management with persistence
- **ObdClient**: OBD-II protocol implementation
- **Smart PID Polling**: Only polls required PIDs for current screen
- **Immediate Poll**: Automatic polling on screen navigation

## Platform Support

- ✅ Android
- ✅ iOS  
- ✅ Windows
- ✅ Linux
- ✅ macOS
- ✅ Web

## Development

### iOS Build

```bash
cd ios
pod install
cd ..
flutter build ios
```

**Requirements:**
- Mac with Xcode
- CocoaPods: `sudo gem install cocoapods`
- Apple Developer Account (for device testing)

**Configuration:**
- Bundle ID: `com.kahastudio.obd2scanner`
- Bluetooth permissions configured
- App Transport Security configured (allows HTTP for OBD emulator)

### Icon Setup

1. Place `app_icon.png` (1024x1024 px) in `assets/icon/`
2. Run: `flutter pub run flutter_launcher_icons`
3. Rebuild: `flutter clean && flutter pub get && flutter run`

See [SETUP_ICON.md](SETUP_ICON.md) for details.

## Notes

- Connection is maintained across screen navigation
- Only disconnects on user action or app termination
- Demo mode works completely offline

## Documentation

- **[../README.md](../README.md)** - Project overview
- **[../OBD_REFERENCE.md](../OBD_REFERENCE.md)** - Complete OBD-II protocol reference
- **[../CHANGELOG.md](../CHANGELOG.md)** - Version history
