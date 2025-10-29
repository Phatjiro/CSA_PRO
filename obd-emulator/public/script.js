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
    
    // Live data
    connectedClients: document.getElementById('connectedClients'),
    engineRPM: document.getElementById('engineRPM'),
    vehicleSpeed: document.getElementById('vehicleSpeed'),
    coolantTemp: document.getElementById('coolantTemp'),
    intakeTemp: document.getElementById('intakeTemp'),
    throttlePosition: document.getElementById('throttlePosition'),
    fuelLevel: document.getElementById('fuelLevel'),
    
    // Progress bars
    rpmBar: document.getElementById('rpmBar'),
    speedBar: document.getElementById('speedBar'),
    coolantBar: document.getElementById('coolantBar'),
    intakeBar: document.getElementById('intakeBar'),
    throttleBar: document.getElementById('throttleBar'),
    fuelBar: document.getElementById('fuelBar'),
    
    // Log
    logContainer: document.getElementById('logContainer')
};

// Current configuration
let currentConfig = {};

// Initialize
document.addEventListener('DOMContentLoaded', function() {
    updateTime();
    setInterval(updateTime, 1000);
    
    loadConfiguration();
    setupEventListeners();
    
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
    const timeString = now.toLocaleTimeString('vi-VN', { 
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

// Setup event listeners
function setupEventListeners() {
    // Control buttons
    elements.startBtn.addEventListener('click', startServer);
    elements.stopBtn.addEventListener('click', stopServer);
    elements.resetBtn.addEventListener('click', resetConfiguration);
    elements.clearLogBtn.addEventListener('click', clearLog);
    
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
    updateDataValue(elements.engineRPM, data.engineRPM);
    updateDataValue(elements.vehicleSpeed, data.vehicleSpeed);
    updateDataValue(elements.coolantTemp, data.coolantTemp);
    updateDataValue(elements.intakeTemp, data.intakeTemp);
    updateDataValue(elements.throttlePosition, data.throttlePosition);
    updateDataValue(elements.fuelLevel, data.fuelLevel);
    
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
