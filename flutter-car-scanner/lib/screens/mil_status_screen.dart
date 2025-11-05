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
  bool _milOn = false;
  int _storedCount = 0;

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
      final mil = await _client!.readMilAndCount();
      if (!mounted) return;
      setState(() {
        _milOn = mil.$1;
        _storedCount = mil.$2;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() { _error = 'Error reading MIL: ${e.toString()}'; _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('MIL Status'),
        backgroundColor: const Color(0xFF1E88E5),
        foregroundColor: Colors.white,
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _loading ? null : _refresh),
        ],
      ),
      body: Column(
        children: [
          if (_loading) const LinearProgressIndicator(minHeight: 2),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(_error!, style: const TextStyle(color: Colors.redAccent)),
            ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: _milOn ? Colors.redAccent.withValues(alpha: 0.2) : Colors.green.withValues(alpha: 0.2),
                  border: Border.all(color: _milOn ? Colors.redAccent : Colors.greenAccent),
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Text(
                  _milOn ? 'MIL: ON' : 'MIL: OFF',
                  style: TextStyle(
                    color: _milOn ? Colors.redAccent : Colors.greenAccent,
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
                child: Text('Stored: $_storedCount'),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Container(
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
          ),
          const Spacer(),
          SafeArea(
            top: false,
            minimum: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: Text(
              'Success criteria: MIL matches Stored DTCs (ON when count > 0; OFF after clear).',
              style: const TextStyle(color: Colors.white60),
              textAlign: TextAlign.center,
            ),
          )
        ],
      ),
    );
  }
}


