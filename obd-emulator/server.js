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

// TCP Server for OBD communication
let tcpServer;
const connectedClients = [];

// Emulator configuration
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
    spaces: true,
    doubleLF: false
  },
  isRunning: false
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
  '011C': '41 1C 01', // OBD Standards
  '011F': '41 1F 00 1F 40', // Run time since engine start
  '0121': '41 21 00 1F 40', // Distance traveled with MIL on
  '012E': '41 2E 21', // Commanded evaporative purge
  '012F': '41 2F 0F', // Fuel Tank Level Input
  '0130': '41 30 50', // # warm-ups since codes cleared
  '0131': '41 31 00 1F 40', // Distance traveled since codes cleared
  '0133': '41 33 65', // Barometric Pressure (101 kPa)
  '013C': '41 3C 00 1F 40', // Catalyst Temperature Bank 1 Sensor 1
  '0142': '41 42 0A 8F', // Control Module Voltage
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
  '0159': '41 59 8F', // Short term secondary O2 sensor trim Bank 3
  '015A': '41 5A 8F', // Long term secondary O2 sensor trim Bank 3
  '015B': '41 5B 8F', // Short term secondary O2 sensor trim Bank 4
  '015C': '41 5C 8F', // Long term secondary O2 sensor trim Bank 4
  '015D': '41 5D 00 1F 40', // Catalyst Temperature Bank 1 Sensor 1
  '015E': '41 5E 80 00 00 00', // O2 Sensor 1 Equivalence Ratio (lambda=1.00), current=0
  '015F': '41 5F 00 1F 40', // Catalyst Temperature Bank 2 Sensor 1
  '0160': '41 60 00 1F 40', // Catalyst Temperature Bank 2 Sensor 2
};

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

  // MAP (PID 010B) kPa, mô phỏng theo throttle & rpm
  const mapKpa = Math.max(20, Math.min(255, Math.floor(30 + data.throttlePosition * 0.9 + data.engineRPM / 100)));
  const mapHex = mapKpa.toString(16).padStart(2, '0').toUpperCase();
  obdPids['010B'] = `41 0B ${mapHex}`;

  // Barometric Pressure (PID 0133) kPa (gần 101)
  const baro = 101;
  obdPids['0133'] = `41 33 ${baro.toString(16).padStart(2, '0').toUpperCase()}`;

  // MAF (PID 0110) g/s -> (256*A + B) / 100
  const mafGs = Math.max(2, Math.floor(10 + data.throttlePosition * 0.6 + data.engineRPM / 80));
  const mafRaw = mafGs * 100;
  const mafA = Math.floor(mafRaw / 256).toString(16).padStart(2, '0').toUpperCase();
  const mafB = (mafRaw % 256).toString(16).padStart(2, '0').toUpperCase();
  obdPids['0110'] = `41 10 ${mafA} ${mafB}`;

  // Control Module Voltage (PID 0142) -> (256*A+B)/1000 V
  const voltageMv = Math.floor(12500 + Math.sin(Date.now() / 3000) * 800 + data.throttlePosition * 5);
  const vA = Math.floor(voltageMv / 256).toString(16).padStart(2, '0').toUpperCase();
  const vB = (voltageMv % 256).toString(16).padStart(2, '0').toUpperCase();
  obdPids['0142'] = `41 42 ${vA} ${vB}`;

  // Ambient Air Temperature (PID 0146)
  const ambTemp = 27; // cố định
  const ambHex = (ambTemp + 40).toString(16).padStart(2, '0').toUpperCase();
  obdPids['0146'] = `41 46 ${ambHex}`;

  // O2 Sensor 1 Equivalence Ratio (PID 015E) -> ratio=(256*A+B)/32768
  const lambda = 1.00; // xấp xỉ stoich
  const lambdaRaw = Math.floor(lambda * 32768);
  const lamA = Math.floor(lambdaRaw / 256).toString(16).padStart(2, '0').toUpperCase();
  const lamB = (lambdaRaw % 256).toString(16).padStart(2, '0').toUpperCase();
  obdPids['015E'] = `41 5E ${lamA} ${lamB} 00 00`;

  // Fuel System Status (PID 0103)
  obdPids['0103'] = '41 03 02'; // Open loop due to driving conditions

  // Timing Advance (PID 010E)
  const timing = Math.floor(10 + Math.sin(Date.now() / 2000) * 5);
  obdPids['010E'] = `41 0E ${timing.toString(16).padStart(2, '0').toUpperCase()}`;

  // Runtime since engine start (PID 011F) - seconds
  const runtime = Math.floor(Date.now() / 1000) % 65536;
  const runtimeA = Math.floor(runtime / 256).toString(16).padStart(2, '0').toUpperCase();
  const runtimeB = (runtime % 256).toString(16).padStart(2, '0').toUpperCase();
  obdPids['011F'] = `41 1F ${runtimeA} ${runtimeB}`;

  // Distance with MIL on (PID 0121) - km
  const milDistance = Math.floor(data.vehicleSpeed * 0.1);
  const milA = Math.floor(milDistance / 256).toString(16).padStart(2, '0').toUpperCase();
  const milB = (milDistance % 256).toString(16).padStart(2, '0').toUpperCase();
  obdPids['0121'] = `41 21 ${milA} ${milB}`;

  // Commanded evaporative purge (PID 012E)
  const purge = Math.floor(20 + data.throttlePosition * 0.3);
  obdPids['012E'] = `41 2E ${purge.toString(16).padStart(2, '0').toUpperCase()}`;

  // Warm-ups since codes cleared (PID 0130)
  const warmups = Math.floor(Date.now() / 300000) % 256; // ~5 min per warmup
  obdPids['0130'] = `41 30 ${warmups.toString(16).padStart(2, '0').toUpperCase()}`;

  // Distance since codes cleared (PID 0131) - km
  const clearDistance = Math.floor(data.vehicleSpeed * 0.05);
  const clearA = Math.floor(clearDistance / 256).toString(16).padStart(2, '0').toUpperCase();
  const clearB = (clearDistance % 256).toString(16).padStart(2, '0').toUpperCase();
  obdPids['0131'] = `41 31 ${clearA} ${clearB}`;

  // Catalyst Temperature (PID 013C)
  const catTemp = Math.floor(400 + data.engineRPM * 0.1);
  const catA = Math.floor(catTemp / 256).toString(16).padStart(2, '0').toUpperCase();
  const catB = (catTemp % 256).toString(16).padStart(2, '0').toUpperCase();
  obdPids['013C'] = `41 3C ${catA} ${catB}`;

  // Absolute load value (PID 0143)
  const absLoad = Math.floor(data.throttlePosition * 0.8);
  obdPids['0143'] = `41 43 ${absLoad.toString(16).padStart(2, '0').toUpperCase()}`;

  // Commanded Equivalence Ratio (PID 0144)
  const equivRatio = Math.floor(128 + Math.sin(Date.now() / 1000) * 20);
  const equivA = Math.floor(equivRatio / 256).toString(16).padStart(2, '0').toUpperCase();
  const equivB = (equivRatio % 256).toString(16).padStart(2, '0').toUpperCase();
  obdPids['0144'] = `41 44 ${equivA} ${equivB}`;

  // Relative throttle position (PID 0145)
  const relThrottle = Math.floor(data.throttlePosition * 0.9);
  obdPids['0145'] = `41 45 ${relThrottle.toString(16).padStart(2, '0').toUpperCase()}`;

  // Absolute throttle position B (PID 0147)
  const absThrottleB = Math.floor(data.throttlePosition * 0.8);
  obdPids['0147'] = `41 47 ${absThrottleB.toString(16).padStart(2, '0').toUpperCase()}`;

  // Absolute throttle position C (PID 0148)
  const absThrottleC = Math.floor(data.throttlePosition * 0.7);
  obdPids['0148'] = `41 48 ${absThrottleC.toString(16).padStart(2, '0').toUpperCase()}`;

  // Accelerator pedal positions (PID 0149-014B)
  const pedalD = Math.floor(data.throttlePosition * 1.2);
  const pedalE = Math.floor(data.throttlePosition * 0.6);
  const pedalF = Math.floor(data.throttlePosition * 0.8);
  obdPids['0149'] = `41 49 ${Math.min(255, pedalD).toString(16).padStart(2, '0').toUpperCase()}`;
  obdPids['014A'] = `41 4A ${Math.min(255, pedalE).toString(16).padStart(2, '0').toUpperCase()}`;
  obdPids['014B'] = `41 4B ${Math.min(255, pedalF).toString(16).padStart(2, '0').toUpperCase()}`;

  // Commanded throttle actuator (PID 014C)
  const throttleActuator = Math.floor(data.throttlePosition * 0.9);
  obdPids['014C'] = `41 4C ${throttleActuator.toString(16).padStart(2, '0').toUpperCase()}`;

  // Time run with MIL on (PID 014D)
  const milTime = Math.floor(Date.now() / 1000) % 65536;
  const milTimeA = Math.floor(milTime / 256).toString(16).padStart(2, '0').toUpperCase();
  const milTimeB = (milTime % 256).toString(16).padStart(2, '0').toUpperCase();
  obdPids['014D'] = `41 4D ${milTimeA} ${milTimeB}`;

  // Time since trouble codes cleared (PID 014E)
  const clearTime = Math.floor(Date.now() / 2000) % 65536;
  const clearTimeA = Math.floor(clearTime / 256).toString(16).padStart(2, '0').toUpperCase();
  const clearTimeB = (clearTime % 256).toString(16).padStart(2, '0').toUpperCase();
  obdPids['014E'] = `41 4E ${clearTimeA} ${clearTimeB}`;

  // Maximum value for equivalence ratio (PID 014F)
  obdPids['014F'] = '41 4F 80 00';

  // Maximum value for air flow rate (PID 0150)
  const maxAirFlow = Math.floor(mafGs * 1.5);
  const maxAirA = Math.floor(maxAirFlow / 256).toString(16).padStart(2, '0').toUpperCase();
  const maxAirB = (maxAirFlow % 256).toString(16).padStart(2, '0').toUpperCase();
  obdPids['0150'] = `41 50 ${maxAirA} ${maxAirB}`;

  // Fuel type (PID 0151)
  obdPids['0151'] = '41 51 01'; // Gasoline

  // Ethanol fuel % (PID 0152)
  obdPids['0152'] = '41 52 00'; // 0% ethanol

  // Absolute evap system vapor pressure (PID 0153)
  const evapPressure = Math.floor(1000 + Math.sin(Date.now() / 1000) * 200);
  const evapA = Math.floor(evapPressure / 256).toString(16).padStart(2, '0').toUpperCase();
  const evapB = (evapPressure % 256).toString(16).padStart(2, '0').toUpperCase();
  obdPids['0153'] = `41 53 ${evapA} ${evapB}`;

  // Evap system vapor pressure (PID 0154)
  const evapPressure2 = Math.floor(800 + Math.sin(Date.now() / 1500) * 150);
  const evap2A = Math.floor(evapPressure2 / 256).toString(16).padStart(2, '0').toUpperCase();
  const evap2B = (evapPressure2 % 256).toString(16).padStart(2, '0').toUpperCase();
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

  // Catalyst temperatures (PID 015D-0160)
  const catTemp1 = Math.floor(400 + data.engineRPM * 0.1);
  const catTemp2 = Math.floor(380 + data.engineRPM * 0.08);
  const catTemp3 = Math.floor(420 + data.engineRPM * 0.12);
  const catTemp4 = Math.floor(390 + data.engineRPM * 0.09);
  
  const cat1A = Math.floor(catTemp1 / 256).toString(16).padStart(2, '0').toUpperCase();
  const cat1B = (catTemp1 % 256).toString(16).padStart(2, '0').toUpperCase();
  obdPids['015D'] = `41 5D ${cat1A} ${cat1B}`;
  
  const cat2A = Math.floor(catTemp2 / 256).toString(16).padStart(2, '0').toUpperCase();
  const cat2B = (catTemp2 % 256).toString(16).padStart(2, '0').toUpperCase();
  obdPids['015F'] = `41 5F ${cat2A} ${cat2B}`;
  
  const cat3A = Math.floor(catTemp3 / 256).toString(16).padStart(2, '0').toUpperCase();
  const cat3B = (catTemp3 % 256).toString(16).padStart(2, '0').toUpperCase();
  obdPids['015F'] = `41 5F ${cat3A} ${cat3B}`;
  
  const cat4A = Math.floor(catTemp4 / 256).toString(16).padStart(2, '0').toUpperCase();
  const cat4B = (catTemp4 % 256).toString(16).padStart(2, '0').toUpperCase();
  obdPids['0160'] = `41 60 ${cat4A} ${cat4B}`;

  // Fuel pressure (PID 010A)
  const fuelPressure = Math.floor(300 + data.throttlePosition * 2);
  const fuelPA = Math.floor(fuelPressure / 256).toString(16).padStart(2, '0').toUpperCase();
  const fuelPB = (fuelPressure % 256).toString(16).padStart(2, '0').toUpperCase();
  obdPids['010A'] = `41 0A ${fuelPA} ${fuelPB}`;

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
    
    // Tạo dữ liệu giả lập với giá trị thực tế
    const liveData = {
      timestamp: now.toLocaleTimeString(),
      engineRPM: Math.max(0, Math.floor(800 + ((Math.sin(time / 1000) + 1) / 2) * 5000)),
      vehicleSpeed: Math.floor(60 + Math.sin(time / 2000) * 40),
      coolantTemp: Math.floor(80 + Math.sin(time / 3000) * 20),
      intakeTemp: Math.floor(25 + Math.sin(time / 4000) * 15),
      throttlePosition: Math.floor(10 + Math.sin(time / 1500) * 30),
      fuelLevel: Math.floor(50 + Math.sin(time / 5000) * 30),
      engineLoad: Math.floor(10 + Math.sin(time / 1500) * 30),
      map: Math.floor(30 + Math.sin(time / 1500) * 20),
      baro: 101,
      maf: Math.floor(10 + Math.sin(time / 1500) * 15),
      voltage: Math.floor(12.5 * 1000 + Math.sin(time / 3000) * 800) / 1000,
      ambient: 27,
      lambda: 1.00,
      fuelSystemStatus: 2,
      timingAdvance: Math.floor(10 + Math.sin(time / 2000) * 5),
      runtimeSinceStart: Math.floor(time / 1000) % 65536,
      distanceWithMIL: Math.floor((60 + Math.sin(time / 2000) * 40) * 0.1),
      commandedPurge: Math.floor(20 + Math.sin(time / 1500) * 10),
      warmupsSinceClear: Math.floor(time / 300000) % 256,
      distanceSinceClear: Math.floor((60 + Math.sin(time / 2000) * 40) * 0.05),
      catalystTemp: Math.floor(400 + (800 + Math.sin(time / 1000) * 2000) * 0.1),
      absoluteLoad: Math.floor((10 + Math.sin(time / 1500) * 30) * 0.8),
      commandedEquivRatio: Math.floor(128 + Math.sin(time / 1000) * 20),
      relativeThrottle: Math.floor((10 + Math.sin(time / 1500) * 30) * 0.9),
      absoluteThrottleB: Math.floor((10 + Math.sin(time / 1500) * 30) * 0.8),
      absoluteThrottleC: Math.floor((10 + Math.sin(time / 1500) * 30) * 0.7),
      pedalPositionD: Math.floor((10 + Math.sin(time / 1500) * 30) * 1.2),
      pedalPositionE: Math.floor((10 + Math.sin(time / 1500) * 30) * 0.6),
      pedalPositionF: Math.floor((10 + Math.sin(time / 1500) * 30) * 0.8),
      commandedThrottleActuator: Math.floor((10 + Math.sin(time / 1500) * 30) * 0.9),
      timeRunWithMIL: Math.floor(time / 1000) % 65536,
      timeSinceCodesCleared: Math.floor(time / 2000) % 65536,
      maxEquivRatio: 128,
      maxAirFlow: Math.floor((10 + Math.sin(time / 1500) * 15) * 1.5),
      fuelType: 1,
      ethanolFuel: 0,
      absEvapPressure: Math.floor(1000 + Math.sin(time / 1000) * 200),
      evapPressure: Math.floor(800 + Math.sin(time / 1500) * 150),
      shortTermO2Trim1: Math.floor(-50 + Math.sin(time / 2000) * 30),
      longTermO2Trim1: Math.floor(-50 + Math.sin(time / 2000) * 30),
      shortTermO2Trim2: Math.floor(-50 + Math.sin(time / 2000) * 30),
      longTermO2Trim2: Math.floor(-50 + Math.sin(time / 2000) * 30),
      shortTermO2Trim3: Math.floor(-50 + Math.sin(time / 2000) * 30),
      longTermO2Trim3: Math.floor(-50 + Math.sin(time / 2000) * 30),
      shortTermO2Trim4: Math.floor(-50 + Math.sin(time / 2000) * 30),
      longTermO2Trim4: Math.floor(-50 + Math.sin(time / 2000) * 30),
      catalystTemp1: Math.floor(400 + (800 + Math.sin(time / 1000) * 2000) * 0.1),
      catalystTemp2: Math.floor(380 + (800 + Math.sin(time / 1000) * 2000) * 0.08),
      catalystTemp3: Math.floor(420 + (800 + Math.sin(time / 1000) * 2000) * 0.12),
      catalystTemp4: Math.floor(390 + (800 + Math.sin(time / 1000) * 2000) * 0.09),
      fuelPressure: Math.floor(300 + (10 + Math.sin(time / 1500) * 30) * 2),
      shortTermFuelTrim1: Math.floor(-25 + Math.sin(time / 3000) * 15),
      longTermFuelTrim1: Math.floor(-25 + Math.sin(time / 3000) * 15),
      shortTermFuelTrim2: Math.floor(-25 + Math.sin(time / 3000) * 15),
      longTermFuelTrim2: Math.floor(-25 + Math.sin(time / 3000) * 15),
    };

    // Cập nhật OBD PIDs với dữ liệu thực tế
    updateOBDData(liveData);
    
    io.emit('liveData', liveData);
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
        const pid = command.substring(0, 4);
        if (obdPids[pid]) {
          response = obdPids[pid];
        } else {
          response = 'NO DATA';
        }
      } else if (command === 'ATDPN') {
        response = 'A6';
      } else {
        response = '?';
      }
      
      if (emulatorConfig.settings.spaces) {
        response = response.replace(/(.{2})/g, '$1 ').trim();
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

const PORT = process.env.PORT || 3000;
server.listen(PORT, () => {
  const url = `http://localhost:${PORT}`;
  console.log(`Server running at ${url}`);
  console.log('Press CTRL+C to stop.');
});
