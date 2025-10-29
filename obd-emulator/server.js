const express = require('express');
const http = require('http');
const socketIo = require('socket.io');
const net = require('net');
const path = require('path');
const cors = require('cors');

const app = express();
const server = http.createServer(app);
const io = socketIo(server, {
  cors: {
    origin: "*",
    methods: ["GET", "POST"]
  }
});

app.use(cors());
app.use(express.json());
app.use(express.static('public'));

// OBD ELM327 Emulator Configuration
let emulatorConfig = {
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
  '0105': '41 05 7B', // Engine Coolant Temperature (83°C)
  '010C': '41 0C 1F 40', // Engine RPM (2000 RPM)
  '010D': '41 0D 40', // Vehicle Speed (64 km/h)
  '010F': '41 0F 78', // Intake Air Temperature (38°C)
  '0110': '41 10 0F A0', // MAF Air Flow Rate
  '0111': '41 11 0A 8F', // Throttle Position
  '011C': '41 1C 01', // OBD Standards
  '012F': '41 2F 0F', // Fuel Tank Level Input
  '0133': '41 33 7B', // Barometric Pressure
  '0142': '41 42 0A 8F', // Control Module Voltage
  '0144': '41 44 0F A0', // Commanded Equivalence Ratio
  '0146': '41 46 0A 8F', // Ambient Air Temperature
  '0147': '41 47 0F A0', // Absolute Throttle Position B
  '0148': '41 48 0A 8F', // Absolute Throttle Position C
  '0149': '41 49 0F A0', // Accelerator Pedal Position D
  '014A': '41 4A 0A 8F', // Accelerator Pedal Position E
  '014B': '41 4B 0F A0', // Accelerator Pedal Position F
  '014C': '41 4C 0A 8F', // Commanded Throttle Actuator
  '014D': '41 4D 0F A0', // Time Run with MIL On
  '014E': '41 4E 0A 8F', // Time Since Trouble Codes Cleared
  '014F': '41 4F 0F A0', // Maximum Value for Equivalence Ratio
  '0150': '41 50 0A 8F', // Maximum Value for Air Flow Rate
  '0151': '41 51 0F A0', // Fuel Type
  '0152': '41 52 0A 8F', // Ethanol Fuel %
  '0153': '41 53 0F A0', // Absolute Evap System Vapor Pressure
  '0154': '41 54 0A 8F', // Evap System Vapor Pressure
  '0155': '41 55 0F A0', // Short Term Secondary O2 Sensor Trim Bank 1
  '0156': '41 56 0A 8F', // Long Term Secondary O2 Sensor Trim Bank 1
  '0157': '41 57 0F A0', // Short Term Secondary O2 Sensor Trim Bank 2
  '0158': '41 58 0A 8F', // Long Term Secondary O2 Sensor Trim Bank 2
  '0159': '41 59 0F A0', // Short Term Secondary O2 Sensor Trim Bank 3
  '015A': '41 5A 0A 8F', // Long Term Secondary O2 Sensor Trim Bank 3
  '015B': '41 5B 0F A0', // Short Term Secondary O2 Sensor Trim Bank 4
  '015C': '41 5C 0A 8F', // Long Term Secondary O2 Sensor Trim Bank 4
  '015D': '41 5D 0F A0', // Catalyst Temperature Bank 1 Sensor 1
  '015E': '41 5E 0A 8F', // Catalyst Temperature Bank 2 Sensor 1
  '015F': '41 5F 0F A0', // Catalyst Temperature Bank 1 Sensor 2
  '0160': '41 60 0A 8F', // Catalyst Temperature Bank 2 Sensor 2
  '0161': '41 61 0F A0', // PIDs supported 61-80
  '0162': '41 62 0A 8F', // Driver's Demand Engine Torque
  '0163': '41 63 0F A0', // Actual Engine Torque
  '0164': '41 64 0A 8F', // Engine Reference Torque
  '0165': '41 65 0F A0', // Engine Percent Torque Data
  '0166': '41 66 0A 8F', // Auxiliary Input / Output Supported
  '0167': '41 67 0F A0', // Mass Air Flow Sensor
  '0168': '41 68 0A 8F', // Engine Coolant Temperature
  '0169': '41 69 0F A0', // Intake Air Temperature Sensor
  '016A': '41 6A 0A 8F', // Commanded EGR
  '016B': '41 6B 0F A0', // EGR Error
  '016C': '41 6C 0A 8F', // Commanded Evaporative Purge
  '016D': '41 6D 0F A0', // Fuel Tank Level Input
  '016E': '41 6E 0A 8F', // Warm-ups Since Codes Cleared
  '016F': '41 6F 0F A0', // Distance Since Codes Cleared
  '0170': '41 70 0A 8F', // Evap System Vapor Pressure
  '0171': '41 71 0F A0', // Absolute Barometric Pressure
  '0172': '41 72 0A 8F', // PIDs supported 81-A0
  '0173': '41 73 0F A0', // Fuel Type
  '0174': '41 74 0A 8F', // Ethanol Fuel %
  '0175': '41 75 0F A0', // Absolute Evap System Vapor Pressure
  '0176': '41 76 0A 8F', // Evap System Vapor Pressure
  '0177': '41 77 0F A0', // Short Term Secondary O2 Sensor Trim Bank 1
  '0178': '41 78 0A 8F', // Long Term Secondary O2 Sensor Trim Bank 1
  '0179': '41 79 0F A0', // Short Term Secondary O2 Sensor Trim Bank 2
  '017A': '41 7A 0A 8F', // Long Term Secondary O2 Sensor Trim Bank 2
  '017B': '41 7B 0F A0', // Short Term Secondary O2 Sensor Trim Bank 3
  '017C': '41 7C 0A 8F', // Long Term Secondary O2 Sensor Trim Bank 3
  '017D': '41 7D 0F A0', // Short Term Secondary O2 Sensor Trim Bank 4
  '017E': '41 7E 0A 8F', // Long Term Secondary O2 Sensor Trim Bank 4
  '017F': '41 7F 0F A0', // Catalyst Temperature Bank 1 Sensor 1
  '0180': '41 80 0A 8F', // Catalyst Temperature Bank 2 Sensor 1
  '0181': '41 81 0F A0', // Catalyst Temperature Bank 1 Sensor 2
  '0182': '41 82 0A 8F', // Catalyst Temperature Bank 2 Sensor 2
  '0183': '41 83 0F A0', // PIDs supported 81-A0
  '0184': '41 84 0A 8F', // Driver's Demand Engine Torque
  '0185': '41 85 0F A0', // Actual Engine Torque
  '0186': '41 86 0A 8F', // Engine Reference Torque
  '0187': '41 87 0F A0', // Engine Percent Torque Data
  '0188': '41 88 0A 8F', // Auxiliary Input / Output Supported
  '0189': '41 89 0F A0', // Mass Air Flow Sensor
  '018A': '41 8A 0A 8F', // Engine Coolant Temperature
  '018B': '41 8B 0F A0', // Intake Air Temperature Sensor
  '018C': '41 8C 0A 8F', // Commanded EGR
  '018D': '41 8D 0F A0', // EGR Error
  '018E': '41 8E 0A 8F', // Commanded Evaporative Purge
  '018F': '41 8F 0F A0', // Fuel Tank Level Input
  '0190': '41 90 0A 8F', // Warm-ups Since Codes Cleared
  '0191': '41 91 0F A0', // Distance Since Codes Cleared
  '0192': '41 92 0A 8F', // Evap System Vapor Pressure
  '0193': '41 93 0F A0', // Absolute Barometric Pressure
  '0194': '41 94 0A 8F', // PIDs supported 81-A0
  '0195': '41 95 0F A0', // Fuel Type
  '0196': '41 96 0A 8F', // Ethanol Fuel %
  '0197': '41 97 0F A0', // Absolute Evap System Vapor Pressure
  '0198': '41 98 0A 8F', // Evap System Vapor Pressure
  '0199': '41 99 0F A0', // Short Term Secondary O2 Sensor Trim Bank 1
  '019A': '41 9A 0A 8F', // Long Term Secondary O2 Sensor Trim Bank 1
  '019B': '41 9B 0F A0', // Short Term Secondary O2 Sensor Trim Bank 2
  '019C': '41 9C 0A 8F', // Long Term Secondary O2 Sensor Trim Bank 2
  '019D': '41 9D 0F A0', // Short Term Secondary O2 Sensor Trim Bank 3
  '019E': '41 9E 0A 8F', // Long Term Secondary O2 Sensor Trim Bank 3
  '019F': '41 9F 0F A0', // Short Term Secondary O2 Sensor Trim Bank 4
  '01A0': '41 A0 0A 8F', // Long Term Secondary O2 Sensor Trim Bank 4
  '01A1': '41 A1 0F A0', // Catalyst Temperature Bank 1 Sensor 1
  '01A2': '41 A2 0A 8F', // Catalyst Temperature Bank 2 Sensor 1
  '01A3': '41 A3 0F A0', // Catalyst Temperature Bank 1 Sensor 2
  '01A4': '41 A4 0A 8F', // Catalyst Temperature Bank 2 Sensor 2
  '01A5': '41 A5 0F A0', // PIDs supported 81-A0
  '01A6': '41 A6 0A 8F', // Driver's Demand Engine Torque
  '01A7': '41 A7 0F A0', // Actual Engine Torque
  '01A8': '41 A8 0A 8F', // Engine Reference Torque
  '01A9': '41 A9 0F A0', // Engine Percent Torque Data
  '01AA': '41 AA 0A 8F', // Auxiliary Input / Output Supported
  '01AB': '41 AB 0F A0', // Mass Air Flow Sensor
  '01AC': '41 AC 0A 8F', // Engine Coolant Temperature
  '01AD': '41 AD 0F A0', // Intake Air Temperature Sensor
  '01AE': '41 AE 0A 8F', // Commanded EGR
  '01AF': '41 AF 0F A0', // EGR Error
  '01B0': '41 B0 0A 8F', // Commanded Evaporative Purge
  '01B1': '41 B1 0F A0', // Fuel Tank Level Input
  '01B2': '41 B2 0A 8F', // Warm-ups Since Codes Cleared
  '01B3': '41 B3 0F A0', // Distance Since Codes Cleared
  '01B4': '41 B4 0A 8F', // Evap System Vapor Pressure
  '01B5': '41 B5 0F A0', // Absolute Barometric Pressure
  '01B6': '41 B6 0A 8F', // PIDs supported 81-A0
  '01B7': '41 B7 0F A0', // Fuel Type
  '01B8': '41 B8 0A 8F', // Ethanol Fuel %
  '01B9': '41 B9 0F A0', // Absolute Evap System Vapor Pressure
  '01BA': '41 BA 0A 8F', // Evap System Vapor Pressure
  '01BB': '41 BB 0F A0', // Short Term Secondary O2 Sensor Trim Bank 1
  '01BC': '41 BC 0A 8F', // Long Term Secondary O2 Sensor Trim Bank 1
  '01BD': '41 BD 0F A0', // Short Term Secondary O2 Sensor Trim Bank 2
  '01BE': '41 BE 0A 8F', // Long Term Secondary O2 Sensor Trim Bank 2
  '01BF': '41 BF 0F A0', // Short Term Secondary O2 Sensor Trim Bank 3
  '01C0': '41 C0 0A 8F', // Long Term Secondary O2 Sensor Trim Bank 3
  '01C1': '41 C1 0F A0', // Short Term Secondary O2 Sensor Trim Bank 4
  '01C2': '41 C2 0A 8F', // Long Term Secondary O2 Sensor Trim Bank 4
  '01C3': '41 C3 0F A0', // Catalyst Temperature Bank 1 Sensor 1
  '01C4': '41 C4 0A 8F', // Catalyst Temperature Bank 2 Sensor 1
  '01C5': '41 C5 0F A0', // Catalyst Temperature Bank 1 Sensor 2
  '01C6': '41 C6 0A 8F', // Catalyst Temperature Bank 2 Sensor 2
  '01C7': '41 C7 0F A0', // PIDs supported 81-A0
  '01C8': '41 C8 0A 8F', // Driver's Demand Engine Torque
  '01C9': '41 C9 0F A0', // Actual Engine Torque
  '01CA': '41 CA 0A 8F', // Engine Reference Torque
  '01CB': '41 CB 0F A0', // Engine Percent Torque Data
  '01CC': '41 CC 0A 8F', // Auxiliary Input / Output Supported
  '01CD': '41 CD 0F A0', // Mass Air Flow Sensor
  '01CE': '41 CE 0A 8F', // Engine Coolant Temperature
  '01CF': '41 CF 0F A0', // Intake Air Temperature Sensor
  '01D0': '41 D0 0A 8F', // Commanded EGR
  '01D1': '41 D1 0F A0', // EGR Error
  '01D2': '41 D2 0A 8F', // Commanded Evaporative Purge
  '01D3': '41 D3 0F A0', // Fuel Tank Level Input
  '01D4': '41 D4 0A 8F', // Warm-ups Since Codes Cleared
  '01D5': '41 D5 0F A0', // Distance Since Codes Cleared
  '01D6': '41 D6 0A 8F', // Evap System Vapor Pressure
  '01D7': '41 D7 0F A0', // Absolute Barometric Pressure
  '01D8': '41 D8 0A 8F', // PIDs supported 81-A0
  '01D9': '41 D9 0F A0', // Fuel Type
  '01DA': '41 DA 0A 8F', // Ethanol Fuel %
  '01DB': '41 DB 0F A0', // Absolute Evap System Vapor Pressure
  '01DC': '41 DC 0A 8F', // Evap System Vapor Pressure
  '01DD': '41 DD 0F A0', // Short Term Secondary O2 Sensor Trim Bank 1
  '01DE': '41 DE 0A 8F', // Long Term Secondary O2 Sensor Trim Bank 1
  '01DF': '41 DF 0F A0', // Short Term Secondary O2 Sensor Trim Bank 2
  '01E0': '41 E0 0A 8F', // Long Term Secondary O2 Sensor Trim Bank 2
  '01E1': '41 E1 0F A0', // Short Term Secondary O2 Sensor Trim Bank 3
  '01E2': '41 E2 0A 8F', // Long Term Secondary O2 Sensor Trim Bank 3
  '01E3': '41 E3 0F A0', // Short Term Secondary O2 Sensor Trim Bank 4
  '01E4': '41 E4 0A 8F', // Long Term Secondary O2 Sensor Trim Bank 4
  '01E5': '41 E5 0F A0', // Catalyst Temperature Bank 1 Sensor 1
  '01E6': '41 E6 0A 8F', // Catalyst Temperature Bank 2 Sensor 1
  '01E7': '41 E7 0F A0', // Catalyst Temperature Bank 1 Sensor 2
  '01E8': '41 E8 0A 8F', // Catalyst Temperature Bank 2 Sensor 2
  '01E9': '41 E9 0F A0', // PIDs supported 81-A0
  '01EA': '41 EA 0A 8F', // Driver's Demand Engine Torque
  '01EB': '41 EB 0F A0', // Actual Engine Torque
  '01EC': '41 EC 0A 8F', // Engine Reference Torque
  '01ED': '41 ED 0F A0', // Engine Percent Torque Data
  '01EE': '41 EE 0A 8F', // Auxiliary Input / Output Supported
  '01EF': '41 EF 0F A0', // Mass Air Flow Sensor
  '01F0': '41 F0 0A 8F', // Engine Coolant Temperature
  '01F1': '41 F1 0F A0', // Intake Air Temperature Sensor
  '01F2': '41 F2 0A 8F', // Commanded EGR
  '01F3': '41 F3 0F A0', // EGR Error
  '01F4': '41 F4 0A 8F', // Commanded Evaporative Purge
  '01F5': '41 F5 0F A0', // Fuel Tank Level Input
  '01F6': '41 F6 0A 8F', // Warm-ups Since Codes Cleared
  '01F7': '41 F7 0F A0', // Distance Since Codes Cleared
  '01F8': '41 F8 0A 8F', // Evap System Vapor Pressure
  '01F9': '41 F9 0F A0', // Absolute Barometric Pressure
  '01FA': '41 FA 0A 8F', // PIDs supported 81-A0
  '01FB': '41 FB 0F A0', // Fuel Type
  '01FC': '41 FC 0A 8F', // Ethanol Fuel %
  '01FD': '41 FD 0F A0', // Absolute Evap System Vapor Pressure
  '01FE': '41 FE 0A 8F', // Evap System Vapor Pressure
  '01FF': '41 FF 0F A0'  // Short Term Secondary O2 Sensor Trim Bank 1
};

