import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_car_scanner/services/connection_manager.dart';
import 'package:flutter_car_scanner/services/vin_decoder_service.dart';
import 'package:flutter_car_scanner/services/vehicle_service.dart';
import 'package:flutter_car_scanner/models/obd_live_data.dart';
import 'package:flutter_car_scanner/data/car_makes.dart';

class VehicleSpecificDataScreen extends StatefulWidget {
  const VehicleSpecificDataScreen({super.key});

  @override
  State<VehicleSpecificDataScreen> createState() => _VehicleSpecificDataScreenState();
}

class _VehicleSpecificDataScreenState extends State<VehicleSpecificDataScreen> {
  static const List<String> _saeExtendedPidOrder = [
    '0121', '012E', '012F', '0130', '0131', '0133',
    '013C', '013D', '013E', '013F',
    '0142', '0143', '0144', '0145', '0146',
    '0147', '0148', '0149', '014A', '014B', '014C',
    '014D', '014E', '014F',
    '0150', '0151', '0152', '0153', '0154',
    '0155', '0156', '0157', '0158',
    '0159', '015A', '015B', '015C', '015D', '015E', '015F',
    '0161', '0162', '0163',
  ];
  static const Set<String> _saeExtendedPidSet = {
    '0121', '012E', '012F', '0130', '0131', '0133',
    '013C', '013D', '013E', '013F',
    '0142', '0143', '0144', '0145', '0146',
    '0147', '0148', '0149', '014A', '014B', '014C',
    '014D', '014E', '014F',
    '0150', '0151', '0152', '0153', '0154',
    '0155', '0156', '0157', '0158',
    '0159', '015A', '015B', '015C', '015D', '015E', '015F',
    '0161', '0162', '0163',
  };

  // PIDs that are already visualized on the main dashboard (avoid duplicates here)
  static const Set<String> _dashboardPidSet = {
    '0121', '012E', '012F', '0130', '0131', '0133',
    '013C', '013D', '013E', '013F',
    '0142', '0143', '0144', '0145', '0146',
    '0147', '0148', '0149', '014A', '014B', '014C',
    '014D', '014E', '014F',
    '0150', '0151', '0152', '0153', '0154',
    '0155', '0156', '0157', '0158',
    '0159', '015A', '015B',
  };

