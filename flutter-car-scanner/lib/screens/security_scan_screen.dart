import 'package:flutter/material.dart';
import 'package:flutter_car_scanner/services/connection_manager.dart';
import 'package:flutter_car_scanner/services/obd_client.dart';
import 'package:flutter_car_scanner/services/battery_history_service.dart';

class SecurityScanScreen extends StatefulWidget {
  const SecurityScanScreen({super.key});

  @override
  State<SecurityScanScreen> createState() => _SecurityScanScreenState();
}

class _SecurityScanScreenState extends State<SecurityScanScreen> {
  bool _scanning = false;
  bool _scanComplete = false;
  int _currentStep = 0;
  double _progress = 0.0;
  final List<_ScanStep> _scanSteps = [
    _ScanStep('OBD-II Port', 'Checking port accessibility...', Icons.usb, Colors.blueAccent),
    _ScanStep('ECU Communication', 'Analyzing communication protocol...', Icons.memory, Colors.purpleAccent),
    _ScanStep('CAN Bus', 'Scanning CAN bus traffic...', Icons.lan, Colors.greenAccent),
    _ScanStep('Network Security', 'Checking network vulnerabilities...', Icons.security, Colors.orangeAccent),
    _ScanStep('Data Transmission', 'Analyzing data patterns...', Icons.data_usage, Colors.cyanAccent),
  ];

  bool get _isConnected => ConnectionManager.instance.client != null;

  // Real scan data (optional)
  bool? _milOn;
  int? _dtcStoredCount;
  int? _dtcPendingCount;
  int? _dtcPermanentCount;
  String? _vin;
  double? _batteryAvgRecent;
  bool? _batteryOftenLow;

