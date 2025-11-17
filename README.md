# CSA_PRO - Car Scanner & OBD Development Project

A comprehensive OBD-II car scanner solution with ELM327 emulator and Flutter mobile application.

**Current Version:** v1.3.0 (November 13, 2024)

## 🎉 Latest Update (v1.3.0)

**New Features:**
- 🔥 **78 Sensors Total** (69 PIDs + 9 calculated) - Up from 71
- 🌡️ **4-Point Catalyst Monitoring** - Complete temperature coverage
- ⛽ **Professional Fuel Diagnostics** - Fuel Trim analysis + Fuel Pressure
- 🚗 **Enhanced All Sensors Screen** - More comprehensive data for users

See [CHANGELOG.md](CHANGELOG.md) for complete version history.

## Project Structure

```
CSA_PRO/
├── obd-emulator/           # OBD ELM327 Emulator (Node.js)
├── flutter-car-scanner/    # Flutter Car Scanner App
└── README.md
```

## Quick Start

### OBD ELM327 Emulator

Node.js-based emulator that simulates ELM327 OBD-II adapters for development and testing.

**Features:**
- Web interface for configuration and monitoring
- TCP server for OBD-II connections
- **71 PIDs Mode 01** (Live Data) + Modes 02, 03, 04, 06, 09
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
- **Live Data**: Real-time dashboard with gauges and charts - **78 Sensors**
- **All Sensors**: Comprehensive sensor list organized by category
- **Diagnostics**: Read/clear DTCs, freeze frame analysis, MIL status
- **Testing**: Mode 06 scan, O2 sensor test, battery detection, acceleration tests
- **Emission**: Readiness monitors, emission compliance checking
- **Vehicle Management**: Multi-vehicle support, maintenance tracking
- **Connection**: TCP/IP, Bluetooth Low Energy (BLE), Demo mode

**Sensor Categories:**
- 🏎️ **Engine** (10): RPM, Load, Timing, Runtime, etc.
- 🌡️ **Temperature** (8): Coolant, Intake, Catalyst (4-point monitoring)
- ⛽ **Fuel** (12): Level, Pressure, Fuel Trim (short/long term), Ethanol
- 💨 **Air** (4): MAF, MAP, Barometric Pressure
- 🎚️ **Throttle** (8): Position, Commanded, Relative positions
- 🔬 **Advanced** (18): O2 sensors, Control module voltage, etc.
- 🔧 **Calculated** (9): HP, AFR, MPG, 0-100 time, etc.

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

## Documentation

- **[CHANGELOG.md](CHANGELOG.md)** - Version history and updates
- **[OBD_REFERENCE.md](OBD_REFERENCE.md)** - Complete OBD-II protocol reference (PIDs, DTCs, formulas)

## License

This project is developed by CSA_PRO team.
