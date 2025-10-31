# OBD-II/SAE J1979 – Freeze Frame Standard for Emulator and App

## Objective
Define a unified contract to capture and serve Freeze Frame data (Mode 02) between the emulator and the Flutter app, staying close to SAE J1979. Ensures consistent capture, encoding, and decoding.

## Scope
- Mode 02 requests for Freeze Frame data.
- Snapshot timing: when a DTC is set (recommended) or via manual capture for testing.
- Minimal PID set for the snapshot and response format.

## Minimal PID Snapshot
Capture at least the following Mode 01 PIDs at the moment of DTC:
- 010C (Engine RPM)
- 010D (Vehicle Speed)
- 0105 (Engine Coolant Temp)
- 010F (Intake Air Temp)
- 0110 (MAF)
- 0111 (Throttle Position)

These are sufficient to provide useful context around the fault.

## Response Format (Mode 02)
- Command: `02 xx` (where `xx` is a PID from the snapshot set)
- Emulator Response: `42 xx <DATA_BYTES>`
  - Replace Mode 01 header `41` with `42`
  - `<DATA_BYTES>` identical to Mode 01 encoding for the same PID
- If no Freeze Frame captured or PID not in snapshot → `NO DATA`

Examples:
- Request: `020C` → Response: `42 0C AABB` (same data bytes as `010C` but with `42` prefix)
- Request: `0211` → Response: `42 11 AA` (same as `0111` encoding)

## Emulator Behavior
- Maintain an internal snapshot map: `{ '010C': '41 0C AABB', '010D': '41 0D AA', ... }`
- On capture (either when a DTC is set, or via manual REST endpoint), fill this map with current Mode 01 encoded values.
- On Mode 02 command, look up the corresponding Mode 01 PID and return `42` response.
- On Mode 04 (Clear DTCs), clear the Freeze Frame snapshot.

### REST (for Web UI testing)
- `GET /api/freeze-frame` → `{ snapshot: { '010C': '41 0C AABB', ... } | null }`
- `POST /api/freeze-frame/capture` → `{ success: true, snapshot: {...} }`
- `POST /api/freeze-frame/clear` → `{ success: true }`

## App Decoding Rules
- For `02 xx` responses, decode using the same formulas as Mode 01 PIDs (from `OBD_PID_STANDARD.md`).
- If `NO DATA`, show empty state indicating there is no snapshot captured.

## Acceptance Checklist
1. Emulator returns `42 xx ...` for the minimal PID set after snapshot exists.
2. App issues `02 0C/0D/05/0F/10/11` and decodes values correctly.
3. Mode 04 clears snapshot; subsequent `02 xx` returns `NO DATA`.
4. Web UI shows current snapshot and allows manual capture/clear.
