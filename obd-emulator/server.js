const express = require('express');
const http = require('http');
const socketIo = require('socket.io');
const net = require('net');

const app = express();
const server = http.createServer(app);
const io = socketIo(server);

// Middleware
app.use(express.json());

// Serve static files
app.use(express.static('public'));

// --- DTC State & Helpers ---
const dtcState = {
  stored: ['P0301', 'P0420'],
  pending: ['P0171'],
  permanent: ['P0301'],
  milOn: true,
};

// --- Freeze Frame State ---
// Store encoded responses for selected Mode 01 PIDs at the moment of capture
// e.g. { '010C': '41 0C 1F 40', '010D': '41 0D 40', ... }
let freezeFrame = null;

function captureFreezeFrameFromCurrent() {
  const selected = ['010C','010D','0105','010F','0110','0111'];
  const snap = {};
  for (const pid of selected) {
    if (obdPids[pid]) snap[pid] = obdPids[pid];
  }
  freezeFrame = snap;
  return freezeFrame;
}

function clearFreezeFrame() {
  freezeFrame = null;
}

function injectRandomDtc() {
  const dtcPool = [
    'P0301', 'P0171', 'P0101', 'P0113', 'P0299',
    'P0700', 'P0740', 'P0087', 'C0035', 'C1234',
    'B0028', 'B2010', 'U0100', 'U0123', 'U0155',
    'P0420', 'P0505', 'P0141', 'P0401', 'P0135',
    'C0040', 'C0055', 'U0073', 'B0030', 'B0091',
  ];
  const count = Math.max(1, Math.floor(Math.random() * 3) + 1);
  const codes = new Set();
  while (codes.size < count) {
    codes.add(dtcPool[Math.floor(Math.random() * dtcPool.length)]);
  }
  dtcState.stored = Array.from(codes);
  dtcState.pending = [];
  dtcState.permanent = [];
  dtcState.milOn = true;
  freezeFrame = captureFreezeFrameFromCurrent();
  updatePid0101FromDtc();
  try { io.emit('mil', { milOn: dtcState.milOn, storedCount: dtcState.stored.length }); } catch (e) {}
  return dtcState.stored;
}

function formatFreezeFrameResponse(cmd) {
  // cmd like '020C' -> map to '010C' if snapshot exists
  if (!freezeFrame) return 'NO DATA';
  if (cmd.length < 4) return 'NO DATA';
  const pid01 = '01' + cmd.substring(2, 4);
  const encoded = freezeFrame[pid01];
  if (!encoded) return 'NO DATA';
  // encoded is like '41 0C AA BB' -> replace 41 with 42
  const parts = encoded.trim().split(/\s+/);
  if (parts.length < 2) return 'NO DATA';
  parts[0] = '42';
  return parts.join(' ');
}

// --- Mode 06: On-board monitoring test results (simplified) ---
// Represent a few sample tests with 16-bit value/min/max
const mode06Tests = {
  // TID 01: Catalyst efficiency Bank 1 Sensor 1 (example)
  '01': { name: 'Catalyst B1S1', value: 0x0050, min: 0x0010, max: 0x00F0 },
  // TID 02: O2 Sensor response Bank 1 Sensor 1
  '02': { name: 'O2 Sensor B1S1', value: 0x0032, min: 0x0014, max: 0x0080 },
  // TID 03: EVAP system leak test (example)
  '03': { name: 'EVAP Leak Test', value: 0x000A, min: 0x0000, max: 0x0020 },
};

function formatMode06Supported() {
  // Return a simple bitmap for TIDs 01-20 (A = bits 1..8 → 01..08)
  // Here we set bits for 01..03
  const A = 0b11100000; // bits 1..3 set starting from MSB? For demo, clients usually don't rely strictly
  // To avoid confusion, also append explicit list of supported TIDs
  const supported = Object.keys(mode06Tests).map(k => k.padStart(2, '0')).join(' ');
  // Minimal: many tools accept a simple header-only plus separate queries; we return both styles for robustness
  return `46 00 00 00 00 00 ${supported}`.trim();
}

function formatMode06Tid(tid) {
  const t = mode06Tests[tid];
  if (!t) return 'NO DATA';
  const vA = Math.floor(t.value / 256).toString(16).padStart(2, '0').toUpperCase();
  const vB = (t.value % 256).toString(16).padStart(2, '0').toUpperCase();
  const minA = Math.floor(t.min / 256).toString(16).padStart(2, '0').toUpperCase();
  const minB = (t.min % 256).toString(16).padStart(2, '0').toUpperCase();
  const maxA = Math.floor(t.max / 256).toString(16).padStart(2, '0').toUpperCase();
  const maxB = (t.max % 256).toString(16).padStart(2, '0').toUpperCase();
  // 46 TID value min max (2 bytes each)
  return `46 ${tid} ${vA} ${vB} ${minA} ${minB} ${maxA} ${maxB}`;
}

function encodeDtcPair(code) {
  // code like P0301
  const sysChar = code[0].toUpperCase();
  const sysBits = { P: 0, C: 1, B: 2, U: 3 }[sysChar] ?? 0;
  const d1 = parseInt(code[1], 16) || 0;
  const d2 = parseInt(code[2], 16) || 0;
  const d3 = parseInt(code[3], 16) || 0;
  const d4 = parseInt(code[4], 16) || 0;
  const b1 = ((sysBits & 0x3) << 6) | ((d1 & 0x3) << 4) | (d2 & 0xF);
  const b2 = ((d3 & 0xF) << 4) | (d4 & 0xF);
  return [b1, b2]
    .map(v => v.toString(16).padStart(2, '0').toUpperCase())
    .join(' ');
}

function formatDtcResponse(header, list) {
  if (!list || list.length === 0) return 'NO DATA';
  const payload = list.map(encodeDtcPair).join(' ');
  return `${header} ${payload}`;
}

function updatePid0101FromDtc() {
  const a = (dtcState.milOn ? 0x80 : 0x00) | Math.min(0x7F, (dtcState.stored?.length || 0));
  const aHex = a.toString(16).padStart(2, '0').toUpperCase();
  
  // Dynamic readiness monitors based on DTCs
  const stored = dtcState.stored || [];
  const hasDtcs = stored.length > 0;
  
  // Byte B: Availability bits (0-2 for continuous monitors)
  // All continuous monitors are always available
  let byteB = 0x07; // bits 0,1,2 = misfire, fuel, components available
  
  // Byte C: Completion bits (0-7)
  // Bit 0 = Misfire (incomplete if P0300-P0308)
  // Bit 1 = Fuel System (incomplete if P0171-P0175, P0190-P0199)
  // Bit 2 = Components (incomplete if general P codes)
  // Bit 3 = Catalyst (incomplete if P0420, P0430)
  // Bit 4 = Heated Catalyst (incomplete if P0421, P0431)
  // Bit 5 = Evap System (incomplete if P0440-P0455)
  // Bit 6 = Secondary Air (incomplete if P0410-P0419)
  // Bit 7 = EGR/VVT (incomplete if P0400-P0409, P0010-P0029)
  
  let byteC = 0x00; // Start with all complete (bits = 0 means complete)
  
  if (hasDtcs) {
    // Check for specific DTC patterns
    const hasMisfire = stored.some(dtc => /^P030[0-8]/.test(dtc));
    const hasFuel = stored.some(dtc => /^P017[1-5]|^P019[0-9]/.test(dtc));
    const hasCatalyst = stored.some(dtc => /^P042[0-9]|^P043[0-9]/.test(dtc));
    const hasHeatedCat = stored.some(dtc => /^P042[1-9]|^P043[1-9]/.test(dtc));
    const hasEvap = stored.some(dtc => /^P044[0-9]|^P045[0-9]/.test(dtc));
    const hasSecondaryAir = stored.some(dtc => /^P041[0-9]/.test(dtc));
    const hasEgr = stored.some(dtc => /^P040[0-9]|^P001[0-9]|^P002[0-9]/.test(dtc));
    const hasGeneralP = stored.some(dtc => /^P/.test(dtc));
    
    // Set incomplete bits (1 = incomplete)
    if (hasMisfire) byteC |= 0x01; // bit 0
    if (hasFuel) byteC |= 0x02; // bit 1
    if (hasGeneralP && !hasMisfire && !hasFuel) byteC |= 0x04; // bit 2
    if (hasCatalyst) byteC |= 0x08; // bit 3
    if (hasHeatedCat) byteC |= 0x10; // bit 4
    if (hasEvap) byteC |= 0x20; // bit 5
    if (hasSecondaryAir) byteC |= 0x40; // bit 6
    if (hasEgr) byteC |= 0x80; // bit 7
  }
  
  // Byte D: Completion bits (0-7)
  // Bit 0 = O2 Sensor (incomplete if P0130-P0141, P0150-P0155)
  // Bit 1 = O2 Sensor Heater (incomplete if P0135, P0141, P0155)
  // Bit 2 = EGR/VVT System (same as bit 7 in byte C, but for different systems)
  // Bits 3-7 = Reserved/Other monitors
  
  let byteD = 0x00; // Start with all complete
  
  if (hasDtcs) {
    const hasO2 = stored.some(dtc => /^P013[0-9]|^P014[0-9]|^P015[0-9]/.test(dtc));
    const hasO2Heater = stored.some(dtc => /^P0135|^P0141|^P0155/.test(dtc));
    const hasEgrVvt = stored.some(dtc => /^P040[0-9]|^P001[0-9]|^P002[0-9]/.test(dtc));
    
    if (hasO2) byteD |= 0x01; // bit 0
    if (hasO2Heater) byteD |= 0x02; // bit 1
    if (hasEgrVvt) byteD |= 0x04; // bit 2
  }
  
  const bHex = byteB.toString(16).padStart(2, '0').toUpperCase();
  const cHex = byteC.toString(16).padStart(2, '0').toUpperCase();
  const dHex = byteD.toString(16).padStart(2, '0').toUpperCase();
  
  obdPids['0101'] = `41 01 ${aHex} ${bHex} ${cHex} ${dHex}`;
}

