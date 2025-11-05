# CSA_PRO - Car Scanner & OBD Development Project

A comprehensive OBD-II car scanner solution with ELM327 emulator and Flutter mobile application.

## Project Structure

```
CSA_PRO/
├── obd-emulator/           # OBD ELM327 Emulator (Node.js)
├── flutter-car-scanner/    # Flutter Car Scanner App
└── README.md
```

## Components

### OBD ELM327 Emulator

Node.js-based emulator that simulates ELM327 OBD-II adapters for development and testing.

**Features:**
- Web interface for configuration and monitoring
- TCP server for OBD-II connections
- Supports 200+ OBD PIDs (Mode 01, 02, 03, 04, 06, 09)
- Real-time data streaming
- REST API for configuration

**Quick Start:**
```bash
cd obd-emulator
npm install
npm start
```
Access web interface at `http://localhost:3000`

### Flutter Car Scanner App

Cross-platform mobile application for OBD-II diagnostics and vehicle monitoring.

**Key Features:**
- **Live Data**: Real-time dashboard with gauges and charts
- **Diagnostics**: Read/clear DTCs, freeze frame analysis, MIL status
- **Testing**: Mode 06 scan, O2 sensor test, battery detection, acceleration tests
- **Emission**: Readiness monitors, emission compliance checking
- **Vehicle Management**: Multi-vehicle support, maintenance tracking
- **Connection**: TCP/IP, Bluetooth Low Energy (BLE), Demo mode

**Quick Start:**
```bash
cd flutter-car-scanner
flutter pub get
flutter run
```

## Connection Options

1. **TCP**: Connect to emulator or WiFi OBD adapter
2. **BLE**: Bluetooth Low Energy connection
3. **Demo**: Simulated data mode (no hardware required)

## Technology Stack

- **Backend**: Node.js, Express, Socket.IO
- **Frontend**: Flutter, Dart
- **Database**: Hive (local storage)
- **Charts**: Flutter Chart, Syncfusion Gauges

## Supported Platforms

- Android
- iOS
- Windows
- Linux
- macOS
- Web

## Features

✅ Live data monitoring with real-time updates  
✅ Diagnostic trouble code (DTC) reading and clearing  
✅ Freeze frame analysis  
✅ Component testing (Mode 06)  
✅ O2 sensor diagnostics  
✅ Battery voltage monitoring  
✅ Emission readiness checking  
✅ Multi-vehicle management  
✅ Connection persistence across screens

## License

This project is developed by CSA_PRO team.
