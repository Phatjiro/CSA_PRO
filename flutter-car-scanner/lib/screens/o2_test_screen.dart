import 'package:flutter/material.dart';
import '../services/connection_manager.dart';
import '../services/obd_client.dart';

class O2TestScreen extends StatefulWidget {
  const O2TestScreen({super.key});

  @override
  State<O2TestScreen> createState() => _O2TestScreenState();
}

class _O2TestScreenState extends State<O2TestScreen> {
  bool _loading = false;
  String? _error;
  List<O2Reading> _data = [];

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    setState(() { _loading = true; _error = null; _data = []; });
    final client = ConnectionManager.instance.client;
    if (client == null) {
      setState(() { _error = 'Not connected. Please CONNECT first.'; _loading = false; });
      return;
    }
    try {
      final list = await client.readO2Sensors();
      setState(() { _data = list; _loading = false; });
    } catch (e) {
      setState(() { _error = e.toString(); _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('O2 Test'),
        backgroundColor: const Color(0xFF9B59B6),
        foregroundColor: Colors.white,
        actions: [ IconButton(onPressed: _loading ? null : _refresh, icon: const Icon(Icons.refresh)) ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Padding(padding: const EdgeInsets.all(16), child: Text(_error!, textAlign: TextAlign.center)))
              : _data.isEmpty
                  ? const Center(child: Text('No O2 sensor data'))
                  : ListView.separated(
                      itemCount: _data.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (context, i) {
                        final r = _data[i];
                        return ListTile(
                          title: Text(_labelForPid(r.pidHex)),
                          subtitle: Text('Short trim: ${r.shortTrimPercent.toStringAsFixed(1)} %'),
                          trailing: Text('${r.voltage.toStringAsFixed(3)} V', style: const TextStyle(fontWeight: FontWeight.w700)),
                        );
                      },
                    ),
    );
  }

  String _labelForPid(String pidHex) {
    switch (pidHex) {
      case '14': return 'O2 B1S1';
      case '15': return 'O2 B1S2';
      case '16': return 'O2 B1S3';
      case '17': return 'O2 B1S4';
      case '18': return 'O2 B2S1';
      case '19': return 'O2 B2S2';
      case '1A': return 'O2 B2S3';
      case '1B': return 'O2 B2S4';
    }
    return 'O2 PID 0x$pidHex';
  }
}