// Emulator configuration & TCP state
let tcpServer;
const connectedClients = [];
const emulatorConfig = {
  elmName: 'ELM327',
  elmVersion: 'v1.2',
  deviceId: 'ELM327',
  vinCode: 'WAUBFGFFXF1001572',
  ecuCount: 2,
  server: '192.168.1.76',
  port: 35000,
  settings: {
    echo: false,
    headers: true,
    dlc: false,
    lineFeed: false,
    spaces: false,  // ← Changed to false by default (no spaces)
    doubleLF: false,
  },
  isRunning: false,
  live: {
    mode: 'random', // 'random' | 'static' | 'acceleration'
    random: {
      engineRPM: { min: 800, max: 4000 },
      vehicleSpeed: { min: 0, max: 120 },
      coolantTemp: { min: 70, max: 100 },
      intakeTemp: { min: 20, max: 45 },
      throttlePosition: { min: 0, max: 80 },
      fuelLevel: { min: 20, max: 100 },
    },
    static: {
      engineRPM: 2000,
      vehicleSpeed: 60,
      coolantTemp: 85,
      intakeTemp: 30,
      throttlePosition: 25,
      fuelLevel: 50,
    },
    acceleration: {
      active: false,
      startSpeed: 0,
      endSpeed: 200,
      duration: 20000, // 20 seconds to go from 0 to 200 km/h
      startTime: null,
    },
  },
};

// OBD PIDs và responses (theo chuẩn SAE J1979)
const obdPids = {
  '0101': '41 01 00 07 25 A0', // Readiness since DTC clear (MIL off, some monitors not completed)
  '0100': '41 00 98 1B A0 13', // Supported PIDs 01-20
  '0103': '41 03 02', // Fuel System Status (Open loop due to driving conditions)
  '0104': '41 04 50', // Calculated Engine Load
  '0105': '41 05 7B', // Engine Coolant Temperature (83°C)
  '0106': '41 06 8F', // Short term fuel % trim - Bank 1
  '0107': '41 07 8F', // Long term fuel % trim - Bank 1
  '0108': '41 08 8F', // Short term fuel % trim - Bank 2
  '0109': '41 09 8F', // Long term fuel % trim - Bank 2
  '010A': '41 0A 8F', // Fuel pressure (kPa)
  '010B': '41 0B 64', // MAP (kPa)
  '010C': '41 0C 1F 40', // Engine RPM (2000 RPM)
  '010D': '41 0D 40', // Vehicle Speed (64 km/h)
  '010E': '41 0E 32', // Timing advance
  '010F': '41 0F 78', // Intake Air Temperature (38°C)
  '0110': '41 10 0F A0', // MAF Air Flow Rate
  '0111': '41 11 0A 8F', // Throttle Position
  // O2 sensor voltages and short-term fuel trims
  // A = voltage * 200 (V), B = short term fuel trim (% = B/1.28 - 100)
  '0114': '41 14 96 80', // O2 B1S1: 0.75 V, 0%
  '0115': '41 15 8C 7C', // O2 B1S2: 0.70 V, ~ -3%
  '0116': '41 16 A0 82', // O2 B1S3: 0.80 V, ~ +1.6%
  '0117': '41 17 00 80', // O2 B1S4: 0.00 V, 0% (unused)
  '0118': '41 18 90 80', // O2 B2S1: 0.72 V, 0%
  '0119': '41 19 88 84', // O2 B2S2: 0.68 V, ~ +3.1%
  '011A': '41 1A 00 80', // O2 B2S3: unused
  '011B': '41 1B 00 80', // O2 B2S4: unused
  '011C': '41 1C 01', // OBD Standards
  '011F': '41 1F 00 1F 40', // Run time since engine start
  '0121': '41 21 00 1F 40', // Distance traveled with MIL on
  '012E': '41 2E 21', // Commanded evaporative purge
  '012F': '41 2F 0F', // Fuel Tank Level Input
  '0130': '41 30 50', // # warm-ups since codes cleared
  '0131': '41 31 00 1F 40', // Distance traveled since codes cleared
  '0133': '41 33 65', // Barometric Pressure (101 kPa)
  '013C': '41 3C 00 1F 40', // Catalyst Temperature Bank 1 Sensor 1
  '013D': '41 3D 00 1E 78', // Catalyst Temperature Bank 2 Sensor 1
  '013E': '41 3E 00 1F D0', // Catalyst Temperature Bank 1 Sensor 2
  '013F': '41 3F 00 1E F0', // Catalyst Temperature Bank 2 Sensor 2
  '0142': '41 42 30 D4', // Control Module Voltage (12.52V default)
  '0143': '41 43 24', // Absolute load value
  '0144': '41 44 0F A0', // Commanded Equivalence Ratio
  '0145': '41 45 28', // Relative throttle position
  '0146': '41 46 0A 8F', // Ambient Air Temperature
  '0147': '41 47 1E', // Absolute throttle position B
  '0148': '41 48 1E', // Absolute throttle position C
  '0149': '41 49 39', // Accelerator pedal position D
  '014A': '41 4A 13', // Accelerator pedal position E
  '014B': '41 4B 1E', // Accelerator pedal position F
  '014C': '41 4C 1F', // Commanded throttle actuator
  '014D': '41 4D 00 1F 40', // Time run with MIL on
  '014E': '41 4E 00 1F 40', // Time since trouble codes cleared
  '014F': '41 4F 80 00', // Maximum value for equivalence ratio
  '0150': '41 50 0F A0', // Maximum value for air flow rate
  '0151': '41 51 01', // Fuel type
  '0152': '41 52 00', // Ethanol fuel %
  '0153': '41 53 00 1F 40', // Absolute evap system vapor pressure
  '0154': '41 54 00 1F 40', // Evap system vapor pressure
  '0155': '41 55 8F', // Short term secondary O2 sensor trim Bank 1
  '0156': '41 56 8F', // Long term secondary O2 sensor trim Bank 1
  '0157': '41 57 8F', // Short term secondary O2 sensor trim Bank 2
  '0158': '41 58 8F', // Long term secondary O2 sensor trim Bank 2
  '0159': '41 59 00 00 E0 20', // Fuel rail absolute pressure: 5754 kPa ((0xE020)*10 = 57440)
  '015A': '41 5A 64', // Relative accelerator pedal position: 39.2% (100/255)
  '015B': '41 5B B3', // Hybrid battery pack remaining life: 70% (179/255)
  '015C': '41 5C 78', // Engine oil temperature: 80°C (120-40=80)
  '015D': '41 5D 69 00', // Fuel injection timing: 0° (26880-26880)/128
  '015E': '41 5E 80 00 00 00', // Engine fuel rate: 0 L/h (lambda=1.00)
  '015F': '41 5F 01', // Emission requirements: OBD-II (CARB)
  '0160': '41 60 00 00 00 00', // PIDs supported [61-80] - bitmap
  '0161': '41 61 8D', // Driver's demand engine torque: 16% (141-125=16)
  '0162': '41 62 8B', // Actual engine torque: 14% (139-125=14)
  '0163': '41 63 05 DC', // Engine reference torque: 1500 Nm (0x05DC=1500)
};

// ensure PID 0101 reflects current DTC state
updatePid0101FromDtc();

