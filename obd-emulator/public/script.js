// Socket.IO connection
const socket = io();

// DOM Elements
const elements = {
    // Status
    statusIndicator: document.getElementById('statusIndicator'),
    statusText: document.getElementById('statusText'),
    currentTime: document.getElementById('currentTime'),
    
    // Configuration
    elmName: document.getElementById('elmName'),
    elmVersion: document.getElementById('elmVersion'),
    deviceId: document.getElementById('deviceId'),
    vinCode: document.getElementById('vinCode'),
    ecuCount: document.getElementById('ecuCount'),
    server: document.getElementById('server'),
    port: document.getElementById('port'),
    
    // Toggle switches
    echo: document.getElementById('echo'),
    headers: document.getElementById('headers'),
    dlc: document.getElementById('dlc'),
    lineFeed: document.getElementById('lineFeed'),
    spaces: document.getElementById('spaces'),
    doubleLF: document.getElementById('doubleLF'),
    
    // Buttons
    startBtn: document.getElementById('startBtn'),
    stopBtn: document.getElementById('stopBtn'),
    resetBtn: document.getElementById('resetBtn'),
    ecuMinus: document.getElementById('ecuMinus'),
    ecuPlus: document.getElementById('ecuPlus'),
    clearLogBtn: document.getElementById('clearLogBtn'),
    toggleLiveDataViewBtn: document.getElementById('toggleLiveDataViewBtn'),
    // Live mode toggle
    liveModeToggle: document.getElementById('liveModeToggle'),
    
    // Live data
    connectedClients: document.getElementById('connectedClients'),
    engineRPM: document.getElementById('engineRPM'),
    vehicleSpeed: document.getElementById('vehicleSpeed'),
    coolantTemp: document.getElementById('coolantTemp'),
    intakeTemp: document.getElementById('intakeTemp'),
    throttlePosition: document.getElementById('throttlePosition'),
    fuelLevel: document.getElementById('fuelLevel'),
    engineLoad: document.getElementById('engineLoad'),
    map: document.getElementById('map'),
    baro: document.getElementById('baro'),
    maf: document.getElementById('maf'),
    voltage: document.getElementById('voltage'),
    ambient: document.getElementById('ambient'),
    lambda: document.getElementById('lambda'),
    fuelSystemStatus: document.getElementById('fuelSystemStatus'),
    timingAdvance: document.getElementById('timingAdvance'),
    runtimeSinceStart: document.getElementById('runtimeSinceStart'),
    distanceWithMIL: document.getElementById('distanceWithMIL'),
    commandedPurge: document.getElementById('commandedPurge'),
    warmupsSinceClear: document.getElementById('warmupsSinceClear'),
    distanceSinceClear: document.getElementById('distanceSinceClear'),
    catalystTemp: document.getElementById('catalystTemp'),
    absoluteLoad: document.getElementById('absoluteLoad'),
    commandedEquivRatio: document.getElementById('commandedEquivRatio'),
    relativeThrottle: document.getElementById('relativeThrottle'),
    absoluteThrottleB: document.getElementById('absoluteThrottleB'),
    absoluteThrottleC: document.getElementById('absoluteThrottleC'),
    pedalPositionD: document.getElementById('pedalPositionD'),
    pedalPositionE: document.getElementById('pedalPositionE'),
    pedalPositionF: document.getElementById('pedalPositionF'),
    commandedThrottleActuator: document.getElementById('commandedThrottleActuator'),
    timeRunWithMIL: document.getElementById('timeRunWithMIL'),
    timeSinceCodesCleared: document.getElementById('timeSinceCodesCleared'),
    maxEquivRatio: document.getElementById('maxEquivRatio'),
    maxAirFlow: document.getElementById('maxAirFlow'),
    fuelType: document.getElementById('fuelType'),
    ethanolFuel: document.getElementById('ethanolFuel'),
    absEvapPressure: document.getElementById('absEvapPressure'),
    evapPressure: document.getElementById('evapPressure'),
    shortTermO2Trim1: document.getElementById('shortTermO2Trim1'),
    longTermO2Trim1: document.getElementById('longTermO2Trim1'),
    shortTermO2Trim2: document.getElementById('shortTermO2Trim2'),
    longTermO2Trim2: document.getElementById('longTermO2Trim2'),
    shortTermO2Trim3: document.getElementById('shortTermO2Trim3'),
    longTermO2Trim3: document.getElementById('longTermO2Trim3'),
    shortTermO2Trim4: document.getElementById('shortTermO2Trim4'),
    longTermO2Trim4: document.getElementById('longTermO2Trim4'),
    catalystTemp1: document.getElementById('catalystTemp1'),
    catalystTemp2: document.getElementById('catalystTemp2'),
    catalystTemp3: document.getElementById('catalystTemp3'),
    catalystTemp4: document.getElementById('catalystTemp4'),
    fuelPressure: document.getElementById('fuelPressure'),
    shortTermFuelTrim1: document.getElementById('shortTermFuelTrim1'),
    longTermFuelTrim1: document.getElementById('longTermFuelTrim1'),
    shortTermFuelTrim2: document.getElementById('shortTermFuelTrim2'),
    longTermFuelTrim2: document.getElementById('longTermFuelTrim2'),
    
    // Progress bars
    rpmBar: document.getElementById('rpmBar'),
    speedBar: document.getElementById('speedBar'),
    coolantBar: document.getElementById('coolantBar'),
    intakeBar: document.getElementById('intakeBar'),
    throttleBar: document.getElementById('throttleBar'),
    fuelBar: document.getElementById('fuelBar'),
    
    // Log
    logContainer: document.getElementById('logContainer'),
    liveDataSection: document.querySelector('.live-data-section'),
    liveDataGrid: document.getElementById('liveDataGrid')
};