  bool _loading = true;
  String? _error;
  List<String> _supported = []; // PIDs supported by ECU
  bool _hasShownDialog = false;
  ObdLiveData? _liveData;
  StreamSubscription<ObdLiveData>? _dataSubscription;
  Set<String>? _previousEnabledPids;
  List<String> get _displayedExtendedPids {
    final orderMap = {
      for (int i = 0; i < _saeExtendedPidOrder.length; i++) _saeExtendedPidOrder[i]: i
    };
    final filtered = _supported.where((pid) {
      return _saeExtendedPidSet.contains(pid) && !_dashboardPidSet.contains(pid);
    }).toList();
    filtered.sort((a, b) {
      final ai = orderMap[a] ?? 999;
      final bi = orderMap[b] ?? 999;
      return ai.compareTo(bi);
    });
    return filtered;
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkAndShowDialog();
    });
    _load();
    _startListening();
  }

  @override
  void dispose() {
    _dataSubscription?.cancel();
    _restorePreviousPids();
    super.dispose();
  }

  void _startListening() {
    final client = ConnectionManager.instance.client;
    if (client == null) return;
    
    _dataSubscription = client.dataStream.listen((data) {
      if (mounted) {
        setState(() {
          _liveData = data;
        });
      }
    });
  }

  void _enableExtendedPids() {
    final client = ConnectionManager.instance.client;
    if (client == null) return;
    
    // Save current enabled PIDs
    _previousEnabledPids = Set<String>.from(client.enabledPids);
    
    // Enable Extended PIDs
    final extendedPids = Set<String>.from(_displayedExtendedPids);
    // Keep essential PIDs
    extendedPids.addAll(['010C', '010D', '0105']);
    client.setEnabledPids(extendedPids);
    client.pollNow();
  }

  void _restorePreviousPids() {
    final client = ConnectionManager.instance.client;
    if (client == null || _previousEnabledPids == null) return;
    
    // Restore previous enabled PIDs when leaving screen
    client.setEnabledPids(_previousEnabledPids!);
  }
  
  Future<void> _checkAndShowDialog() async {
    // Check if we have vehicle info, if not show dialog
    final vehicle = ConnectionManager.instance.vehicle;
    String? make = vehicle?.make;
    
    // Try VIN decode if no make
    if ((make == null || make.isEmpty) && 
        vehicle != null && vehicle.vin != null && vehicle.vin!.isNotEmpty && vehicle.vin! != '-') {
      try {
        final vinData = await VinDecoderService.decodeVin(vehicle.vin!);
        if (vinData != null) {
          make = vinData['Make'];
        }
      } catch (e) {
        // Silent fail
      }
    }
    
    // If still no make, show dialog
    if ((make == null || make.isEmpty) && !_hasShownDialog) {
      _hasShownDialog = true;
      await _showVehicleInfoDialog(autoShow: true);
    }
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

      // Get supported Extended PIDs from ECU
      final list = await client.getExtendedSupportedPids();

      setState(() {
        _supported = list;
        _loading = false;
      });
      
      // Enable Extended PIDs for live updates
      if (_supported.isNotEmpty) {
        _enableExtendedPids();
      }
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
        title: const Text(
          'Vehicle-Specific Data',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w500,
          ),
        ),
        backgroundColor: const Color(0xFF9B59B6),
        foregroundColor: Colors.white,
        actions: [
          if (_loading)
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            )
          else
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: _loading ? null : _load,
              tooltip: 'Refresh',
            ),
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
    final displayPids = _displayedExtendedPids;
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
                'No extended PIDs available.',
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

    if (displayPids.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.check_circle_outline, size: 56, color: Colors.white54),
              const SizedBox(height: 12),
              const Text(
                'Tất cả Extended PIDs hiện có đã hiển thị trong dashboard.',
                style: TextStyle(color: Colors.white70),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'Chọn hãng xe khác hoặc kết nối ECU khác để xem các PID riêng.',
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
        // Summary Card
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.blueAccent.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.blueAccent.withValues(alpha: 0.3)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Vehicle-specific Extended PIDs: ${displayPids.length}',
                style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        
        // Extended PIDs List
        ...displayPids.map((pid) => _buildBasicPidCard(pid)),
      ],
    );
  }


  Widget _buildBasicPidCard(String pid) {
    final pidInfo = _getPidInfo(pid);
    final value = _getPidValueFromLiveData(pid);
    final unit = pidInfo['unit'] ?? '';
    
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      color: Colors.white.withValues(alpha: 0.08),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      pidInfo['name'] ?? 'Extended PID $pid',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      pidInfo['description'] ?? 'Manufacturer/ECU-specific support',
                      style: const TextStyle(
                        color: Colors.white54,
                        fontSize: 12,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 24), // Increased spacing between title and value
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    value != null
                        ? value.toStringAsFixed(value.truncateToDouble() == value ? 0 : 2)
                        : 'N/A',
                    style: TextStyle(
                      color: value != null ? Colors.white : Colors.white38,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  if (unit.isNotEmpty && value != null)
                    Text(
                      unit,
                      style: const TextStyle(
                        color: Colors.white54,
                        fontSize: 12,
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
    );
  }

  double? _getPidValueFromLiveData(String pid) {
    if (_liveData == null) return null;
    
    // Map Extended PIDs to ObdLiveData fields
    switch (pid) {
      case '0121': return _liveData!.distanceWithMIL.toDouble();
      case '012E': return _liveData!.commandedPurge.toDouble();
      case '012F': return _liveData!.fuelLevelPercent.toDouble();
      case '0130': return _liveData!.warmupsSinceClear.toDouble();
      case '0131': return _liveData!.distanceSinceClear.toDouble();
      case '0133': return _liveData!.baroKpa.toDouble();
      case '013C': return _liveData!.catalystTemp1.toDouble();
      case '013D': return _liveData!.catalystTemp2.toDouble();
      case '013E': return _liveData!.catalystTemp3.toDouble();
      case '013F': return _liveData!.catalystTemp4.toDouble();
      case '0142': return _liveData!.voltageV;
      case '0143': return _liveData!.absoluteLoad.toDouble();
      case '0144': return _liveData!.commandedEquivRatio;
      case '0145': return _liveData!.relativeThrottle.toDouble();
      case '0146': return _liveData!.ambientTempC.toDouble();
      case '0147': return _liveData!.absoluteThrottleB.toDouble();
      case '0148': return _liveData!.absoluteThrottleC.toDouble();
      case '0149': return _liveData!.pedalPositionD.toDouble();
      case '014A': return _liveData!.pedalPositionE.toDouble();
      case '014B': return _liveData!.pedalPositionF.toDouble();
      case '014C': return _liveData!.commandedThrottleActuator.toDouble();
      case '014D': return _liveData!.timeRunWithMIL.toDouble();
      case '014E': return _liveData!.timeSinceCodesCleared.toDouble();
      case '014F': return _liveData!.maxEquivRatio;
      case '0150': return _liveData!.maxAirFlow.toDouble();
      case '0151': return _liveData!.fuelType.toDouble();
      case '0152': return _liveData!.ethanolFuel.toDouble();
      case '0153': return _liveData!.absEvapPressure.toDouble();
      case '0154': return _liveData!.evapPressure.toDouble();
      case '0155': return _liveData!.shortTermO2Trim1.toDouble();
      case '0156': return _liveData!.longTermO2Trim1.toDouble();
      case '0157': return _liveData!.shortTermO2Trim2.toDouble();
      case '0158': return _liveData!.longTermO2Trim2.toDouble();
      case '0159': return _liveData!.fuelPressure.toDouble();
      case '015A': return _liveData!.pedalPositionD.toDouble(); // Relative accelerator pedal position
      case '015B': return null; // Hybrid battery - not in ObdLiveData
      case '015C': return _liveData!.engineOilTempC.toDouble();
      case '015D': return null; // Fuel injection timing - not in ObdLiveData
      case '015E': return _liveData!.engineFuelRate;
      case '015F': return _liveData!.fuelType.toDouble(); // Emission requirements
      case '0161': return _liveData!.driverDemandTorque.toDouble();
      case '0162': return _liveData!.actualTorque.toDouble();
      case '0163': return _liveData!.referenceTorque.toDouble();
      default: return null;
    }
  }

  Map<String, String> _getPidInfo(String pid) {
    // Extended PIDs info from OBD_REFERENCE.md
    final pidMap = {
      '0121': {'name': 'Distance traveled with MIL on', 'description': 'Kilometers traveled with check engine light on', 'unit': 'km'},
      '012E': {'name': 'Commanded evaporative purge', 'description': 'Evaporative purge valve command', 'unit': '%'},
      '012F': {'name': 'Fuel tank level input', 'description': 'Fuel level from sensor', 'unit': '%'},
      '0130': {'name': 'Warm-ups since codes cleared', 'description': 'Number of warm-up cycles', 'unit': 'count'},
      '0131': {'name': 'Distance traveled since codes cleared', 'description': 'Kilometers since DTCs cleared', 'unit': 'km'},
      '0133': {'name': 'Absolute barometric pressure', 'description': 'Barometric pressure reading', 'unit': 'kPa'},
      '013C': {'name': 'Catalyst Temperature: Bank 1, Sensor 1', 'description': 'Catalyst temperature upstream', 'unit': '°C'},
      '013D': {'name': 'Catalyst Temperature: Bank 2, Sensor 1', 'description': 'Catalyst temperature upstream', 'unit': '°C'},
      '013E': {'name': 'Catalyst Temperature: Bank 1, Sensor 2', 'description': 'Catalyst temperature downstream', 'unit': '°C'},
      '013F': {'name': 'Catalyst Temperature: Bank 2, Sensor 2', 'description': 'Catalyst temperature downstream', 'unit': '°C'},
      '0142': {'name': 'Control module voltage', 'description': 'ECU/ECM voltage', 'unit': 'V'},
      '0143': {'name': 'Absolute load value', 'description': 'Absolute engine load', 'unit': '%'},
      '0144': {'name': 'Commanded Air-Fuel Equivalence Ratio', 'description': 'Lambda/AFR ratio', 'unit': 'ratio'},
      '0145': {'name': 'Relative throttle position', 'description': 'Relative throttle position', 'unit': '%'},
      '0146': {'name': 'Ambient air temperature', 'description': 'Outside air temperature', 'unit': '°C'},
      '0147': {'name': 'Absolute throttle position B', 'description': 'Throttle position sensor B', 'unit': '%'},
      '0148': {'name': 'Absolute throttle position C', 'description': 'Throttle position sensor C', 'unit': '%'},
      '0149': {'name': 'Accelerator pedal position D', 'description': 'Pedal position sensor D', 'unit': '%'},
      '014A': {'name': 'Accelerator pedal position E', 'description': 'Pedal position sensor E', 'unit': '%'},
      '014B': {'name': 'Accelerator pedal position F', 'description': 'Pedal position sensor F', 'unit': '%'},
      '014C': {'name': 'Commanded throttle actuator', 'description': 'Throttle actuator command', 'unit': '%'},
      '014D': {'name': 'Time run with MIL on', 'description': 'Minutes with check engine light on', 'unit': 'min'},
      '014E': {'name': 'Time since trouble codes cleared', 'description': 'Minutes since DTCs cleared', 'unit': 'min'},
      '014F': {'name': 'Maximum value for Equivalence Ratio', 'description': 'Max lambda value', 'unit': ''},
      '0150': {'name': 'Maximum value for air flow rate', 'description': 'Max MAF value', 'unit': 'g/s'},
      '0151': {'name': 'Fuel Type', 'description': 'Fuel type code', 'unit': 'code'},
      '0152': {'name': 'Ethanol fuel %', 'description': 'Ethanol percentage', 'unit': '%'},
      '0153': {'name': 'Absolute Evap system Vapor Pressure', 'description': 'Evap system pressure', 'unit': 'kPa'},
      '0154': {'name': 'Evap system vapor pressure', 'description': 'Evap pressure differential', 'unit': 'Pa'},
      '0155': {'name': 'Short term secondary O2 trim—Bank 1', 'description': 'O2 sensor trim Bank 1', 'unit': '%'},
      '0156': {'name': 'Long term secondary O2 trim—Bank 1', 'description': 'O2 sensor trim Bank 1', 'unit': '%'},
      '0157': {'name': 'Short term secondary O2 trim—Bank 2', 'description': 'O2 sensor trim Bank 2', 'unit': '%'},
      '0158': {'name': 'Long term secondary O2 trim—Bank 2', 'description': 'O2 sensor trim Bank 2', 'unit': '%'},
      '0159': {'name': 'Fuel rail absolute pressure', 'description': 'Fuel rail pressure', 'unit': 'kPa'},
      '015A': {'name': 'Relative accelerator pedal position', 'description': 'Pedal position relative', 'unit': '%'},
      '015B': {'name': 'Hybrid battery pack remaining life', 'description': 'Hybrid battery life', 'unit': '%'},
      '015C': {'name': 'Engine oil temperature', 'description': 'Engine oil temperature', 'unit': '°C'},
      '015D': {'name': 'Fuel injection timing', 'description': 'Fuel injection timing', 'unit': '°'},
      '015E': {'name': 'Engine fuel rate', 'description': 'Fuel consumption rate', 'unit': 'L/h'},
      '015F': {'name': 'Emission requirements', 'description': 'Emission standard code', 'unit': 'code'},
      '0161': {'name': 'Driver\'s demand engine - percent torque', 'description': 'Requested engine torque', 'unit': '%'},
      '0162': {'name': 'Actual engine - percent torque', 'description': 'Actual engine torque', 'unit': '%'},
      '0163': {'name': 'Engine reference torque', 'description': 'Reference torque value', 'unit': 'Nm'},
    };
    return pidMap[pid] ?? {'name': 'Extended PID $pid', 'description': 'Manufacturer/ECU-specific PID', 'unit': ''};
  }

  Future<void> _readPidValue(String pid) async {
    final client = ConnectionManager.instance.client;
    if (client == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Not connected to vehicle')),
      );
      return;
    }

    // Show loading dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: Card(
          child: Padding(
            padding: EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text('Reading PID value...'),
              ],
            ),
          ),
        ),
      ),
    );

    try {
      final response = await client.requestPid(pid);
      final value = _parsePidValue(pid, response);
      final pidInfo = _getPidInfo(pid);
      
      if (!mounted) return;
      Navigator.pop(context); // Close loading dialog
      
      // Show value dialog
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          backgroundColor: const Color(0xFF1C1F2A),
          title: Row(
            children: [
              const Icon(Icons.extension, color: Color(0xFF9B59B6)),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  pidInfo['name'] ?? 'Extended PID $pid',
                  style: const TextStyle(color: Colors.white, fontSize: 18),
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                pidInfo['description'] ?? 'Manufacturer/ECU-specific PID',
                style: const TextStyle(color: Colors.white70, fontSize: 14),
              ),
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF9B59B6).withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: const Color(0xFF9B59B6).withValues(alpha: 0.3),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      value != null ? value.toStringAsFixed(2) : 'N/A',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (value != null && pidInfo['unit'] != null && pidInfo['unit']!.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(left: 8),
                        child: Text(
                          pidInfo['unit']!,
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 18,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'PID: $pid',
                style: const TextStyle(color: Colors.white54, fontSize: 12),
              ),
              Text(
                'Raw: $response',
                style: const TextStyle(color: Colors.white38, fontSize: 11, fontFamily: 'monospace'),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close', style: TextStyle(color: Colors.white70)),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                _readPidValue(pid); // Refresh
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF9B59B6),
                foregroundColor: Colors.white,
              ),
              child: const Text('Refresh'),
            ),
          ],
        ),
      );
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context); // Close loading dialog
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to read PID: ${e.toString()}')),
      );
    }
  }

  double? _parsePidValue(String pid, String response) {
    try {
      final cleaned = response.replaceAll(RegExp(r"\s+"), '').toUpperCase();
      final key = '41' + pid.substring(2).toUpperCase();
      final i = cleaned.indexOf(key);
      if (i < 0) return null;

      switch (pid) {
        // 2-byte PIDs: (A×256)+B
        case '0121': // Distance traveled with MIL on - km
        case '0131': // Distance traveled since codes cleared - km
        case '014D': // Time run with MIL on - min
        case '014E': // Time since trouble codes cleared - min
          if (cleaned.length >= i + 8) {
            final a = int.parse(cleaned.substring(i + 4, i + 6), radix: 16);
            final b = int.parse(cleaned.substring(i + 6, i + 8), radix: 16);
            return (a * 256 + b).toDouble();
          }
          break;
        
        // 2-byte with division: ((A×256)+B)/X
        case '0142': // Control module voltage - V
          if (cleaned.length >= i + 8) {
            final a = int.parse(cleaned.substring(i + 4, i + 6), radix: 16);
            final b = int.parse(cleaned.substring(i + 6, i + 8), radix: 16);
            return ((a * 256) + b) / 1000.0;
          }
          break;
        case '013C': // Catalyst Temperature - °C
        case '013D':
        case '013E':
        case '013F':
          if (cleaned.length >= i + 8) {
            final a = int.parse(cleaned.substring(i + 4, i + 6), radix: 16);
            final b = int.parse(cleaned.substring(i + 6, i + 8), radix: 16);
            return ((a * 256) + b) / 10.0 - 40.0;
          }
          break;
        case '0144': // Commanded Air-Fuel Equivalence Ratio
          if (cleaned.length >= i + 8) {
            final a = int.parse(cleaned.substring(i + 4, i + 6), radix: 16);
            final b = int.parse(cleaned.substring(i + 6, i + 8), radix: 16);
            return ((a * 256) + b) / 32768.0;
          }
          break;
        case '0153': // Absolute Evap system Vapor Pressure - kPa
          if (cleaned.length >= i + 8) {
            final a = int.parse(cleaned.substring(i + 4, i + 6), radix: 16);
            final b = int.parse(cleaned.substring(i + 6, i + 8), radix: 16);
            return ((a * 256) + b) / 200.0;
          }
          break;
        case '0154': // Evap system vapor pressure - Pa
          if (cleaned.length >= i + 8) {
            final a = int.parse(cleaned.substring(i + 4, i + 6), radix: 16);
            final b = int.parse(cleaned.substring(i + 6, i + 8), radix: 16);
            return (a * 256 + b - 32767).toDouble();
          }
          break;
        case '0159': // Fuel rail absolute pressure - kPa
          if (cleaned.length >= i + 8) {
            final a = int.parse(cleaned.substring(i + 4, i + 6), radix: 16);
            final b = int.parse(cleaned.substring(i + 6, i + 8), radix: 16);
            return ((a * 256) + b) * 10.0;
          }
          break;
        case '015E': // Engine fuel rate - L/h
          if (cleaned.length >= i + 8) {
            final a = int.parse(cleaned.substring(i + 4, i + 6), radix: 16);
            final b = int.parse(cleaned.substring(i + 6, i + 8), radix: 16);
            return ((a * 256) + b) * 0.05;
          }
          break;
        case '0163': // Engine reference torque - Nm
          if (cleaned.length >= i + 8) {
            final a = int.parse(cleaned.substring(i + 4, i + 6), radix: 16);
            final b = int.parse(cleaned.substring(i + 6, i + 8), radix: 16);
            return (a * 256 + b).toDouble();
          }
          break;
        case '0143': // Absolute load value - %
          if (cleaned.length >= i + 8) {
            final a = int.parse(cleaned.substring(i + 4, i + 6), radix: 16);
            final b = int.parse(cleaned.substring(i + 6, i + 8), radix: 16);
            return ((a * 256) + b) * 100.0 / 255.0;
          }
          break;
        case '015D': // Fuel injection timing - °
          if (cleaned.length >= i + 8) {
            final a = int.parse(cleaned.substring(i + 4, i + 6), radix: 16);
            final b = int.parse(cleaned.substring(i + 6, i + 8), radix: 16);
            return ((a * 256) + b - 26880) / 128.0;
          }
          break;
        
        // 1-byte PIDs: A×100/255 (%)
        case '012E': // Commanded evaporative purge - %
        case '012F': // Fuel tank level input - %
        case '0145': // Relative throttle position - %
        case '0147': // Absolute throttle position B - %
        case '0148': // Absolute throttle position C - %
        case '0149': // Accelerator pedal position D - %
        case '014A': // Accelerator pedal position E - %
        case '014B': // Accelerator pedal position F - %
        case '014C': // Commanded throttle actuator - %
        case '0152': // Ethanol fuel % - %
        case '015A': // Relative accelerator pedal position - %
        case '015B': // Hybrid battery pack remaining life - %
          if (cleaned.length >= i + 6) {
            final a = int.parse(cleaned.substring(i + 4, i + 6), radix: 16);
            return (a * 100.0) / 255.0;
          }
          break;
        
        // 1-byte PIDs: A-40 (°C)
        case '0146': // Ambient air temperature - °C
        case '015C': // Engine oil temperature - °C
          if (cleaned.length >= i + 6) {
            final a = int.parse(cleaned.substring(i + 4, i + 6), radix: 16);
            return (a - 40).toDouble();
          }
          break;
        
        // 1-byte PIDs: A (direct value)
        case '0130': // Warm-ups since codes cleared
        case '0133': // Absolute barometric pressure - kPa
        case '014F': // Maximum value for Equivalence Ratio
        case '0150': // Maximum value for air flow rate - g/s (A×10)
        case '0151': // Fuel Type
        case '015F': // Emission requirements
          if (cleaned.length >= i + 6) {
            final a = int.parse(cleaned.substring(i + 4, i + 6), radix: 16);
            if (pid == '0150') return (a * 10).toDouble(); // g/s
            return a.toDouble();
          }
          break;
        
        // 1-byte PIDs: A-125 (%)
        case '0161': // Driver's demand engine - percent torque
        case '0162': // Actual engine - percent torque
          if (cleaned.length >= i + 6) {
            final a = int.parse(cleaned.substring(i + 4, i + 6), radix: 16);
            return (a - 125).toDouble();
          }
          break;
        
        // Fuel trim PIDs: (A-128)×100/128 (%)
        case '0155': // Short term secondary O2 trim—Bank 1
        case '0156': // Long term secondary O2 trim—Bank 1
        case '0157': // Short term secondary O2 trim—Bank 2
        case '0158': // Long term secondary O2 trim—Bank 2
          if (cleaned.length >= i + 6) {
            final a = int.parse(cleaned.substring(i + 4, i + 6), radix: 16);
            return ((a - 128) * 100.0) / 128.0;
          }
          break;
      }
    } catch (e) {
      // Parse error
    }
    return null;
  }



  Future<void> _showVehicleInfoDialog({bool autoShow = false}) async {
    final vehicle = ConnectionManager.instance.vehicle;
    String? selectedMake = vehicle?.make;
    
    final makeController = TextEditingController(text: selectedMake ?? '');

    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => _VehicleInfoScreen(
          autoShow: autoShow,
          makeController: makeController,
          onConfirm: (make) {
            _loadWithVehicleInfo(make: make);
          },
        ),
        fullscreenDialog: true,
      ),
    );
  }

  Future<void> _loadWithVehicleInfo({
    required String make,
  }) async {
    // Update vehicle info and persist it
    final vehicle = ConnectionManager.instance.vehicle;
    if (vehicle != null) {
      final updatedVehicle = vehicle.copyWith(
        make: make,
      );
      await VehicleService.save(updatedVehicle);
      ConnectionManager.instance.currentVehicle.value = updatedVehicle;
    }
    
    // Reload with vehicle info
    await _load();
  }
}