// Live data simulation
let liveData = {
  timestamp: new Date().toLocaleTimeString(),
  engineRPM: 0,
  vehicleSpeed: 0,
  coolantTemp: 0,
  intakeTemp: 0,
  throttlePosition: 0,
  fuelLevel: 0,
  engineLoad: 0,
  map: 0,
  baro: 0,
  maf: 0,
  voltage: 0,
  ambient: 0,
  lambda: 0,
  fuelSystemStatus: 0,
  timingAdvance: 0,
  runtimeSinceStart: 0,
  distanceWithMIL: 0,
  commandedPurge: 0,
  warmupsSinceClear: 0,
  distanceSinceClear: 0,
  catalystTemp: 0,
  absoluteLoad: 0,
  commandedEquivRatio: 0,
  relativeThrottle: 0,
  absoluteThrottleB: 0,
  absoluteThrottleC: 0,
  pedalPositionD: 0,
  pedalPositionE: 0,
  pedalPositionF: 0,
  commandedThrottleActuator: 0,
  timeRunWithMIL: 0,
  timeSinceCodesCleared: 0,
  maxEquivRatio: 0,
  maxAirFlow: 0,
  fuelType: 0,
  ethanolFuel: 0,
  absEvapPressure: 0,
  evapPressure: 0,
  shortTermO2Trim1: 0,
  longTermO2Trim1: 0,
  shortTermO2Trim2: 0,
  longTermO2Trim2: 0,
  shortTermO2Trim3: 0,
  longTermO2Trim3: 0,
  shortTermO2Trim4: 0,
  longTermO2Trim4: 0,
  catalystTemp1: 0,
  catalystTemp2: 0,
  catalystTemp3: 0,
  catalystTemp4: 0,
  fuelPressure: 0,
  shortTermFuelTrim1: 0,
  longTermFuelTrim1: 0,
  shortTermFuelTrim2: 0,
  longTermFuelTrim2: 0,
};

