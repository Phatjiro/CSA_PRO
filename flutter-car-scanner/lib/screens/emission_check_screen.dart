import 'dart:async';

import 'package:flutter/material.dart';

import '../services/connection_manager.dart';
import '../services/obd_client.dart';
import 'emission_tests_screen.dart';

class EmissionCheckScreen extends StatefulWidget {
  const EmissionCheckScreen({super.key});

  @override
  State<EmissionCheckScreen> createState() => _EmissionCheckScreenState();
}

class _EmissionCheckScreenState extends State<EmissionCheckScreen> with SingleTickerProviderStateMixin {
  late final ObdClient _client;
  late TabController _tabController;
  Timer? _timer;
  
  // Readiness data
  Map<String, (bool available, bool completed)> _readinessItems = {};
  bool _milOn = false;
  int _storedCount = 0;
  
  // Drive cycle data
  int _runtimeSeconds = 0;
  int _distanceKm = 0;
  int _warmups = 0;
  int _coolantTemp = 0;
  bool _isLoading = false;
  
  // DTCs related to emission
  List<String> _emissionDtcs = [];

  @override
  void initState() {
    super.initState();
    _client = ConnectionManager.instance.client!;
    _tabController = TabController(length: 4, vsync: this);
    _refreshAll();
    _timer = Timer.periodic(const Duration(seconds: 5), (_) => _refreshAll());
  }