const dtcEls = {
  btnStored: document.getElementById('btnDtcStored'),
  btnPending: document.getElementById('btnDtcPending'),
  btnPermanent: document.getElementById('btnDtcPermanent'),
  btnClear: document.getElementById('btnDtcClear'),
  list: document.getElementById('dtcList'),
  mil: document.getElementById('milStatus'),
};

const ffEls = {
  btnCapture: document.getElementById('btnFfCapture'),
  btnClear: document.getElementById('btnFfClear'),
  btnRefresh: document.getElementById('btnFfRefresh'),
  grid: document.getElementById('ffGrid'),
};

const m6Els = {
  btnRefresh: document.getElementById('btnM6Refresh'),
  grid: document.getElementById('m6Grid'),
};

// Current configuration
let currentConfig = {};

// Initialize
document.addEventListener('DOMContentLoaded', function() {
    updateTime();
    setInterval(updateTime, 1000);
    
    loadConfiguration();
    setupEventListeners();
    initLiveDataViewMode();
    initLiveModeFromServer();

    // DTC buttons
    if (dtcEls.btnStored) dtcEls.btnStored.addEventListener('click', () => loadDtc('stored'));
    if (dtcEls.btnPending) dtcEls.btnPending.addEventListener('click', () => loadDtc('pending'));
    if (dtcEls.btnPermanent) dtcEls.btnPermanent.addEventListener('click', () => loadDtc('permanent'));
    if (dtcEls.btnClear) dtcEls.btnClear.addEventListener('click', () => clearDtc());

    // Freeze Frame buttons
    if (ffEls.btnCapture) ffEls.btnCapture.addEventListener('click', () => captureFreezeFrame());
    if (ffEls.btnClear) ffEls.btnClear.addEventListener('click', () => clearFreezeFrame());
    if (ffEls.btnRefresh) ffEls.btnRefresh.addEventListener('click', () => loadFreezeFrame());

    // Mode 06
    if (m6Els.btnRefresh) m6Els.btnRefresh.addEventListener('click', () => loadMode06());

    // Auto load stored on start
    setTimeout(() => loadDtc('stored'), 300);
    setTimeout(() => loadFreezeFrame(), 600);
    setTimeout(() => loadMode06(), 900);

    // Socket events
    socket.on('dtcCleared', () => {
        addLogEntry('INFO', 'DTC cleared');
        loadDtc('stored');
    });

    // Request current configuration from server
    fetch('/api/config')
        .then(response => response.json())
        .then(config => {
            currentConfig = config;
            updateUI();
        })
        .catch(error => {
            console.error('Error loading configuration:', error);
            addLogEntry('ERROR', 'Failed to load configuration');
        });
});

