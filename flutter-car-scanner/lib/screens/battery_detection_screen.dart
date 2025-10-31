import 'package:flutter/material.dart';
import '../services/connection_manager.dart';

class BatteryDetectionScreen extends StatefulWidget {
  const BatteryDetectionScreen({super.key});

  @override
  State<BatteryDetectionScreen> createState() => _BatteryDetectionScreenState();
}

class _BatteryDetectionScreenState extends State<BatteryDetectionScreen> {
  bool _loading = false;
  String? _error;
  double? _voltage;

  @override
  void initState() {
    super.initState();
    _refresh();
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
      setState(() { _voltage = v; _loading = false; });
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Battery Detection'),
        backgroundColor: const Color(0xFF9B59B6),
        foregroundColor: Colors.white,
        actions: [ IconButton(onPressed: _loading ? null : _refresh, icon: const Icon(Icons.refresh)) ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Padding(padding: const EdgeInsets.all(16), child: Text(_error!, textAlign: TextAlign.center)))
              : _voltage == null
                  ? const Center(child: Text('No data'))
                  : Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text('${_voltage!.toStringAsFixed(2)} V', style: const TextStyle(fontSize: 38, fontWeight: FontWeight.w800)),
                          const SizedBox(height: 8),
                          Chip(label: Text(_health(_voltage!)), backgroundColor: _healthColor(_voltage!).withOpacity(0.2), labelStyle: TextStyle(color: _healthColor(_voltage!))),
                          const SizedBox(height: 16),
                          const Padding(
                            padding: EdgeInsets.symmetric(horizontal: 20),
                            child: Text('Measured from ECU (PID 0142). Engine OFF recommended for resting voltage.', textAlign: TextAlign.center),
                          )
                        ],
                      ),
                    ),
    );
  }
}


