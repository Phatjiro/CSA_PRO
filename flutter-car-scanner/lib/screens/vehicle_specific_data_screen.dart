import 'package:flutter/material.dart';
import 'package:flutter_car_scanner/services/connection_manager.dart';

class VehicleSpecificDataScreen extends StatefulWidget {
  const VehicleSpecificDataScreen({super.key});

  @override
  State<VehicleSpecificDataScreen> createState() => _VehicleSpecificDataScreenState();
}

class _VehicleSpecificDataScreenState extends State<VehicleSpecificDataScreen> {
  bool _loading = true;
  String? _error;
  List<String> _supported = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
      _supported = [];
    });
    try {
      final client = ConnectionManager.instance.client;
      if (client == null) {
        setState(() {
          _error = 'Not connected. Please CONNECT first.';
          _loading = false;
        });
        return;
      }
      final list = await client.getExtendedSupportedPids();
      setState(() {
        _supported = list;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Failed to load extended PIDs: ${e.toString()}';
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Vehicle-Specific Data'),
        backgroundColor: const Color(0xFF9B59B6),
        foregroundColor: Colors.white,
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _loading ? null : _load)
        ],
      ),
      body: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
                ? Center(child: Padding(padding: const EdgeInsets.all(16), child: Text(_error!, textAlign: TextAlign.center)))
                : _buildContent(),
      ),
    );
  }

  Widget _buildContent() {
    if (_supported.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.info_outline, size: 56, color: Colors.white54),
              const SizedBox(height: 12),
              const Text(
                'No extended PIDs reported by this vehicle/adapter.',
                style: TextStyle(color: Colors.white70),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              const Text(
                'Extended PID ranges: 0121-0140, 0141-0160, 0161-0180',
                style: TextStyle(color: Colors.white54, fontSize: 12),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.blueAccent.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.blueAccent.withValues(alpha: 0.3)),
          ),
          child: Text(
            'Supported Extended PIDs: ${_supported.length}',
            style: const TextStyle(color: Colors.white70, fontSize: 13),
          ),
        ),
        const SizedBox(height: 12),
        ..._supported.map((pid) => Card(
              color: Colors.white.withValues(alpha: 0.08),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              child: ListTile(
                leading: const Icon(Icons.extension, color: Colors.cyanAccent),
                title: Text('Extended PID $pid', style: const TextStyle(color: Colors.white)),
                subtitle: const Text('Manufacturer/ECU-specific support reported via bitmap', style: TextStyle(color: Colors.white54, fontSize: 12)),
              ),
            )),
      ],
    );
  }
}
