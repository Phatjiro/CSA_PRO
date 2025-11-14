# 🚗 OBD-II Complete Standard - App & Emulator Contract

## 📋 Purpose
Unified reference for **OBD-II protocol** covering Mode 01 PIDs, DTCs (Mode 03/07/0A/04), Freeze Frame (Mode 02), and Mode 06 monitoring. Ensures consistency between Flutter app and Node.js emulator.

---

## Mode 01 - Live Data PIDs

Complete list of Mode 01 PIDs following SAE J1979 standard.

### Standard PIDs (0x00-0x1F)

| PID | Name | Formula | Unit | Range | Notes |
|-----|------|---------|------|-------|-------|
| `0100` | PIDs supported [01-20] | Bitmap | - | - | 4 bytes |
| `0101` | Monitor status since DTCs cleared | - | - | - | MIL + readiness |
| `0102` | Freeze DTC | - | - | - | - |
| `0103` | Fuel system status | A | code | 1-16 | SAE codes |
| `0104` | Calculated engine load | A×100/255 | % | 0-100 | - |
| `0105` | Engine coolant temperature | A-40 | °C | -40 to 215 | - |
| `0106` | Short term fuel trim—Bank 1 | (A-128)×100/128 | % | -100 to +99.2 | - |
| `0107` | Long term fuel trim—Bank 1 | (A-128)×100/128 | % | -100 to +99.2 | - |
| `0108` | Short term fuel trim—Bank 2 | (A-128)×100/128 | % | -100 to +99.2 | - |
| `0109` | Long term fuel trim—Bank 2 | (A-128)×100/128 | % | -100 to +99.2 | - |
| `010A` | Fuel pressure | A×3 | kPa | 0-765 | - |
| `010B` | Intake manifold absolute pressure | A | kPa | 0-255 | - |
| `010C` | Engine RPM | ((A×256)+B)/4 | rpm | 0-16383.75 | - |
| `010D` | Vehicle speed | A | km/h | 0-255 | - |
| `010E` | Timing advance | (A-128)/2 | ° | -64 to +63.5 | Before TDC |
| `010F` | Intake air temperature | A-40 | °C | -40 to 215 | - |
| `0110` | MAF air flow rate | ((A×256)+B)/100 | g/s | 0-655.35 | - |
| `0111` | Throttle position | A×100/255 | % | 0-100 | - |
| `0112` | Commanded secondary air status | A | code | - | - |
| `0113` | Oxygen sensors present | Bitmap | - | - | 2 banks |
| `0114` | O2 Sensor 1 | V=A/200, Trim=(B-128)×100/128 | V, % | 0-1.275V | Bank 1 |
| `0115` | O2 Sensor 2 | V=A/200, Trim=(B-128)×100/128 | V, % | 0-1.275V | Bank 1 |
| `0116` | O2 Sensor 3 | V=A/200, Trim=(B-128)×100/128 | V, % | 0-1.275V | Bank 1 |
| `0117` | O2 Sensor 4 | V=A/200, Trim=(B-128)×100/128 | V, % | 0-1.275V | Bank 1 |
| `0118` | O2 Sensor 5 | V=A/200, Trim=(B-128)×100/128 | V, % | 0-1.275V | Bank 2 |
| `0119` | O2 Sensor 6 | V=A/200, Trim=(B-128)×100/128 | V, % | 0-1.275V | Bank 2 |
| `011A` | O2 Sensor 7 | V=A/200, Trim=(B-128)×100/128 | V, % | 0-1.275V | Bank 2 |
| `011B` | O2 Sensor 8 | V=A/200, Trim=(B-128)×100/128 | V, % | 0-1.275V | Bank 2 |
| `011C` | OBD standards | A | code | 1-36 | SAE J1979 |
| `011D` | O2 sensors present | Bitmap | - | - | 4 banks |
| `011E` | Auxiliary input status | A | - | - | PTO status |
| `011F` | Run time since engine start | (A×256)+B | s | 0-65535 | - |

### Extended PIDs (0x20-0x3F)

