## OBD-II DTC Modes – Emulator/App Contract (03/07/0A/02/04)

Scope: Define a consistent contract between emulator and app for Diagnostic Trouble Codes (DTCs) and related modes, following SAE J1979 format where applicable.

### Roles
- Emulator: generates/maintains DTC state, encodes responses for modes 03/07/0A/02/04, keeps Mode 01 PID 01 (MIL/Readiness) in sync.
- App: issues mode commands, parses responses, displays Stored/Pending/Permanent DTCs, Freeze Frame snapshot, handles Clear.

### Data model (emulator)
- MIL (boolean): check engine lamp state (on/off)
- DTC sets:
  - Stored/Confirmed (Mode 03)
  - Pending (Mode 07)
  - Permanent (Mode 0A)
- Freeze Frame (Mode 02): snapshot of key PIDs at DTC set time (at minimum: 010C RPM, 010D speed, 0105 ECT, 010F IAT, 0110 MAF, 0111 throttle)

### DTC code encoding (SAE format)
- Code string: P/C/B/U + 4 hex (e.g., P0301)
- Two-byte encoding to payload (A,B):
  - Use 2 bits for system (P=0, C=1, B=2, U=3) in A[7:6]
  - The remaining nibbles are the 4 hex digits of the code
- Multiple codes are concatenated as pairs of bytes

### Mode framing and headers
- Mode 03 → header `43` followed by pairs for Stored DTCs
- Mode 07 → header `47` followed by pairs for Pending DTCs
- Mode 0A → header `4A` followed by pairs for Permanent DTCs
- If no codes → return `NO DATA`

### Mode 04 – Clear DTCs
- On clear:
  - Stored and Pending sets are cleared
  - MIL set to OFF
  - Readiness (Mode 01 PID 01) reset appropriately
  - Freeze Frame cleared
- Response: `44` (or `OK` in some ELM variants; we standardize on `44`)

### Mode 02 – Freeze Frame
- Returns snapshot values of selected PIDs using Mode-01 style pairs but under Mode 02 semantics
- Minimum set to include: 010C, 010D, 0105, 010F, 0110, 0111
- App decodes using the same formulas as Mode 01 tables

### Mode 01 PID 01 – MIL and Readiness sync
- Byte A: bit7 = MIL (1 on), bits6..0 = DTC count (Stored)
- Emulator MUST update `41 01` immediately when DTC state changes (e.g., after Mode 04)

### App parsing rules
- Do not attempt to infer codes from Mode 01; always use modes 03/07/0A
- For `NO DATA`, show empty state with a hint (e.g., no codes present)
- After 04, refresh 01 01, 03, 07, 0A, and 02

### Examples
- Stored: `43 01 03 01 04 20` → P0301, P0420
- Pending: `47 01 71` → P0171
- Permanent: `4A 01 03 01` → P0301
- Clear: `44`

### Emulator UI (optional reference)
- DTC section: buttons for Stored/Pending/Permanent and Clear; MIL status displayed; list codes
- REST endpoints (for web UI only, not part of ELM contract):
  - GET `/api/dtc/stored|pending|permanent` → `{ codes: string[], milOn: boolean }`
  - POST `/api/dtc/clear` → `{ success: true, milOn: boolean }`

### Acceptance checklist
- App lists Stored/Pending/Permanent accurately; `NO DATA` handled gracefully
- Freeze Frame decodes with Mode 01 formulas
- Clear (04) flips MIL off (unless codes re-appear), resets readiness, clears FF
- PID 0101 reflects MIL and count

### Notes
- Permanent DTCs normally require drive cycles and specific criteria to clear; emulator may provide a test flag to force-clear for demos.