// Update time display
function updateTime() {
    const now = new Date();
    const timeString = now.toLocaleTimeString('en-US', { 
        hour: '2-digit', 
        minute: '2-digit',
        hour12: false 
    });
    elements.currentTime.textContent = timeString;
}

// Load configuration from localStorage
function loadConfiguration() {
    const savedConfig = localStorage.getItem('obdEmulatorConfig');
    if (savedConfig) {
        try {
            const config = JSON.parse(savedConfig);
            applyConfiguration(config);
        } catch (error) {
            console.error('Error loading saved configuration:', error);
        }
    }
}

// Save configuration to localStorage
function saveConfiguration() {
    const config = getCurrentConfiguration();
    localStorage.setItem('obdEmulatorConfig', JSON.stringify(config));
}

// Get current configuration from UI
function getCurrentConfiguration() {
    return {
        elmName: elements.elmName.value,
        elmVersion: elements.elmVersion.value,
        deviceId: elements.deviceId.value,
        vinCode: elements.vinCode.value,
        ecuCount: parseInt(elements.ecuCount.value),
        server: elements.server.value,
        port: parseInt(elements.port.value),
        settings: {
            echo: elements.echo.checked,
            headers: elements.headers.checked,
            dlc: elements.dlc.checked,
            lineFeed: elements.lineFeed.checked,
            spaces: elements.spaces.checked,
            doubleLF: elements.doubleLF.checked
        }
    };
}

// Apply configuration to UI
function applyConfiguration(config) {
    elements.elmName.value = config.elmName || 'ELM327';
    elements.elmVersion.value = config.elmVersion || 'v1.2';
    elements.deviceId.value = config.deviceId || 'ELM327';
    elements.vinCode.value = config.vinCode || 'WAUBFGFFXF1001572';
    elements.ecuCount.value = config.ecuCount || 2;
    elements.server.value = config.server || '192.168.1.76';
    elements.port.value = config.port || 35000;
    
    if (config.settings) {
        elements.echo.checked = config.settings.echo || false;
        elements.headers.checked = config.settings.headers !== false;
        elements.dlc.checked = config.settings.dlc || false;
        elements.lineFeed.checked = config.settings.lineFeed || false;
        elements.spaces.checked = config.settings.spaces !== false;
        elements.doubleLF.checked = config.settings.doubleLF || false;
    }
}

// Update UI with current configuration
function updateUI() {
    applyConfiguration(currentConfig);
    updateStatus(currentConfig.isRunning);
}

// Init live mode from server
function initLiveModeFromServer() {
    fetch('/api/live')
        .then(r => r.json())
        .then(data => {
            const mode = (data && data.mode) || 'random';
            applyLiveModeToUI(mode);
        })
        .catch(() => {});
}

function applyLiveModeToUI(mode) {
    if (!elements.liveModeToggle) return;
    elements.liveModeToggle.checked = mode !== 'static';
}

function setLiveMode(mode) {
    fetch('/api/live/mode', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ mode })
    })
    .then(r => r.json())
    .then(res => {
        if (res && res.success) {
            addLogEntry('INFO', `Live mode set to ${mode}`);
        } else {
            addLogEntry('ERROR', 'Failed to set live mode');
        }
    })
    .catch(err => {
        addLogEntry('ERROR', 'Failed to set live mode: ' + err.message);
    });
}