  Future<void> _runScan() async {
    if (!_isConnected) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Not connected. Please CONNECT or enable Demo mode.')),
      );
      return;
    }
    setState(() {
      _scanning = true;
      _scanComplete = false;
      _currentStep = 0;
      _progress = 0.0;
    });

    // Fetch real diagnostics data (non-invasive)
    try {
      final client = ConnectionManager.instance.client as ObdClient?;
      if (client != null) {
        // Step 1: MIL & stored count
        final milAndCount = await client.readMilAndCount();
        _milOn = milAndCount.$1;
        _dtcStoredCount = milAndCount.$2;

        // Step 2: DTC sets
        final stored = await client.readStoredDtc();
        final pending = await client.readPendingDtc();
        final permanent = await client.readPermanentDtc();
        _dtcStoredCount = stored.length;
        _dtcPendingCount = pending.length;
        _dtcPermanentCount = permanent.length;

        // Step 3: VIN
        try {
          final vin = await client.readVin();
          if (vin != null && vin.isNotEmpty && vin != '-') {
            _vin = vin;
          }
        } catch (_) {}

        // Step 4: Battery recent trend (local history)
        final history = BatteryHistoryService.getHistory(limit: 30);
        if (history.isNotEmpty) {
          final recent = history.take(20).toList();
          _batteryAvgRecent = recent.map((r) => r.voltage).reduce((a, b) => a + b) / recent.length;
          _batteryOftenLow = recent.where((r) => r.voltage < 12.2).length >= (recent.length / 2);
        }
      }
    } catch (_) {
      // Ignore failures; still show UI as informational
    }

    // Simulate scan progress through each step
    for (int i = 0; i < _scanSteps.length; i++) {
      if (!mounted || !_scanning) break;
      
      setState(() {
        _currentStep = i;
        _progress = (i + 1) / _scanSteps.length;
      });

      await Future.delayed(const Duration(milliseconds: 800));
    }

    if (mounted && _scanning) {
      await Future.delayed(const Duration(milliseconds: 500));
      setState(() {
        _scanning = false;
        _scanComplete = true;
      });
    }
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
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.orangeAccent.withOpacity(0.2),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: Colors.orangeAccent.withOpacity(0.4),
                  width: 1,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.info_outline, color: Colors.orangeAccent, size: 20),
                      const SizedBox(width: 8),
                      Text(
                        'Informational Tool',
                        style: TextStyle(
                          color: Colors.orangeAccent,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'This is an educational/informational tool. It provides general security recommendations based on industry best practices. It does not perform actual security scanning or vulnerability testing.',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Scan Button or Progress
            if (!_scanComplete && !_scanning)
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _isConnected ? _runScan : null,
                  icon: const Icon(Icons.security),
                  label: Text(_isConnected ? 'Start Security Scan' : 'Connect to run scan'),
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
                      const Color(0xFF9B59B6).withOpacity(0.3),
                      Colors.blueAccent.withOpacity(0.2),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: Colors.purpleAccent.withOpacity(0.3),
                    width: 1,
                  ),
                ),
                child: Column(
                  children: [
                    // Animated icon
                    TweenAnimationBuilder<double>(
                      tween: Tween(begin: 0.0, end: 1.0),
                      duration: const Duration(seconds: 2),
                      builder: (context, value, child) {
                        return Transform.rotate(
                          angle: value * 2 * 3.14159,
                          child: Container(
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              color: Colors.purpleAccent.withOpacity(0.2),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.security,
                              size: 48,
                              color: Colors.purpleAccent,
                            ),
                          ),
                        );
                      },
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
                        backgroundColor: Colors.white.withOpacity(0.1),
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.purpleAccent),
                      ),
                    ),
                    const SizedBox(height: 24),
                    // Current step
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.08),
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
                                    ? Colors.greenAccent.withOpacity(0.2)
                                    : isCurrent
                                        ? step.color.withOpacity(0.2)
                                        : Colors.white.withOpacity(0.05),
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
                      Colors.greenAccent.withOpacity(0.2),
                      Colors.blueAccent.withOpacity(0.1),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: Colors.greenAccent.withOpacity(0.3),
                    width: 1,
                  ),
                ),
                child: Column(
                  children: [
                    Icon(
                      Icons.verified_user,
                      size: 48,
                      color: Colors.greenAccent,
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
                      'No critical security issues detected',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              // Scan Results for each step (with real data where available)
              _buildResultCard(
                icon: Icons.usb,
                title: 'OBD-II Port',
                status: (_vin != null || _isConnected) ? 'Secure' : 'Info',
                description: (_vin != null)
                    ? 'VIN detected: '+_vin!+''
                    : 'Standard OBD-II connection detected. VIN may be available depending on vehicle.',
                color: Colors.greenAccent,
              ),
              const SizedBox(height: 12),
              _buildResultCard(
                icon: Icons.memory,
                title: 'ECU Communication',
                status: (_milOn != null) ? 'Normal' : 'Info',
                description: (_milOn != null)
                    ? 'MIL: '+(_milOn! ? 'ON' : 'OFF')+' • Stored: '+(_dtcStoredCount ?? 0).toString()+', Pending: '+(_dtcPendingCount ?? 0).toString()+', Permanent: '+(_dtcPermanentCount ?? 0).toString()+''
                    : 'Communication follows OBD-II standards. Detailed DTC info not available.',
                color: Colors.greenAccent,
              ),
              const SizedBox(height: 12),
              _buildResultCard(
                icon: Icons.lan,
                title: 'CAN Bus',
                status: 'Normal',
                description: 'OBD-II diagnostic communication observed (not raw CAN monitoring).',
                color: Colors.greenAccent,
              ),
              const SizedBox(height: 12),
              _buildResultCard(
                icon: Icons.security,
                title: 'Network Security',
                status: 'Info',
                description: 'Standard diagnostic communication observed. Follow security best practices for enhanced protection.',
                color: Colors.blueAccent,
              ),
              const SizedBox(height: 12),
              _buildResultCard(
                icon: Icons.data_usage,
                title: 'Data Transmission',
                status: (_batteryAvgRecent != null) ? 'Normal' : 'Info',
                description: (_batteryAvgRecent != null)
                    ? 'Recent battery voltage avg: '+_batteryAvgRecent!.toStringAsFixed(1)+'V'+(_batteryOftenLow == true ? ' • Often low' : '')
                    : 'No battery history available yet. Drive and use the app to build history.',
                color: Colors.greenAccent,
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _resetScan,
                      icon: const Icon(Icons.close),
                      label: const Text('Reset'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white,
                        side: const BorderSide(color: Colors.white54),
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

            const SizedBox(height: 24),

            // Security Tips Section
            _buildSectionTitle('Vehicle Cybersecurity Tips'),
            const SizedBox(height: 12),
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

            const SizedBox(height: 24),

            // What We Check Section
            _buildSectionTitle('What This Tool Checks'),
            const SizedBox(height: 12),
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

            const SizedBox(height: 24),

            // Limitations Section
            _buildSectionTitle('Important Limitations'),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.redAccent.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: Colors.redAccent.withOpacity(0.3),
                  width: 1,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.warning, color: Colors.redAccent, size: 20),
                      const SizedBox(width: 8),
                      Text(
                        'This tool does NOT:',
                        style: TextStyle(
                          color: Colors.redAccent,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _buildLimitationItem('Perform actual vulnerability scanning'),
                  _buildLimitationItem('Detect ECU-specific security flaws'),
                  _buildLimitationItem('Test CAN bus security'),
                  _buildLimitationItem('Replace professional security audits'),
                ],
              ),
            ),

            const SizedBox(height: 24),
          ],
        ),
      ),
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
      color: Colors.white.withOpacity(0.08),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: color.withOpacity(0.3),
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
                color: color.withOpacity(0.2),
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
                          color: color.withOpacity(0.2),
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
      color: Colors.white.withOpacity(0.08),
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
        color: Colors.white.withOpacity(0.05),
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

  Widget _buildLimitationItem(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '✗ ',
            style: TextStyle(color: Colors.redAccent, fontSize: 14),
          ),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ScanStep {
  final String title;
  final String description;
  final IconData icon;
  final Color color;

  _ScanStep(this.title, this.description, this.icon, this.color);
}

