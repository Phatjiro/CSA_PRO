import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../services/connection_manager.dart';
import '../services/battery_history_service.dart';
import '../models/battery_reading.dart';

class BatteryDetectionScreen extends StatefulWidget {
  const BatteryDetectionScreen({super.key});

  @override
  State<BatteryDetectionScreen> createState() => _BatteryDetectionScreenState();
}

class _BatteryDetectionScreenState extends State<BatteryDetectionScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _loading = false;
  String? _error;
  double? _voltage;
  int? _engineRpm;
  bool? _isCharging;

  @override
  void initState() {
    super.initState();
    BatteryHistoryService.init();
    _tabController = TabController(length: 2, vsync: this);
    _refresh();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    setState(() { _loading = true; _error = null; });
    final client = ConnectionManager.instance.client;
    if (client == null) {
      setState(() { _error = 'Not connected. Please CONNECT first.'; _loading = false; });
      return;
    }
    try {
      final v = await client.readBatteryVoltage();
      if (v == null) {
        setState(() { _error = 'Failed to read voltage'; _loading = false; });
        return;
      }

      // Get engine RPM for charging detection
      final rpmHex = await client.requestPid('010C');
      int rpm = 0;
      try {
        final cleaned = rpmHex.replaceAll(RegExp(r"\s+"), '');
        final i = cleaned.indexOf('410C');
        if (i >= 0 && cleaned.length >= i + 8) {
          final a = int.parse(cleaned.substring(i + 4, i + 6), radix: 16);
          final b = int.parse(cleaned.substring(i + 6, i + 8), radix: 16);
          rpm = ((256 * a + b) ~/ 4);
        }
      } catch (_) {}

      // Determine charging status
      bool? charging;
      if (rpm > 0) {
        charging = v >= 13.5; // Charging if voltage >= 13.5V when engine ON
      }

      // Save to history
      await BatteryHistoryService.addReading(v, rpm);

      setState(() {
        _voltage = v;
        _engineRpm = rpm;
        _isCharging = charging;
        _loading = false;
      });
    } catch (e) {
      setState(() { _error = e.toString(); _loading = false; });
    }
  }

  String _health(double v) {
    if (v >= 12.6) return 'Excellent';
    if (v >= 12.4) return 'Good';
    if (v >= 12.2) return 'Fair';
    if (v >= 12.0) return 'Low';
    return 'Very Low';
  }

  Color _healthColor(double v) {
    if (v >= 12.6) return Colors.green;
    if (v >= 12.4) return Colors.lightGreen;
    if (v >= 12.2) return Colors.orange;
    if (v >= 12.0) return Colors.deepOrange;
    return Colors.red;
  }

  String _chargingStatusText() {
    if (_engineRpm == null || _engineRpm == 0) return 'Engine OFF';
    if (_isCharging == true) return 'Charging';
    if (_isCharging == false) return 'Not Charging';
    return 'Unknown';
  }

  Color _chargingStatusColor() {
    if (_engineRpm == null || _engineRpm == 0) return Colors.grey;
    if (_isCharging == true) return Colors.green;
    if (_isCharging == false) return Colors.orange;
    return Colors.grey;
  }

  Widget _buildCurrentTab() {
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Text(_error!, textAlign: TextAlign.center),
        ),
      );
    }
    if (_voltage == null) {
      return const Center(child: Text('No data'));
    }

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            '${_voltage!.toStringAsFixed(2)} V',
            style: const TextStyle(fontSize: 38, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Chip(
                label: Text(_health(_voltage!)),
                backgroundColor: _healthColor(_voltage!).withValues(alpha: 0.2),
                labelStyle: TextStyle(color: _healthColor(_voltage!)),
              ),
              const SizedBox(width: 8),
              if (_engineRpm != null)
                Chip(
                  label: Text(_chargingStatusText()),
                  backgroundColor: _chargingStatusColor().withValues(alpha: 0.2),
                  labelStyle: TextStyle(color: _chargingStatusColor()),
                ),
            ],
          ),
          if (_engineRpm != null && _engineRpm! > 0) ...[
            const SizedBox(height: 8),
            Text(
              'Engine: ON ($_engineRpm RPM)',
              style: TextStyle(fontSize: 14, color: Colors.white70),
            ),
          ],
          const SizedBox(height: 24),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 20),
            child: Text(
              'Measured from ECU (PID 0142). Engine OFF recommended for resting voltage.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: Colors.white60),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHistoryTab() {
    return ValueListenableBuilder(
      valueListenable: Hive.box<BatteryReading>(BatteryHistoryService.boxName).listenable(),
      builder: (context, box, _) {
        final readings = BatteryHistoryService.getHistory(limit: 200);
        
        if (readings.isEmpty) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.history, size: 64, color: Colors.white38),
                SizedBox(height: 16),
                Text('No history yet', style: TextStyle(color: Colors.white70)),
                SizedBox(height: 8),
                Text('Refresh to start recording', style: TextStyle(fontSize: 12, color: Colors.white60)),
              ],
            ),
          );
        }

        final spots = readings.asMap().entries.map((e) {
          final x = e.key.toDouble();
          final y = e.value.voltage;
          return FlSpot(x, y);
        }).toList();

        final minVoltage = readings.map((r) => r.voltage).reduce((a, b) => a < b ? a : b);
        final maxVoltage = readings.map((r) => r.voltage).reduce((a, b) => a > b ? a : b);
        final avgVoltage = readings.map((r) => r.voltage).reduce((a, b) => a + b) / readings.length;
        final step = (readings.length ~/ 4) == 0 ? 1 : (readings.length ~/ 4);

        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
            children: [
              // Stats
              Card(
                color: Colors.white.withValues(alpha: 0.05),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildStat('Min', '${minVoltage.toStringAsFixed(2)} V', Colors.orange),
                      _buildStat('Avg', '${avgVoltage.toStringAsFixed(2)} V', Colors.white70),
                      _buildStat('Max', '${maxVoltage.toStringAsFixed(2)} V', Colors.green),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              // Chart
              Expanded(
                child: LineChart(
                  LineChartData(
                    gridData: FlGridData(
                      show: true,
                      drawVerticalLine: false,
                      horizontalInterval: 0.5,
                      getDrawingHorizontalLine: (value) {
                        return FlLine(
                          color: Colors.white.withValues(alpha: 0.1),
                          strokeWidth: 1,
                        );
                      },
                    ),
                    titlesData: FlTitlesData(
                      show: true,
                      rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      bottomTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          reservedSize: 30,
                          getTitlesWidget: (value, meta) {
                            if (value.toInt() % step != 0) return const Text('');
                            final idx = value.toInt();
                            if (idx >= 0 && idx < readings.length) {
                              final time = readings[idx].timestamp;
                              return Text(
                                '${time.hour}:${time.minute.toString().padLeft(2, '0')}',
                                style: const TextStyle(fontSize: 10, color: Colors.white60),
                              );
                            }
                            return const Text('');
                          },
                        ),
                      ),
                      leftTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          reservedSize: 50,
                          interval: 0.5,
                          getTitlesWidget: (value, meta) {
                            return Text(
                              value.toStringAsFixed(1),
                              style: const TextStyle(fontSize: 10, color: Colors.white60),
                            );
                          },
                        ),
                      ),
                    ),
                    borderData: FlBorderData(
                      show: true,
                      border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
                    ),
                    minX: 0,
                    maxX: (readings.length - 1).toDouble(),
                    minY: (minVoltage - 0.5).clamp(10.0, double.infinity),
                    maxY: (maxVoltage + 0.5).clamp(double.negativeInfinity, 16.0),
                    lineBarsData: [
                      LineChartBarData(
                        spots: spots,
                        isCurved: true,
                        color: Colors.purpleAccent,
                        barWidth: 2,
                        dotData: const FlDotData(show: false),
                        belowBarData: BarAreaData(
                          show: true,
                          color: Colors.purpleAccent.withValues(alpha: 0.1),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              // Clear button
              OutlinedButton.icon(
                icon: const Icon(Icons.delete_outline),
                label: const Text('Clear History'),
                onPressed: () async {
                  final confirm = await showDialog<bool>(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      title: const Text('Clear History?'),
                      content: const Text('This will delete all voltage history.'),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(ctx, false),
                          child: const Text('Cancel'),
                        ),
                        TextButton(
                          onPressed: () => Navigator.pop(ctx, true),
                          style: TextButton.styleFrom(foregroundColor: Colors.red),
                          child: const Text('Clear'),
                        ),
                      ],
                    ),
                  );
                  if (confirm == true) {
                    await BatteryHistoryService.clearHistory();
                  }
                },
              ),
              const SizedBox(height: 8),
            ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildStat(String label, String value, Color color) {
    return Column(
      children: [
        Text(label, style: TextStyle(fontSize: 12, color: Colors.white60)),
        const SizedBox(height: 4),
        Text(value, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: color)),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Battery Detection'),
        backgroundColor: const Color(0xFF9B59B6),
        foregroundColor: Colors.white,
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          indicatorColor: Colors.white,
          tabs: const [
            Tab(text: 'Current', icon: Icon(Icons.battery_full, size: 18)),
            Tab(text: 'History', icon: Icon(Icons.history, size: 18)),
          ],
        ),
        actions: [
          IconButton(
            onPressed: _loading ? null : _refresh,
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                _buildCurrentTab(),
                _buildHistoryTab(),
              ],
            ),
    );
  }
}