| PID | Name | Formula | Unit | Range | Notes |
|-----|------|---------|------|-------|-------|
| `0120` | PIDs supported [21-40] | Bitmap | - | - | 4 bytes |
| `0121` | Distance traveled with MIL on | (A×256)+B | km | 0-65535 | - |
| `012E` | Commanded evaporative purge | A×100/255 | % | 0-100 | - |
| `012F` | Fuel tank level input | A×100/255 | % | 0-100 | - |
| `0130` | Warm-ups since codes cleared | A | count | 0-255 | - |
| `0131` | Distance traveled since codes cleared | (A×256)+B | km | 0-65535 | - |
| `0133` | Absolute barometric pressure | A | kPa | 0-255 | - |
| `013C` | Catalyst Temperature: Bank 1, Sensor 1 | ((A×256)+B)/10-40 | °C | -40 to 6513.5 | - |
| `013D` | Catalyst Temperature: Bank 2, Sensor 1 | ((A×256)+B)/10-40 | °C | -40 to 6513.5 | - |
| `013E` | Catalyst Temperature: Bank 1, Sensor 2 | ((A×256)+B)/10-40 | °C | -40 to 6513.5 | - |
| `013F` | Catalyst Temperature: Bank 2, Sensor 2 | ((A×256)+B)/10-40 | °C | -40 to 6513.5 | - |

### Advanced PIDs (0x40-0x5F)

| PID | Name | Formula | Unit | Range | Notes |
|-----|------|---------|------|-------|-------|
| `0140` | PIDs supported [41-60] | Bitmap | - | - | 4 bytes |
| `0142` | Control module voltage | ((A×256)+B)/1000 | V | 0-65.535 | - |
| `0143` | Absolute load value | ((A×256)+B)×100/255 | % | 0-25700 | - |
| `0144` | Commanded Air-Fuel Equivalence Ratio | ((A×256)+B)/32768 | ratio | 0-2 | Lambda |
| `0145` | Relative throttle position | A×100/255 | % | 0-100 | - |
| `0146` | Ambient air temperature | A-40 | °C | -40 to 215 | - |
| `0147` | Absolute throttle position B | A×100/255 | % | 0-100 | - |
| `0148` | Absolute throttle position C | A×100/255 | % | 0-100 | - |
| `0149` | Accelerator pedal position D | A×100/255 | % | 0-100 | - |
| `014A` | Accelerator pedal position E | A×100/255 | % | 0-100 | - |
| `014B` | Accelerator pedal position F | A×100/255 | % | 0-100 | - |
| `014C` | Commanded throttle actuator | A×100/255 | % | 0-100 | - |
| `014D` | Time run with MIL on | (A×256)+B | min | 0-65535 | - |
| `014E` | Time since trouble codes cleared | (A×256)+B | min | 0-65535 | - |
| `014F` | Maximum value for Equivalence Ratio | A | - | 0-255 | - |
| `0150` | Maximum value for air flow rate | A×10 | g/s | 0-2550 | - |
| `0151` | Fuel Type | A | code | 0-23 | SAE J1979 |
| `0152` | Ethanol fuel % | A×100/255 | % | 0-100 | - |
| `0153` | Absolute Evap system Vapor Pressure | ((A×256)+B)/200 | kPa | 0-327.675 | - |
| `0154` | Evap system vapor pressure | (A×256)+B-32767 | Pa | -32767 to 32768 | - |
| `0155` | Short term secondary O2 trim—Bank 1 | (A-128)×100/128 | % | -100 to +99.2 | - |
| `0156` | Long term secondary O2 trim—Bank 1 | (A-128)×100/128 | % | -100 to +99.2 | - |
| `0157` | Short term secondary O2 trim—Bank 2 | (A-128)×100/128 | % | -100 to +99.2 | - |
| `0158` | Long term secondary O2 trim—Bank 2 | (A-128)×100/128 | % | -100 to +99.2 | - |
| `0159` | Fuel rail absolute pressure | ((A×256)+B)×10 | kPa | 0-655350 | - |
| `015A` | Relative accelerator pedal position | A×100/255 | % | 0-100 | - |
| `015B` | Hybrid battery pack remaining life | A×100/255 | % | 0-100 | - |
| `015C` | **Engine oil temperature** ⚠️ | **A-40** | **°C** | **-40 to 215** | **IMPORTANT** |
| `015D` | Fuel injection timing | ((A×256)+B-26880)/128 | ° | -210 to 301.992 | - |
| `015E` | Engine fuel rate | ((A×256)+B)×0.05 | L/h | 0-3212.75 | - |
| `015F` | Emission requirements | A | code | - | - |

### Extended PIDs (0x60-0x9F)

