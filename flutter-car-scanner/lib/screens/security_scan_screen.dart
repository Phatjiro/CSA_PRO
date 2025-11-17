import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_car_scanner/services/connection_manager.dart';
import 'package:flutter_car_scanner/services/obd_client.dart';
import 'package:flutter_car_scanner/services/battery_history_service.dart';
import 'package:flutter_car_scanner/data/car_makes.dart';
import 'package:flutter_car_scanner/services/vehicle_service.dart';
import 'package:flutter_car_scanner/models/vehicle.dart';
import 'package:url_launcher/url_launcher.dart';

class _SystemScanResult {
  final String name;
  final IconData icon;
  final Color color;
  bool isOk;
  int dtcCount;
  List<String> dtcs;
  String? description;
  String? errorMessage;

  _SystemScanResult({
    required this.name,
    required this.icon,
    required this.color,
    this.isOk = true,
    this.dtcCount = 0,
    this.dtcs = const [],
    this.description,
    this.errorMessage,
  });
}

class SecurityScanScreen extends StatefulWidget {
  const SecurityScanScreen({super.key});

  @override
  State<SecurityScanScreen> createState() => _SecurityScanScreenState();
}

class _SecurityScanScreenState extends State<SecurityScanScreen> with SingleTickerProviderStateMixin {
  bool _scanning = false;
  bool _scanComplete = false;
  int _currentStep = 0;
  double _progress = 0.0;
  String? _selectedMake;
  late final AnimationController _scanController;
  
  final List<_ScanStep> _scanSteps = [
    _ScanStep('Engine Control Module', 'Scanning engine systems...', Icons.engineering, Colors.blueAccent),
    _ScanStep('Transmission Control', 'Checking transmission systems...', Icons.settings, Colors.purpleAccent),
    _ScanStep('ABS/Brake System', 'Scanning brake and ABS...', Icons.directions_car, Colors.redAccent),
    _ScanStep('Airbag System', 'Checking airbag modules...', Icons.airline_seat_recline_normal, Colors.orangeAccent),
    _ScanStep('Body Control Module', 'Scanning body electronics...', Icons.door_front_door, Colors.greenAccent),
    _ScanStep('Network Communication', 'Checking CAN bus and network...', Icons.lan, Colors.cyanAccent),
    _ScanStep('Readiness Monitors', 'Verifying emission readiness...', Icons.check_circle, Colors.yellowAccent),
  ];

  bool get _isConnected => ConnectionManager.instance.client != null;

  // System scan results
  final Map<String, _SystemScanResult> _systemResults = {};
  
  // Summary data
  int _totalSystems = 0;
  int _okSystems = 0;
  int _errorSystems = 0;
  int _totalDtcs = 0;
  bool? _milOn;
  String? _vin;

  @override
  void initState() {
    super.initState();
    _scanController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    );
    
