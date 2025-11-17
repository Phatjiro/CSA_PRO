# Flutter Car Scanner

Cross-platform OBD-II car scanner application for vehicle diagnostics and monitoring.

## Features

### Core Functionality
- Real-time live data dashboard with gauges and charts
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

## Notes

- Connection is maintained across screen navigation
- Only disconnects on user action or app termination
- Demo mode works completely offline
