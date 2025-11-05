import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/vehicle.dart';
import '../services/connection_manager.dart';
import '../services/vehicle_service.dart';
import '../services/ble_obd_link.dart';
import '../utils/prefs_keys.dart';
import '../widgets/vehicle_picker.dart';

class ConnectScreen extends StatefulWidget {
  const ConnectScreen({super.key});

  @override
  State<ConnectScreen> createState() => _ConnectScreenState();
}

class _ConnectScreenState extends State<ConnectScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  
  // TCP/IP fields
  final TextEditingController _hostController =
      TextEditingController(text: '192.168.1.76');
  final TextEditingController _portController =
      TextEditingController(text: '35000');
  
  // BLE fields
  List<BleScanResult> _bleDevices = [];
  bool _scanning = false;
  BleScanResult? _selectedBleDevice;
  StreamSubscription<List<BleScanResult>>? _scanSub;
  
  // Common fields
  bool _connecting = false;
  String? _error;
  Vehicle? _selectedVehicle;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadLastVehicle();
  }

  @override
  void dispose() {
    _scanSub?.cancel();
    _tabController.dispose();
    _hostController.dispose();
    _portController.dispose();
    super.dispose();
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
      final vehicles = VehicleService.all();
      if (vehicles.isNotEmpty) {
        setState(() => _selectedVehicle = vehicles.first);
      }
    }
  }

  Future<void> _scanBle() async {
    setState(() {
      _scanning = true;
      _bleDevices = [];
      _error = null;
    });
    
    try {
      _scanSub?.cancel();
      _scanSub = BleObdLink.scanProgress(timeout: const Duration(seconds: 8))
          .listen((results) {
        // Progressive sort and update UI
        final sorted = [...results];
        final macLike = RegExp(r"^(?:[0-9A-Fa-f]{2}:){5}[0-9A-Fa-f]{2}");
        int score(BleScanResult r) {
          final n = (r.name ?? '').trim();
          if (n.isEmpty) return 0;
          if (macLike.hasMatch(n)) return 1;
          return 2;
        }
        sorted.sort((a, b) {
          final sa = score(a);
          final sb = score(b);
          if (sa != sb) return sb.compareTo(sa);
          final ar = a.rssi ?? -999;
          final br = b.rssi ?? -999;
          if (ar != br) return br.compareTo(ar);
          final an = (a.name ?? '').toLowerCase();
          final bn = (b.name ?? '').toLowerCase();
          if (an != bn) return an.compareTo(bn);
          return a.deviceId.compareTo(b.deviceId);
        });
        if (mounted) {
          setState(() {
            _bleDevices = sorted;
          });
        }
      }, onError: (e) {
        if (mounted) {
          setState(() => _error = 'Scan failed: $e');
        }
      }, onDone: () {
        if (mounted) {
          setState(() => _scanning = false);
        }
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Scan failed: $e';
          _scanning = false;
        });
      }
    }
  }

  Future<void> _connectTcp() async {
    if (_selectedVehicle == null) {
      setState(() => _error = 'Please select a vehicle first');
      return;
    }

    setState(() {
      _connecting = true;
      _error = null;
    });
    
    try {
      await ConnectionManager.instance.connectTcp(
        host: _hostController.text.trim(),
        port: int.tryParse(_portController.text.trim()) ?? 35000,
        vehicle: _selectedVehicle,
      );
      
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(PrefsKeys.currentVehicleId, _selectedVehicle!.id);
      
      if (!mounted) return;
      Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _connecting = false;
        });
      }
    }
  }

  Future<void> _connectBle() async {
    if (_selectedVehicle == null) {
      setState(() => _error = 'Please select a vehicle first');
      return;
    }
    
    if (_selectedBleDevice == null) {
      setState(() => _error = 'Please select a Bluetooth device first');
      return;
    }

    setState(() {
      _connecting = true;
      _error = null;
    });
    
    try {
      await ConnectionManager.instance.connectBle(
        deviceId: _selectedBleDevice!.deviceId,
        vehicle: _selectedVehicle,
      );
      
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(PrefsKeys.currentVehicleId, _selectedVehicle!.id);
      
      if (!mounted) return;
      Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
        });
      }
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
      appBar: AppBar(
        title: const Text('Connect'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Wi‑Fi (TCP)', icon: Icon(Icons.wifi)),
            Tab(text: 'Bluetooth', icon: Icon(Icons.bluetooth)),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildTcpTab(),
          _buildBleTab(),
        ],
      ),
    );
  }

  Widget _buildTcpTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Connect via Wi‑Fi (TCP ELM327)',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
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
              onPressed: (_connecting || _selectedVehicle == null) ? null : _connectTcp,
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
                color: Colors.red.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(_error!, style: const TextStyle(color: Colors.redAccent)),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildBleTab() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Connect via Bluetooth (BLE ELM327)',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 16),
          VehiclePicker(
            selectedVehicle: _selectedVehicle,
            onVehicleSelected: (vehicle) {
              setState(() => _selectedVehicle = vehicle);
            },
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: (_scanning || _connecting) ? null : _scanBle,
                  icon: _scanning
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.search),
                  label: Text(_scanning ? 'Scanning...' : 'Scan for Devices'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Expanded(
            child: _buildBleList(),
          ),
          SafeArea(
            top: false,
            minimum: const EdgeInsets.only(bottom: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: (_connecting || _selectedVehicle == null || _selectedBleDevice == null)
                        ? null
                        : _connectBle,
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
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.red.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(_error!, style: const TextStyle(color: Colors.redAccent)),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBleList() {
    if (_scanning && _bleDevices.isEmpty) {
      return const Center(child: Text('Scanning for devices...'));
    }
    if (_bleDevices.isEmpty) {
      return const Center(
        child: Text(
          'No devices found.\nTap "Scan for Devices" to search.',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.grey),
        ),
      );
    }
    return ListView.builder(
      itemCount: _bleDevices.length + 1,
      itemBuilder: (context, index) {
        if (index == 0) {
          return const Padding(
            padding: EdgeInsets.only(bottom: 8),
            child: Text(
              'Available Devices:',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
            ),
          );
        }
        final device = _bleDevices[index - 1];
        return Card(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          clipBehavior: Clip.antiAlias,
          child: RadioListTile<BleScanResult>(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            title: Text(device.displayName),
            subtitle: device.rssi != null ? Text('RSSI: ${device.rssi} dBm') : null,
            value: device,
            groupValue: _selectedBleDevice,
            onChanged: (_connecting) ? null : (value) {
              setState(() => _selectedBleDevice = value);
            },
          ),
        );
      },
    );
  }
}