    // Auto-load make from connected vehicle if available, otherwise prompt
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final vehicle = ConnectionManager.instance.vehicle;
      if (vehicle != null && vehicle.make != null && vehicle.make!.isNotEmpty && mounted) {
        setState(() {
          _selectedMake = vehicle.make;
        });
      } else {
        // Prompt user to select make on first load
        await _pickMake();
      }
    });
  }


  Future<void> _runScan() async {
    // Check if make is selected
    if (_selectedMake == null || _selectedMake!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select vehicle make first')),
      );
      await _pickMake();
      return;
    }

    if (!_isConnected) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Not connected to vehicle')),
      );
      return;
    }

    final client = ConnectionManager.instance.client as ObdClient?;
    if (client == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No active OBD connection found.')),
      );
      return;
    }

    _scanController.repeat();
    setState(() {
      _scanning = true;
      _scanComplete = false;
      _currentStep = 0;
      _progress = 0.0;
      _systemResults.clear();
      _totalSystems = 0;
      _okSystems = 0;
      _errorSystems = 0;
      _totalDtcs = 0;
    });

    try {
      // Step 0: Get VIN and MIL status
      try {
        final vin = await client.readVin();
        if (vin != null && vin.isNotEmpty && vin != '-') {
          _vin = vin;
        }
      } catch (_) {}
      
      final milAndCount = await client.readMilAndCount();
      _milOn = milAndCount.$1;

      List<String> storedCodes = [];
      List<String> pendingCodes = [];
      List<String> permanentCodes = [];
      try {
        storedCodes = await client.readStoredDtc();
      } catch (_) {}
      try {
        pendingCodes = await client.readPendingDtc();
      } catch (_) {}
      try {
        permanentCodes = await client.readPermanentDtc();
      } catch (_) {}
      
      // Step 1: Engine Control Module (Powertrain)
      await _scanSystem(
        'engine',
        'Engine Control Module',
        Icons.engineering,
        Colors.blueAccent,
        storedCodes,
        pendingCodes,
        permanentCodes,
        _isEngineCode,
      );
      
      // Step 2: Transmission Control (Powertrain specific)
      await _scanSystem(
        'transmission',
        'Transmission Control',
        Icons.settings,
        Colors.purpleAccent,
        storedCodes,
        pendingCodes,
        permanentCodes,
        _isTransmissionCode,
      );
      
      // Step 3: ABS/Brake System (Chassis)
      await _scanSystem(
        'abs',
        'ABS/Brake System',
        Icons.directions_car,
        Colors.redAccent,
        storedCodes,
        pendingCodes,
        permanentCodes,
        _isAbsCode,
      );
      
      // Step 4: Airbag System (Body - Safety)
      await _scanSystem(
        'airbag',
        'Airbag System',
        Icons.airline_seat_recline_normal,
        Colors.orangeAccent,
        storedCodes,
        pendingCodes,
        permanentCodes,
        _isAirbagCode,
      );
      
      // Step 5: Body Control Module (Body electronics)
      await _scanSystem(
        'body',
        'Body Control Module',
        Icons.door_front_door,
        Colors.greenAccent,
        storedCodes,
        pendingCodes,
        permanentCodes,
        _isBodyCode,
      );
      
      // Step 6: Network Communication (CAN/U-codes)
      await _scanSystem(
        'network',
        'Network Communication',
        Icons.lan,
        Colors.cyanAccent,
        storedCodes,
        pendingCodes,
        permanentCodes,
        _isNetworkCode,
      );
      
      // Step 7: Readiness Monitors
      await _scanReadiness(client);

      // Calculate summary
      _totalSystems = _systemResults.length;
      _okSystems = _systemResults.values.where((r) => r.isOk).length;
      _errorSystems = _totalSystems - _okSystems;
      _totalDtcs = _systemResults.values.fold(0, (sum, r) => sum + r.dtcCount);

    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Scan error: ${e.toString()}')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _scanning = false;
          _scanComplete = true;
        });
      }
      _scanController.stop();
      _scanController.reset();
    }
  }


  Future<void> _pickMake() async {
    final vehicle = ConnectionManager.instance.vehicle;
    String? selectedMake = vehicle?.make ?? _selectedMake;
    
    final makeController = TextEditingController(text: selectedMake ?? '');

    final result = await Navigator.of(context).push<String>(
      MaterialPageRoute(
        builder: (context) => _VehicleMakeScreen(
          makeController: makeController,
          onConfirm: (make) async {
            // Update vehicle info and persist it
            if (vehicle != null) {
              final updatedVehicle = vehicle.copyWith(make: make);
              await VehicleService.save(updatedVehicle);
              ConnectionManager.instance.currentVehicle.value = updatedVehicle;
            }
            return make;
          },
        ),
        fullscreenDialog: true,
      ),
    );

    if (result != null && result.isNotEmpty && mounted) {
      setState(() {
        _selectedMake = result;
      });
    }
  }

  Future<void> _scanSystem(
    String key,
    String name,
    IconData icon,
    Color color,
    List<String> storedCodes,
    List<String> pendingCodes,
    List<String> permanentCodes,
    bool Function(String) filter,
  ) async {
    if (!mounted || !_scanning) return;

    final stepIndex = _scanSteps.indexWhere((s) => s.title == name);
    if (stepIndex >= 0) {
      setState(() {
        _currentStep = stepIndex;
        _progress = (stepIndex + 1) / _scanSteps.length;
      });
    }

    await Future.delayed(const Duration(milliseconds: 600));

    try {
      final systemDtcs = <String>{
        ...storedCodes.where(filter),
        ...pendingCodes.where(filter),
        ...permanentCodes.where(filter),
      }.toList();

      final result = _SystemScanResult(
        name: name,
        icon: icon,
        color: color,
        isOk: systemDtcs.isEmpty,
        dtcCount: systemDtcs.length,
        dtcs: systemDtcs,
        description: systemDtcs.isEmpty 
            ? 'No issues detected' 
            : '${systemDtcs.length} DTC${systemDtcs.length > 1 ? 's' : ''} found',
      );

      if (mounted) {
        setState(() {
          _systemResults[key] = result;
        });
      }
    } catch (e) {
      final result = _SystemScanResult(
        name: name,
        icon: icon,
        color: color,
        isOk: false,
        errorMessage: 'Scan failed: ${e.toString()}',
      );
      if (mounted) {
        setState(() {
          _systemResults[key] = result;
        });
      }
    }
  }

  Future<void> _scanReadiness(ObdClient client) async {
    if (!mounted || !_scanning) return;

    final stepIndex = _scanSteps.indexWhere((s) => s.title == 'Readiness Monitors');
    if (stepIndex >= 0) {
      setState(() {
        _currentStep = stepIndex;
        _progress = (stepIndex + 1) / _scanSteps.length;
      });
    }

    await Future.delayed(const Duration(milliseconds: 600));

    try {
      final resp = await client.requestPid('0101');
      final cleaned = resp.replaceAll(RegExp(r"\s+"), '').toUpperCase();
      final i = cleaned.indexOf('4101');
      
      if (i >= 0 && cleaned.length >= i + 12) {
        final c = int.parse(cleaned.substring(i + 8, i + 10), radix: 16);
        final d = int.parse(cleaned.substring(i + 10, i + 12), radix: 16);
        
        // Check readiness bits
        final catalystReady = (c & 0x08) == 0;
        final evapReady = (c & 0x20) == 0;
        final o2Ready = (d & 0x01) == 0;
        final o2HeaterReady = (d & 0x02) == 0;
        final egrReady = (d & 0x04) == 0;
        
        final allReady = catalystReady && evapReady && o2Ready && o2HeaterReady && egrReady;
        final incompleteCount = [
          !catalystReady, !evapReady, !o2Ready, !o2HeaterReady, !egrReady
        ].where((x) => x).length;

        final result = _SystemScanResult(
          name: 'Readiness Monitors',
          icon: Icons.check_circle,
          color: Colors.yellowAccent,
          isOk: allReady,
          dtcCount: incompleteCount,
          description: allReady 
              ? 'All monitors complete' 
              : '$incompleteCount monitor${incompleteCount > 1 ? 's' : ''} incomplete',
        );

        if (mounted) {
          setState(() {
            _systemResults['readiness'] = result;
          });
        }
      }
    } catch (e) {
      final result = _SystemScanResult(
        name: 'Readiness Monitors',
        icon: Icons.check_circle,
        color: Colors.yellowAccent,
        isOk: false,
        errorMessage: 'Readiness scan failed',
      );
      if (mounted) {
        setState(() {
          _systemResults['readiness'] = result;
        });
      }
    }
  }

  @override
  void dispose() {
    _scanController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Security Scan'),
        backgroundColor: const Color(0xFF9B59B6),
        foregroundColor: Colors.white,
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Disclaimer Banner
            // Make selection
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: (_selectedMake != null && _selectedMake!.isNotEmpty)
                      ? const Color(0xFF9B59B6).withValues(alpha: 0.3)
                      : Colors.orangeAccent.withValues(alpha: 0.3),
                  width: 1,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.directions_car_filled,
                    color: (_selectedMake != null && _selectedMake!.isNotEmpty)
                        ? const Color(0xFF9B59B6)
                        : Colors.orangeAccent,
                    size: 24,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Vehicle Make',
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 12,
                          ),
                        ),
                        Text(
                          _selectedMake?.isNotEmpty == true ? _selectedMake! : 'Not set',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  TextButton.icon(
                    onPressed: _pickMake,
                    icon: const Icon(Icons.search, size: 16),
                    label: Text((_selectedMake != null && _selectedMake!.isNotEmpty) ? 'Change' : 'Select'),
                    style: TextButton.styleFrom(
                      foregroundColor: const Color(0xFF9B59B6),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            
            // Scan Button or Progress
            if (!_scanComplete && !_scanning)
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: (_isConnected && _selectedMake != null && _selectedMake!.isNotEmpty) ? _runScan : null,
                  icon: const Icon(Icons.security),
                  label: Text(
                    !_isConnected 
                        ? 'Connect to run scan'
                        : (_selectedMake == null || _selectedMake!.isEmpty)
                            ? 'Select vehicle make to scan'
                            : 'Start Full System Scan'
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF9B59B6),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),

            // Scanning Progress
            if (_scanning) ...[
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      const Color(0xFF9B59B6).withValues(alpha: 0.3),
                      Colors.blueAccent.withValues(alpha: 0.2),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: Colors.purpleAccent.withValues(alpha: 0.3),
                    width: 1,
                  ),
                ),
                child: Column(
                  children: [
                    // Animated scanning container with scanning line
                    Stack(
                      alignment: Alignment.center,
                      children: [
                        // Pulsing background circle
                        AnimatedBuilder(
                          animation: _scanController,
                          builder: (context, child) {
                            final value = _scanController.value;
                            final opacity = (0.4 * (1 - value)).clamp(0.0, 0.4);
                            return Container(
                              width: 120,
                              height: 120,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: RadialGradient(
                                  colors: [
                                    Colors.purpleAccent.withOpacity(opacity),
                                    Colors.purpleAccent.withOpacity(0),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                        // Static icon (no rotation)
                        Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: Colors.purpleAccent.withValues(alpha: 0.2),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.security,
                            size: 48,
                            color: Colors.purpleAccent,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    // Scanning line animation
                    Container(
                      height: 4,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(2),
                        color: Colors.white.withValues(alpha: 0.1),
                      ),
                      child: AnimatedBuilder(
                        animation: _scanController,
                        builder: (context, child) {
                          final value = Curves.easeInOut.transform(_scanController.value);
                          return Align(
                            alignment: Alignment(value * 2 - 1, 0),
                            child: Container(
                              width: 100,
                              height: 4,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(2),
                                gradient: const LinearGradient(
                                  colors: [
                                    Colors.transparent,
                                    Colors.purpleAccent,
                                    Colors.transparent,
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'Scanning Vehicle...',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${(_progress * 100).toInt()}% Complete',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 24),
                    // Progress bar
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: LinearProgressIndicator(
                        value: _progress,
                        minHeight: 8,
                        backgroundColor: Colors.white.withValues(alpha: 0.1),
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.purpleAccent),
                      ),
                    ),
                    const SizedBox(height: 24),
                    // Current step
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            _scanSteps[_currentStep].icon,
                            color: _scanSteps[_currentStep].color,
                            size: 24,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _scanSteps[_currentStep].title,
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  _scanSteps[_currentStep].description,
                                  style: TextStyle(
                                    color: Colors.white70,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                _scanSteps[_currentStep].color,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    // All steps
                    ...List.generate(_scanSteps.length, (index) {
                      final step = _scanSteps[index];
                      final isCompleted = index < _currentStep;
                      final isCurrent = index == _currentStep;
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Row(
                          children: [
                            Container(
                              width: 32,
                              height: 32,
                              decoration: BoxDecoration(
                                color: isCompleted
                                    ? Colors.greenAccent.withValues(alpha: 0.2)
                                    : isCurrent
                                        ? step.color.withValues(alpha: 0.2)
                                        : Colors.white.withValues(alpha: 0.05),
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: isCompleted
                                      ? Colors.greenAccent
                                      : isCurrent
                                          ? step.color
                                          : Colors.white24,
                                  width: 2,
                                ),
                              ),
                              child: isCompleted
                                  ? Icon(
                                      Icons.check,
                                      color: Colors.greenAccent,
                                      size: 18,
                                    )
                                  : isCurrent
                                      ? SizedBox(
                                          width: 16,
                                          height: 16,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            valueColor: AlwaysStoppedAnimation<Color>(step.color),
                                          ),
                                        )
                                      : null,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                step.title,
                                style: TextStyle(
                                  color: isCompleted || isCurrent
                                      ? Colors.white
                                      : Colors.white54,
                                  fontSize: 13,
                                  fontWeight: isCurrent
                                      ? FontWeight.w600
                                      : FontWeight.normal,
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    }),
                  ],
                ),
              ),
            ],

            // Scan Results
            if (_scanComplete) ...[
              // Summary Card
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      (_errorSystems == 0 ? Colors.greenAccent : Colors.orangeAccent).withValues(alpha: 0.2),
                      Colors.blueAccent.withValues(alpha: 0.1),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: (_errorSystems == 0 ? Colors.greenAccent : Colors.orangeAccent).withValues(alpha: 0.3),
                    width: 1,
                  ),
                ),
                child: Column(
                  children: [
                    Icon(
                      _errorSystems == 0 ? Icons.check_circle : Icons.warning,
                      size: 48,
                      color: _errorSystems == 0 ? Colors.greenAccent : Colors.orangeAccent,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Scan Complete',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _errorSystems == 0 
                          ? 'All systems OK' 
                          : '$_errorSystems system${_errorSystems > 1 ? 's' : ''} with issues',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _buildSummaryItem('Systems', '$_okSystems/$_totalSystems', Colors.greenAccent),
                        _buildSummaryItem('DTCs', '$_totalDtcs', _totalDtcs > 0 ? Colors.redAccent : Colors.greenAccent),
                        _buildSummaryItem('MIL', _milOn == true ? 'ON' : 'OFF', _milOn == true ? Colors.redAccent : Colors.greenAccent),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              // System Results
              ..._systemResults.values.map((result) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _buildSystemResultCard(result),
                  )),
              const SizedBox(height: 24),
            Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _clearAllErrors,
                        icon: const Icon(Icons.delete_sweep),
                        label: const Text('Clear All'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.orangeAccent,
                          side: BorderSide(color: Colors.orangeAccent.withValues(alpha: 0.5)),
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: _runScan,
                        icon: const Icon(Icons.refresh),
                        label: const Text('Scan Again'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF9B59B6),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            ],

            const SizedBox(height: 24),

            // Security Tips Section (Expandable)
            _ExpandableSection(
              title: 'Vehicle Cybersecurity Tips',
              icon: Icons.lightbulb_outline,
              children: [
                _buildTipCard(
                  icon: Icons.lock,
                  title: 'Physical Security',
                  tips: [
                    'Keep your OBD-II port covered when not in use',
                    'Park in secure, well-lit areas',
                    'Use steering wheel locks for additional security',
                  ],
                ),
                const SizedBox(height: 12),
                _buildTipCard(
                  icon: Icons.wifi_off,
                  title: 'Wireless Security',
                  tips: [
                    'Disable Bluetooth/Wi-Fi when not in use',
                    'Use secure, password-protected OBD-II adapters',
                    'Avoid connecting to public/unsecured networks',
                  ],
                ),
                const SizedBox(height: 12),
                _buildTipCard(
                  icon: Icons.update,
                  title: 'Software Updates',
                  tips: [
                    'Keep vehicle software/firmware updated',
                    'Update OBD-II adapter firmware regularly',
                    'Install security patches from manufacturers',
                  ],
                ),
                const SizedBox(height: 12),
                _buildTipCard(
                  icon: Icons.visibility,
                  title: 'Monitoring',
                  tips: [
                    'Monitor for unusual vehicle behavior',
                    'Check OBD-II connection logs regularly',
                    'Be aware of unauthorized access attempts',
                  ],
                ),
              ],
            ),

            const SizedBox(height: 16),

            // What We Check Section (Expandable)
            _ExpandableSection(
              title: 'What This Tool Checks',
              icon: Icons.checklist,
              children: [
                _buildInfoCard(
                  'Connection Protocol',
                  'Verifies standard OBD-II communication protocol is being used.',
                ),
                const SizedBox(height: 8),
                _buildInfoCard(
                  'Communication Patterns',
                  'Monitors for unusual data transmission patterns that may indicate security concerns.',
                ),
                const SizedBox(height: 8),
                _buildInfoCard(
                  'Best Practices',
                  'Provides general recommendations based on industry cybersecurity standards.',
                ),
              ],
            ),

            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryItem(String label, String value, Color color) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            color: color,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            color: Colors.white70,
            fontSize: 12,
          ),
        ),
      ],
    );
  }

  Widget _buildSystemResultCard(_SystemScanResult result) {
    final statusColor = result.isOk ? Colors.greenAccent : Colors.redAccent;
    final statusText = result.isOk ? 'OK' : 'ERROR';
    
    return _SystemResultCardExpansion(
      result: result,
      statusColor: statusColor,
      statusText: statusText,
    );
  }

  Widget _buildResultCard({
    required IconData icon,
    required String title,
    required String status,
    required String description,
    required Color color,
  }) {
    return Card(
      color: Colors.white.withValues(alpha: 0.08),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: color.withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          title,
                          style: TextStyle(
                            color: color,
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          status,
                          style: TextStyle(
                            color: color,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    description,
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        color: Colors.white,
        fontSize: 18,
        fontWeight: FontWeight.bold,
      ),
    );
  }

  Widget _buildTipCard({
    required IconData icon,
    required String title,
    required List<String> tips,
  }) {
    return Card(
      color: Colors.white.withValues(alpha: 0.08),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: Colors.blueAccent, size: 24),
                const SizedBox(width: 12),
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ...tips.map((tip) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        '• ',
                        style: TextStyle(color: Colors.white70, fontSize: 14),
                      ),
                      Expanded(
                        child: Text(
                          tip,
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ],
                  ),
                )),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoCard(String title, String description) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            description,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  void _resetScan() {
    setState(() {
      _scanning = false;
      _scanComplete = false;
      _currentStep = 0;
      _progress = 0.0;
    });
  }

  Future<void> _clearAllErrors() async {
    // Show confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear All Error Codes'),
        content: const Text(
          'This will send a command to clear all diagnostic trouble codes (DTCs) from the vehicle\'s ECU.\n\n'
          'After clearing, the system will automatically rescan to verify.\n\n'
          'Are you sure you want to continue?'
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
            ),
            child: const Text('Clear & Rescan'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    // Get OBD client
    final client = ConnectionManager.instance.client as ObdClient?;
    if (client == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No active OBD connection')),
        );
      }
      return;
    }

    // Show loading dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Clearing error codes...',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 16),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                minHeight: 8,
                backgroundColor: Colors.purpleAccent.withValues(alpha: 0.1),
                valueColor: const AlwaysStoppedAnimation<Color>(Colors.purpleAccent),
              ),
            ),
          ],
        ),
      ),
    );

    try {
      // Send clear command
      await client.clearDtc();
      
      // Wait a bit for the ECU to process
      await Future.delayed(const Duration(milliseconds: 500));

      if (!mounted) return;

      // Close loading dialog
      Navigator.of(context).pop();

      // Show success dialog
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const AlertDialog(
          title: Row(
            children: [
              Icon(Icons.check_circle, color: Colors.greenAccent, size: 28),
              SizedBox(width: 12),
              Text('Codes Cleared'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Error codes have been cleared successfully.'),
              SizedBox(height: 16),
              Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.blueAccent, size: 20),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Rescanning now to verify...',
                      style: TextStyle(fontSize: 13),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      );

      // Auto close success dialog after 1.5 seconds
      await Future.delayed(const Duration(milliseconds: 1500));

      if (!mounted) return;

      // Close success dialog
      Navigator.of(context).pop();

      // Wait a bit before triggering rescan
      await Future.delayed(const Duration(milliseconds: 300));

      if (!mounted) return;

      // Trigger rescan
      _runScan();

    } catch (e) {
      if (!mounted) return;
      
      // Close loading dialog
      Navigator.of(context).pop();
      
      // Show error
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.error, color: Colors.redAccent, size: 28),
              SizedBox(width: 12),
              Text('Clear Failed'),
            ],
          ),
          content: Text('Failed to clear codes: $e'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close'),
            ),
          ],
        ),
      );
    }
  }

