import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/vehicle.dart';
import '../services/connection_manager.dart';
import '../services/vehicle_service.dart';
import '../services/ble_obd_link.dart';
import '../utils/prefs_keys.dart';
import '../widgets/vehicle_picker.dart';
import 'scan_dialog.dart';

class ConnectScreen extends StatefulWidget {
  const ConnectScreen({super.key});

  @override
  State<ConnectScreen> createState() => _ConnectScreenState();
}

class _ConnectScreenState extends State<ConnectScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  
  // TCP/IP fields
  final TextEditingController _hostController =
      TextEditingController(text: '192.168.0.10');
  final TextEditingController _portController =
      TextEditingController(text: '35000');
  
  // BLE fields
  List<BleScanResult> _bleDevices = [];
  bool _scanning = false;
  BleScanResult? _selectedBleDevice;
  StreamSubscription<List<BleScanResult>>? _scanSub;
  String? _lastBleDeviceId;
  String? _lastBleDeviceName;
  
  // Common fields
  bool _connecting = false;
  bool _isConnected = false;
  bool _isScanning = false;
  String? _error;
  Vehicle? _selectedVehicle;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadLastVehicle();
  }

  @override
  void dispose() {
    _scanSub?.cancel();
    _tabController.dispose();
    _hostController.dispose();
    _portController.dispose();
    super.dispose();
  }

  Future<void> _loadLastVehicle() async {
    await VehicleService.init();
    final prefs = await SharedPreferences.getInstance();
    final vehicleId = prefs.getString(PrefsKeys.currentVehicleId);
    Vehicle? vehicle;
    if (vehicleId != null) {
      vehicle = VehicleService.getById(vehicleId);
    }
    vehicle ??= VehicleService.all().isNotEmpty ? VehicleService.all().first : null;

    final savedHost = prefs.getString(PrefsKeys.lastTcpHost);
    if (savedHost != null && savedHost.isNotEmpty) {
      _hostController.text = savedHost;
    }
    final savedPort = prefs.getString(PrefsKeys.lastTcpPort);
    if (savedPort != null && savedPort.isNotEmpty) {
      _portController.text = savedPort;
    }

    setState(() {
      _selectedVehicle = vehicle ?? _selectedVehicle;
      _lastBleDeviceId = prefs.getString(PrefsKeys.lastBleDeviceId);
      _lastBleDeviceName = prefs.getString(PrefsKeys.lastBleDeviceName);
    });
  }

  Future<void> _scanBle() async {
    setState(() {
      _scanning = true;
      _bleDevices = [];
      _error = null;
    });
    
    try {
      _scanSub?.cancel();
      _scanSub = BleObdLink.scanProgress(timeout: const Duration(seconds: 8))
          .listen((results) {
        // Progressive sort and update UI
        final sorted = [...results];
        final macLike = RegExp(r"^(?:[0-9A-Fa-f]{2}:){5}[0-9A-Fa-f]{2}");
        int score(BleScanResult r) {
          final n = (r.name ?? '').trim();
          if (n.isEmpty) return 0;
          if (macLike.hasMatch(n)) return 1;
          return 2;
        }
        sorted.sort((a, b) {
          final sa = score(a);
          final sb = score(b);
          if (sa != sb) return sb.compareTo(sa);
          final ar = a.rssi ?? -999;
          final br = b.rssi ?? -999;
          if (ar != br) return br.compareTo(ar);
          final an = (a.name ?? '').toLowerCase();
          final bn = (b.name ?? '').toLowerCase();
          if (an != bn) return an.compareTo(bn);
          return a.deviceId.compareTo(b.deviceId);
        });
        if (mounted) {
          setState(() {
            _bleDevices = sorted;
            if (_lastBleDeviceId != null) {
              for (final device in sorted) {
                if (device.deviceId == _lastBleDeviceId &&
                    (_selectedBleDevice == null || _selectedBleDevice!.deviceId != device.deviceId)) {
                  _selectedBleDevice = device;
                  break;
                }
              }
            }
          });
        }
      }, onError: (e) {
        if (mounted) {
          setState(() => _error = 'Scan failed: $e');
        }
      }, onDone: () {
        if (mounted) {
          setState(() => _scanning = false);
        }
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Scan failed: $e';
          _scanning = false;
        });
      }
    }
  }

  Future<void> _connectTcp() async {
    if (_selectedVehicle == null) {
      setState(() => _error = 'Please select a vehicle first');
      return;
    }

    setState(() {
      _connecting = true;
      _error = null;
    });
    
    // Show connecting dialog (đơn giản - chỉ vòng tròn xoay)
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => const _ConnectingDialog(),
    );
    
    try {
      await ConnectionManager.instance.connectTcp(
        host: _hostController.text.trim(),
        port: int.tryParse(_portController.text.trim()) ?? 35000,
        vehicle: _selectedVehicle,
      );
      
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(PrefsKeys.currentVehicleId, _selectedVehicle!.id);
      await prefs.setString(PrefsKeys.lastTcpHost, _hostController.text.trim());
      await prefs.setString(PrefsKeys.lastTcpPort, _portController.text.trim());
      
      if (!mounted) return;
      
      // Close dialog ngay khi connect thành công
      if (Navigator.of(context, rootNavigator: true).canPop()) {
        Navigator.of(context, rootNavigator: true).pop();
      }
      
      setState(() {
        _connecting = false;
        _isConnected = true;
      });
      
      // Tự động scan sau khi connect thành công
      await _startScan();
    } catch (e) {
      if (mounted) {
        // Close dialog khi có lỗi
        if (Navigator.of(context, rootNavigator: true).canPop()) {
          Navigator.of(context, rootNavigator: true).pop();
        }
        setState(() {
          _error = e.toString();
          _connecting = false;
        });
        // Hiện SnackBar báo lỗi
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Connection failed: ${e.toString()}'),
            backgroundColor: Colors.redAccent,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }
  
  Future<void> _startScan() async {
    setState(() {
      _isScanning = true;
      _error = null;
    });
    
    // Show scan dialog (similar to demo_init_screen)
    final scanResult = await showScanDialog(context);
    
    if (!mounted) return;
    
    setState(() {
      _isScanning = false;
    });
    
    // If scan completed successfully, close connect screen
    if (scanResult == true) {
      Navigator.of(context).pop();
    }
  }

  Future<void> _connectBle() async {
    if (_selectedVehicle == null) {
      setState(() => _error = 'Please select a vehicle first');
      return;
    }
    
    if (_selectedBleDevice == null) {
      setState(() => _error = 'Please select a Bluetooth device first');
      return;
    }

    setState(() {
      _connecting = true;
      _error = null;
    });
    
    // Show connecting dialog (đơn giản - chỉ vòng tròn xoay)
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => const _ConnectingDialog(),
    );
    
    try {
      await ConnectionManager.instance.connectBle(
        deviceId: _selectedBleDevice!.deviceId,
        vehicle: _selectedVehicle,
      );
      
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(PrefsKeys.currentVehicleId, _selectedVehicle!.id);
      await prefs.setString(PrefsKeys.lastBleDeviceId, _selectedBleDevice!.deviceId);
      await prefs.setString(
        PrefsKeys.lastBleDeviceName,
        _selectedBleDevice!.displayName,
      );
      
      if (!mounted) return;
      
      // Close dialog ngay khi connect thành công
      if (Navigator.of(context, rootNavigator: true).canPop()) {
        Navigator.of(context, rootNavigator: true).pop();
      }
      
      setState(() {
        _connecting = false;
        _isConnected = true;
        _lastBleDeviceId = _selectedBleDevice!.deviceId;
        _lastBleDeviceName = _selectedBleDevice!.displayName;
      });
      
      // Tự động scan sau khi connect thành công
      await _startScan();
    } catch (e) {
      if (mounted) {
        // Close dialog khi có lỗi
        if (Navigator.of(context, rootNavigator: true).canPop()) {
          Navigator.of(context, rootNavigator: true).pop();
        }
        setState(() {
          _error = e.toString();
          _connecting = false;
        });
        // Hiện SnackBar báo lỗi
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Connection failed: ${e.toString()}'),
            backgroundColor: Colors.redAccent,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Connect'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Wi‑Fi (TCP)', icon: Icon(Icons.wifi)),
            Tab(text: 'Bluetooth', icon: Icon(Icons.bluetooth)),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildTcpTab(),
          _buildBleTab(),
        ],
      ),
    );
  }

  Widget _buildTcpTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Connect via Wi‑Fi (TCP ELM327)',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
          if (!_isConnected) ...[
            const SizedBox(height: 16),
            VehiclePicker(
              selectedVehicle: _selectedVehicle,
              onVehicleSelected: (vehicle) {
                setState(() => _selectedVehicle = vehicle);
              },
            ),
          ],
          const SizedBox(height: 16),
          TextField(
            controller: _hostController,
            decoration: const InputDecoration(labelText: 'Host (IP)'),
            keyboardType: TextInputType.number,
            enabled: !_isConnected,
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _portController,
            decoration: const InputDecoration(labelText: 'Port'),
            keyboardType: TextInputType.number,
            enabled: !_isConnected,
          ),
          if (_isConnected) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF2ECC71).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: const Color(0xFF2ECC71).withValues(alpha: 0.3),
                  width: 1,
                ),
              ),
              child: const Row(
                children: [
                  Icon(Icons.check_circle, color: Color(0xFF2ECC71), size: 20),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Connected! Tap SCAN to load vehicle data.',
                      style: TextStyle(
                        color: Color(0xFF2ECC71),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: (_connecting || _isScanning || _selectedVehicle == null) 
                  ? null 
                  : (_isConnected ? _startScan : _connectTcp),
              style: ElevatedButton.styleFrom(
                backgroundColor: _isConnected 
                    ? const Color(0xFF2ECC71) 
                    : const Color(0xFF42A5F5),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 18),
                elevation: _isConnected ? 4 : 8,
                shadowColor: _isConnected 
                    ? const Color(0xFF2ECC71).withValues(alpha: 0.5)
                    : const Color(0xFF42A5F5).withValues(alpha: 0.6),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ).copyWith(
                backgroundColor: WidgetStateProperty.resolveWith((states) {
                  if (states.contains(WidgetState.disabled)) {
                    return Colors.grey;
                  }
                  if (_isConnected) {
                    return const Color(0xFF2ECC71);
                  }
                  return const Color(0xFF42A5F5);
                }),
              ),
              child: _isScanning
                  ? const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        ),
                        SizedBox(width: 12),
                        Text('SCANNING...', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                      ],
                    )
                  : Text(
                      _isConnected ? 'SCAN' : 'CONNECT',
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, letterSpacing: 1.2),
                    ),
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(_error!, style: const TextStyle(color: Colors.redAccent)),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildBleTab() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Connect via Bluetooth (BLE ELM327)',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
          if (!_isConnected) ...[
            const SizedBox(height: 16),
            VehiclePicker(
              selectedVehicle: _selectedVehicle,
              onVehicleSelected: (vehicle) {
                setState(() => _selectedVehicle = vehicle);
              },
            ),
          ],
          if (_lastBleDeviceName != null) ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.history, size: 18, color: Colors.white70),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Last connected: $_lastBleDeviceName',
                      style: const TextStyle(color: Colors.white70),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: (_scanning || _connecting) ? null : _scanBle,
                  icon: _scanning
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.search),
                  label: Text(_scanning ? 'Scanning...' : 'Scan for Devices'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Expanded(
            child: _buildBleList(),
          ),
          if (_isConnected) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF2ECC71).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: const Color(0xFF2ECC71).withValues(alpha: 0.3),
                  width: 1,
                ),
              ),
              child: const Row(
                children: [
                  Icon(Icons.check_circle, color: Color(0xFF2ECC71), size: 20),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Connected! Tap SCAN to load vehicle data.',
                      style: TextStyle(
                        color: Color(0xFF2ECC71),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          SafeArea(
            top: false,
            minimum: const EdgeInsets.only(bottom: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: (_connecting || _isScanning || _selectedVehicle == null || _selectedBleDevice == null)
                        ? null
                        : (_isConnected ? _startScan : _connectBle),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _isConnected 
                          ? const Color(0xFF2ECC71) 
                          : const Color(0xFF42A5F5),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 18),
                      elevation: _isConnected ? 4 : 8,
                      shadowColor: _isConnected 
                          ? const Color(0xFF2ECC71).withValues(alpha: 0.5)
                          : const Color(0xFF42A5F5).withValues(alpha: 0.6),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ).copyWith(
                      backgroundColor: WidgetStateProperty.resolveWith((states) {
                        if (states.contains(WidgetState.disabled)) {
                          return Colors.grey;
                        }
                        if (_isConnected) {
                          return const Color(0xFF2ECC71);
                        }
                        return const Color(0xFF42A5F5);
                      }),
                    ),
                    child: _isScanning
                        ? const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                ),
                              ),
                              SizedBox(width: 12),
                              Text('SCANNING...', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                            ],
                          )
                        : Text(
                            _isConnected ? 'SCAN' : 'CONNECT',
                            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, letterSpacing: 1.2),
                          ),
                  ),
                ),
                if (_error != null) ...[
                  const SizedBox(height: 12),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.red.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(_error!, style: const TextStyle(color: Colors.redAccent)),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBleList() {
    if (_scanning && _bleDevices.isEmpty) {
      return const Center(child: Text('Scanning for devices...'));
    }
    if (_bleDevices.isEmpty) {
      return const Center(
        child: Text(
          'No devices found.\nTap "Scan for Devices" to search.',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.grey),
        ),
      );
    }
    return ListView.builder(
      itemCount: _bleDevices.length + 1,
      itemBuilder: (context, index) {
        if (index == 0) {
          return const Padding(
            padding: EdgeInsets.only(bottom: 8),
            child: Text(
              'Available Devices:',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
            ),
          );
        }
        final device = _bleDevices[index - 1];
        return Card(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          clipBehavior: Clip.antiAlias,
          child: RadioListTile<BleScanResult>(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            title: Text(device.displayName),
            subtitle: device.rssi != null ? Text('RSSI: ${device.rssi} dBm') : null,
            value: device,
            groupValue: _selectedBleDevice,
            onChanged: (_connecting) ? null : (value) {
              setState(() => _selectedBleDevice = value);
            },
          ),
        );
      },
    );
  }
}