// Cập nhật OBD PIDs với dữ liệu thực tế
function updateOBDData(data) {
  // Engine RPM (PID 010C)
  // Formula: RPM = (256*A + B) / 4
  const rpmRaw = data.engineRPM * 4;
  const rpmA = Math.floor(rpmRaw / 256).toString(16).padStart(2, '0').toUpperCase();
  const rpmB = (rpmRaw % 256).toString(16).padStart(2, '0').toUpperCase();
  obdPids['010C'] = `41 0C ${rpmA} ${rpmB}`;

  // Vehicle Speed (PID 010D)
  // Formula: Speed = A
  const speedHex = data.vehicleSpeed.toString(16).padStart(2, '0').toUpperCase();
  obdPids['010D'] = `41 0D ${speedHex}`;

  // Engine Coolant Temperature (PID 0105)
  // Formula: Temp = A - 40
  const ectData = (data.coolantTemp + 40).toString(16).padStart(2, '0').toUpperCase();
  obdPids['0105'] = `41 05 ${ectData}`;

  // Intake Air Temperature (PID 010F)
  // Formula: Data = Temperature + 40
  const iatData = (data.intakeTemp + 40).toString(16).padStart(2, '0').toUpperCase();
  obdPids['010F'] = `41 0F ${iatData}`;

  // Throttle Position (PID 0111)
  // Formula: Position = (Data * 100) / 255
  const throttleData = Math.floor((data.throttlePosition * 255) / 100).toString(16).padStart(2, '0').toUpperCase();
  obdPids['0111'] = `41 11 ${throttleData}`;

  // Fuel Tank Level (PID 012F)
  // Formula: Level = (Data * 100) / 255
  const fuelData = Math.floor((data.fuelLevel * 255) / 100).toString(16).padStart(2, '0').toUpperCase();
  obdPids['012F'] = `41 2F ${fuelData}`;

  // Calculated Engine Load (PID 0104) ~ gần với throttle
  const loadData = Math.floor((data.throttlePosition * 255) / 100).toString(16).padStart(2, '0').toUpperCase();
  obdPids['0104'] = `41 04 ${loadData}`;

  // MAP (PID 010B) kPa - use data.map from sample
  const mapKpa = (typeof data.map === 'number') ? Math.floor(data.map) : 45;
  const mapHex = mapKpa.toString(16).padStart(2, '0').toUpperCase();
  obdPids['010B'] = `41 0B ${mapHex}`;

  // Barometric Pressure (PID 0133) kPa - use data.baro from sample
  const baro = (typeof data.baro === 'number') ? Math.floor(data.baro) : 101;
  obdPids['0133'] = `41 33 ${baro.toString(16).padStart(2, '0').toUpperCase()}`;

  // MAF (PID 0110) - use data.maf from sample
  // Formula: MAF = ((256×A)+B)/100, (A,B) = round(MAF×100)
  const mafGs = (typeof data.maf === 'number') ? data.maf : 25;
  const mafRaw = Math.round(mafGs * 100);
  const mafA = Math.floor(mafRaw / 256).toString(16).padStart(2, '0').toUpperCase();
  const mafB = (mafRaw % 256).toString(16).padStart(2, '0').toUpperCase();
  obdPids['0110'] = `41 10 ${mafA} ${mafB}`;

  // Control Module Voltage (PID 0142)
  // Formula: V = ((256×A)+B)/1000, (A,B) = round(V×1000)
  const voltageV = (typeof data.voltage === 'number') ? data.voltage : (12.5 + Math.sin(Date.now() / 3000) * 0.8 + data.throttlePosition * 0.005);
  const voltageMv = Math.round(voltageV * 1000);
  const vA = Math.floor(voltageMv / 256).toString(16).padStart(2, '0').toUpperCase();
  const vB = (voltageMv % 256).toString(16).padStart(2, '0').toUpperCase();
  obdPids['0142'] = `41 42 ${vA} ${vB}`;

  // Ambient Air Temperature (PID 0146)
  const ambTemp = 27; // cố định
  const ambHex = (ambTemp + 40).toString(16).padStart(2, '0').toUpperCase();
  obdPids['0146'] = `41 46 ${ambHex}`;

  // O2 Sensor 1 Equivalence Ratio (PID 015E)
  // Formula: λ = ((256×A)+B)/32768, (A,B) = round(λ×32768)
  const lambda = (typeof data.lambda === 'number') ? data.lambda : 1.00; // xấp xỉ stoich
  const lambdaRaw = Math.round(lambda * 32768);
  const lamA = Math.floor(lambdaRaw / 256).toString(16).padStart(2, '0').toUpperCase();
  const lamB = (lambdaRaw % 256).toString(16).padStart(2, '0').toUpperCase();
  obdPids['015E'] = `41 5E ${lamA} ${lamB} 00 00`;

  // Fuel System Status (PID 0103)
  obdPids['0103'] = '41 03 02'; // Open loop due to driving conditions

  // Timing Advance (PID 010E) per SAE: decoded = A/2 - 64 -> encode A = round((advance+64)*2)
  const desiredAdvance = (typeof data.timingAdvance === 'number') ? data.timingAdvance : Math.floor(10 + Math.sin(Date.now() / 2000) * 5);
  const advEnc = Math.max(0, Math.min(255, Math.round((desiredAdvance + 64) * 2)));
  obdPids['010E'] = `41 0E ${advEnc.toString(16).padStart(2, '0').toUpperCase()}`;

  // Runtime since engine start (PID 011F) - seconds
  // Formula: t = 256×A + B, (A,B) = t split
  const runtime = Math.round((typeof data.runtimeSinceStart === 'number') ? data.runtimeSinceStart : (Date.now() / 1000 % 65536));
  const runtimeA = Math.floor(runtime / 256).toString(16).padStart(2, '0').toUpperCase();
  const runtimeB = (runtime % 256).toString(16).padStart(2, '0').toUpperCase();
  obdPids['011F'] = `41 1F ${runtimeA} ${runtimeB}`;

  // Distance with MIL on (PID 0121) - km
  // Formula: d = 256×A + B, (A,B) = d split
  const milDistance = Math.round((typeof data.distanceWithMIL === 'number') ? data.distanceWithMIL : (data.vehicleSpeed * 0.1));
  const milA = Math.floor(milDistance / 256).toString(16).padStart(2, '0').toUpperCase();
  const milB = (milDistance % 256).toString(16).padStart(2, '0').toUpperCase();
  obdPids['0121'] = `41 21 ${milA} ${milB}`;

  // Commanded evaporative purge (PID 012E)
  // Formula: % = A, A = round(%)
  const purge = Math.min(100, Math.max(0, Math.round((typeof data.commandedPurge === 'number') ? data.commandedPurge : (20 + data.throttlePosition * 0.3))));
  obdPids['012E'] = `41 2E ${purge.toString(16).padStart(2, '0').toUpperCase()}`;

  // Warm-ups since codes cleared (PID 0130) - use data.warmupsSinceClear from sample
  const warmups = (typeof data.warmupsSinceClear === 'number') ? Math.floor(data.warmupsSinceClear) : 10;
  obdPids['0130'] = `41 30 ${warmups.toString(16).padStart(2, '0').toUpperCase()}`;

  // Distance since codes cleared (PID 0131) - km
  // Formula: d = 256×A + B, (A,B) = d split
  const clearDistance = Math.round((typeof data.distanceSinceClear === 'number') ? data.distanceSinceClear : (data.vehicleSpeed * 0.05));
  const clearA = Math.floor(clearDistance / 256).toString(16).padStart(2, '0').toUpperCase();
  const clearB = (clearDistance % 256).toString(16).padStart(2, '0').toUpperCase();
  obdPids['0131'] = `41 31 ${clearA} ${clearB}`;

  // Catalyst Temperature (PID 013C) - encode per SAE: T = ((256×A)+B)/10 - 40 -> A,B = round((T+40)×10)
  const catTemp = (typeof data.catalystTemp === 'number') ? data.catalystTemp : Math.floor(400 + data.engineRPM * 0.1);
  const catEnc = Math.round((catTemp + 40) * 10);
  const catA = Math.floor(catEnc / 256).toString(16).padStart(2, '0').toUpperCase();
  const catB = (catEnc % 256).toString(16).padStart(2, '0').toUpperCase();
  obdPids['013C'] = `41 3C ${catA} ${catB}`;

  // Absolute load value (PID 0143)
  // Formula: % = A, A = round(%)
  const absLoad = Math.min(100, Math.max(0, Math.round((typeof data.absoluteLoad === 'number') ? data.absoluteLoad : (data.throttlePosition * 0.8))));
  obdPids['0143'] = `41 43 ${absLoad.toString(16).padStart(2, '0').toUpperCase()}`;

  // Commanded Equivalence Ratio (PID 0144)
  // Formula: ER = ((256×A)+B), (A,B) = round(ER)
  const equivRatio = Math.round((typeof data.commandedEquivRatio === 'number') ? data.commandedEquivRatio : (128 + Math.sin(Date.now() / 1000) * 20));
  const equivA = Math.floor(equivRatio / 256).toString(16).padStart(2, '0').toUpperCase();
  const equivB = (equivRatio % 256).toString(16).padStart(2, '0').toUpperCase();
  obdPids['0144'] = `41 44 ${equivA} ${equivB}`;

  // Relative throttle position (PID 0145)
  // Formula: % = A, A = round(%)
  const relThrottle = Math.min(100, Math.max(0, Math.round((typeof data.relativeThrottle === 'number') ? data.relativeThrottle : (data.throttlePosition * 0.9))));
  obdPids['0145'] = `41 45 ${relThrottle.toString(16).padStart(2, '0').toUpperCase()}`;

  // Absolute throttle position B (PID 0147)
  // Formula: % = A, A = round(%)
  const absThrottleB = Math.min(100, Math.max(0, Math.round((typeof data.absoluteThrottleB === 'number') ? data.absoluteThrottleB : (data.throttlePosition * 0.8))));
  obdPids['0147'] = `41 47 ${absThrottleB.toString(16).padStart(2, '0').toUpperCase()}`;

  // Absolute throttle position C (PID 0148)
  // Formula: % = A, A = round(%)
  const absThrottleC = Math.min(100, Math.max(0, Math.round((typeof data.absoluteThrottleC === 'number') ? data.absoluteThrottleC : (data.throttlePosition * 0.7))));
  obdPids['0148'] = `41 48 ${absThrottleC.toString(16).padStart(2, '0').toUpperCase()}`;

  // Accelerator pedal positions (PID 0149-014B)
  // Formula: % = A, A = round(%)
  const pedalD = Math.min(100, Math.max(0, Math.round((typeof data.pedalPositionD === 'number') ? data.pedalPositionD : (data.throttlePosition * 1.2))));
  const pedalE = Math.min(100, Math.max(0, Math.round((typeof data.pedalPositionE === 'number') ? data.pedalPositionE : (data.throttlePosition * 0.6))));
  const pedalF = Math.min(100, Math.max(0, Math.round((typeof data.pedalPositionF === 'number') ? data.pedalPositionF : (data.throttlePosition * 0.8))));
  obdPids['0149'] = `41 49 ${pedalD.toString(16).padStart(2, '0').toUpperCase()}`;
  obdPids['014A'] = `41 4A ${pedalE.toString(16).padStart(2, '0').toUpperCase()}`;
  obdPids['014B'] = `41 4B ${pedalF.toString(16).padStart(2, '0').toUpperCase()}`;

  // Commanded throttle actuator (PID 014C)
  // Formula: % = A, A = round(%)
  const throttleActuator = Math.min(100, Math.max(0, Math.round((typeof data.commandedThrottleActuator === 'number') ? data.commandedThrottleActuator : (data.throttlePosition * 0.9))));
  obdPids['014C'] = `41 4C ${throttleActuator.toString(16).padStart(2, '0').toUpperCase()}`;

  // Time run with MIL on (PID 014D) - seconds
  // Formula: t = 256×A + B, (A,B) = t split
  const milTime = Math.round((typeof data.timeRunWithMIL === 'number') ? data.timeRunWithMIL : (Date.now() / 1000 % 65536));
  const milTimeA = Math.floor(milTime / 256).toString(16).padStart(2, '0').toUpperCase();
  const milTimeB = (milTime % 256).toString(16).padStart(2, '0').toUpperCase();
  obdPids['014D'] = `41 4D ${milTimeA} ${milTimeB}`;

  // Time since trouble codes cleared (PID 014E) - seconds
  // Formula: t = 256×A + B, (A,B) = t split
  const clearTime = Math.round((typeof data.timeSinceCodesCleared === 'number') ? data.timeSinceCodesCleared : (Date.now() / 2000 % 65536));
  const clearTimeA = Math.floor(clearTime / 256).toString(16).padStart(2, '0').toUpperCase();
  const clearTimeB = (clearTime % 256).toString(16).padStart(2, '0').toUpperCase();
  obdPids['014E'] = `41 4E ${clearTimeA} ${clearTimeB}`;

  // Maximum value for equivalence ratio (PID 014F)
  // Formula: ERmax = ((256×A)+B), (A,B) = round(ERmax)
  const maxEquivRatio = Math.round((typeof data.maxEquivRatio === 'number') ? data.maxEquivRatio : 32768);
  const maxEquivA = Math.floor(maxEquivRatio / 256).toString(16).padStart(2, '0').toUpperCase();
  const maxEquivB = (maxEquivRatio % 256).toString(16).padStart(2, '0').toUpperCase();
  obdPids['014F'] = `41 4F ${maxEquivA} ${maxEquivB}`;

  // Maximum value for air flow rate (PID 0150)
  // Formula: max = 256×A + B, (A,B) = round(max) - g/s
  const maxAirFlow = Math.round((typeof data.maxAirFlow === 'number') ? data.maxAirFlow : (mafGs * 1.5));
  const maxAirA = Math.floor(maxAirFlow / 256).toString(16).padStart(2, '0').toUpperCase();
  const maxAirB = (maxAirFlow % 256).toString(16).padStart(2, '0').toUpperCase();
  obdPids['0150'] = `41 50 ${maxAirA} ${maxAirB}`;

  // Fuel type (PID 0151)
  obdPids['0151'] = '41 51 01'; // Gasoline

  // Ethanol fuel % (PID 0152)
  // Formula: % = A, A = round(%)
  const ethanolFuel = Math.min(100, Math.max(0, Math.round((typeof data.ethanolFuel === 'number') ? data.ethanolFuel : 0)));
  obdPids['0152'] = `41 52 ${ethanolFuel.toString(16).padStart(2, '0').toUpperCase()}`;

  // Absolute evap system vapor pressure (PID 0153)
  // Formula: p = 256×A + B, (A,B) = round(p) - Pa/kPa
  const absEvapPressure = Math.round((typeof data.absEvapPressure === 'number') ? data.absEvapPressure : (1000 + Math.sin(Date.now() / 1000) * 200));
  const evapA = Math.floor(absEvapPressure / 256).toString(16).padStart(2, '0').toUpperCase();
  const evapB = (absEvapPressure % 256).toString(16).padStart(2, '0').toUpperCase();
  obdPids['0153'] = `41 53 ${evapA} ${evapB}`;

  // Evap system vapor pressure (PID 0154)
  // Formula: p = 256×A + B, (A,B) = round(p) - Pa/kPa
  const evapPressure = Math.round((typeof data.evapPressure === 'number') ? data.evapPressure : (800 + Math.sin(Date.now() / 1500) * 150));
  const evap2A = Math.floor(evapPressure / 256).toString(16).padStart(2, '0').toUpperCase();
  const evap2B = (evapPressure % 256).toString(16).padStart(2, '0').toUpperCase();
  obdPids['0154'] = `41 54 ${evap2A} ${evap2B}`;

  // O2 sensor trims (PID 0155-015C)
  const o2Trim = Math.floor(-50 + Math.sin(Date.now() / 2000) * 30);
  const o2TrimHex = (o2Trim + 128).toString(16).padStart(2, '0').toUpperCase();
  obdPids['0155'] = `41 55 ${o2TrimHex}`;
  obdPids['0156'] = `41 56 ${o2TrimHex}`;
  obdPids['0157'] = `41 57 ${o2TrimHex}`;
  obdPids['0158'] = `41 58 ${o2TrimHex}`;
  obdPids['0159'] = `41 59 ${o2TrimHex}`;
  obdPids['015A'] = `41 5A ${o2TrimHex}`;
  obdPids['015B'] = `41 5B ${o2TrimHex}`;
  obdPids['015C'] = `41 5C ${o2TrimHex}`;

  // Catalyst temperatures (Mode 01: 013C-013F). Prefer provided values if available
  const catTemp1 = (typeof data.catalystTemp1 === 'number') ? data.catalystTemp1 : Math.floor(400 + data.engineRPM * 0.1);
  const catTemp2 = (typeof data.catalystTemp2 === 'number') ? data.catalystTemp2 : Math.floor(380 + data.engineRPM * 0.08);
  const catTemp3 = (typeof data.catalystTemp3 === 'number') ? data.catalystTemp3 : Math.floor(420 + data.engineRPM * 0.12);
  const catTemp4 = (typeof data.catalystTemp4 === 'number') ? data.catalystTemp4 : Math.floor(390 + data.engineRPM * 0.09);
  
  // Encode per SAE: value = (256*A + B)/10 - 40 -> A,B = ((temp+40)*10)
  const cat1Enc = Math.floor((catTemp1 + 40) * 10);
  const cat1A = Math.floor(cat1Enc / 256).toString(16).padStart(2, '0').toUpperCase();
  const cat1B = (cat1Enc % 256).toString(16).padStart(2, '0').toUpperCase();
  obdPids['013C'] = `41 3C ${cat1A} ${cat1B}`;
  
  const cat2Enc = Math.floor((catTemp2 + 40) * 10);
  const cat2A = Math.floor(cat2Enc / 256).toString(16).padStart(2, '0').toUpperCase();
  const cat2B = (cat2Enc % 256).toString(16).padStart(2, '0').toUpperCase();
  obdPids['013D'] = `41 3D ${cat2A} ${cat2B}`;
  
  const cat3Enc = Math.floor((catTemp3 + 40) * 10);
  const cat3A = Math.floor(cat3Enc / 256).toString(16).padStart(2, '0').toUpperCase();
  const cat3B = (cat3Enc % 256).toString(16).padStart(2, '0').toUpperCase();
  obdPids['013E'] = `41 3E ${cat3A} ${cat3B}`;
  
  const cat4Enc = Math.floor((catTemp4 + 40) * 10);
  const cat4A = Math.floor(cat4Enc / 256).toString(16).padStart(2, '0').toUpperCase();
  const cat4B = (cat4Enc % 256).toString(16).padStart(2, '0').toUpperCase();
  obdPids['013F'] = `41 3F ${cat4A} ${cat4B}`;

  // Fuel pressure (PID 010A)
  // Formula: P = 3×A (kPa), A = round(P/3) - chỉ biểu diễn bội số 3 kPa
  const fpValue = (typeof data.fuelPressure === 'number') ? data.fuelPressure : (300 + data.throttlePosition * 2);
  const fuelAInt = Math.max(0, Math.min(255, Math.round(fpValue / 3))); // lượng tử hóa về bội số 3 kPa
  const fuelA = fuelAInt.toString(16).padStart(2, '0').toUpperCase();
  obdPids['010A'] = `41 0A ${fuelA}`;

  // Fuel trims (PID 0106-0109)
  const fuelTrim = Math.floor(-25 + Math.sin(Date.now() / 3000) * 15);
  const fuelTrimHex = (fuelTrim + 128).toString(16).padStart(2, '0').toUpperCase();
  obdPids['0106'] = `41 06 ${fuelTrimHex}`;
  obdPids['0107'] = `41 07 ${fuelTrimHex}`;
  obdPids['0108'] = `41 08 ${fuelTrimHex}`;
  obdPids['0109'] = `41 09 ${fuelTrimHex}`;
}