bool _isEngineCode(String code) {
  final upper = code.toUpperCase();
  if (!upper.startsWith('P') || upper.length < 3) return false;
  final prefix = upper.substring(0, 3); // e.g. P01, P07
  // Transmission-specific ranges handled separately
  if (prefix.startsWith('P07') || prefix.startsWith('P08') || prefix.startsWith('P09')) {
    return false;
  }
  // Treat all other P-codes as engine/powertrain modules
  return true;
}

bool _isTransmissionCode(String code) {
  final upper = code.toUpperCase();
  if (!upper.startsWith('P') || upper.length < 4) return false;
  final prefix3 = upper.substring(0, 4); // P07x
  return prefix3.startsWith('P07') || prefix3.startsWith('P08') || prefix3.startsWith('P09');
}

bool _isAbsCode(String code) {
  final upper = code.toUpperCase();
  return upper.startsWith('C');
}

bool _isAirbagCode(String code) {
  final upper = code.toUpperCase();
  // Airbag/safety typically B00-B19
  if (!upper.startsWith('B')) return false;
  if (upper.length < 4) return true;
  final group = upper.substring(0, 4); // e.g. B00, B14
  return group.compareTo('B00') >= 0 && group.compareTo('B19') <= 0;
}

bool _isBodyCode(String code) {
  final upper = code.toUpperCase();
  if (!upper.startsWith('B')) return false;
  if (upper.length < 4) return true;
  final group = upper.substring(0, 4);
  // Body electronics from B20 upwards
  return group.compareTo('B20') >= 0;
}