  @override
  void dispose() {
    _timer?.cancel();
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _refreshAll() async {
    if (_isLoading) return;
    setState(() => _isLoading = true);
    try {
      // Readiness
      final resp = await _client.requestPid('0101');
      final mil = await _client.readMilAndCount();
      final parsed = _parseReadiness(resp);
      
      // Drive cycle data
      final runtimeHex = await _client.requestPid('011F');
      final distanceHex = await _client.requestPid('0131');
      final warmupsHex = await _client.requestPid('0130');
      final ectHex = await _client.requestPid('0105');
      
      // DTCs (check for emission-related)
      final storedDtcs = await _client.readStoredDtc();
      
      if (mounted) {
        setState(() {
          _readinessItems = parsed;
          _milOn = mil.$1;
          _storedCount = mil.$2;
          _runtimeSeconds = _parseTwoBytes(runtimeHex, '011F');
          _distanceKm = _parseTwoBytes(distanceHex, '0131');
          _warmups = _parseSingleByte(warmupsHex, '0130');
          _coolantTemp = _parseCoolantTemp(ectHex, '0105');
          _emissionDtcs = storedDtcs.where((dtc) => dtc.startsWith('P')).toList();
          _isLoading = false;
        });
      }
    } catch (_) {}
    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  int _parseTwoBytes(String response, String pid) {
    final cleaned = response.replaceAll(RegExp(r"\s+"), '').toUpperCase();
    final key = '41' + pid.substring(2).toUpperCase();
    final i = cleaned.indexOf(key);
    if (i < 0 || cleaned.length < i + 8) return 0;
    final a = int.parse(cleaned.substring(i + 4, i + 6), radix: 16);
    final b = int.parse(cleaned.substring(i + 6, i + 8), radix: 16);
    return (a * 256) + b;
  }

  int _parseSingleByte(String response, String pid) {
    final cleaned = response.replaceAll(RegExp(r"\s+"), '').toUpperCase();
    final key = '41' + pid.substring(2).toUpperCase();
    final i = cleaned.indexOf(key);
    if (i < 0 || cleaned.length < i + 6) return 0;
    return int.parse(cleaned.substring(i + 4, i + 6), radix: 16);
  }

  int _parseCoolantTemp(String response, String pid) {
    final tempByte = _parseSingleByte(response, pid);
    return tempByte - 40;
  }

  Map<String, (bool available, bool completed)> _parseReadiness(String response) {
    final cleaned = response.replaceAll(RegExp(r"\s+"), '');
    final i = cleaned.indexOf('4101');
    if (i < 0 || cleaned.length < i + 12) return {};
    final a = int.parse(cleaned.substring(i + 4, i + 6), radix: 16);
    final b = int.parse(cleaned.substring(i + 6, i + 8), radix: 16);
    final c = int.parse(cleaned.substring(i + 8, i + 10), radix: 16);
    final d = int.parse(cleaned.substring(i + 10, i + 12), radix: 16);

    final misfireAvail = (b & 0x01) != 0;
    final fuelAvail = (b & 0x02) != 0;
    final compAvail = (b & 0x04) != 0;
    final misfireCompleted = (c & 0x01) == 0;
    final fuelCompleted = (c & 0x02) == 0;
    final compCompleted = (c & 0x04) == 0;

    final map = <String, (bool, bool)>{
      'Misfire': (misfireAvail, misfireCompleted),
      'Fuel System': (fuelAvail, fuelCompleted),
      'Components': (compAvail, compCompleted),
      'Catalyst': (true, (c & 0x08) == 0),
      'Heated Catalyst': (true, (c & 0x10) == 0),
      'Evap System': (true, (c & 0x20) == 0),
      'Secondary Air System': (true, (c & 0x40) == 0),
      'O2 Sensor': (true, (d & 0x01) == 0),
      'O2 Sensor Heater': (true, (d & 0x02) == 0),
      'EGR/VVT System': (true, (d & 0x04) == 0),
    };

    return map;
  }

  bool _isDriveCycleReady() {
    // Basic criteria for drive cycle completion
    return _coolantTemp >= 70 && // Engine warmed up
           _runtimeSeconds >= 300 && // At least 5 minutes runtime
           _distanceKm >= 50; // At least 50km driven
  }

  int _getCompletedCount() {
    return _readinessItems.values.where((v) => v.$2).length;
  }

  int _getTotalCount() {
    return _readinessItems.length;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Emission Check'),
        backgroundColor: const Color(0xFFF39C12),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _isLoading ? null : _refreshAll,
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          indicatorColor: Colors.white,
          tabs: const [
            Tab(text: 'Overview', icon: Icon(Icons.dashboard, size: 18)),
            Tab(text: 'Readiness', icon: Icon(Icons.check_circle, size: 18)),
            Tab(text: 'Drive Cycle', icon: Icon(Icons.directions_car, size: 18)),
            Tab(text: 'Guide', icon: Icon(Icons.info, size: 18)),
          ],
        ),
      ),
      body: SafeArea(
        child: _isLoading && _readinessItems.isEmpty
            ? const Center(child: CircularProgressIndicator())
            : TabBarView(
                controller: _tabController,
                children: [
                  _buildOverviewTab(),
                  _buildReadinessTab(),
                  _buildDriveCycleTab(),
                  _buildGuideTab(),
                ],
              ),
      ),
    );
  }

  Widget _buildOverviewTab() {
    final completedCount = _getCompletedCount();
    final totalCount = _getTotalCount();
    final readinessPercent = totalCount > 0 ? (completedCount / totalCount * 100).round() : 0;
    final driveCycleReady = _isDriveCycleReady();

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Status Card
        Card(
          color: Colors.white.withValues(alpha: 0.05),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      _milOn ? Icons.error : Icons.check_circle,
                      color: _milOn ? Colors.redAccent : Colors.greenAccent,
                      size: 32,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _milOn ? 'MIL: ON' : 'MIL: OFF',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: _milOn ? Colors.redAccent : Colors.greenAccent,
                            ),
                          ),
                          if (_storedCount > 0)
                            Text(
                              '$_storedCount DTC(s) stored',
                              style: TextStyle(color: Colors.redAccent, fontSize: 12),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        
        // Readiness Progress
        Card(
          color: Colors.white.withValues(alpha: 0.05),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'I/M Readiness',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    Text(
                      '$completedCount/$totalCount',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: readinessPercent >= 80 ? Colors.greenAccent : Colors.orangeAccent,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                LinearProgressIndicator(
                  value: totalCount > 0 ? completedCount / totalCount : 0,
                  backgroundColor: Colors.white.withValues(alpha: 0.1),
                  valueColor: AlwaysStoppedAnimation<Color>(
                    readinessPercent >= 80 ? Colors.greenAccent : Colors.orangeAccent,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '$readinessPercent% complete',
                  style: TextStyle(fontSize: 12, color: Colors.white70),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        
        // Drive Cycle Status
        Card(
          color: Colors.white.withValues(alpha: 0.05),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      driveCycleReady ? Icons.check_circle : Icons.pending,
                      color: driveCycleReady ? Colors.greenAccent : Colors.orangeAccent,
                      size: 24,
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Text(
                        'Drive Cycle Status',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                    ),
                    Text(
                      driveCycleReady ? 'Ready' : 'Not Ready',
                      style: TextStyle(
                        color: driveCycleReady ? Colors.greenAccent : Colors.orangeAccent,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _buildDriveCycleItem('Runtime', '${_runtimeSeconds ~/ 60} min', _runtimeSeconds >= 300),
                _buildDriveCycleItem('Distance', '$_distanceKm km', _distanceKm >= 50),
                _buildDriveCycleItem('Warm-ups', '$_warmups', _warmups >= 1),
                _buildDriveCycleItem('Coolant Temp', '$_coolantTemp°C', _coolantTemp >= 70),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        
        // Emission DTCs
        if (_emissionDtcs.isNotEmpty)
          Card(
            color: Colors.redAccent.withValues(alpha: 0.1),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.warning, color: Colors.redAccent, size: 24),
                      SizedBox(width: 12),
                      Text(
                        'Emission DTCs',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ..._emissionDtcs.map((dtc) => Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(dtc, style: const TextStyle(color: Colors.redAccent)),
                      )),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildDriveCycleItem(String label, String value, bool passed) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 14)),
          Row(
            children: [
              Text(
                value,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: passed ? Colors.greenAccent : Colors.orangeAccent,
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                passed ? Icons.check_circle : Icons.pending,
                size: 16,
                color: passed ? Colors.greenAccent : Colors.orangeAccent,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildReadinessTab() {
    if (_readinessItems.isEmpty) {
      return const Center(child: Text('No readiness data'));
    }

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: _readinessItems.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final key = _readinessItems.keys.elementAt(index);
        final (available, completed) = _readinessItems[key]!;
        return Card(
          color: Colors.white.withValues(alpha: 0.05),
          child: ListTile(
            leading: Icon(
              completed ? Icons.check_circle : Icons.error_outline,
              color: completed ? Colors.greenAccent : Colors.redAccent,
            ),
            title: Text(key),
            subtitle: Text(
              available ? 'Available' : 'Not available',
              style: TextStyle(color: available ? Colors.greenAccent : Colors.redAccent),
            ),
            trailing: Chip(
              label: Text(completed ? 'Done' : 'Pending'),
              backgroundColor: completed
                  ? Colors.greenAccent.withValues(alpha: 0.2)
                  : Colors.orangeAccent.withValues(alpha: 0.2),
              labelStyle: TextStyle(
                color: completed ? Colors.greenAccent : Colors.orangeAccent,
                fontSize: 12,
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildDriveCycleTab() {
    final driveCycleReady = _isDriveCycleReady();

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          color: Colors.white.withValues(alpha: 0.05),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      driveCycleReady ? Icons.check_circle : Icons.info,
                      color: driveCycleReady ? Colors.greenAccent : Colors.orangeAccent,
                      size: 32,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        driveCycleReady ? 'Drive Cycle Complete' : 'Drive Cycle Incomplete',
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _buildDriveCycleMetric('Runtime Since Start', '${_runtimeSeconds ~/ 60} min ${_runtimeSeconds % 60} s', _runtimeSeconds >= 300),
                _buildDriveCycleMetric('Distance Since Clear', '$_distanceKm km', _distanceKm >= 50),
                _buildDriveCycleMetric('Warm-ups Since Clear', '$_warmups', _warmups >= 1),
                _buildDriveCycleMetric('Engine Coolant Temp', '$_coolantTemp°C', _coolantTemp >= 70),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        Card(
          color: Colors.blue.withValues(alpha: 0.1),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.info_outline, color: Colors.blueAccent),
                    SizedBox(width: 8),
                    Text(
                      'Drive Cycle Requirements',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _buildRequirementItem('Engine runtime: ≥ 5 minutes', _runtimeSeconds >= 300),
                _buildRequirementItem('Distance driven: ≥ 50 km', _distanceKm >= 50),
                _buildRequirementItem('Engine warm-up: ≥ 1 cycle', _warmups >= 1),
                _buildRequirementItem('Coolant temp: ≥ 70°C', _coolantTemp >= 70),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDriveCycleMetric(String label, String value, bool passed) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(fontSize: 14),
            ),
          ),
          Row(
            children: [
              Text(
                value,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: passed ? Colors.greenAccent : Colors.orangeAccent,
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                passed ? Icons.check_circle : Icons.pending,
                size: 20,
                color: passed ? Colors.greenAccent : Colors.orangeAccent,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRequirementItem(String text, bool met) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(
            met ? Icons.check_circle : Icons.radio_button_unchecked,
            size: 18,
            color: met ? Colors.greenAccent : Colors.white70,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 14,
                color: met ? Colors.greenAccent : Colors.white70,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGuideTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          color: Colors.white.withValues(alpha: 0.05),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.checklist, color: Colors.blueAccent, size: 24),
                    SizedBox(width: 12),
                    Text(
                      'Pre-Test Checklist',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _buildGuideStep('1', 'Ensure engine is warmed up (coolant temp ≥ 70°C)'),
                _buildGuideStep('2', 'Check that MIL (Check Engine) is OFF'),
                _buildGuideStep('3', 'Verify no stored DTCs (especially P-codes)'),
                _buildGuideStep('4', 'Complete at least one warm-up cycle'),
                _buildGuideStep('5', 'Drive for at least 50 km with varying conditions'),
                _buildGuideStep('6', 'Verify all readiness monitors show "Completed"'),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        Card(
          color: Colors.blue.withValues(alpha: 0.1),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.schedule, color: Colors.blueAccent, size: 24),
                    SizedBox(width: 12),
                    Text(
                      'Typical Drive Cycle',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                const Text(
                  'For best results, perform a complete drive cycle that includes:',
                  style: TextStyle(fontSize: 14),
                ),
                const SizedBox(height: 8),
                _buildGuideItem('• Start engine and idle for 2-3 minutes'),
                _buildGuideItem('• Drive at city speeds (30-60 km/h) for 10 minutes'),
                _buildGuideItem('• Drive at highway speeds (80-100 km/h) for 10 minutes'),
                _buildGuideItem('• Slow down and stop, then idle for 1-2 minutes'),
                _buildGuideItem('• Repeat the cycle until all monitors complete'),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        Card(
          color: Colors.orange.withValues(alpha: 0.1),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.warning_amber, color: Colors.orangeAccent, size: 24),
                    SizedBox(width: 12),
                    Text(
                      'Important Notes',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _buildGuideItem('• Do not clear DTCs before emission test'),
                _buildGuideItem('• Some monitors require specific conditions to run'),
                _buildGuideItem('• Evap system monitor may take several days'),
                _buildGuideItem('• Catalyst monitor needs highway driving'),
                _buildGuideItem('• O2 sensor monitor needs warm engine'),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildGuideStep(String num, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: Colors.blueAccent.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Center(
              child: Text(
                num,
                style: const TextStyle(
                  color: Colors.blueAccent,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                text,
                style: const TextStyle(fontSize: 14),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGuideItem(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(
        text,
        style: const TextStyle(fontSize: 14),
      ),
    );
  }
}