// Connecting Dialog Widget
class _ConnectingDialog extends StatefulWidget {
  const _ConnectingDialog();

  @override
  State<_ConnectingDialog> createState() => _ConnectingDialogState();
}

class _ConnectingDialogState extends State<_ConnectingDialog> with TickerProviderStateMixin {
  final List<_StepItem> _steps = [
    _StepItem('Initializing connection...', Icons.power_settings_new),
    _StepItem('Establishing link...', Icons.link),
    _StepItem('Verifying connection...', Icons.verified),
  ];

  int _current = 0;
  Timer? _timer;
  late AnimationController _pulseController;
  late AnimationController _indeterminateController;
  late Animation<double> _pulseAnimation;
  late Animation<double> _indeterminateAnimation;

  @override
  void initState() {
    super.initState();
    // Pulse animation for glow effect
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 0.3, end: 0.6).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
    
    // Indeterminate progress animation (chạy tới lui)
    _indeterminateController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
    _indeterminateAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _indeterminateController, curve: Curves.easeInOut),
    );
    
    _runSequence();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pulseController.dispose();
    _indeterminateController.dispose();
    super.dispose();
  }

  Future<void> _runSequence() async {
    // Cập nhật step text liên tục
    const totalMs = 3000;
    const tickMs = 16;
    int elapsed = 0;
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(milliseconds: tickMs), (t) {
      elapsed += tickMs;
      final p = (elapsed / totalMs).clamp(0.0, 1.0);
      if (!mounted) return;
      setState(() {
        _current = (p * _steps.length).clamp(0, (_steps.length - 1).toDouble()).floor();
      });
      if (p >= 1.0) {
        elapsed = 0; // Reset để lặp lại
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    const Color accent = Color(0xFF42A5F5);
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Material(
          color: Colors.transparent,
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  const Color(0xFF1C1F2A),
                  const Color(0xFF1A1D28),
                  const Color(0xFF1C1F2A),
                ],
              ),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.5),
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.5),
                  blurRadius: 30,
                  offset: const Offset(0, 15),
                  spreadRadius: -5,
                ),
                BoxShadow(
                  color: accent.withValues(alpha: 0.1),
                  blurRadius: 20,
                  offset: const Offset(0, 0),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          ShaderMask(
                            shaderCallback: (bounds) => LinearGradient(
                              colors: [
                                Colors.white,
                                Colors.white.withValues(alpha: 0.9),
                              ],
                            ).createShader(bounds),
                            child: const Text(
                              'Connecting',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
                                letterSpacing: 0.5,
                                decoration: TextDecoration.none,
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Icon(
                                _steps[_current].icon,
                                size: 16,
                                color: accent,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  _steps[_current].title,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.white,
                                    letterSpacing: 0.3,
                                    decoration: TextDecoration.none,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                // Indeterminate progress bar (chạy tới lui)
                LayoutBuilder(
                  builder: (context, constraints) {
                    final barWidth = constraints.maxWidth;
                    return AnimatedBuilder(
                      animation: Listenable.merge([_indeterminateAnimation, _pulseAnimation]),
                      builder: (context, child) {
                        // Tính toán vị trí của progress bar (chạy tới lui)
                        final progressWidth = barWidth * 0.4;
                        final minX = 0.0;
                        final maxX = barWidth - progressWidth;
                        final currentX = minX + (maxX - minX) * _indeterminateAnimation.value;
                        
                        return ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: Container(
                            height: 10,
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(10),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.2),
                                  blurRadius: 4,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Stack(
                              children: [
                                // Background
                                Container(
                                  width: double.infinity,
                                  height: 10,
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.08),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                ),
                                // Indeterminate progress bar (chạy tới lui)
                                Positioned(
                                  left: currentX,
                                  child: Container(
                                    width: progressWidth,
                                    height: 10,
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        colors: [
                                          accent,
                                          const Color(0xFF1E88E5),
                                          const Color(0xFF1976D2),
                                          const Color(0xFF1565C0),
                                        ],
                                        begin: Alignment.centerLeft,
                                        end: Alignment.centerRight,
                                      ),
                                      borderRadius: BorderRadius.circular(10),
                                      boxShadow: [
                                        BoxShadow(
                                          color: accent.withValues(alpha: _pulseAnimation.value),
                                          blurRadius: 10,
                                          spreadRadius: 1,
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _StepItem {
  final String title;
  final IconData icon;
  const _StepItem(this.title, this.icon);
}