bool _isNetworkCode(String code) {
  return code.toUpperCase().startsWith('U');
}

}

class _ScanStep {
  final String title;
  final String description;
  final IconData icon;
  final Color color;

  _ScanStep(this.title, this.description, this.icon, this.color);
}

// Full screen dialog for selecting vehicle make (same as Vehicle-Specific Data)
class _VehicleMakeScreen extends StatefulWidget {
  final TextEditingController makeController;
  final Future<String> Function(String) onConfirm;

  const _VehicleMakeScreen({
    required this.makeController,
    required this.onConfirm,
  });

  @override
  State<_VehicleMakeScreen> createState() => _VehicleMakeScreenState();
}

class _VehicleMakeScreenState extends State<_VehicleMakeScreen> {
  String _makeSearchQuery = '';
  final List<String> _allMakes = CarMakes.getAll();
  
  List<String> get _filteredMakes {
    if (_makeSearchQuery.isEmpty) {
      return _allMakes;
    }
    final query = _makeSearchQuery.toLowerCase();
    return _allMakes.where((make) => make.toLowerCase().contains(query)).toList();
  }
  
  @override
  void initState() {
    super.initState();
  }

  void _confirm() async {
    final make = widget.makeController.text.trim();
    
    if (make.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a manufacturer'),
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }
    
    final result = await widget.onConfirm(make);
    if (mounted) {
      Navigator.pop(context, result);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1C1F2A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF9B59B6),
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          'Select Vehicle Information',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w500,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Column(
        children: [
          // Content
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Select vehicle manufacturer:',
                    style: TextStyle(color: Colors.white70, fontSize: 16),
                  ),
                  const SizedBox(height: 16),
                  // Search bar
                  TextField(
                    style: const TextStyle(color: Colors.white, fontSize: 16),
                    decoration: InputDecoration(
                      hintText: 'Search manufacturer...',
                      hintStyle: const TextStyle(color: Colors.white38),
                      prefixIcon: const Icon(Icons.search, color: Colors.white54),
                      filled: true,
                      fillColor: Colors.white.withValues(alpha: 0.1),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.2)),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.2)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Color(0xFF9B59B6), width: 2),
                      ),
                    ),
                    onChanged: (value) {
                      setState(() {
                        _makeSearchQuery = value;
                      });
                    },
                  ),
                  const SizedBox(height: 16),
                  // List of all makes
                  Expanded(
                    child: ListView.builder(
                      itemCount: _filteredMakes.length,
                      itemBuilder: (context, index) {
                        final make = _filteredMakes[index];
                        final isSelected = widget.makeController.text == make;
                        return Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          child: Material(
                            color: Colors.transparent,
                            child: InkWell(
                              onTap: () {
                                widget.makeController.text = make;
                                setState(() {});
                              },
                              borderRadius: BorderRadius.circular(12),
                              splashColor: const Color(0xFF9B59B6).withValues(alpha: 0.3),
                              highlightColor: const Color(0xFF9B59B6).withValues(alpha: 0.1),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? const Color(0xFF9B59B6).withValues(alpha: 0.2)
                                      : Colors.white.withValues(alpha: 0.05),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: isSelected
                                        ? const Color(0xFF9B59B6)
                                        : Colors.white.withValues(alpha: 0.1),
                                    width: isSelected ? 2 : 1,
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        make,
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 16,
                                          fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                                        ),
                                      ),
                                    ),
                                    if (isSelected)
                                      const Icon(Icons.check_circle, color: Color(0xFF9B59B6), size: 24),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
          
          // Footer with buttons
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: const Color(0xFF1C1F2A),
              border: Border(
                top: BorderSide(
                  color: Colors.white.withValues(alpha: 0.1),
                  width: 1,
                ),
              ),
            ),
            child: SafeArea(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    ),
                    child: const Text('Cancel', style: TextStyle(color: Colors.white70, fontSize: 16)),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton(
                    onPressed: widget.makeController.text.trim().isNotEmpty ? _confirm : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF9B59B6),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
                      disabledBackgroundColor: const Color(0xFF9B59B6).withValues(alpha: 0.3),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text('Confirm', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// Expandable card widget for system scan results
class _SystemResultCardExpansion extends StatefulWidget {
  final _SystemScanResult result;
  final Color statusColor;
  final String statusText;

  const _SystemResultCardExpansion({
    required this.result,
    required this.statusColor,
    required this.statusText,
  });

  @override
  State<_SystemResultCardExpansion> createState() => _SystemResultCardExpansionState();
}

class _SystemResultCardExpansionState extends State<_SystemResultCardExpansion> {
  bool _expanded = false;

  void _searchDtcOnGoogle(String dtc) async {
    final query = Uri.encodeComponent('$dtc car diagnostic trouble code');
    final url = Uri.parse('https://www.google.com/search?q=$query');
    
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not open browser for $dtc')),
        );
      }
    }
  }


  @override
  Widget build(BuildContext context) {
    return Card(
      color: Colors.white.withValues(alpha: 0.08),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: widget.statusColor.withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: Column(
        children: [
          InkWell(
            onTap: widget.result.dtcs.isNotEmpty ? () {
              setState(() {
                _expanded = !_expanded;
              });
            } : null,
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: widget.result.color.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(widget.result.icon, color: widget.result.color, size: 24),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                widget.result.name,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: widget.statusColor.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    widget.result.isOk ? Icons.check_circle : Icons.error,
                                    size: 14,
                                    color: widget.statusColor,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    widget.statusText,
                                    style: TextStyle(
                                      color: widget.statusColor,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          widget.result.errorMessage ?? widget.result.description ?? 
                              (widget.result.isOk ? 'System operating normally' : 'System error detected'),
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 13,
                          ),
                        ),
                        if (widget.result.dtcs.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Icon(
                                _expanded ? Icons.expand_less : Icons.expand_more,
                                size: 18,
                                color: Colors.orangeAccent,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                '${widget.result.dtcs.length} error code${widget.result.dtcs.length > 1 ? "s" : ""} found',
                                style: const TextStyle(
                                  color: Colors.orangeAccent,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          // Expanded error codes list
          if (_expanded && widget.result.dtcs.isNotEmpty)
            Container(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Divider(height: 1),
                  const SizedBox(height: 12),
                  const Text(
                    'Error Codes:',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  ...widget.result.dtcs.map((dtc) => Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: InkWell(
                      onTap: () => _searchDtcOnGoogle(dtc),
                      borderRadius: BorderRadius.circular(6),
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.redAccent.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: Colors.redAccent.withValues(alpha: 0.3),
                            width: 1,
                          ),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                dtc,
                                style: const TextStyle(
                                  color: Colors.redAccent,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  fontFamily: 'monospace',
                                ),
                              ),
                            ),
                            const Icon(
                              Icons.search,
                              size: 16,
                              color: Colors.redAccent,
                            ),
                          ],
                        ),
                      ),
                    ),
                  )),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

// Expandable section widget
class _ExpandableSection extends StatefulWidget {
  final String title;
  final IconData icon;
  final List<Widget> children;

  const _ExpandableSection({
    required this.title,
    required this.icon,
    required this.children,
  });

  @override
  State<_ExpandableSection> createState() => _ExpandableSectionState();
}

class _ExpandableSectionState extends State<_ExpandableSection> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Colors.white.withValues(alpha: 0.08),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: Colors.white.withValues(alpha: 0.1),
          width: 1,
        ),
      ),
      child: Column(
        children: [
          InkWell(
            onTap: () {
              setState(() {
                _expanded = !_expanded;
              });
            },
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Icon(
                    widget.icon,
                    color: Colors.blueAccent,
                    size: 24,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      widget.title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  Icon(
                    _expanded ? Icons.expand_less : Icons.expand_more,
                    color: Colors.white70,
                    size: 24,
                  ),
                ],
              ),
            ),
          ),
          if (_expanded)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Column(
                children: [
                  const Divider(height: 1),
                  const SizedBox(height: 16),
                  ...widget.children,
                ],
              ),
            ),
        ],
      ),
    );
  }
}