// Live data simulation timer
setInterval(() => {
  if (emulatorConfig.isRunning && connectedClients.length > 0) {
    const now = new Date();
    const time = now.getTime();

    const clamp = (v, min = 0, max = Number.MAX_SAFE_INTEGER) => Math.max(min, Math.min(max, v));
    const rnd = (min, max) => Math.floor(Math.random() * (max - min + 1)) + min;

    let sample;
    if (emulatorConfig.live && emulatorConfig.live.mode === 'static') {
      const s = emulatorConfig.live.static || {};
      sample = {
        timestamp: now.toLocaleTimeString(),
        engineRPM: clamp(s.engineRPM ?? 2000, 0, 8000),
        vehicleSpeed: clamp(s.vehicleSpeed ?? 60, 0, 255),
        coolantTemp: clamp(s.coolantTemp ?? 85, -40, 215),
        intakeTemp: clamp(s.intakeTemp ?? 30, -40, 215),
        throttlePosition: clamp(s.throttlePosition ?? 25, 0, 100),
        fuelLevel: clamp(s.fuelLevel ?? 50, 0, 100),
        // phần còn lại giữ ổn định/giá trị hợp lý
        engineLoad: clamp((s.throttlePosition ?? 25), 0, 100),
        map: clamp(40, 10, 255),
        baro: 101,
        maf: clamp(15, 0, 255),
        voltage: 12.5,
        ambient: 27,
        lambda: 1.0,
        fuelSystemStatus: 2,
        timingAdvance: 12,
        runtimeSinceStart: clamp(Math.floor(time / 1000) % 65536, 0, 65535),
        distanceWithMIL: 0,
        commandedPurge: 20,
        warmupsSinceClear: clamp(Math.floor(time / 300000) % 256, 0, 255),
        distanceSinceClear: 0,
        catalystTemp: 450,
        absoluteLoad: clamp(Math.floor((s.throttlePosition ?? 25) * 0.8), 0, 255),
        commandedEquivRatio: 128,
        relativeThrottle: clamp(Math.floor((s.throttlePosition ?? 25) * 0.9), 0, 255),
        absoluteThrottleB: clamp(Math.floor((s.throttlePosition ?? 25) * 0.8), 0, 255),
        absoluteThrottleC: clamp(Math.floor((s.throttlePosition ?? 25) * 0.7), 0, 255),
        pedalPositionD: clamp(Math.floor((s.throttlePosition ?? 25) * 1.2), 0, 255),
        pedalPositionE: clamp(Math.floor((s.throttlePosition ?? 25) * 0.6), 0, 255),
        pedalPositionF: clamp(Math.floor((s.throttlePosition ?? 25) * 0.8), 0, 255),
        commandedThrottleActuator: clamp(Math.floor((s.throttlePosition ?? 25) * 0.9), 0, 255),
        timeRunWithMIL: clamp(Math.floor(time / 1000) % 65536, 0, 65535),
        timeSinceCodesCleared: clamp(Math.floor(time / 2000) % 65536, 0, 65535),
        maxEquivRatio: 128,
        maxAirFlow: 30,
        fuelType: 1,
        ethanolFuel: 0,
        absEvapPressure: 1100,
        evapPressure: 900,
        shortTermO2Trim1: 0,
        longTermO2Trim1: 0,
        shortTermO2Trim2: 0,
        longTermO2Trim2: 0,
        shortTermO2Trim3: 0,
        longTermO2Trim3: 0,
        shortTermO2Trim4: 0,
        longTermO2Trim4: 0,
        catalystTemp1: 450,
        catalystTemp2: 430,
        catalystTemp3: 470,
        catalystTemp4: 440,
        fuelPressure: 320,
        shortTermFuelTrim1: 0,
        longTermFuelTrim1: 0,
        shortTermFuelTrim2: 0,
        longTermFuelTrim2: 0,
      };
    } else if (emulatorConfig.live?.mode === 'acceleration' && emulatorConfig.live?.acceleration?.active) {
      // Acceleration mode: Linear speed increase
      const accel = emulatorConfig.live.acceleration;
      if (!accel.startTime) {
        accel.startTime = Date.now();
      }
      const elapsed = Date.now() - accel.startTime;
      const progress = Math.min(1, elapsed / accel.duration);
      const currentSpeed = Math.floor(accel.startSpeed + (accel.endSpeed - accel.startSpeed) * progress);
      const currentRPM = Math.floor(800 + (currentSpeed / accel.endSpeed) * 4000); // RPM increases with speed
      
      // If completed, reset and deactivate
      if (progress >= 1) {
        accel.active = false;
        accel.startTime = null;
      }
      
      sample = {
        timestamp: now.toLocaleTimeString(),
        engineRPM: clamp(currentRPM, 0, 8000),
        vehicleSpeed: clamp(currentSpeed, 0, 255),
        coolantTemp: clamp(85 + Math.floor(progress * 15), -40, 215), // Heats up during acceleration
        intakeTemp: clamp(30 + Math.floor(progress * 10), -40, 215),
        throttlePosition: clamp(Math.floor(progress * 90), 0, 100), // Wide open throttle
        fuelLevel: clamp(Math.floor(50 - progress * 2), 0, 100),
        engineLoad: clamp(Math.floor(progress * 90), 0, 100),
        map: clamp(Math.floor(80 + progress * 20), 10, 255),
        baro: clamp(Math.floor(98 + Math.sin(time / 4000) * 3), 95, 105),
        maf: clamp(Math.floor(20 + progress * 80 + Math.sin(time / 1000) * 10), 0, 255),
        voltage: clamp(Math.floor(12.5 * 1000 + Math.sin(time / 3000) * 800) / 1000, 10, 16),
        ambient: clamp(Math.floor(25 + Math.sin(time / 5000) * 5), 15, 35),
        lambda: clamp(Math.floor((0.95 + Math.sin(time / 1500) * 0.1) * 100) / 100, 0.8, 1.2),
        fuelSystemStatus: clamp(Math.floor(2 + Math.sin(time / 6000) * 0.5), 1, 3),
        timingAdvance: Math.floor(10 + progress * 20),
        runtimeSinceStart: clamp(Math.floor(time / 1000) % 65536, 0, 65535),
        distanceWithMIL: clamp(Math.floor(time / 5000) % 500, 0, 65535),
        commandedPurge: clamp(Math.floor(20 + progress * 30 + Math.sin(time / 1200) * 5), 0, 100),
        warmupsSinceClear: clamp(Math.floor(5 + Math.sin(time / 18000) * 3), 0, 255),
        distanceSinceClear: clamp(Math.floor(currentSpeed * 0.05), 0, 65535),
        catalystTemp: clamp(Math.floor(400 + progress * 400 + Math.sin(time / 2000) * 50), 0, 65535),
        absoluteLoad: clamp(Math.floor(progress * 90 + Math.sin(time / 800) * 5), 0, 255),
        commandedEquivRatio: clamp(Math.floor((0.98 + Math.sin(time / 1800) * 0.05) * 100) / 100, 0.8, 1.2),
        relativeThrottle: clamp(Math.floor(progress * 90), 0, 255),
        absoluteThrottleB: clamp(Math.floor(progress * 90), 0, 255),
        absoluteThrottleC: clamp(Math.floor(progress * 85), 0, 255),
        pedalPositionD: clamp(Math.floor(progress * 95), 0, 255),
        pedalPositionE: clamp(Math.floor(progress * 80), 0, 255),
        pedalPositionF: clamp(Math.floor(progress * 88), 0, 255),
        commandedThrottleActuator: clamp(Math.floor(progress * 92), 0, 255),
        timeRunWithMIL: clamp(Math.floor(time / 7000) % 300, 0, 65535),
        timeSinceCodesCleared: clamp(Math.floor(time / 2000) % 65536, 0, 65535),
        maxEquivRatio: clamp(Math.floor((1.15 + Math.sin(time / 12000) * 0.15) * 100) / 100, 1.0, 1.5),
        maxAirFlow: clamp(Math.floor(100 + progress * 150 + Math.sin(time / 1500) * 20), 0, 65535),
        fuelType: clamp(Math.floor(1 + Math.sin(time / 25000) * 0.3), 1, 2),
        ethanolFuel: clamp(Math.floor(3 + Math.sin(time / 9000) * 3), 0, 15),
        absEvapPressure: clamp(Math.floor(1000 + progress * 200), 0, 65535),
        evapPressure: clamp(Math.floor(800 + progress * 150), 0, 65535),
        shortTermO2Trim1: Math.floor(-20 + progress * 10),
        longTermO2Trim1: Math.floor(-15 + progress * 8),
        shortTermO2Trim2: Math.floor(-20 + progress * 10),
        longTermO2Trim2: Math.floor(-15 + progress * 8),
        shortTermO2Trim3: clamp(Math.floor(-8 + Math.sin(time / 2200) * 12), -25, 25),
        longTermO2Trim3: clamp(Math.floor(-5 + Math.sin(time / 3400) * 9), -25, 25),
        shortTermO2Trim4: clamp(Math.floor(-6 + Math.sin(time / 2400) * 10), -25, 25),
        longTermO2Trim4: clamp(Math.floor(-3 + Math.sin(time / 3600) * 7), -25, 25),
        catalystTemp1: clamp(Math.floor(400 + progress * 400 + Math.sin(time / 2800) * 60), 0, 65535),
        catalystTemp2: clamp(Math.floor(380 + progress * 380 + Math.sin(time / 3000) * 55), 0, 65535),
        catalystTemp3: clamp(Math.floor(420 + progress * 420 + Math.sin(time / 3200) * 65), 0, 65535),
        catalystTemp4: clamp(Math.floor(390 + progress * 390 + Math.sin(time / 3400) * 58), 0, 65535),
        fuelPressure: clamp(Math.floor(300 + progress * 200 + Math.sin(time / 1100) * 30), 0, 65535),
        shortTermFuelTrim1: Math.floor(-20 + progress * 10),
        longTermFuelTrim1: Math.floor(-15 + progress * 8),
        shortTermFuelTrim2: Math.floor(-20 + progress * 10),
        longTermFuelTrim2: Math.floor(-15 + progress * 8),
      };
    } else {
      const rr = (emulatorConfig.live && emulatorConfig.live.random) || {};
      const r = (k, dmin, dmax) => {
        const cfg = rr[k] || { min: dmin, max: dmax };
        const min = Math.min(cfg.min ?? dmin, cfg.max ?? dmax);
        const max = Math.max(cfg.min ?? dmin, cfg.max ?? dmax);
        return rnd(min, max);
      };
      sample = {
        timestamp: now.toLocaleTimeString(),
        engineRPM: clamp(Math.floor(2000 + Math.sin(time / 1300) * 1500), 0, 8000),
        vehicleSpeed: clamp(Math.floor(60 + Math.sin(time / 2000) * 40), 0, 255),
        coolantTemp: clamp(Math.floor(85 + Math.sin(time / 4000) * 15), -40, 215),
        intakeTemp: clamp(Math.floor(32 + Math.sin(time / 3500) * 12), -40, 215),
        throttlePosition: clamp(Math.floor(40 + Math.sin(time / 1700) * 30), 0, 100),
        fuelLevel: clamp(Math.floor(50 + Math.sin(time / 8000) * 30), 0, 100),
        engineLoad: clamp(Math.floor(35 + Math.sin(time / 1600) * 25), 0, 100),
        map: clamp(Math.floor(45 + Math.sin(time / 1500) * 25), 10, 255),
        baro: clamp(Math.floor(98 + Math.sin(time / 5000) * 3), 95, 105),
        maf: clamp(Math.floor(25 + Math.sin(time / 1400) * 20), 0, 255),
        voltage: clamp(Math.floor(12.5 * 1000 + Math.sin(time / 3000) * 800) / 1000, 11, 14.5),
        ambient: clamp(Math.floor(25 + Math.sin(time / 8000) * 5), 15, 35),
        lambda: clamp(Math.floor((0.95 + Math.sin(time / 2000) * 0.05) * 100) / 100, 0.8, 1.2),
        fuelSystemStatus: clamp(Math.floor(2 + Math.sin(time / 7000) * 0.5), 1, 3),
        timingAdvance: clamp(Math.floor(10 + Math.sin(time / 2000) * 5), -10, 30),
        runtimeSinceStart: clamp(Math.floor(time / 1000) % 65536, 0, 65535),
        distanceWithMIL: clamp(Math.floor(time / 5000) % 1000, 0, 65535),
        commandedPurge: clamp(Math.floor(20 + Math.sin(time / 1500) * 10), 0, 100),
        warmupsSinceClear: clamp(Math.floor(10 + Math.sin(time / 20000) * 5), 0, 255),
        distanceSinceClear: clamp(Math.floor(time / 100) % 65536, 0, 65535),
        catalystTemp: clamp(Math.floor(400 + Math.sin(time / 3000) * 100), 200, 800),
        absoluteLoad: clamp(Math.floor(40 + Math.sin(time / 1800) * 30), 0, 100),
        commandedEquivRatio: clamp(Math.floor((0.98 + Math.sin(time / 2000) * 0.04) * 100) / 100, 0.8, 1.2),
        relativeThrottle: clamp(Math.floor(45 + Math.sin(time / 1000) * 35), 0, 100),
        absoluteThrottleB: clamp(Math.floor(42 + Math.sin(time / 1200) * 32), 0, 100),
        absoluteThrottleC: clamp(Math.floor(38 + Math.sin(time / 1400) * 28), 0, 100),
        pedalPositionD: clamp(Math.floor(50 + Math.sin(time / 900) * 40), 0, 100),
        pedalPositionE: clamp(Math.floor(47 + Math.sin(time / 1100) * 37), 0, 100),
        pedalPositionF: clamp(Math.floor(44 + Math.sin(time / 1300) * 34), 0, 100),
        commandedThrottleActuator: clamp(Math.floor(46 + Math.sin(time / 800) * 36), 0, 100),
        timeRunWithMIL: clamp(Math.floor(time / 8000) % 500, 0, 65535),
        timeSinceCodesCleared: clamp(Math.floor(time / 2000) % 65536, 0, 65535),
        maxEquivRatio: clamp(Math.floor((1.20 + Math.sin(time / 15000) * 0.1) * 100) / 100, 1.0, 1.5),
        maxAirFlow: clamp(Math.floor((10 + Math.sin(time / 1500) * 15) * 1.5), 10, 255),
        fuelType: clamp(Math.floor(1 + Math.sin(time / 30000) * 0.3), 1, 2),
        ethanolFuel: clamp(Math.floor(5 + Math.sin(time / 10000) * 2), 0, 15),
        absEvapPressure: clamp(Math.floor(100 + Math.sin(time / 2000) * 20), 80, 150),
        evapPressure: clamp(Math.floor(80 + Math.sin(time / 2500) * 15), 60, 120),
        shortTermO2Trim1: clamp(Math.floor(-5 + Math.sin(time / 2000) * 8), -25, 25),
        longTermO2Trim1: clamp(Math.floor(-3 + Math.sin(time / 3000) * 6), -25, 25),
        shortTermO2Trim2: clamp(Math.floor(-4 + Math.sin(time / 2100) * 7), -25, 25),
        longTermO2Trim2: clamp(Math.floor(-2 + Math.sin(time / 3100) * 5), -25, 25),
        shortTermO2Trim3: clamp(Math.floor(-6 + Math.sin(time / 2200) * 9), -25, 25),
        longTermO2Trim3: clamp(Math.floor(-4 + Math.sin(time / 3200) * 7), -25, 25),
        shortTermO2Trim4: clamp(Math.floor(-3 + Math.sin(time / 2300) * 6), -25, 25),
        longTermO2Trim4: clamp(Math.floor(-1 + Math.sin(time / 3300) * 4), -25, 25),
        catalystTemp1: clamp(Math.floor(450 + Math.sin(time / 3000) * 80), 200, 800),
        catalystTemp2: clamp(Math.floor(430 + Math.sin(time / 3200) * 70), 200, 800),
        catalystTemp3: clamp(Math.floor(470 + Math.sin(time / 3400) * 90), 200, 800),
        catalystTemp4: clamp(Math.floor(440 + Math.sin(time / 3600) * 75), 200, 800),
        fuelPressure: clamp(Math.floor(320 + Math.sin(time / 1000) * 40), 250, 500),
        shortTermFuelTrim1: clamp(Math.floor(-3 + Math.sin(time / 3000) * 8), -25, 25),
        longTermFuelTrim1: clamp(Math.floor(-2 + Math.sin(time / 4000) * 6), -25, 25),
        shortTermFuelTrim2: clamp(Math.floor(-5 + Math.sin(time / 3200) * 9), -25, 25),
        longTermFuelTrim2: clamp(Math.floor(-3 + Math.sin(time / 4200) * 7), -25, 25),
      };
    }

    updateOBDData(sample);
    io.emit('liveData', sample);
    try { app.set('lastLiveSample', sample); } catch (e) {}
  }
}, 1000);