| PID | Name | Formula | Unit | Range | Notes |
|-----|------|---------|------|-------|-------|
| `0160` | PIDs supported [61-80] | Bitmap | - | - | 4 bytes |
| `0161` | Driver's demand engine - percent torque | A-125 | % | -125 to 130 | - |
| `0162` | Actual engine - percent torque | A-125 | % | -125 to 130 | - |
| `0163` | Engine reference torque | (A×256)+B | Nm | 0-65535 | - |

---

## Mode 03/07/0A - Diagnostic Trouble Codes (DTCs)

### DTC Format
- **String**: P/C/B/U + 4 hex digits (e.g., `P0301`)
- **Encoding**: 2 bytes per code
  - Bits 15-14: System (0=P, 1=C, 2=B, 3=U)
  - Bits 13-12: First digit
  - Bits 11-8: Second digit
  - Bits 7-4: Third digit
  - Bits 3-0: Fourth digit

### Mode 03 - Stored DTCs
- **Request**: `03`
- **Response**: `43 NN AA BB CC DD ...` (NN = count, then pairs)
- **No codes**: `NO DATA` or `43 00`

### Mode 07 - Pending DTCs
- **Request**: `07`
- **Response**: `47 NN AA BB ...`
- **No codes**: `NO DATA`

### Mode 0A - Permanent DTCs
- **Request**: `0A`
- **Response**: `4A NN AA BB ...`
- **No codes**: `NO DATA`

### Mode 04 - Clear DTCs
- **Request**: `04`
- **Response**: `44`
- **Actions**:
  - Clear stored & pending DTCs
  - Turn off MIL
  - Clear freeze frame
  - Reset readiness monitors

---

## Mode 02 - Freeze Frame

### Purpose
Snapshot of key PIDs when DTC is set.

### Minimum PIDs
- `020C` (RPM)
- `020D` (Speed)
- `0205` (Coolant Temp)
- `020F` (IAT)
- `0210` (MAF)
- `0211` (Throttle)

### Response Format
- **Request**: `02XX` (where XX = PID from Mode 01)
- **Response**: `42 XX [DATA]` (same data as Mode 01, header `41` → `42`)
- **No data**: `NO DATA`

---

## Mode 06 - On-board Monitoring

### Test IDs (TIDs)
- **Request**: `06XX`
- **Response**: `46 XX vA vB minA minB maxA maxB`
  - Value = (vA×256)+vB
  - Min = (minA×256)+minB
  - Max = (maxA×256)+maxB
  - **PASS** if min ≤ value ≤ max

### Example TIDs
- `0600`: Supported TIDs
- `0601`: O2 Sensor Response Time
- `0602`: Catalyst Efficiency
- `0603`: EGR Flow

---

## Implementation Checklist

### App (Flutter)
- [x] **78 sensors** (69 PIDs + 9 calculated) - **v1.3.0 UPDATE**
- [x] DTC read/clear (Mode 03/04)
- [x] PID `015C` = Engine Oil Temp
- [x] Async polling with smoothing
- [x] Demo mode with random values
- [x] Parser loại bỏ spaces để xử lý cả "410D40" và "41 0D 40"
- [x] Debug logging cho PIDs quan trọng (010C, 010D, 0105)
- [x] **v1.2.0 CRITICAL FIX**: Mutex serialization cho OBD requests (fix race condition)
- [x] Force enable essential PIDs (010C, 010D, 0105)
- [x] **v1.3.0 NEW**: Thêm 7 sensors (2 Catalyst Temp + 5 Fuel diagnostics)

### Emulator (Node.js)
- [x] **71 PIDs Mode 01** - **v1.2.0 UPDATE**
- [x] DTC support
- [x] Freeze frame
- [x] Mode 06 basic
- [x] **v1.1.0 FIX**: Command normalization (hỗ trợ cả "010D" và "01 0D")
- [x] **v1.1.0 FIX**: Spaces setting logic (khi spaces=false → loại bỏ spaces)
- [x] Test script (`test-emulator.js`) để verify PIDs
- [x] Debug guide (`DEBUG_GUIDE.md`) với troubleshooting chi tiết
- [x] **v1.2.0 NEW**: Thêm 3 Catalyst Temp PIDs (013D, 013E, 013F)

---

## References
- **SAE J1979**: OBD-II standard
- **Wikipedia**: [OBD-II PIDs](https://en.wikipedia.org/wiki/OBD-II_PIDs)
- **ISO 15031**: Diagnostic connector standard

