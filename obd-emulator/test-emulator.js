#!/usr/bin/env node

/**
 * Test script for OBD2 Emulator
 * Tests các PIDs quan trọng: Speed, Coolant Temp, RPM
 */

const net = require('net');

const HOST = 'localhost';
const PORT = 35000;

const COLORS = {
  reset: '\x1b[0m',
  green: '\x1b[32m',
  red: '\x1b[31m',
  yellow: '\x1b[33m',
  blue: '\x1b[34m',
  cyan: '\x1b[36m',
};

function log(color, message) {
  console.log(color + message + COLORS.reset);
}

function parseResponse(response) {
  return response.replace(/>/g, '').trim();
}

function testPID(client, pid, description, parser) {
  return new Promise((resolve) => {
    let buffer = '';
    
    const timeout = setTimeout(() => {
      log(COLORS.red, `❌ ${description} (${pid}): TIMEOUT`);
      resolve(false);
    }, 2000);
    
    const dataHandler = (data) => {
      buffer += data.toString();
      
      if (buffer.includes('>')) {
        clearTimeout(timeout);
        client.removeListener('data', dataHandler);
        
        const response = parseResponse(buffer);
        const value = parser(response);
        
        if (value !== null && value !== undefined) {
          log(COLORS.green, `✅ ${description} (${pid}): ${value}`);
          log(COLORS.cyan, `   Raw response: "${response}"`);
          resolve(true);
        } else {
          log(COLORS.red, `❌ ${description} (${pid}): PARSE ERROR`);
          log(COLORS.yellow, `   Raw response: "${response}"`);
          resolve(false);
        }
      }
    };
    
    client.on('data', dataHandler);
    client.write(pid + '\r');
  });
}

// Parser functions (same as Flutter app)
function parseSpeed(response) {
  const cleaned = response.replace(/\s+/g, '');
  const i = cleaned.indexOf('410D');
  if (i >= 0 && cleaned.length >= i + 6) {
    return parseInt(cleaned.substring(i + 4, i + 6), 16) + ' km/h';
  }
  return null;
}

function parseCoolantTemp(response) {
  const cleaned = response.replace(/\s+/g, '');
  const i = cleaned.indexOf('4105');
  if (i >= 0 && cleaned.length >= i + 6) {
    const v = parseInt(cleaned.substring(i + 4, i + 6), 16);
    return (v - 40) + ' °C';
  }
  return null;
}

function parseRPM(response) {
  const cleaned = response.replace(/\s+/g, '');
  const i = cleaned.indexOf('410C');
  if (i >= 0 && cleaned.length >= i + 8) {
    const a = parseInt(cleaned.substring(i + 4, i + 6), 16);
    const b = parseInt(cleaned.substring(i + 6, i + 8), 16);
    return Math.floor((256 * a + b) / 4) + ' rpm';
  }
  return null;
}

function parseIntakeTemp(response) {
  const cleaned = response.replace(/\s+/g, '');
  const i = cleaned.indexOf('410F');
  if (i >= 0 && cleaned.length >= i + 6) {
    const v = parseInt(cleaned.substring(i + 4, i + 6), 16);
    return (v - 40) + ' °C';
  }
  return null;
}

function parseThrottle(response) {
  const cleaned = response.replace(/\s+/g, '');
  const i = cleaned.indexOf('4111');
  if (i >= 0 && cleaned.length >= i + 6) {
    const v = parseInt(cleaned.substring(i + 4, i + 6), 16);
    return Math.round((v * 100) / 255) + ' %';
  }
  return null;
}

async function runTests() {
  log(COLORS.blue, '\n🔌 Connecting to OBD2 Emulator...');
  log(COLORS.cyan, `   Host: ${HOST}:${PORT}\n`);
  
  const client = new net.Socket();
  
  client.connect(PORT, HOST, async () => {
    log(COLORS.green, '✅ Connected!\n');
    
    // Wait for prompt
    await new Promise(resolve => setTimeout(resolve, 100));
    
    log(COLORS.blue, '📡 Initializing ELM327...\n');
    
    // Send init commands
    const initCommands = [
      { cmd: 'ATZ', desc: 'Reset' },
      { cmd: 'ATE0', desc: 'Echo OFF' },
      { cmd: 'ATL0', desc: 'Linefeeds OFF' },
      { cmd: 'ATS0', desc: 'Spaces OFF' },
      { cmd: 'ATH0', desc: 'Headers OFF' },
      { cmd: 'ATSP0', desc: 'Auto Protocol' },
    ];
    
    for (const { cmd, desc } of initCommands) {
      await new Promise((resolve) => {
        let buffer = '';
        const dataHandler = (data) => {
          buffer += data.toString();
          if (buffer.includes('>')) {
            client.removeListener('data', dataHandler);
            const response = parseResponse(buffer);
            log(COLORS.cyan, `   ${cmd} (${desc}): ${response}`);
            resolve();
          }
        };
        client.on('data', dataHandler);
        client.write(cmd + '\r');
      });
      await new Promise(resolve => setTimeout(resolve, 100));
    }
    
    log(COLORS.blue, '\n🧪 Testing PIDs...\n');
    
    // Test essential PIDs
    const tests = [
      { pid: '010C', desc: 'Engine RPM', parser: parseRPM },
      { pid: '010D', desc: 'Vehicle Speed', parser: parseSpeed },
      { pid: '0105', desc: 'Coolant Temperature', parser: parseCoolantTemp },
      { pid: '010F', desc: 'Intake Air Temperature', parser: parseIntakeTemp },
      { pid: '0111', desc: 'Throttle Position', parser: parseThrottle },
    ];
    
    let passed = 0;
    for (const test of tests) {
      const result = await testPID(client, test.pid, test.desc, test.parser);
      if (result) passed++;
      await new Promise(resolve => setTimeout(resolve, 200));
    }
    
    log(COLORS.blue, `\n📊 Results: ${passed}/${tests.length} tests passed`);
    
    if (passed === tests.length) {
      log(COLORS.green, '🎉 All tests passed! Emulator is working correctly.\n');
    } else {
      log(COLORS.yellow, '⚠️  Some tests failed. Check emulator configuration.\n');
    }
    
    client.destroy();
  });
  
  client.on('error', (err) => {
    log(COLORS.red, `\n❌ Connection Error: ${err.message}`);
    log(COLORS.yellow, '\n💡 Make sure emulator is running:');
    log(COLORS.cyan, '   1. cd obd-emulator');
    log(COLORS.cyan, '   2. node server.js');
    log(COLORS.cyan, '   3. Open http://localhost:3000');
    log(COLORS.cyan, '   4. Click "Start Server"\n');
  });
}

log(COLORS.blue, '════════════════════════════════════════');
log(COLORS.blue, '   OBD2 Emulator Test Script');
log(COLORS.blue, '════════════════════════════════════════');

runTests();

