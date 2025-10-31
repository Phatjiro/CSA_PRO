# OBD-II/SAE J1979 – Mode 06 (On-board Monitoring) Standard for Emulator and App

## Objective
Define a unified contract for Service 06 (on-board monitoring test results) between the Emulator and the Flutter app. Keep it simple and predictable for demos while staying close to SAE J1979.

## Scope
- Commands: `0600` (supported TIDs) and `06xx` (query a specific Test ID).
- Demo dataset (a few representative tests). Real vehicles expose many more; this spec focuses on a minimal, consistent set.

## Response Format
- `0600` → list supported TIDs
  - Emulator response: `46 00 ...` followed by a list of supported TIDs (space-separated) for robustness in tools.
  - Example (demo): `46 00 01 02 03`

- `06xx` → a single test result
  - Emulator response: `46 xx vA vB minA minB maxA maxB`
    - `value = 256×vA + vB`
    - `min   = 256×minA + minB`
    - `max   = 256×maxA + maxB`
  - PASS criteria: `min ≤ value ≤ max`
  - If unknown TID: `NO DATA`

Notes:
- Some tools expect more elaborate frames (e.g., MID, multiple CIDs per TID). For demo, we standardize on the compact form above.

## Emulator Encoding (Demo)
- Supported TIDs and meanings:
  - `01` – Catalyst B1S1: value/min/max (16-bit), unit-less demo number
  - `02` – O2 Sensor B1S1
  - `03` – EVAP Leak Test
- Value ranges are synthetic but stable; can be randomized slightly if needed (future option).
- REST for web UI:
  - `GET /api/mode06` → `{ tests: [{ tid, name, value, min, max, pass }] }`

## App Decoding
- For `0600`: parse supported TID list for UI navigation (optional).
- For `06xx`:
  1) Join high/low bytes → value/min/max (unsigned 16-bit)
  2) PASS if `value` within `[min, max]`, else FAIL
  3) Display: `TID – Name` with `value (min..max)` and PASS/FAIL badge

## Acceptance Checklist
1. Emulator returns predictable values for `0600`, `0601`, `0602`, `0603`.
2. App decodes 16‑bit numbers, compares to thresholds, and renders PASS/FAIL correctly.
3. Web UI Mode 06 panel shows the same PASS/FAIL as the app for the same tests.
4. Unknown/unsupported TIDs return `NO DATA` and are handled gracefully by the app.

## Future Extensions (Non-blocking)
- Add more TIDs and bank/sensor variants (B2S1, S2, etc.).
- Per‑engine‑type profiles (spark vs compression) with additional tests.
- Randomized or time‑varying values to simulate real monitoring behavior.
