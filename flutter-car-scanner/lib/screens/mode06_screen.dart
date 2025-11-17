import 'package:flutter/material.dart';
import 'package:flutter_car_scanner/services/connection_manager.dart';
import 'package:flutter_car_scanner/services/obd_client.dart';
import 'package:flutter_car_scanner/services/log_service.dart';

class Mode06Screen extends StatefulWidget {
  const Mode06Screen({super.key});

  @override
  State<Mode06Screen> createState() => _Mode06ScreenState();
}

class _Mode06ScreenState extends State<Mode06Screen> {
  ObdClient? _client;
  bool _loading = false;
  String? _error;

  final List<_Mode06Item> _items = [];

  @override
  void initState() {
    super.initState();
    _client = ConnectionManager.instance.client;
    _refresh();
  }

  Future<void> _refresh() async {
    final client = _client;
    if (client == null) {
      setState(() => _error = 'Not connected. Please CONNECT first.');
      return;
    }
    setState(() { _loading = true; _error = null; _items.clear(); });
    try {
      final supported = await client.readMode06Supported();
      final tids = supported.isEmpty ? ['01','02','03'] : supported;
      for (final tid in tids) {
        final res = await client.readMode06Tid(tid);
        _items.add(_Mode06Item(tid: tid, name: _nameForTid(tid), value: res.$1, min: res.$2, max: res.$3));
      }
      final pass = _items.where((e) => e.value >= e.min && e.value <= e.max).length;
      await LogService.add({ 
        'type': 'mode06', 
        'passCount': pass, 
        'total': _items.length,
        'vehicleId': ConnectionManager.instance.vehicle?.id,
      });
      if (mounted) setState(() => _loading = false);
    } catch (e) {
      if (!mounted) return;
      setState(() { _error = 'Error reading Mode 06: ${e.toString()}'; _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mode 06'),
        backgroundColor: const Color(0xFF2ECC71),
        foregroundColor: Colors.white,
        actions: [ IconButton(icon: const Icon(Icons.refresh), onPressed: _loading ? null : _refresh) ],
      ),
      body: Column(
        children: [
          if (_loading) const LinearProgressIndicator(minHeight: 2),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(_error!, style: const TextStyle(color: Colors.redAccent)),
            ),
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.only(bottom: 12),
              itemCount: _items.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final it = _items[index];
                final pass = it.value >= it.min && it.value <= it.max;
                return ListTile(
                  leading: Icon(pass ? Icons.check_circle : Icons.error_outline, color: pass ? Colors.green : Colors.redAccent),
                  title: Text('${it.tid} – ${it.name}'),
                  subtitle: Text('Min ${it.min}, Max ${it.max}', style: const TextStyle(color: Colors.white70)),
                  trailing: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text('${it.value}', style: const TextStyle(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 2),
                      Text(pass ? 'PASS' : 'FAIL', style: TextStyle(color: pass ? Colors.green : Colors.redAccent)),
                    ],
                  ),
                );
              },
            ),
          )
        ],
      ),
    );
  }

  String _nameForTid(String tid) {
    switch (tid.toUpperCase()) {
      case '01': return 'Catalyst B1S1';
      case '02': return 'O2 Sensor B1S1';
      case '03': return 'EVAP Leak Test';
      default: return 'Test $tid';
    }
  }
}

class _Mode06Item {
  final String tid;
  final String name;
  final int value;
  final int min;
  final int max;
  _Mode06Item({required this.tid, required this.name, required this.value, required this.min, required this.max});
}