// TCP Server setup
function startTCPServer() {
  tcpServer = net.createServer((socket) => {
    console.log('Client connected:', socket.remoteAddress);
    connectedClients.push(socket);
    // update clients count on web UI
    try { io.emit('clients', connectedClients.length); } catch (e) {}
    
    socket.on('data', (data) => {
      const command = data.toString().trim().toUpperCase();
      console.log('Received command:', command);
      
      let response = '';
      
      if (command === 'ATZ') {
        response = 'ELM327 v1.2';
      } else if (command === 'ATI') {
        response = 'ELM327 v1.2';
      } else if (command === 'AT@1') {
        response = 'OBDII to RS232 Interpreter';
      } else if (command === 'AT@2') {
        response = '?';
      } else if (command === 'ATRV') {
        response = '12.1V';
      } else if (command === 'ATDP') {
        response = 'AUTO, ISO 15765-4 (CAN 11/500)';
      } else if (command === 'ATDPN') {
        response = 'A6';
      } else if (command === 'ATSP0') {
        response = 'OK';
      } else if (command === 'ATL0') {
        response = 'OK';
      } else if (command === 'ATS0') {
        emulatorConfig.settings.spaces = false;
        response = 'OK';
      } else if (command === 'ATS1') {
        emulatorConfig.settings.spaces = true;
        response = 'OK';
      } else if (command === 'ATH0') {
        response = 'OK';
      } else if (command === 'ATD') {
        response = 'OK';
      } else if (command === 'ATZ') {
        response = 'ELM327 v1.2';
      } else if (command.startsWith('01')) {
        // OBD Mode 01 - Show current data
        // Remove all spaces to normalize command (supports both "010D" and "01 0D")
        const normalized = command.replace(/\s+/g, '');
        const pid = normalized.substring(0, 4);
        if (obdPids[pid]) {
          response = obdPids[pid];
        } else {
          response = 'NO DATA';
        }
      } else if (command === '03') {
        // Mode 03 - Stored/Confirmed DTCs
        response = formatDtcResponse('43', dtcState.stored);
      } else if (command === '07') {
        // Mode 07 - Pending DTCs
        response = formatDtcResponse('47', dtcState.pending);
      } else if (command === '0A') {
        // Mode 0A - Permanent DTCs
        response = formatDtcResponse('4A', dtcState.permanent);
      } else if (command.startsWith('99')) {
        // Custom command (Mode 99) - inject random DTC for testing
        const codes = injectRandomDtc();
        response = `RANDOM ${codes.join(' ')}`;
      } else if (command === '04') {
        // Mode 04 - Clear DTCs
        dtcState.stored = [];
        dtcState.pending = [];
        dtcState.milOn = false;
        updatePid0101FromDtc();
    clearFreezeFrame();
        response = '44';
  } else if (command.startsWith('02')) {
    // Mode 02 - Freeze Frame snapshot (per-PID request like 020C)
    response = formatFreezeFrameResponse(command);
  } else if (command.startsWith('06')) {
    // Mode 06 - On-board monitoring test results
    if (command === '0600') {
      response = formatMode06Supported();
    } else if (command.length === 4) {
      const tid = command.substring(2, 4);
      response = formatMode06Tid(tid);
    } else {
      response = 'NO DATA';
    }
  } else if (command === 'ATDPN') {
        response = 'A6';
      } else {
        response = '?';
      }
      
      // Apply spaces setting only if spaces=false (remove all spaces)
      // ELM327 responses typically have spaces by default
      if (!emulatorConfig.settings.spaces) {
        response = response.replace(/\s+/g, '');
      }
      
      if (emulatorConfig.settings.lineFeed) {
        response += '\n';
      }
      
      if (emulatorConfig.settings.doubleLF) {
        response += '\n\n';
      }
      
      response += '>';
      
      socket.write(response);
      console.log('Sent response:', response);
      // emit log to web UI
      try { io.emit('log', { data: command, response }); } catch (e) {}
    });
    
    socket.on('close', () => {
      console.log('Client disconnected');
      const index = connectedClients.indexOf(socket);
      if (index > -1) {
        connectedClients.splice(index, 1);
      }
      // update clients count on web UI
      try { io.emit('clients', connectedClients.length); } catch (e) {}
    });
    
    socket.on('error', (err) => {
      console.log('Socket error:', err);
    });
  });
  
  tcpServer.listen(emulatorConfig.port, () => {
    console.log(`TCP Server listening on port ${emulatorConfig.port}`);
  });
}