let tcpServer = null;
let connectedClients = [];

// TCP Server để nhận kết nối từ Car Scanner
function startTCPServer() {
  if (tcpServer) {
    tcpServer.close();
  }

  tcpServer = net.createServer((socket) => {
    console.log('Client connected:', socket.remoteAddress);
    connectedClients.push(socket);
    
    // Gửi thông báo kết nối thành công
    socket.write('ELM327 v1.2\r');
    
    socket.on('data', (data) => {
      const command = data.toString().trim().toUpperCase();
      console.log('Received command:', command);
      
      let response = '';
      
      if (command === 'ATZ') {
        response = 'ELM327 v1.2\r';
      } else if (command === 'ATI') {
        response = 'ELM327 v1.2\r';
      } else if (command === 'AT@1') {
        response = 'OBDII to RS232 Interpreter\r';
      } else if (command === 'AT@2') {
        response = '?\r';
      } else if (command === 'ATRV') {
        response = '12.6V\r';
      } else if (command === 'ATDP') {
        response = 'AUTO, ISO 15765-4 (CAN 11/500)\r';
      } else if (command === 'ATDPN') {
        response = 'A6\r';
      } else if (command === 'ATSP0') {
        response = 'OK\r';
      } else if (command === 'ATL0') {
        response = 'OK\r';
      } else if (command === 'ATH1') {
        response = 'OK\r';
      } else if (command === 'ATS0') {
        response = 'OK\r';
      } else if (command === 'ATCAF0') {
        response = 'OK\r';
      } else if (command === 'ATCFC0') {
        response = 'OK\r';
      } else if (command === 'ATCFC1') {
        response = 'OK\r';
      } else if (command === 'ATCFC2') {
        response = 'OK\r';
      } else if (command === 'ATCFC3') {
        response = 'OK\r';
      } else if (command === 'ATCFC4') {
        response = 'OK\r';
      } else if (command === 'ATCFC5') {
        response = 'OK\r';
      } else if (command === 'ATCFC6') {
        response = 'OK\r';
      } else if (command === 'ATCFC7') {
        response = 'OK\r';
      } else if (command === 'ATCFC8') {
        response = 'OK\r';
      } else if (command === 'ATCFC9') {
        response = 'OK\r';
      } else if (command === 'ATCFCA') {
        response = 'OK\r';
      } else if (command === 'ATCFCB') {
        response = 'OK\r';
      } else if (command === 'ATCFCC') {
        response = 'OK\r';
      } else if (command === 'ATCFCD') {
        response = 'OK\r';
      } else if (command === 'ATCFCE') {
        response = 'OK\r';
      } else if (command === 'ATCFCF') {
        response = 'OK\r';
      } else if (command.startsWith('AT')) {
        response = 'OK\r';
      } else if (command.startsWith('01')) {
        // OBD Commands
        if (obdPids[command]) {
          response = obdPids[command] + '\r';
        } else {
          response = 'NO DATA\r';
        }
      } else if (command === '') {
        response = '>';
      } else {
        response = '?';
      }
      
      console.log('Sending response:', response);
      socket.write(response);
      
      // Gửi log đến web interface
      io.emit('log', {
        timestamp: new Date().toLocaleTimeString(),
        type: 'command',
        data: command,
        response: response.trim()
      });
    });
    
    socket.on('close', () => {
      console.log('Client disconnected');
      const index = connectedClients.indexOf(socket);
      if (index > -1) {
        connectedClients.splice(index, 1);
      }
    });
    
    socket.on('error', (err) => {
      console.log('Socket error:', err);
    });
  });
  
  tcpServer.listen(emulatorConfig.port, emulatorConfig.server, () => {
    console.log(`OBD ELM327 Emulator running on ${emulatorConfig.server}:${emulatorConfig.port}`);
    emulatorConfig.isRunning = true;
    io.emit('status', { running: true, port: emulatorConfig.port });
  });
  
  tcpServer.on('error', (err) => {
    console.log('TCP Server error:', err);
    emulatorConfig.isRunning = false;
    io.emit('status', { running: false, error: err.message });
  });
}