// Setup event listeners
function setupEventListeners() {
    // Control buttons
    elements.startBtn.addEventListener('click', startServer);
    elements.stopBtn.addEventListener('click', stopServer);
    elements.resetBtn.addEventListener('click', resetConfiguration);
    elements.clearLogBtn.addEventListener('click', clearLog);
    
    // Toggle live data view
    if (elements.toggleLiveDataViewBtn) {
        elements.toggleLiveDataViewBtn.addEventListener('click', toggleLiveDataViewMode);
    }
    
    // ECU count controls
    elements.ecuMinus.addEventListener('click', () => {
        const current = parseInt(elements.ecuCount.value);
        if (current > 1) {
            elements.ecuCount.value = current - 1;
            saveConfiguration();
        }
    });
    
    elements.ecuPlus.addEventListener('click', () => {
        const current = parseInt(elements.ecuCount.value);
        if (current < 10) {
            elements.ecuCount.value = current + 1;
            saveConfiguration();
        }
    });
    
    // Configuration inputs
    const configInputs = [
        elements.elmName, elements.elmVersion, elements.deviceId,
        elements.vinCode, elements.ecuCount, elements.server, elements.port
    ];
    
    configInputs.forEach(input => {
        input.addEventListener('change', saveConfiguration);
        input.addEventListener('input', saveConfiguration);
    });
    
    // Toggle switches
    const toggles = [
        elements.echo, elements.headers, elements.dlc,
        elements.lineFeed, elements.spaces, elements.doubleLF
    ];
    
    toggles.forEach(toggle => {
        toggle.addEventListener('change', saveConfiguration);
    });

    // Live mode toggle change
    if (elements.liveModeToggle) {
        elements.liveModeToggle.addEventListener('change', () => {
            const mode = elements.liveModeToggle.checked ? 'random' : 'static';
            setLiveMode(mode);
        });
    }
}

// Live Data view mode (scroll/full)
function initLiveDataViewMode() {
    const mode = localStorage.getItem('liveDataViewMode') || 'scroll';
    applyLiveDataViewMode(mode);
}

function toggleLiveDataViewMode() {
    const current = localStorage.getItem('liveDataViewMode') || 'scroll';
    const next = current === 'scroll' ? 'full' : 'scroll';
    localStorage.setItem('liveDataViewMode', next);
    applyLiveDataViewMode(next);
}

function applyLiveDataViewMode(mode) {
    if (!elements.liveDataSection || !elements.toggleLiveDataViewBtn) return;
    if (mode === 'full') {
        elements.liveDataSection.classList.add('full');
        elements.toggleLiveDataViewBtn.innerHTML = '<i class="fas fa-compress"></i> Collapse';
        elements.toggleLiveDataViewBtn.title = 'Collapse to scroll mode';
    } else {
        elements.liveDataSection.classList.remove('full');
        elements.toggleLiveDataViewBtn.innerHTML = '<i class="fas fa-expand"></i> Show full';
        elements.toggleLiveDataViewBtn.title = 'Show all';
    }
}

// Start server
function startServer() {
    const config = getCurrentConfiguration();
    
    fetch('/api/start', {
        method: 'POST',
        headers: {
            'Content-Type': 'application/json'
        },
        body: JSON.stringify(config)
    })
    .then(response => response.json())
    .then(data => {
        if (data.success) {
            addLogEntry('INFO', 'Server started successfully');
            elements.startBtn.disabled = true;
            elements.stopBtn.disabled = false;
        } else {
            addLogEntry('ERROR', 'Failed to start server: ' + data.message);
        }
    })
    .catch(error => {
        console.error('Error starting server:', error);
        addLogEntry('ERROR', 'Failed to start server: ' + error.message);
    });
}