// Socket.IO events
io.on('connection', (socket) => {
  console.log('Web client connected');
  
  socket.on('startServer', () => {
    if (!emulatorConfig.isRunning) {
      startTCPServer();
      emulatorConfig.isRunning = true;
      socket.emit('serverStatus', { running: true, port: emulatorConfig.port });
    }
  });
  
  socket.on('stopServer', () => {
    if (emulatorConfig.isRunning) {
      tcpServer.close();
      emulatorConfig.isRunning = false;
      connectedClients.length = 0;
      socket.emit('serverStatus', { running: false });
    }
  });
  
  socket.on('updateConfig', (config) => {
    Object.assign(emulatorConfig, config);
    console.log('Configuration updated:', config);
  });
  
  socket.on('disconnect', () => {
    console.log('Web client disconnected');
  });
});

// REST APIs for web UI
app.get('/api/config', (req, res) => {
  res.json(emulatorConfig);
});

// DTC APIs
app.get('/api/dtc/stored', (req, res) => {
  res.json({ codes: dtcState.stored || [], milOn: dtcState.milOn, type: 'stored' });
});
app.get('/api/dtc/pending', (req, res) => {
  res.json({ codes: dtcState.pending || [], milOn: dtcState.milOn, type: 'pending' });
});
app.get('/api/dtc/permanent', (req, res) => {
  res.json({ codes: dtcState.permanent || [], milOn: dtcState.milOn, type: 'permanent' });
});
app.post('/api/dtc/random', (req, res) => {
  try {
    const codes = injectRandomDtc();
    res.json({ success: true, codes, milOn: dtcState.milOn });
  } catch (e) {
    res.status(500).json({ success: false, message: e?.message || 'Unknown error' });
  }
});
app.post('/api/dtc/clear', (req, res) => {
  try {
    dtcState.stored = [];
    dtcState.pending = [];
    dtcState.milOn = false;
    updatePid0101FromDtc();
    io.emit('dtcCleared', { ok: true, milOn: dtcState.milOn });
    res.json({ success: true, milOn: dtcState.milOn });
  } catch (e) {
    res.status(500).json({ success: false, message: e?.message || 'Unknown error' });
  }
});

