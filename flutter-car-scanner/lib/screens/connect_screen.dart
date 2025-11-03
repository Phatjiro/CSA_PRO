import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/vehicle.dart';
import '../services/connection_manager.dart';
import '../services/vehicle_service.dart';
import '../utils/prefs_keys.dart';
import '../widgets/vehicle_picker.dart';

class ConnectScreen extends StatefulWidget {
  const ConnectScreen({super.key});

  @override
  State<ConnectScreen> createState() => _ConnectScreenState();
}

class _ConnectScreenState extends State<ConnectScreen> {
  final TextEditingController _hostController =
      TextEditingController(text: '192.168.1.76');
  final TextEditingController _portController =
      TextEditingController(text: '35000');
  bool _connecting = false;
  String? _error;
  Vehicle? _selectedVehicle;

  @override
  void initState() {
    super.initState();
    _loadLastVehicle();
  }

  Future<void> _loadLastVehicle() async {
    await VehicleService.init();
    final prefs = await SharedPreferences.getInstance();
    final vehicleId = prefs.getString(PrefsKeys.currentVehicleId);
    if (vehicleId != null) {
      final vehicle = VehicleService.getById(vehicleId);
      if (vehicle != null) {
        setState(() => _selectedVehicle = vehicle);
      }
    } else {
      // Try to get default vehicle
      final vehicles = VehicleService.all();
      if (vehicles.isNotEmpty) {
        setState(() => _selectedVehicle = vehicles.first);
      }
    }
  }

  @override
  void dispose() {
    _hostController.dispose();
    _portController.dispose();
    super.dispose();
  }

  Future<void> _connect() async {
    if (_selectedVehicle == null) {
      setState(() => _error = 'Please select a vehicle first');
      return;
    }

    setState(() {
      _connecting = true;
      _error = null;
    });
    try {
      await ConnectionManager.instance.connect(
        host: _hostController.text.trim(),
        port: int.tryParse(_portController.text.trim()) ?? 35000,
        vehicle: _selectedVehicle,
      );
      
      // Save as last selected vehicle
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(PrefsKeys.currentVehicleId, _selectedVehicle!.id);
      
      if (!mounted) return;
      Navigator.of(context).pop();
    } catch (e) {
      setState(() {
        _error = e.toString();
      });
    } finally {
      if (mounted) {
        setState(() {
          _connecting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Car Scanner')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Connect via Wi‑Fi (TCP ELM327)',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
            const SizedBox(height: 16),
            VehiclePicker(
              selectedVehicle: _selectedVehicle,
              onVehicleSelected: (vehicle) {
                setState(() => _selectedVehicle = vehicle);
              },
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _hostController,
              decoration: const InputDecoration(labelText: 'Host (IP)'),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _portController,
              decoration: const InputDecoration(labelText: 'Port'),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: (_connecting || _selectedVehicle == null) ? null : _connect,
                child: _connecting
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('CONNECT'),
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(_error!, style: const TextStyle(color: Colors.redAccent)),
              ),
            ],
          ],
        ),
      ),
    );
  }
}


