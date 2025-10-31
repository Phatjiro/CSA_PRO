## OBD-II/SAE J1979 – Encoding/Decoding spec for Emulator and App

Goal: The emulator and the Flutter app follow one unified spec (close to SAE J1979), so values match a real ELM327 + vehicle for the supported PIDs.

General notes
- Mode 01 – Current Data, responses are `41 xx ...` where `xx` is the PID.
- Byte A, B, (C, D) are data bytes in order.
- Some PIDs have mandatory range/quantization (e.g., Fuel Pressure uses multiples of 3 kPa).
- Emulator MUST ENCODE with formulas below; App MUST DECODE with the corresponding formulas.

Core PIDs (Mode 01)

| PID  | Name | App decoding formula | Emulator encoding formula | Unit | Range/Notes |
|------|------|----------------------|---------------------------|------|-------------|
| 010C | Engine RPM | RPM = ((256×A)+B)/4 | (A,B) = round(RPM×4) split into 2 bytes | rpm | 0–16383.75 |
| 010D | Vehicle Speed | Speed = A | A = clamp(0..255) | km/h | 0–255 |
| 0105 | Coolant Temp | Temp = A − 40 | A = Temp + 40 | °C | −40..215 |
| 010F | Intake Air Temp | Temp = A − 40 | A = Temp + 40 | °C | −40..215 |
| 0146 | Ambient Air Temp | Temp = A − 40 | A = Temp + 40 | °C | −40..215 |
| 0110 | MAF Air Flow | MAF = ((256×A)+B)/100 | (A,B) = round(MAF×100) | g/s | 0–655.35 |
| 0111 | Throttle Position | % = 100×A/255 | A = round(%×255/100) | % | 0–100 (encoded 0..255) |
| 012F | Fuel Level | % = 100×A/255 | A = round(%×255/100) | % | 0–100 (encoded 0..255) |
| 0142 | Control Module Voltage | V = ((256×A)+B)/1000 | (A,B) = round(V×1000) | V | ~0–65.535 |
| 0103 | Fuel System Status | Status = A | A = status code | code | SAE standard values |
| 010E | Timing Advance | Adv = A/2 − 64 | A = round((Adv+64)×2) | ° | −64..+63.5 |
| 011F | Runtime Since Start | t = 256×A + B | (A,B) = split t | s | 0–65535 |
| 0121 | Distance with MIL | d = 256×A + B | (A,B) = split d | km | 0–65535 |
| 012E | Commanded Evap Purge | % = A | A = round(%) | % | 0–100 |
| 0130 | Warm-ups Since Clear | n = A | A = n | count | 0–255 |
| 0131 | Distance Since Clear | d = 256×A + B | (A,B) = split d | km | 0–65535 |
| 0143 | Absolute Load | % = A | A = round(%) | % | 0–100 |
| 0144 | Commanded Equiv. Ratio | ER = ((256×A)+B) | (A,B) = round(ER) | — | ECU dependent |
| 0145 | Relative Throttle | % = A | A = round(%) | % | 0–100 |
| 0147 | Abs Throttle B | % = A | A = round(%) | % | 0–100 |
| 0148 | Abs Throttle C | % = A | A = round(%) | % | 0–100 |
| 0149 | Pedal Position D | % = A | A = round(%) | % | 0–100 |
| 014A | Pedal Position E | % = A | A = round(%) | % | 0–100 |
| 014B | Pedal Position F | % = A | A = round(%) | % | 0–100 |
| 014C | Commanded Throttle Actuator | % = A | A = round(%) | % | 0–100 |
| 014D | Time run with MIL | t = 256×A + B | (A,B) = split t | s | 0–65535 |
| 014E | Time since codes cleared | t = 256×A + B | (A,B) = split t | s | 0–65535 |
| 014F | Max Equiv. Ratio | ERmax = ((256×A)+B) | (A,B) = round(ERmax) | — | ECU dependent |
| 0150 | Max Air Flow | max = 256×A + B | (A,B) = round(max) | g/s | 0–65535 |
| 0151 | Fuel Type | type = A | A = fuel type code | code | SAE standard |
| 0152 | Ethanol Fuel % | % = A | A = round(%) | % | 0–100 |
| 0153 | Abs Evap System Vapor Pressure | p = 256×A + B | (A,B) = round(p) | Pa/kPa | per definition |
| 0154 | Evap System Vapor Pressure | p = 256×A + B | (A,B) = round(p) | Pa/kPa | per definition |
| 015E | O2 Sensor 1 λ (equiv. ratio) | λ = ((256×A)+B)/32768 | (A,B) = round(λ×32768) | ratio | ≈0.7–2.0 |

Catalyst Temperatures (Mode 01)

| PID  | Name | App decoding formula | Emulator encoding formula | Unit | Notes |
|------|------|----------------------|---------------------------|------|-------|
| 013C | Catalyst Temp B1S1 | T = ((256×A)+B)/10 − 40 | (A,B) = round((T+40)×10) | °C | Cat Temp 1 |
| 013D | Catalyst Temp B1S2 | T = ((256×A)+B)/10 − 40 | (A,B) = round((T+40)×10) | °C | Cat Temp 2 |
| 013E | Catalyst Temp B2S1 | T = ((256×A)+B)/10 − 40 | (A,B) = round((T+40)×10) | °C | Cat Temp 3 |
| 013F | Catalyst Temp B2S2 | T = ((256×A)+B)/10 − 40 | (A,B) = round((T+40)×10) | °C | Cat Temp 4 |

Fuel Pressure

| PID  | Name | App decoding formula | Emulator encoding formula | Unit | Notes |
|------|------|----------------------|---------------------------|------|-------|
| 010A | Fuel Pressure | P = 3×A | A = round(P/3) | kPa | Multiples of 3 kPa only |

Emulator <-> App synchronization
- Emulator: always encode with “Emulator encoding formula”, and keep value within valid range/quantization (e.g., Fuel Pressure quantized to 3 kPa; Timing Advance encoded as A = round((adv+64)×2)).
- App: only decode after confirming the `41 xx` frame for the requested PID; do not fallback to bytes from unrelated PID. Use `>` prompt as packet delimiter.

Differences vs real vehicles
- Some PIDs may vary by manufacturer (e.g., 0143..0154). The table follows common/SAE usage where available.
- If values beyond standard ranges are needed (e.g., Speed > 255), use extended/proprietary or custom PIDs, not standard 010D.

Checklist
1) Emulator – each PID encodes correctly, respects range and quantization.
2) App – decodes correctly, reads correct PID (`41 xx`), frames by `>` prompt.
3) Static mode – set values within domain and quantization (e.g., 321 kPa, not 320).
4) Cross-check – compare App vs Emulator UI at the same time for PIDs above.


