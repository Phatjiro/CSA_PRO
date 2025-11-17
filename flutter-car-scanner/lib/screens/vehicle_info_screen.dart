import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_car_scanner/services/connection_manager.dart';
import 'package:flutter_car_scanner/services/vehicle_service.dart';

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
      
      // Detect connection type
      final isLinkBased = client.host == 'link' && client.port == -1;
      String connectionType = 'Unknown';
      bool isDemo = false;
      
      if (isLinkBased) {
        // Could be BLE or Demo - need to detect by testing ATI command
        try {
          final atiResponse = await client.requestPid('ATI');
          // Demo typically returns just 'OK' or very short response
          // Real ELM returns version string like "ELM327 v1.5" or similar
          if (atiResponse.trim().toUpperCase() == 'OK' || 
              atiResponse.trim().isEmpty ||
              atiResponse.length < 5) {
            isDemo = true;
            connectionType = 'Demo Mode';
          } else {
            connectionType = 'BLE';
          }
        } catch (_) {
          // If ATI fails, assume demo for safety
          isDemo = true;
          connectionType = 'Demo Mode';
        }
      } else {
        // TCP connection - could be emulator or real device
        connectionType = 'TCP (${client.host}:${client.port})';
      }
      
      // Try emulator REST first (only for TCP connections)
      if (!isLinkBased) {
        try {
          final url = Uri.parse('http://${client.host}:3000/api/config');
          final res = await http.get(url).timeout(const Duration(seconds: 2));
          if (res.statusCode == 200) {
            final cfg = json.decode(res.body) as Map<String, dynamic>;
            cfg['connectionType'] = connectionType;
            setState(() { _cfg = cfg; _loading = false; });
            
            // Auto-update VIN to current vehicle if connected
            final vehicle = ConnectionManager.instance.vehicle;
            final vin = cfg['vinCode'] as String?;
            if (vehicle != null && vin != null && vin.isNotEmpty && vin != '-') {
              await VehicleService.updateVin(vehicle.id, vin);
            }
            return;
          }
        } catch (_) {}
      }

      // Fallback: read VIN via OBD Mode 09 for real ELM devices or demo
      final vin = await client.readVin();
      final cfg = <String, dynamic>{
        'vinCode': vin ?? '-',
        'connectionType': connectionType,
      };
      
      // Try to get ELM info for real devices
      if (!isDemo) {
        try {
          // ATI - ELM327 version
          final elmVersion = await client.requestPid('ATI');
          if (elmVersion.isNotEmpty && 
              !elmVersion.contains('NO DATA') && 
              !elmVersion.contains('ERROR') &&
              elmVersion.trim().toUpperCase() != 'OK') {
            cfg['elmVersion'] = elmVersion.trim();
            // Try to extract ELM name from version
            if (elmVersion.toUpperCase().contains('ELM')) {
              cfg['elmName'] = 'ELM327';
            }
          }
          
          // AT@1 - Device description (optional, not all devices support)
          try {
            final deviceDesc = await client.requestPid('AT@1');
            if (deviceDesc.isNotEmpty && 
                !deviceDesc.contains('NO DATA') && 
                !deviceDesc.contains('ERROR') &&
                deviceDesc.trim().toUpperCase() != 'OK') {
              cfg['deviceId'] = deviceDesc.trim();
            }
          } catch (_) {}
        } catch (_) {}
      } else {
        // Demo mode info
        cfg['elmName'] = 'Demo ELM327';
        cfg['elmVersion'] = 'Demo Mode';
        cfg['deviceId'] = 'Demo';
      }
      
      setState(() {
        _cfg = cfg;
        _loading = false;
      });
      
      // Auto-update VIN to current vehicle if connected
      final vehicle = ConnectionManager.instance.vehicle;
      if (vehicle != null && vin != null && vin.isNotEmpty && vin != '-') {
        await VehicleService.updateVin(vehicle.id, vin);
      }
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
                        if (_cfg!.containsKey('elmVersion') && _cfg!['elmVersion'] != 'Demo Mode') ...[
                          const Divider(height: 1),
                          _tile('ELM Version', _cfg!['elmVersion']),
                        ],
                        if (_cfg!.containsKey('deviceId') && _cfg!['deviceId'] != 'Demo') 
                          _tile('Device ID', _cfg!['deviceId']),
                        if (_cfg!.containsKey('ecuCount')) _tile('ECU Count', _cfg!['ecuCount']),
                        if (_cfg!.containsKey('server')) ...[
                          const Divider(height: 1),
                          _tile('Server', _cfg!['server']),
                        ],
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