class _VehicleInfoScreen extends StatefulWidget {
  final bool autoShow;
  final TextEditingController makeController;
  final Function(String) onConfirm;

  const _VehicleInfoScreen({
    required this.autoShow,
    required this.makeController,
    required this.onConfirm,
  });

  @override
  State<_VehicleInfoScreen> createState() => _VehicleInfoScreenState();
}

class _VehicleInfoScreenState extends State<_VehicleInfoScreen> {
  String _makeSearchQuery = '';
  final List<String> _allMakes = CarMakes.getAll();
  
  List<String> get _filteredMakes {
    if (_makeSearchQuery.isEmpty) {
      return _allMakes;
    }
    final query = _makeSearchQuery.toLowerCase();
    return _allMakes.where((make) => make.toLowerCase().contains(query)).toList();
  }
  
  @override
  void initState() {
    super.initState();
    // Auto-focus first field if autoShow
    if (widget.autoShow && widget.makeController.text.isEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        // Focus will be handled by the field
      });
    }
  }

  void _confirm() {
    final make = widget.makeController.text.trim();
    
    if (make.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a manufacturer'),
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }
    
    Navigator.pop(context);
    widget.onConfirm(make);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1C1F2A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF9B59B6),
        foregroundColor: Colors.white,
        elevation: 0,
        title: Text(
          widget.autoShow ? 'Select Vehicle Information' : 'Set Vehicle Information',
          style: const TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w500,
          ),
        ),
        leading: widget.autoShow
            ? null
            : IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.pop(context),
              ),
      ),
      body: Column(
        children: [
          // Content
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Select vehicle manufacturer:',
                    style: TextStyle(color: Colors.white70, fontSize: 16),
                  ),
                  const SizedBox(height: 16),
                  // Search bar
                  TextField(
                    style: const TextStyle(color: Colors.white, fontSize: 16),
                    decoration: InputDecoration(
                      hintText: 'Search manufacturer...',
                      hintStyle: const TextStyle(color: Colors.white38),
                      prefixIcon: const Icon(Icons.search, color: Colors.white54),
                      filled: true,
                      fillColor: Colors.white.withValues(alpha: 0.1),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.2)),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.2)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Color(0xFF9B59B6), width: 2),
                      ),
                    ),
                    onChanged: (value) {
                      setState(() {
                        _makeSearchQuery = value;
                      });
                    },
                  ),
                  const SizedBox(height: 16),
                  // List of all makes
                  Expanded(
                    child: ListView.builder(
                      itemCount: _filteredMakes.length,
                      itemBuilder: (context, index) {
                        final make = _filteredMakes[index];
                        final isSelected = widget.makeController.text == make;
                        return Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          child: Material(
                            color: Colors.transparent,
                            child: InkWell(
                              onTap: () {
                                widget.makeController.text = make;
                                setState(() {});
                              },
                              borderRadius: BorderRadius.circular(12),
                              splashColor: const Color(0xFF9B59B6).withValues(alpha: 0.3),
                              highlightColor: const Color(0xFF9B59B6).withValues(alpha: 0.1),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? const Color(0xFF9B59B6).withValues(alpha: 0.2)
                                      : Colors.white.withValues(alpha: 0.05),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: isSelected
                                        ? const Color(0xFF9B59B6)
                                        : Colors.white.withValues(alpha: 0.1),
                                    width: isSelected ? 2 : 1,
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        make,
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 16,
                                          fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                                        ),
                                      ),
                                    ),
                                    if (isSelected)
                                      const Icon(Icons.check_circle, color: Color(0xFF9B59B6), size: 24),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
          
          // Footer with buttons
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: const Color(0xFF1C1F2A),
              border: Border(
                top: BorderSide(
                  color: Colors.white.withValues(alpha: 0.1),
                  width: 1,
                ),
              ),
            ),
            child: SafeArea(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  if (!widget.autoShow)
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      ),
                      child: const Text('Cancel', style: TextStyle(color: Colors.white70, fontSize: 16)),
                    ),
                  if (!widget.autoShow) const SizedBox(width: 12),
                  ElevatedButton(
                    onPressed: widget.makeController.text.trim().isNotEmpty ? _confirm : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF9B59B6),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
                      disabledBackgroundColor: const Color(0xFF9B59B6).withValues(alpha: 0.3),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text('Confirm', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

}