// Stop server
function stopServer() {
    fetch('/api/stop', {
        method: 'POST'
    })
    .then(response => response.json())
    .then(data => {
        if (data.success) {
            addLogEntry('INFO', 'Server stopped');
            elements.startBtn.disabled = false;
            elements.stopBtn.disabled = true;
        } else {
            addLogEntry('ERROR', 'Failed to stop server: ' + data.message);
        }
    })
    .catch(error => {
        console.error('Error stopping server:', error);
        addLogEntry('ERROR', 'Failed to stop server: ' + error.message);
    });
}

// Reset configuration
function resetConfiguration() {
    if (confirm('Are you sure you want to reset all settings to default?')) {
        const defaultConfig = {
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
            }
        };
        
        applyConfiguration(defaultConfig);
        saveConfiguration();
        addLogEntry('INFO', 'Configuration reset to default');
    }
}

// Update status indicator
function updateStatus(isRunning) {
    const statusDot = elements.statusIndicator.querySelector('.status-dot');
    if (isRunning) {
        statusDot.classList.add('connected');
        elements.statusText.textContent = 'Connected';
    } else {
        statusDot.classList.remove('connected');
        elements.statusText.textContent = 'Disconnected';
    }
}

// Update live data
function updateLiveData(data) {
    // Update values with animation
    // Core metrics
    updateDataValue(elements.engineRPM, data.engineRPM);
    updateDataValue(elements.vehicleSpeed, data.vehicleSpeed);
    updateDataValue(elements.coolantTemp, data.coolantTemp);
    updateDataValue(elements.intakeTemp, data.intakeTemp);
    updateDataValue(elements.throttlePosition, data.throttlePosition);
    updateDataValue(elements.fuelLevel, data.fuelLevel);
    updateDataValue(elements.engineLoad, data.engineLoad ?? 0);
    updateDataValue(elements.map, data.map ?? 0);
    updateDataValue(elements.baro, data.baro ?? 0);
    updateDataValue(elements.maf, data.maf ?? 0);
    updateDataValue(elements.voltage, data.voltage ?? 0);
    updateDataValue(elements.ambient, data.ambient ?? 0);
    updateDataValue(elements.lambda, data.lambda ?? 0);
    
    // Additional metrics
    updateDataValue(elements.fuelSystemStatus, data.fuelSystemStatus ?? 0);
    updateDataValue(elements.timingAdvance, data.timingAdvance ?? 0);
    updateDataValue(elements.runtimeSinceStart, data.runtimeSinceStart ?? 0);
    updateDataValue(elements.distanceWithMIL, data.distanceWithMIL ?? 0);
    updateDataValue(elements.commandedPurge, data.commandedPurge ?? 0);
    updateDataValue(elements.warmupsSinceClear, data.warmupsSinceClear ?? 0);
    updateDataValue(elements.distanceSinceClear, data.distanceSinceClear ?? 0);
    updateDataValue(elements.catalystTemp, data.catalystTemp ?? 0);
    updateDataValue(elements.absoluteLoad, data.absoluteLoad ?? 0);
    updateDataValue(elements.commandedEquivRatio, data.commandedEquivRatio ?? 0);
    updateDataValue(elements.relativeThrottle, data.relativeThrottle ?? 0);
    updateDataValue(elements.absoluteThrottleB, data.absoluteThrottleB ?? 0);
    updateDataValue(elements.absoluteThrottleC, data.absoluteThrottleC ?? 0);
    updateDataValue(elements.pedalPositionD, data.pedalPositionD ?? 0);
    updateDataValue(elements.pedalPositionE, data.pedalPositionE ?? 0);
    updateDataValue(elements.pedalPositionF, data.pedalPositionF ?? 0);
    updateDataValue(elements.commandedThrottleActuator, data.commandedThrottleActuator ?? 0);
    updateDataValue(elements.timeRunWithMIL, data.timeRunWithMIL ?? 0);
    updateDataValue(elements.timeSinceCodesCleared, data.timeSinceCodesCleared ?? 0);
    updateDataValue(elements.maxEquivRatio, data.maxEquivRatio ?? 0);
    updateDataValue(elements.maxAirFlow, data.maxAirFlow ?? 0);
    updateDataValue(elements.fuelType, data.fuelType ?? 0);
    updateDataValue(elements.ethanolFuel, data.ethanolFuel ?? 0);
    updateDataValue(elements.absEvapPressure, data.absEvapPressure ?? 0);
    updateDataValue(elements.evapPressure, data.evapPressure ?? 0);
    updateDataValue(elements.shortTermO2Trim1, data.shortTermO2Trim1 ?? 0);
    updateDataValue(elements.longTermO2Trim1, data.longTermO2Trim1 ?? 0);
    updateDataValue(elements.shortTermO2Trim2, data.shortTermO2Trim2 ?? 0);
    updateDataValue(elements.longTermO2Trim2, data.longTermO2Trim2 ?? 0);
    updateDataValue(elements.shortTermO2Trim3, data.shortTermO2Trim3 ?? 0);
    updateDataValue(elements.longTermO2Trim3, data.longTermO2Trim3 ?? 0);
    updateDataValue(elements.shortTermO2Trim4, data.shortTermO2Trim4 ?? 0);
    updateDataValue(elements.longTermO2Trim4, data.longTermO2Trim4 ?? 0);
    updateDataValue(elements.catalystTemp1, data.catalystTemp1 ?? 0);
    updateDataValue(elements.catalystTemp2, data.catalystTemp2 ?? 0);
    updateDataValue(elements.catalystTemp3, data.catalystTemp3 ?? 0);
    updateDataValue(elements.catalystTemp4, data.catalystTemp4 ?? 0);
    updateDataValue(elements.fuelPressure, data.fuelPressure ?? 0);
    updateDataValue(elements.shortTermFuelTrim1, data.shortTermFuelTrim1 ?? 0);
    updateDataValue(elements.longTermFuelTrim1, data.longTermFuelTrim1 ?? 0);
    updateDataValue(elements.shortTermFuelTrim2, data.shortTermFuelTrim2 ?? 0);
    updateDataValue(elements.longTermFuelTrim2, data.longTermFuelTrim2 ?? 0);
    
    // Update progress bars
    updateProgressBar(elements.rpmBar, data.engineRPM, 0, 8000);
    updateProgressBar(elements.speedBar, data.vehicleSpeed, 0, 200);
    updateProgressBar(elements.coolantBar, data.coolantTemp, 0, 120);
    updateProgressBar(elements.intakeBar, data.intakeTemp, -40, 60);
    updateProgressBar(elements.throttleBar, data.throttlePosition, 0, 100);
    updateProgressBar(elements.fuelBar, data.fuelLevel, 0, 100);
}

