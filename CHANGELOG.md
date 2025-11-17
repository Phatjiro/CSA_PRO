# Changelog - CSA_PRO (Car Scanner App)

## [1.3.0] - 2024-11-13

### ✨ New Features

**78 Sensors Total** (69 PIDs + 9 calculated) - Up from 71

#### Temperature Category (+2 sensors)
- Catalyst Temp B1S2 (PID 013E)
- Catalyst Temp B2S2 (PID 013F)

#### Fuel Category (+5 sensors)
- Fuel Pressure (PID 010A)
- Short Term Fuel Trim 1 (PID 0106)
- Long Term Fuel Trim 1 (PID 0107)
- Short Term Fuel Trim 2 (PID 0108)
- Long Term Fuel Trim 2 (PID 0109)

#### Emulator Updates
- Added 3 Catalyst Temperature PIDs (013D, 013E, 013F)
- Total PIDs Mode 01: 68 → 71

### 🎯 Benefits

- **4-Point Catalyst Monitoring**: Complete temperature coverage
- **Professional Fuel Diagnostics**: Fuel Trim analysis + Fuel Pressure
- **Enhanced Diagnostics**: Cross-reference Fuel Trim, Lambda, and O2 sensors

---

## [1.2.0] - 2024-11-12

### 🐛 Critical Fixes

- **Race Condition Fix**: Implemented mutex serialization for OBD requests
- Fixed Speed and Coolant Temperature display issues
- Force enable essential PIDs (010C, 010D, 0105)

### ✨ Improvements

- Async polling with smoothing
- Better error handling for critical PIDs
- Enhanced debug logging

---

## [1.1.0] - 2024-11-11

### 🐛 Fixes

- Command normalization (supports both "010D" and "01 0D")
- Spaces setting logic fix
- Parser improvements (handles both "410D40" and "41 0D 40")

### 📝 Documentation

- Added test script (`test-emulator.js`)
- Added debug guide (`DEBUG_GUIDE.md`)

---

## [1.0.0] - 2024-11-10

### 🎉 Initial Release

- Real-time live data monitoring
- Diagnostic trouble code (DTC) reading and clearing
- Freeze frame analysis
- Component testing (Mode 06)
- O2 sensor diagnostics
- Battery voltage monitoring
- Emission readiness checking
- Multi-vehicle management
- Connection persistence across screens
