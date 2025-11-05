import 'package:flutter/material.dart';
import 'package:flutter_car_scanner/services/trend_analyzer.dart';
import 'package:flutter_car_scanner/services/connection_manager.dart';
import 'package:flutter_car_scanner/services/battery_history_service.dart';

class IssueForecastScreen extends StatefulWidget {
  const IssueForecastScreen({super.key});

  @override
  State<IssueForecastScreen> createState() => _IssueForecastScreenState();
}

class _IssueForecastScreenState extends State<IssueForecastScreen> {
  bool _loading = true;
  Map<String, dynamic>? _forecasts;
  int _warningCount = 0;

  @override
  void initState() {
    super.initState();
    _loadForecasts();
  }

  Future<void> _loadForecasts() async {
    setState(() {
      _loading = true;
    });

    // Wait a bit for UI to render
    await Future.delayed(const Duration(milliseconds: 100));

    final vehicleId = ConnectionManager.instance.vehicle?.id;
    final forecasts = TrendAnalyzer.getAllForecasts(vehicleId: vehicleId);
    final warningCount = TrendAnalyzer.getWarningCount(vehicleId: vehicleId);

    if (mounted) {
      setState(() {
        _forecasts = forecasts;
        _warningCount = warningCount;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Issue Forecast'),
        backgroundColor: const Color(0xFF7D3C98),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loading ? null : _loadForecasts,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : RefreshIndicator(
                onRefresh: _loadForecasts,
                child: _buildContent(),
              ),
      ),
    );
  }

  Widget _buildContent() {
    if (_forecasts == null) {
      return const Center(
        child: Text(
          'No data available',
          style: TextStyle(color: Colors.white54),
        ),
      );
    }

    final batteryTrend = _forecasts!['batteryTrend'] as String?;
    final batteryCharging = _forecasts!['batteryCharging'] as String?;
    final dtcRecurrence = _forecasts!['dtcRecurrence'] as List<String>?;

    final hasWarnings = batteryTrend != null || 
                       batteryCharging != null || 
                       (dtcRecurrence != null && dtcRecurrence.isNotEmpty);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Summary Card
        _buildSummaryCard(hasWarnings),
        const SizedBox(height: 16),

        // Battery Trend Warning
        if (batteryTrend != null) ...[
          _buildWarningCard(
            icon: Icons.battery_alert,
            title: 'Battery Voltage Trend',
            message: batteryTrend,
            color: Colors.orangeAccent,
          ),
          const SizedBox(height: 12),
        ],

        // Battery Charging Warning
        if (batteryCharging != null) ...[
          _buildWarningCard(
            icon: Icons.power,
            title: 'Battery Charging Issue',
            message: batteryCharging,
            color: Colors.redAccent,
          ),
          const SizedBox(height: 12),
        ],

        // DTC Recurrence Warnings
        if (dtcRecurrence != null && dtcRecurrence.isNotEmpty) ...[
          for (final warning in dtcRecurrence)
            _buildWarningCard(
              icon: Icons.warning_amber,
              title: 'Recurring DTC',
              message: warning,
              color: Colors.orangeAccent,
            ),
          const SizedBox(height: 12),
        ],

        // No warnings
        if (!hasWarnings) ...[
          _buildNoWarningsCard(),
        ],
      ],
    );
  }

  Widget _buildSummaryCard(bool hasWarnings) {
    return Card(
      color: Colors.white.withOpacity(0.08),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Icon(
              hasWarnings ? Icons.warning_amber : Icons.check_circle,
              size: 48,
              color: hasWarnings ? Colors.orangeAccent : Colors.greenAccent,
            ),
            const SizedBox(height: 12),
            Text(
              hasWarnings ? '$_warningCount Active Warning(s)' : 'All Systems Normal',
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              hasWarnings
                  ? 'Review the warnings below for potential issues'
                  : 'No issues detected based on historical data analysis',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white70,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWarningCard({
    required IconData icon,
    required String title,
    required String message,
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
                  Text(
                    title,
                    style: TextStyle(
                      color: color,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    message,
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 14,
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

  Widget _buildNoWarningsCard() {
    return Card(
      color: Colors.greenAccent.withOpacity(0.1),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: Colors.greenAccent.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Icon(
              Icons.check_circle_outline,
              size: 48,
              color: Colors.greenAccent,
            ),
            const SizedBox(height: 12),
            Text(
              'No Issues Detected',
              style: TextStyle(
                color: Colors.greenAccent,
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Based on historical data analysis:\n• Battery voltage is stable\n• No recurring DTC codes\n• Charging system is working properly',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white70,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