// Update data value with animation
function updateDataValue(element, value) {
    if (element.textContent !== value.toString()) {
        element.textContent = value;
        element.classList.add('updated');
        setTimeout(() => element.classList.remove('updated'), 500);
    }
}

// Update progress bar
function updateProgressBar(element, value, min, max) {
    if (!element) return;
    const percentage = Math.min(100, Math.max(0, ((value - min) / (max - min)) * 100));
    element.style.width = percentage + '%';
}

// Add log entry
function addLogEntry(type, message, data = null) {
    const logEntry = document.createElement('div');
    logEntry.className = 'log-entry';
    
    const time = new Date().toLocaleTimeString('vi-VN');
    const timeSpan = document.createElement('span');
    timeSpan.className = 'log-time';
    timeSpan.textContent = time;
    
    const typeSpan = document.createElement('span');
    typeSpan.className = `log-type ${type}`;
    typeSpan.textContent = type;
    
    const messageSpan = document.createElement('span');
    messageSpan.className = 'log-message';
    messageSpan.textContent = message;
    
    if (data) {
        const dataSpan = document.createElement('span');
        dataSpan.className = 'log-data';
        dataSpan.textContent = ` | Data: ${data}`;
        messageSpan.appendChild(dataSpan);
    }
    
    logEntry.appendChild(timeSpan);
    logEntry.appendChild(typeSpan);
    logEntry.appendChild(messageSpan);
    
    elements.logContainer.appendChild(logEntry);
    elements.logContainer.scrollTop = elements.logContainer.scrollHeight;
}