// MIL API
app.get('/api/mil', (req, res) => {
  try {
    const storedCount = Array.isArray(dtcState.stored) ? dtcState.stored.length : 0;
    res.json({ milOn: !!dtcState.milOn, storedCount });
  } catch (e) {
    res.status(500).json({ message: e?.message || 'Unknown error' });
  }
});

app.post('/api/mil/sync', (req, res) => {
  try {
    // Ensure MIL reflects current stored DTCs
    dtcState.milOn = (Array.isArray(dtcState.stored) && dtcState.stored.length > 0);
    updatePid0101FromDtc();
    const storedCount = Array.isArray(dtcState.stored) ? dtcState.stored.length : 0;
    io.emit('mil', { milOn: dtcState.milOn, storedCount });
    res.json({ success: true, milOn: dtcState.milOn, storedCount });
  } catch (e) {
    res.status(500).json({ success: false, message: e?.message || 'Unknown error' });
  }
});

// Freeze Frame APIs
app.get('/api/freeze-frame', (req, res) => {
  res.json({ snapshot: freezeFrame || null });
});

app.post('/api/freeze-frame/capture', (req, res) => {
  try {
    const snap = captureFreezeFrameFromCurrent();
    return res.json({ success: true, snapshot: snap });
  } catch (e) {
    return res.status(500).json({ success: false, message: e?.message || 'Unknown error' });
  }
});

app.post('/api/freeze-frame/clear', (req, res) => {
  try {
    clearFreezeFrame();
    return res.json({ success: true });
  } catch (e) {
    return res.status(500).json({ success: false, message: e?.message || 'Unknown error' });
  }
});

// Mode 06 REST (for web UI)
app.get('/api/mode06', (req, res) => {
  try {
    const tests = Object.entries(mode06Tests).map(([tid, t]) => ({
      tid,
      name: t.name,
      value: t.value,
      min: t.min,
      max: t.max,
      pass: t.value >= t.min && t.value <= t.max,
    }));
    res.json({ tests });
  } catch (e) {
    res.status(500).json({ message: e?.message || 'Unknown error' });
  }
});

// Live data APIs
app.get('/api/live', (req, res) => {
  res.json({
    mode: emulatorConfig.live?.mode || 'random',
    random: emulatorConfig.live?.random || {},
    static: emulatorConfig.live?.static || {},
    last: app.get('lastLiveSample') || null
  });
});

app.post('/api/live/mode', (req, res) => {
  try {
    const mode = (req.body?.mode || '').toString();
    if (mode !== 'random' && mode !== 'static') {
      return res.status(400).json({ success: false, message: 'mode must be "random" or "static"' });
    }
    emulatorConfig.live = emulatorConfig.live || {};
    emulatorConfig.live.mode = mode;
    io.emit('liveMode', { mode });
    return res.json({ success: true, mode });
  } catch (e) {
    return res.status(500).json({ success: false, message: e.message || 'Unknown error' });
  }
});

app.post('/api/live/static', (req, res) => {
  try {
    const allowed = ['engineRPM','vehicleSpeed','coolantTemp','intakeTemp','throttlePosition','fuelLevel'];
    const body = req.body || {};
    emulatorConfig.live = emulatorConfig.live || {};
    emulatorConfig.live.static = emulatorConfig.live.static || {};
    for (const k of allowed) {
      if (body[k] !== undefined) {
        emulatorConfig.live.static[k] = Number(body[k]);
      }
    }
    return res.json({ success: true, static: emulatorConfig.live.static });
  } catch (e) {
    return res.status(500).json({ success: false, message: e.message || 'Unknown error' });
  }
});

app.post('/api/live/random', (req, res) => {
  try {
    const ranges = req.body?.ranges || req.body || {};
    const allowed = ['engineRPM','vehicleSpeed','coolantTemp','intakeTemp','throttlePosition','fuelLevel'];
    emulatorConfig.live = emulatorConfig.live || {};
    emulatorConfig.live.random = emulatorConfig.live.random || {};
    for (const k of allowed) {
      if (ranges[k]) {
        const min = Number(ranges[k].min);
        const max = Number(ranges[k].max);
        if (Number.isFinite(min) && Number.isFinite(max)) {
          emulatorConfig.live.random[k] = { min, max };
        }
      }
    }
    return res.json({ success: true, random: emulatorConfig.live.random });
  } catch (e) {
    return res.status(500).json({ success: false, message: e.message || 'Unknown error' });
  }
});

app.post('/api/start', (req, res) => {
  try {
    // Allow passing config from client
    if (req.body && typeof req.body === 'object') {
      Object.assign(emulatorConfig, req.body);
    }

    if (emulatorConfig.isRunning) {
      return res.json({ success: false, message: 'Server already running' });
    }

    startTCPServer();
    emulatorConfig.isRunning = true;
    io.emit('status', { running: true, port: emulatorConfig.port });
    return res.json({ success: true, port: emulatorConfig.port });
  } catch (err) {
    console.error('Failed to start TCP server:', err);
    return res.status(500).json({ success: false, message: err.message || 'Unknown error' });
  }
});

app.post('/api/stop', (req, res) => {
  try {
    if (!emulatorConfig.isRunning) {
      return res.json({ success: true, message: 'Server already stopped' });
    }

    tcpServer.close(() => {
      emulatorConfig.isRunning = false;
      connectedClients.forEach(c => { try { c.destroy(); } catch (e) {} });
      connectedClients.length = 0;
      io.emit('status', { running: false });
      return res.json({ success: true });
    });
  } catch (err) {
    console.error('Failed to stop TCP server:', err);
    return res.status(500).json({ success: false, message: err.message || 'Unknown error' });
  }
});

// === Acceleration Test API ===
app.post('/api/acceleration/start', (req, res) => {
  const { startSpeed = 0, endSpeed = 200, duration = 20000 } = req.body;
  
  emulatorConfig.live.mode = 'acceleration';
  emulatorConfig.live.acceleration = {
    active: true,
    startSpeed: Math.max(0, Math.min(255, startSpeed)),
    endSpeed: Math.max(0, Math.min(255, endSpeed)),
    duration: Math.max(1000, Math.min(60000, duration)),
    startTime: null,
  };
  
  res.json({
    success: true,
    message: `Acceleration test started: ${startSpeed} -> ${endSpeed} km/h in ${duration}ms`,
    config: emulatorConfig.live.acceleration,
  });
});

app.post('/api/acceleration/stop', (req, res) => {
  if (emulatorConfig.live.acceleration) {
    emulatorConfig.live.acceleration.active = false;
    emulatorConfig.live.acceleration.startTime = null;
  }
  emulatorConfig.live.mode = 'random';
  
  res.json({ success: true, message: 'Acceleration test stopped' });
});

app.get('/api/acceleration/status', (req, res) => {
  res.json({
    mode: emulatorConfig.live?.mode,
    acceleration: emulatorConfig.live?.acceleration || null,
  });
});

const PORT = process.env.PORT || 3000;
server.listen(PORT, () => {
  const url = `http://localhost:${PORT}`;
  console.log(`Server running at ${url}`);
  console.log('Press CTRL+C to stop.');
  console.log(`Acceleration API: POST ${url}/api/acceleration/start`);
});