// API Routes
app.get('/', (req, res) => {
  res.sendFile(path.join(__dirname, 'public', 'index.html'));
});

app.get('/api/config', (req, res) => {
  res.json(emulatorConfig);
});

app.post('/api/config', (req, res) => {
  emulatorConfig = { ...emulatorConfig, ...req.body };
  res.json(emulatorConfig);
});

app.post('/api/start', (req, res) => {
  startTCPServer();
  res.json({ success: true, message: 'Server started' });
});

app.post('/api/stop', (req, res) => {
  if (tcpServer) {
    tcpServer.close();
    tcpServer = null;
  }
  emulatorConfig.isRunning = false;
  io.emit('status', { running: false });
  res.json({ success: true, message: 'Server stopped' });
});

// Socket.IO events
io.on('connection', (socket) => {
  console.log('Web client connected');
  
  socket.emit('config', emulatorConfig);
  socket.emit('status', { running: emulatorConfig.isRunning });
  
  socket.on('disconnect', () => {
    console.log('Web client disconnected');
  });
});

// Simulate live data với giá trị thực tế
setInterval(() => {
  if (emulatorConfig.isRunning && connectedClients.length > 0) {
    const now = new Date();
    const time = now.getTime();
    
    // Tạo dữ liệu giả lập với giá trị thực tế
    const liveData = {
      timestamp: now.toLocaleTimeString(),
      engineRPM: Math.floor(800 + Math.sin(time / 1000) * 2000),
      vehicleSpeed: Math.floor(60 + Math.sin(time / 2000) * 40),
      coolantTemp: Math.floor(80 + Math.sin(time / 3000) * 20),
      intakeTemp: Math.floor(25 + Math.sin(time / 4000) * 15),
      throttlePosition: Math.floor(10 + Math.sin(time / 1500) * 30),
      fuelLevel: Math.floor(50 + Math.sin(time / 5000) * 30)
    };
    
    // Cập nhật OBD PIDs với dữ liệu thực tế
    updateOBDData(liveData);
    
    io.emit('liveData', liveData);
  }
}, 1000);

// Function để cập nhật OBD data theo giá trị thực tế
function updateOBDData(data) {
  // Engine Coolant Temperature (PID 0105)
  // Formula: Data = Temperature + 40
  const ectData = (data.coolantTemp + 40).toString(16).padStart(2, '0').toUpperCase();
  obdPids['0105'] = `41 05 ${ectData}`;
  
  // Engine RPM (PID 010C)
  // Formula: RPM = (256 * A + B) / 4, so A = (RPM * 4) / 256, B = (RPM * 4) % 256
  const rpmValue = data.engineRPM * 4;
  const rpmA = Math.floor(rpmValue / 256).toString(16).padStart(2, '0').toUpperCase();
  const rpmB = (rpmValue % 256).toString(16).padStart(2, '0').toUpperCase();
  obdPids['010C'] = `41 0C ${rpmA} ${rpmB}`;
  
  // Vehicle Speed (PID 010D)
  // Formula: Speed = Data (km/h)
  const speedData = data.vehicleSpeed.toString(16).padStart(2, '0').toUpperCase();
  obdPids['010D'] = `41 0D ${speedData}`;
  
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
}

const PORT = process.env.PORT || 3000;
server.listen(PORT, () => {
  console.log(`Web server running on http://localhost:${PORT}`);
});
