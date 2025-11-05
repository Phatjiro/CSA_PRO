# OBD-II / SAE J1979 – Unified Protocol Standard (Emulator ↔ App)

Purpose: One concise contract for emulator encoding and app decoding, aligned with SAE J1979, to keep demo behavior consistent with real ELM327 devices.

## Mode 01 – Current Data (Selected Core PIDs)

| PID  | Name | App decoding | Emulator encoding | Unit | Notes |
|------|------|--------------|-------------------|------|-------|
| 010C | Engine RPM | ((256×A)+B)/4 | (A,B)=round(RPM×4) | rpm | 0–16383.75 |
| 010D | Vehicle Speed | A | A=clamp(0..255) | km/h | 0–255 |
| 0105 | Coolant Temp | A−40 | A=Temp+40 | °C | −40..215 |
| 010F | Intake Air Temp | A−40 | A=Temp+40 | °C | −40..215 |
| 0146 | Ambient Air Temp | A−40 | A=Temp+40 | °C | −40..215 |
| 0110 | MAF Air Flow | ((256×A)+B)/100 | (A,B)=round(MAF×100) | g/s | 0–655.35 |
| 0111 | Throttle Position | 100×A/255 | A=round(%×255/100) | % | 0–100 |
| 012F | Fuel Level | 100×A/255 | A=round(%×255/100) | % | 0–100 |
| 0142 | Control Module Voltage | ((256×A)+B)/1000 | (A,B)=round(V×1000) | V | ~0–65.535 |
| 0103 | Fuel System Status | A (code) | A=status code | code | SAE codes |
| 010E | Timing Advance | A/2 − 64 | A=round((adv+64)×2) | ° | −64..+63.5 |
| 011F | Runtime Since Start | 256×A+B | (A,B)=split sec | s | 0–65535 |
| 0121 | Distance with MIL | 256×A+B | (A,B)=split km | km | 0–65535 |
| 012E | Commanded Evap Purge | A | A=round(%) | % | 0–100 |
| 0130 | Warm-ups Since Clear | A | A=n | count | 0–255 |
| 0131 | Distance Since Clear | 256×A+B | (A,B)=split km | km | 0–65535 |
| 0143 | Absolute Load | A | A=round(%) | % | 0–100 |
| 0144 | Commanded Equiv. Ratio | (256×A)+B | (A,B)=round(ER) | — | ECU dep. |
| 0151 | Fuel Type | A | A=fuel type code | code | SAE |
| 0152 | Ethanol Fuel % | A | A=round(%) | % | 0–100 |
| 010A | Fuel Pressure | 3×A | A=round(P/3) | kPa | multiples of 3 |

O2 Sensors (examples)
- 0114..011B: V = A/200, STFT = B/1.28 − 100; encoder does inverse rounding.

Catalyst Temperatures (examples)
- 013C..013F: T = ((256×A)+B)/10 − 40; encoder does inverse.

Sync rules
- Emulator must respect ranges/quantization; App decodes only `41 xx` frames for requested PIDs and uses `>` prompt as frame delimiter.

## Mode 02 – Freeze Frame

Objective: Provide a minimal snapshot when a DTC is set (or manually captured for testing).

Minimal PID set to capture at snapshot time:
- 010C (RPM), 010D (Speed), 0105 (Coolant), 010F (IAT), 0110 (MAF), 0111 (Throttle)

Response format:
- Request: `02 xx`
- Response: `42 xx <DATA_BYTES>` (same data bytes as Mode 01 for the PID; only header changes from `41`→`42`)
- If no snapshot or PID not captured → `NO DATA`

Emulator behavior:
- Maintain snapshot map from Mode 01 encoded values; clear snapshot on Mode 04 (Clear DTCs).

App decoding:
- Decode `42 xx` using the same formulas as Mode 01 for that PID; show empty state on `NO DATA`.

## Mode 06 – On-board Monitoring (Service 06)

Scope: Keep compact, predictable demo set while staying close to J1979.

Supported commands:
- `0600` → supported TIDs list
  - Example: `46 00 01 02 03`
- `06xx` → single test result frame:
  - `46 xx vA vB minA minB maxA maxB`
  - value = 256×vA + vB; min/max similarly
  - PASS if `min ≤ value ≤ max`; unknown TID → `NO DATA`

App decoding:
- Parse 16‑bit values, compare to thresholds, render PASS/FAIL.

Acceptance checklist:
1) Emulator returns predictable `0600`, `0601`, `0602`, `0603`.
2) App renders PASS/FAIL consistent with thresholds.
3) Unknown TIDs handled gracefully.

## Notes & Differences
- Some PIDs vary by manufacturer; this spec follows common SAE definitions.
- For values outside standard ranges, use proprietary/custom PIDs (not standard 01xx).

## Related
- Keep `OBD_DTC_STANDARD.md` as the authoritative document for DTC formats, modes 03/07/0A, and clearing (Mode 04).
