import 'package:flutter/material.dart';
import 'package:flutter_car_scanner/services/connection_manager.dart';
import 'package:flutter_car_scanner/services/obd_client.dart';

class MilStatusScreen extends StatefulWidget {
  const MilStatusScreen({super.key});

  @override
  State<MilStatusScreen> createState() => _MilStatusScreenState();
}

class _MilStatusScreenState extends State<MilStatusScreen> {
  ObdClient? _client;
  bool _loading = false;
  String? _error;
  MilStatusData? _status;

  @override
  void initState() {
    super.initState();
    _client = ConnectionManager.instance.client;
    _refresh();
  }

  Future<void> _refresh() async {
    if (_client == null) {
      setState(() => _error = 'Not connected. Please CONNECT first.');
      return;
    }
    setState(() { _loading = true; _error = null; });
    try {
      final status = await _client!.readMilStatusDetailed();
      if (!mounted) return;
      setState(() {
        _status = status;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() { _error = 'Error reading MIL: ${e.toString()}'; _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    final status = _status;
    final milOn = status?.milOn ?? false;
    final storedCount = status?.storedDtcCount ?? 0;
    final distanceMil = status?.distanceSinceMilOnKm;
    final distanceSinceClear = status?.distanceSinceCodesClearedKm;
    final monitors = status?.monitors ?? const <MilMonitorStatus>[];
    final continuousMonitors =
        monitors.where((m) => m.isContinuous).toList(growable: false);
    final nonContinuousMonitors =
        monitors.where((m) => !m.isContinuous).toList(growable: false);

    return Scaffold(
      appBar: AppBar(
        title: const Text('MIL Status'),
        backgroundColor: const Color(0xFF1E88E5),
        foregroundColor: Colors.white,
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _loading ? null : _refresh),
        ],
      ),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_loading) const LinearProgressIndicator(minHeight: 2),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text(_error!, style: const TextStyle(color: Colors.redAccent)),
              ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: milOn ? Colors.redAccent.withValues(alpha: 0.2) : Colors.green.withValues(alpha: 0.2),
                            border: Border.all(color: milOn ? Colors.redAccent : Colors.greenAccent),
                            borderRadius: BorderRadius.circular(24),
                          ),
                          child: Text(
                            milOn ? 'MIL: ON' : 'MIL: OFF',
                            style: TextStyle(
                              color: milOn ? Colors.redAccent : Colors.greenAccent,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(24),
                          ),
                          child: Text('Stored: $storedCount'),
                        ),
                      ],
                    ),
                    if (distanceMil != null || distanceSinceClear != null) ...[
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          if (distanceMil != null)
                            Expanded(
                              child: _infoCard(
                                title: 'Distance since MIL on',
                                value: '$distanceMil km',
                                icon: Icons.route,
                              ),
                            ),
                          if (distanceMil != null && distanceSinceClear != null)
                            const SizedBox(width: 12),
                          if (distanceSinceClear != null)
                            Expanded(
                              child: _infoCard(
                                title: 'Distance since codes cleared',
                                value: '$distanceSinceClear km',
                                icon: Icons.restart_alt,
                              ),
                            ),
                        ],
                      ),
                    ],
                    const SizedBox(height: 16),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.06),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Text(
                        'MIL (Malfunction Indicator Lamp) indicates whether the ECU has detected a fault and set a DTC. It is ON when stored codes exist and typically turns OFF after clearing codes (Mode 04) unless faults reoccur.',
                        style: TextStyle(color: Colors.white70),
                      ),
                    ),
                    if (continuousMonitors.isNotEmpty || nonContinuousMonitors.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      if (continuousMonitors.isNotEmpty)
                        _monitorSection('Continuous Monitors', continuousMonitors),
                      if (nonContinuousMonitors.isNotEmpty) ...[
                        const SizedBox(height: 16),
                        _monitorSection('Non-Continuous Monitors', nonContinuousMonitors),
                      ],
                    ],
                    const SizedBox(height: 24),
                    Text(
                      'Success criteria: MIL matches Stored DTCs (ON when count > 0; OFF after clear).',
                      style: const TextStyle(color: Colors.white60),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _infoCard({required String title, required String value, required IconData icon}) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Row(
        children: [
          Icon(icon, color: Colors.lightBlueAccent, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 11,
                    color: Colors.white60,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _monitorSection(String title, List<MilMonitorStatus> monitors) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: Colors.white70,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: monitors.map(_monitorChip).toList(),
          ),
        ],
      ),
    );
  }

  Widget _monitorChip(MilMonitorStatus monitor) {
    final Color background;
    final Color border;
    final Color textColor;
    IconData? icon;

    if (!monitor.available) {
      background = Colors.white.withValues(alpha: 0.04);
      border = Colors.white.withValues(alpha: 0.08);
      textColor = Colors.white54;
      icon = Icons.block;
    } else if (monitor.complete) {
      background = Colors.green.withValues(alpha: 0.18);
      border = Colors.greenAccent.withValues(alpha: 0.4);
      textColor = Colors.greenAccent;
      icon = Icons.check_circle;
    } else {
      background = Colors.orange.withValues(alpha: 0.18);
      border = Colors.orangeAccent.withValues(alpha: 0.4);
      textColor = Colors.orangeAccent;
      icon = Icons.hourglass_top;
    }

    final chip = Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: border, width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 16, color: textColor),
            const SizedBox(width: 6),
          ],
          Text(
            monitor.name,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: textColor,
            ),
          ),
        ],
      ),
    );

    if (monitor.description != null) {
      return Tooltip(
        message: monitor.description!,
        child: chip,
      );
    }
    return chip;
  }
}


