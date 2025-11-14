import 'package:flutter/material.dart';
import 'package:flutter_car_scanner/services/connection_manager.dart';
import 'package:flutter_car_scanner/services/obd_client.dart';

class EcuDataScreen extends StatefulWidget {
  const EcuDataScreen({super.key});

  @override
  State<EcuDataScreen> createState() => _EcuDataScreenState();
}

class _EcuDataScreenState extends State<EcuDataScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  
  // Connection state
  bool get _isConnected => ConnectionManager.instance.isConnected.value;
  
  // ECU Identification data
  String? _vin;
  String? _ecuName;
  String? _calibrationId;
  String? _cvn;
  String? _ipt;
  String? _ecuSerialNumber;
  List<String>? _supportedPids;
  bool _loadingEcuId = false;
  
  // Adaptation Values data
  Map<String, String>? _adaptationData;
  bool _loadingAdaptation = false;
  
  // OBD Standards data
  String? _obdStandard;
  String? _fuelType;
  bool _loadingStandards = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }
  
  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }
  
  // ========== Load Functions ==========
  
  Future<void> _loadEcuIdentification() async {
    if (!_isConnected) return;
    
    setState(() {
      _loadingEcuId = true;
    });
    
    final client = ConnectionManager.instance.client as ObdClient?;
    if (client == null) {
      setState(() {
        _loadingEcuId = false;
      });
      return;
    }
    
    try {
      // Read VIN (Mode 09 PID 02)
      try {
        final response = await client.requestPid('09 02');
        _vin = _parseVin(response);
      } catch (e) {
        _vin = 'Not available';
      }
      
      // Read Calibration ID (Mode 09 PID 04)
      try {
        final response = await client.requestPid('09 04');
        _calibrationId = _parseCalibrationId(response);
      } catch (e) {
        _calibrationId = 'Not available';
      }
      
      // Read Calibration Verification Number (Mode 09 PID 06)
      try {
        final response = await client.requestPid('09 06');
        _cvn = _parseCvn(response);
      } catch (e) {
        _cvn = 'Not available';
      }
      
      // Read IPT (In-use Performance Tracking) (Mode 09 PID 08)
      try {
        final response = await client.requestPid('09 08');
        _ipt = _parseIpt(response);
      } catch (e) {
        _ipt = 'Not available';
      }
      
      // Read ECU Name (Mode 09 PID 0A)
      try {
        _ecuName = await client.readEcuName();
      } catch (e) {
        _ecuName = 'Not available';
      }
      
      // Read ECU Serial Number (Mode 09 PID 0C - if supported)
      try {
        final response = await client.requestPid('09 0C');
        _ecuSerialNumber = _parseEcuSerial(response);
      } catch (e) {
        _ecuSerialNumber = 'Not available';
      }
      
      // Read Supported PIDs (Mode 01 PID 00)
      try {
        _supportedPids = await client.readSupportedPids();
      } catch (e) {
        _supportedPids = [];
      }
      
      if (mounted) {
        setState(() {
          _loadingEcuId = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _loadingEcuId = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load ECU identification: $e')),
        );
      }
    }
  }
  
  Future<void> _loadAdaptation() async {
    if (!_isConnected) return;
    
    setState(() {
      _loadingAdaptation = true;
    });
    
    final client = ConnectionManager.instance.client as ObdClient?;
    if (client == null) {
      setState(() {
        _loadingAdaptation = false;
      });
      return;
    }
    
    try {
      final data = <String, String>{};
      
      // Fuel Trim Bank 1 Short Term (PID 06)
      try {
        final response = await client.requestPid('01 06');
        data['Fuel Trim Bank 1 (Short)'] = '${_parseFuelTrim(response)}%';
      } catch (e) {
        data['Fuel Trim Bank 1 (Short)'] = 'N/A';
      }
      
      // Fuel Trim Bank 1 Long Term (PID 07)
      try {
        final response = await client.requestPid('01 07');
        data['Fuel Trim Bank 1 (Long)'] = '${_parseFuelTrim(response)}%';
      } catch (e) {
        data['Fuel Trim Bank 1 (Long)'] = 'N/A';
      }
      
      // Fuel Trim Bank 2 Short Term (PID 08)
      try {
        final response = await client.requestPid('01 08');
        data['Fuel Trim Bank 2 (Short)'] = '${_parseFuelTrim(response)}%';
      } catch (e) {
        data['Fuel Trim Bank 2 (Short)'] = 'N/A';
      }
      
      // Fuel Trim Bank 2 Long Term (PID 09)
      try {
        final response = await client.requestPid('01 09');
        data['Fuel Trim Bank 2 (Long)'] = '${_parseFuelTrim(response)}%';
      } catch (e) {
        data['Fuel Trim Bank 2 (Long)'] = 'N/A';
      }
      
      // Timing Advance (PID 0E)
      try {
        final response = await client.requestPid('01 0E');
        data['Timing Advance'] = '${_parseTimingAdvance(response)}°';
      } catch (e) {
        data['Timing Advance'] = 'N/A';
      }
      
      // O2 Sensor 1 (PID 14)
      try {
        final response = await client.requestPid('01 14');
        final parsed = _parseO2Sensor(response);
        data['O2 Sensor 1 Voltage'] = '${parsed['voltage']} V';
        data['O2 Sensor 1 Trim'] = '${parsed['trim']}%';
      } catch (e) {
        data['O2 Sensor 1 Voltage'] = 'N/A';
        data['O2 Sensor 1 Trim'] = 'N/A';
      }
      
      _adaptationData = data;
      
      if (mounted) {
        setState(() {
          _loadingAdaptation = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _loadingAdaptation = false;
        });
      }
    }
  }
  
  Future<void> _loadStandards() async {
    if (!_isConnected) return;
    
    setState(() {
      _loadingStandards = true;
    });
    
    final client = ConnectionManager.instance.client as ObdClient?;
    if (client == null) {
      setState(() {
        _loadingStandards = false;
      });
      return;
    }
    
    try {
      // Read OBD Standard (Mode 01 PID 1C)
      try {
        final response = await client.requestPid('01 1C');
        _obdStandard = _parseObdStandard(response);
      } catch (e) {
        _obdStandard = 'Not available';
      }
      
      // Read Fuel Type (Mode 01 PID 51)
      try {
        final response = await client.requestPid('01 51');
        _fuelType = _parseFuelType(response);
      } catch (e) {
        _fuelType = 'Not available';
      }
      
      if (mounted) {
        setState(() {
          _loadingStandards = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _loadingStandards = false;
        });
      }
    }
  }
  
  // ========== Parsing Functions ==========
  
  String _parseVin(String response) {
    final cleaned = response.replaceAll(RegExp(r'\s+'), '').toUpperCase();
    final index = cleaned.indexOf('4902');
    if (index < 0) return 'Not available';
    
    // Skip "01" count byte and parse VIN (17 ASCII chars)
    final vinHex = cleaned.substring(index + 6);
    final vinBuffer = StringBuffer();
    
    for (int i = 0; i < vinHex.length - 1 && vinBuffer.length < 17; i += 2) {
      try {
        final charCode = int.parse(vinHex.substring(i, i + 2), radix: 16);
        if (charCode >= 32 && charCode <= 126) {
          vinBuffer.write(String.fromCharCode(charCode));
        }
      } catch (_) {}
    }
    
    final vin = vinBuffer.toString().trim();
    return vin.length == 17 ? vin : 'Not available';
  }
  
  String _parseCalibrationId(String response) {
    final cleaned = response.replaceAll(RegExp(r'\s+'), '').toUpperCase();
    final index = cleaned.indexOf('4904');
    if (index < 0) return 'Not available';
    
    final idHex = cleaned.substring(index + 6);
    final idBuffer = StringBuffer();
    
    for (int i = 0; i < idHex.length - 1; i += 2) {
      try {
        final charCode = int.parse(idHex.substring(i, i + 2), radix: 16);
        if (charCode >= 32 && charCode <= 126) {
          idBuffer.write(String.fromCharCode(charCode));
        }
      } catch (_) {}
    }
    
    final id = idBuffer.toString().trim();
    return id.isNotEmpty ? id : 'Not available';
  }
  
  String _parseCvn(String response) {
    final cleaned = response.replaceAll(RegExp(r'\s+'), '').toUpperCase();
    final index = cleaned.indexOf('4906');
    if (index < 0 || cleaned.length < index + 14) return 'Not available';
    
    try {
      // CVN is 4 bytes (8 hex chars) after count byte
      final cvnHex = cleaned.substring(index + 6, index + 14);
      return cvnHex.toUpperCase();
    } catch (_) {
      return 'Not available';
    }
  }
  
  String _parseIpt(String response) {
    final cleaned = response.replaceAll(RegExp(r'\s+'), '').toUpperCase();
    final index = cleaned.indexOf('4908');
    if (index < 0 || cleaned.length < index + 6) return 'Not available';
    
    try {
      // IPT is typically multiple bytes of counters
      final iptHex = cleaned.substring(index + 6);
      if (iptHex.isEmpty) return 'Not available';
      
      // Parse as hex string
      return iptHex.length > 16 ? '${iptHex.substring(0, 16)}...' : iptHex;
    } catch (_) {
      return 'Not available';
    }
  }
  
  String _parseEcuSerial(String response) {
    final cleaned = response.replaceAll(RegExp(r'\s+'), '').toUpperCase();
    final index = cleaned.indexOf('490C');
    if (index < 0) return 'Not available';
    
    final serialHex = cleaned.substring(index + 6);
    final serialBuffer = StringBuffer();
    
    for (int i = 0; i < serialHex.length - 1; i += 2) {
      try {
        final charCode = int.parse(serialHex.substring(i, i + 2), radix: 16);
        if (charCode >= 32 && charCode <= 126) {
          serialBuffer.write(String.fromCharCode(charCode));
        }
      } catch (_) {}
    }
    
    final serial = serialBuffer.toString().trim();
    return serial.isNotEmpty ? serial : 'Not available';
  }
  
  String _parseObdStandard(String response) {
    final cleaned = response.replaceAll(RegExp(r'\s+'), '').toUpperCase();
    final index = cleaned.indexOf('411C');
    if (index < 0 || cleaned.length < index + 6) return 'Not available';
    
    try {
      final code = int.parse(cleaned.substring(index + 4, index + 6), radix: 16);
      final standards = {
        1: 'OBD-II (CARB)',
        2: 'OBD (EPA)',
        3: 'OBD and OBD-II',
        4: 'OBD-I',
        5: 'Not OBD compliant',
        6: 'EOBD (Europe)',
        7: 'EOBD and OBD-II',
        8: 'EOBD and OBD',
        9: 'EOBD, OBD and OBD-II',
        10: 'JOBD (Japan)',
        11: 'JOBD and OBD-II',
        12: 'JOBD and EOBD',
        13: 'JOBD, EOBD, and OBD-II',
      };
      return standards[code] ?? 'Unknown ($code)';
    } catch (_) {
      return 'Not available';
    }
  }
  
  String _parseFuelType(String response) {
    final cleaned = response.replaceAll(RegExp(r'\s+'), '').toUpperCase();
    final index = cleaned.indexOf('4151');
    if (index < 0 || cleaned.length < index + 6) return 'Not available';
    
    try {
      final code = int.parse(cleaned.substring(index + 4, index + 6), radix: 16);
      final types = {
        0: 'Not available',
        1: 'Gasoline',
        2: 'Methanol',
        3: 'Ethanol',
        4: 'Diesel',
        5: 'LPG',
        6: 'CNG',
        7: 'Propane',
        8: 'Electric',
        9: 'Bifuel (Gasoline)',
        10: 'Bifuel (Methanol)',
        11: 'Bifuel (Ethanol)',
        12: 'Bifuel (LPG)',
        13: 'Bifuel (CNG)',
        14: 'Bifuel (Propane)',
        15: 'Bifuel (Electric)',
        16: 'Bifuel (Electric & Combustion)',
        17: 'Hybrid Gasoline',
        18: 'Hybrid Ethanol',
        19: 'Hybrid Diesel',
        20: 'Hybrid Electric',
        21: 'Hybrid (Electric & Combustion)',
        22: 'Hybrid Regenerative',
        23: 'Bifuel (Diesel)',
      };
      return types[code] ?? 'Unknown ($code)';
    } catch (_) {
      return 'Not available';
    }
  }
  
  int _parseFuelTrim(String response) {
    final cleaned = response.replaceAll(RegExp(r'\s+'), '').toUpperCase();
    final match = RegExp(r'41[0-9A-F]{2}([0-9A-F]{2})').firstMatch(cleaned);
    if (match == null) return 0;
    
    try {
      final value = int.parse(match.group(1)!, radix: 16);
      return ((value - 128) * 100) ~/ 128;
    } catch (_) {
      return 0;
    }
  }
  
  int _parseTimingAdvance(String response) {
    final cleaned = response.replaceAll(RegExp(r'\s+'), '').toUpperCase();
    final index = cleaned.indexOf('410E');
    if (index < 0 || cleaned.length < index + 6) return 0;
    
    try {
      final value = int.parse(cleaned.substring(index + 4, index + 6), radix: 16);
      return (value ~/ 2) - 64;
    } catch (_) {
      return 0;
    }
  }
  
  Map<String, dynamic> _parseO2Sensor(String response) {
    final cleaned = response.replaceAll(RegExp(r'\s+'), '').toUpperCase();
    final match = RegExp(r'41[0-9A-F]{2}([0-9A-F]{2})([0-9A-F]{2})').firstMatch(cleaned);
    if (match == null) return {'voltage': 0.0, 'trim': 0};
    
    try {
      final a = int.parse(match.group(1)!, radix: 16);
      final b = int.parse(match.group(2)!, radix: 16);
      
      final voltage = (a / 200.0).toStringAsFixed(2);
      final trim = b == 0xFF ? 0 : ((b - 128) * 100) ~/ 128;
      
      return {'voltage': voltage, 'trim': trim};
    } catch (_) {
      return {'voltage': 0.0, 'trim': 0};
    }
  }
  
  // ========== UI Build Functions ==========
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1A1A2E),
      appBar: AppBar(
        backgroundColor: const Color(0xFFE91E63),
        foregroundColor: Colors.white,
        title: const Text('ECU Data'),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: const [
            Tab(text: 'ECU ID'),
            Tab(text: 'Adaptation'),
            Tab(text: 'Standards'),
          ],
        ),
      ),
      body: SafeArea(
        bottom: true,
        child: TabBarView(
          controller: _tabController,
          children: [
            _buildEcuIdTab(),
            _buildAdaptationTab(),
            _buildStandardsTab(),
          ],
        ),
      ),
    );
  }
  
  Widget _buildEcuIdTab() {
    if (!_isConnected) {
      return _buildNotConnectedView();
    }
    
    if (_loadingEcuId) {
      return const Center(
        child: CircularProgressIndicator(color: Colors.pinkAccent),
      );
    }
    
    // Show scan button if no data loaded yet
    if (_vin == null && _ecuName == null && _calibrationId == null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.memory,
              size: 64,
              color: Colors.white.withValues(alpha: 0.3),
            ),
            const SizedBox(height: 16),
            Text(
              'ECU Identifiers',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.5),
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Scan to read ECU identification data',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.3),
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _loadEcuIdentification,
              icon: const Icon(Icons.search),
              label: const Text('Start Scan'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFE91E63),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
      );
    }
    
    return RefreshIndicator(
      onRefresh: _loadEcuIdentification,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Vehicle Identification
          Container(
            margin: const EdgeInsets.only(bottom: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(
                  padding: EdgeInsets.only(bottom: 8),
                  child: Text(
                    'Vehicle Identification',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                _buildInfoCard('VIN', Icons.directions_car, _vin ?? 'Not available'),
              ],
            ),
          ),
          
          // ECU Identification
          const Padding(
            padding: EdgeInsets.only(bottom: 8),
            child: Text(
              'ECU Identification',
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          _buildInfoCard('ECU Name', Icons.memory, _ecuName ?? 'Not available'),
          const SizedBox(height: 12),
          _buildInfoCard('ECU Serial Number', Icons.tag, _ecuSerialNumber ?? 'Not available'),
          const SizedBox(height: 12),
          
          // Software Identification
          const Padding(
            padding: EdgeInsets.only(top: 12, bottom: 8),
            child: Text(
              'Software Identification',
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          _buildInfoCard('Calibration ID', Icons.settings, _calibrationId ?? 'Not available'),
          const SizedBox(height: 12),
          _buildInfoCard('CVN (Calibration Verification)', Icons.verified, _cvn ?? 'Not available'),
          const SizedBox(height: 12),
          _buildInfoCard('IPT (In-use Performance)', Icons.analytics, _ipt ?? 'Not available'),
          const SizedBox(height: 16),
          
          // Supported PIDs
          _buildSupportedPidsCard(),
        ],
      ),
    );
  }
  
  Widget _buildAdaptationTab() {
    if (!_isConnected) {
      return _buildNotConnectedView();
    }
    
    if (_loadingAdaptation) {
      return const Center(
        child: CircularProgressIndicator(color: Colors.pinkAccent),
      );
    }
    
    if (_adaptationData == null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.tune,
              size: 64,
              color: Colors.white.withValues(alpha: 0.3),
            ),
            const SizedBox(height: 16),
            Text(
              'Adaptation Values',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.5),
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Scan to read ECU adaptation data',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.3),
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _loadAdaptation,
              icon: const Icon(Icons.search),
              label: const Text('Start Scan'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFE91E63),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
      );
    }
    
    return RefreshIndicator(
      onRefresh: _loadAdaptation,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          ..._adaptationData!.entries.map((entry) => Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _buildInfoCard(entry.key, Icons.tune, entry.value),
          )),
        ],
      ),
    );
  }
  
  Widget _buildStandardsTab() {
    if (!_isConnected) {
      return _buildNotConnectedView();
    }
    
    if (_loadingStandards) {
      return const Center(
        child: CircularProgressIndicator(color: Colors.pinkAccent),
      );
    }
    
    if (_obdStandard == null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.rule,
              size: 64,
              color: Colors.white.withValues(alpha: 0.3),
            ),
            const SizedBox(height: 16),
            Text(
              'OBD Standards',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.5),
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Scan to read OBD standards data',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.3),
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _loadStandards,
              icon: const Icon(Icons.search),
              label: const Text('Start Scan'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFE91E63),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
      );
    }
    
    return RefreshIndicator(
      onRefresh: _loadStandards,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildInfoCard('OBD Standard', Icons.rule, _obdStandard ?? 'Not available'),
          const SizedBox(height: 12),
          _buildInfoCard('Fuel Type', Icons.local_gas_station, _fuelType ?? 'Not available'),
        ],
      ),
    );
  }
  
  Widget _buildInfoCard(String label, IconData icon, String value) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: const Color(0xFFE91E63).withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFFE91E63).withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: const Color(0xFFE91E63), size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildSupportedPidsCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: const Color(0xFFE91E63).withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFFE91E63).withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.checklist, color: Color(0xFFE91E63), size: 24),
              ),
              const SizedBox(width: 16),
              const Expanded(
                child: Text(
                  'Supported PIDs',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFE91E63).withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${_supportedPids?.length ?? 0}',
                  style: const TextStyle(
                    color: Color(0xFFE91E63),
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          if (_supportedPids != null && _supportedPids!.isNotEmpty) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _supportedPids!.map((pid) => Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.1),
                  ),
                ),
                child: Text(
                  pid,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 11,
                    fontFamily: 'monospace',
                  ),
                ),
              )).toList(),
            ),
          ],
        ],
      ),
    );
  }
  
  Widget _buildNotConnectedView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.link_off,
            size: 64,
            color: Colors.white.withValues(alpha: 0.3),
          ),
          const SizedBox(height: 16),
          Text(
            'Not Connected',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.5),
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Connect to vehicle to view ECU data',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.3),
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }
}