// Clear log
function clearLog() {
    elements.logContainer.innerHTML = '';
    addLogEntry('INFO', 'Log cleared');
}

// Socket.IO event handlers
socket.on('connect', () => {
    addLogEntry('INFO', 'Connected to server');
});

socket.on('disconnect', () => {
    addLogEntry('INFO', 'Disconnected from server');
});

socket.on('config', (config) => {
    currentConfig = config;
    updateUI();
});

socket.on('status', (status) => {
    updateStatus(status.running);
    if (status.running) {
        elements.startBtn.disabled = true;
        elements.stopBtn.disabled = false;
    } else {
        elements.startBtn.disabled = false;
        elements.stopBtn.disabled = true;
    }
});

socket.on('liveData', (data) => {
    updateLiveData(data);
});

socket.on('log', (logData) => {
    addLogEntry('COMMAND', `Command: ${logData.data}`, `Response: ${logData.response}`);
});

// Handle connection count updates
socket.on('clients', (count) => {
    elements.connectedClients.textContent = count;
});

// Error handling
window.addEventListener('error', (event) => {
    addLogEntry('ERROR', 'JavaScript error: ' + event.error.message);
});

// Handle unhandled promise rejections
window.addEventListener('unhandledrejection', (event) => {
    addLogEntry('ERROR', 'Unhandled promise rejection: ' + event.reason);
});

// Auto-save configuration every 5 seconds
setInterval(() => {
    saveConfiguration();
}, 5000);

function loadDtc(type) {
  fetch(`/api/dtc/${type}`)
    .then(r => r.json())
    .then(data => {
      renderDtc(data);
    })
    .catch(() => {
      renderDtc({ codes: [], milOn: false, type });
    });
}

function clearDtc() {
  fetch('/api/dtc/clear', { method: 'POST' })
    .then(r => r.json())
    .then(() => loadDtc('stored'))
    .catch(() => {});
}

function renderDtc(data) {
  if (!dtcEls.list) return;
  const codes = data?.codes || [];
  const type = data?.type || 'stored';
  const milOn = !!data?.milOn;
  if (dtcEls.mil) dtcEls.mil.textContent = `MIL: ${milOn ? 'ON' : 'OFF'}`;

  if (codes.length === 0) {
    dtcEls.list.innerHTML = '<div class="data-card">NO DATA</div>';
    return;
  }
  const items = codes.map(c => `<div class="data-card"><div class="data-value" style="font-size:1rem;">${c}</div><div class="data-label">${type}</div></div>`).join('');
  dtcEls.list.innerHTML = items;
}

function loadFreezeFrame() {
  fetch('/api/freeze-frame')
    .then(r => r.json())
    .then(data => renderFreezeFrame(data?.snapshot || null))
    .catch(() => renderFreezeFrame(null));
}

function captureFreezeFrame() {
  fetch('/api/freeze-frame/capture', { method: 'POST' })
    .then(r => r.json())
    .then(() => loadFreezeFrame())
    .catch(() => {});
}

function clearFreezeFrame() {
  fetch('/api/freeze-frame/clear', { method: 'POST' })
    .then(r => r.json())
    .then(() => loadFreezeFrame())
    .catch(() => {});
}

