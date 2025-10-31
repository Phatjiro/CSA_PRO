import 'dart:async';

import 'package:flutter/material.dart';

import '../services/connection_manager.dart';
import '../services/obd_client.dart';

class EmissionTestsScreen extends StatefulWidget {
  const EmissionTestsScreen({super.key});

  @override
  State<EmissionTestsScreen> createState() => _EmissionTestsScreenState();
}

class _EmissionTestsScreenState extends State<EmissionTestsScreen> {
  late final ObdClient _client;
  Timer? _timer;
  Map<String, (bool available, bool completed)> _items = {};
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _client = ConnectionManager.instance.client!;
    _poll();
    _timer = Timer.periodic(const Duration(seconds: 5), (_) => _poll());
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _poll() async {
    if (_isLoading) return;
    setState(() => _isLoading = true);
    try {
      final resp = await _client.requestPid('0101'); // Readiness
      final parsed = _parseReadiness(resp);
      if (mounted) {
        setState(() {
          _items = parsed;
          _isLoading = false;
        });
      }
    } catch (_) {}
    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Emission tests')),
      body: SafeArea(
        child: _isLoading && _items.isEmpty
            ? const Center(child: CircularProgressIndicator())
            : (_items.isEmpty
                ? const Center(child: Text('No readiness data'))
                : ListView.separated(
                    padding: const EdgeInsets.only(bottom: 12),
                    itemCount: _items.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final key = _items.keys.elementAt(index);
                      final (available, completed) = _items[key]!;
                      return ListTile(
                        title: Text(key),
                        subtitle: Text(
                            available ? 'Available' : 'Not available',
                            style: TextStyle(
                                color: available
                                    ? Colors.green
                                    : Colors.redAccent)),
                        trailing: Text(
                            completed ? 'Completed' : 'Not completed',
                            style: TextStyle(
                                color: completed
                                    ? Colors.green
                                    : Colors.redAccent)),
                      );
                    },
                  )),
      ),
    );
  }

  // Very simplified readiness parser from Mode 01 PID 01 response
  // Expect formats like: '41 01 AA BB CC DD'
  Map<String, (bool available, bool completed)> _parseReadiness(String response) {
    final cleaned = response.replaceAll(RegExp(r"\s+"), '');
    final i = cleaned.indexOf('4101');
    if (i < 0 || cleaned.length < i + 12) return {};
    final a = int.parse(cleaned.substring(i + 4, i + 6), radix: 16);
    final b = int.parse(cleaned.substring(i + 6, i + 8), radix: 16);
    final c = int.parse(cleaned.substring(i + 8, i + 10), radix: 16);
    final d = int.parse(cleaned.substring(i + 10, i + 12), radix: 16);

    // Continuous monitors availability (misfire, fuel, components) -> BB bits 0..2
    final misfireAvail = (b & 0x01) != 0;
    final fuelAvail = (b & 0x02) != 0;
    final compAvail = (b & 0x04) != 0;
    // Completion for those monitors: completed when corresponding bit in CC is 0
    final misfireCompleted = (c & 0x01) == 0;
    final fuelCompleted = (c & 0x02) == 0;
    final compCompleted = (c & 0x04) == 0;

    // Simplified mapping for non-continuous (spark engines set)
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
}


