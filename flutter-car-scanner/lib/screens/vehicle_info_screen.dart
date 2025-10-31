import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_car_scanner/services/connection_manager.dart';

class VehicleInfoScreen extends StatefulWidget {
  const VehicleInfoScreen({super.key});

  @override
  State<VehicleInfoScreen> createState() => _VehicleInfoScreenState();
}

class _VehicleInfoScreenState extends State<VehicleInfoScreen> {
  bool _loading = false;
  String? _error;
  Map<String, dynamic>? _cfg;

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  Future<void> _fetch() async {
    setState(() { _loading = true; _error = null; _cfg = null; });
    try {
      final client = ConnectionManager.instance.client;
      if (client == null) {
        setState(() { _error = 'Not connected. Please CONNECT first.'; _loading = false; });
        return;
      }
      // Try emulator REST first
      try {
        final url = Uri.parse('http://${client.host}:3000/api/config');
        final res = await http.get(url).timeout(const Duration(seconds: 2));
        if (res.statusCode == 200) {
          setState(() { _cfg = json.decode(res.body) as Map<String, dynamic>; _loading = false; });
          return;
        }
      } catch (_) {}

      // Fallback: read VIN via OBD Mode 09 for real ELM devices
      final vin = await client.readVin();
      setState(() {
        _cfg = {
          'vinCode': vin ?? '-'
        };
        _loading = false;
      });
    } catch (e) {
      setState(() { _error = 'Failed to load: ${e.toString()}'; _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Vehicle Info'),
        backgroundColor: const Color(0xFFF39C12),
        foregroundColor: Colors.white,
        actions: [ IconButton(icon: const Icon(Icons.refresh), onPressed: _loading ? null : _fetch) ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Padding(padding: const EdgeInsets.all(16), child: Text(_error!, textAlign: TextAlign.center)))
              : _cfg == null
                  ? const Center(child: Text('No data'))
                  : ListView(
                      children: [
                        _tile('VIN', _cfg!['vinCode']),
                        if (_cfg!.containsKey('elmName')) _tile('ELM Name', _cfg!['elmName']),
                        if (_cfg!.containsKey('elmVersion')) _tile('ELM Version', _cfg!['elmVersion']),
                        if (_cfg!.containsKey('deviceId')) _tile('Device ID', _cfg!['deviceId']),
                        if (_cfg!.containsKey('ecuCount')) _tile('ECU Count', _cfg!['ecuCount']),
                        if (_cfg!.containsKey('server')) const Divider(height: 1),
                        if (_cfg!.containsKey('server')) _tile('Server', _cfg!['server']),
                        if (_cfg!.containsKey('port')) _tile('TCP Port', _cfg!['port']),
                      ],
                    ),
    );
  }

  Widget _tile(String title, Object? value) {
    return ListTile(
      title: Text(title),
      trailing: Text('${value ?? '-'}', style: const TextStyle(fontWeight: FontWeight.w600)),
    );
  }
}