function renderFreezeFrame(snapshot) {
  if (!ffEls.grid) return;
  if (!snapshot) {
    ffEls.grid.innerHTML = '<div class="data-card">No snapshot</div>';
    return;
  }
  // Display selected PIDs in a compact way
  const order = ['010C','010D','0105','010F','0110','0111'];
  const items = order
    .filter(pid => snapshot[pid])
    .map(pid => {
      const enc = (snapshot[pid] || '').toString();
      const parsed = parseFreezeFrameValue(pid, enc);
      const label = parsed.label;
      const display = parsed.value != null ? `${parsed.value}${parsed.unit || ''}` : enc;
      return `<div class=\"data-card\"><div class=\"data-value\" style=\"font-size:1.1rem;\">${display}</div><div class=\"data-label\">${label}</div></div>`;
    })
    .join('');
  ffEls.grid.innerHTML = items || '<div class="data-card">No snapshot</div>';
}

// Parse Mode 01-encoded strings like '41 0C AA BB' into numeric values
function parseFreezeFrameValue(pid, encoded) {
  const cleaned = (encoded || '').replace(/\s+/g, '').toUpperCase();
  const key = '41' + pid.substring(2);
  const labelMap = { '010C':'RPM', '010D':'Speed', '0105':'ECT', '010F':'IAT', '0110':'MAF', '0111':'Throttle' };
  const result = { label: labelMap[pid] || pid, value: null, unit: '' };
  const idx = cleaned.indexOf(key);
  if (idx < 0) return result;
  try {
    switch (pid) {
      case '010C': { // RPM = ((256*A)+B)/4
        const a = parseInt(cleaned.substring(idx+4, idx+6), 16);
        const b = parseInt(cleaned.substring(idx+6, idx+8), 16);
        result.value = Math.round(((256*a)+b)/4);
        result.unit = ' rpm';
        break;
      }
      case '010D': { // Speed = A
        const a = parseInt(cleaned.substring(idx+4, idx+6), 16);
        result.value = a;
        result.unit = ' km/h';
        break;
      }
      case '0105': { // Coolant = A-40
        const a = parseInt(cleaned.substring(idx+4, idx+6), 16);
        result.value = a - 40;
        result.unit = ' °C';
        break;
      }
      case '010F': { // IAT = A-40
        const a = parseInt(cleaned.substring(idx+4, idx+6), 16);
        result.value = a - 40;
        result.unit = ' °C';
        break;
      }
      case '0110': { // MAF = ((256*A)+B)/100
        const a = parseInt(cleaned.substring(idx+4, idx+6), 16);
        const b = parseInt(cleaned.substring(idx+6, idx+8), 16);
        result.value = Math.round(((256*a)+b)/100);
        result.unit = ' g/s';
        break;
      }
      case '0111': { // Throttle % = 100*A/255
        const a = parseInt(cleaned.substring(idx+4, idx+6), 16);
        result.value = Math.round((a*100)/255);
        result.unit = ' %';
        break;
      }
    }
  } catch (e) { /* ignore, fallback to hex */ }
  return result;
}

function loadMode06() {
  fetch('/api/mode06')
    .then(r => r.json())
    .then(d => renderMode06(d?.tests || []))
    .catch(() => renderMode06([]));
}

function renderMode06(tests) {
  if (!m6Els.grid) return;
  if (!tests || tests.length === 0) {
    m6Els.grid.innerHTML = '<div class="data-card">No tests</div>';
    return;
  }
  const items = tests.map(t => {
    const pass = !!t.pass;
    const color = pass ? 'style=\"color:#4CAF50\"' : 'style=\"color:#FF5252\"';
    const value = Number(t.value);
    const min = Number(t.min);
    const max = Number(t.max);
    return `<div class=\"data-card\">
      <div class=\"data-value\">${value}</div>
      <div class=\"data-label\">${t.tid} - ${t.name}</div>
      <div ${color}>${pass ? 'PASS' : 'FAIL'} (min ${min}, max ${max})</div>
    </div>`;
  }).join('');
  m6Els.grid.innerHTML = items;
}
