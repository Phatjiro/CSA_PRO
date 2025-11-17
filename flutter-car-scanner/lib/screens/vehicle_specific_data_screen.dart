import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_car_scanner/services/connection_manager.dart';
import 'package:flutter_car_scanner/services/obd_client.dart';
import 'package:flutter_car_scanner/services/obdb_service.dart';
import 'package:flutter_car_scanner/services/obdb_models.dart';
import 'package:flutter_car_scanner/services/vin_decoder_service.dart';
import 'package:flutter_car_scanner/data/car_makes.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

class VehicleSpecificDataScreen extends StatefulWidget {
  const VehicleSpecificDataScreen({super.key});

  @override
  State<VehicleSpecificDataScreen> createState() => _VehicleSpecificDataScreenState();
}

class _VehicleSpecificDataScreenState extends State<VehicleSpecificDataScreen> {
  bool _loading = true;
  String? _error;
  List<String> _supported = []; // PIDs supported by ECU
  ObdbData? _obdbData; // Extended PIDs data from OBDb
  Map<String, ObdbPid> _pidMap = {}; // Map PID hex -> ObdbPid for quick lookup
  
  // Vehicle info for current session
  String? _sessionMake;
  String? _sessionModel;
  int? _sessionYear;
  bool _hasShownDialog = false;
  Set<String> _addedPids = {}; // Track PIDs already added to dashboard

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkAndShowDialog();
    });
    _load();
  }
  
  Future<void> _checkAndShowDialog() async {
    // Check if we have vehicle info, if not show dialog
    final vehicle = ConnectionManager.instance.vehicle;
    String? make = vehicle?.make;
    String? model = vehicle?.model;
    int? year = vehicle?.year;
    
    // Try VIN decode if no make/model
    if ((make == null || make.isEmpty || model == null || model.isEmpty) && 
        vehicle != null && vehicle.vin != null && vehicle.vin!.isNotEmpty && vehicle.vin! != '-') {
      try {
        final vinData = await VinDecoderService.decodeVin(vehicle.vin!);
        if (vinData != null) {
          make = vinData['Make'];
          model = vinData['Model'];
          final yearStr = vinData['Year'] ?? '';
          year = yearStr.isNotEmpty ? int.tryParse(yearStr) : null;
        }
      } catch (e) {
        // Silent fail
      }
    }
    
    // If still no make/model, show dialog
    if ((make == null || make.isEmpty || model == null || model.isEmpty) && !_hasShownDialog) {
      _hasShownDialog = true;
      await _showVehicleInfoDialog(autoShow: true);
    } else {
      // Use existing info
      _sessionMake = make;
      _sessionModel = model;
      _sessionYear = year;
    }
    
    // Load added PIDs
    await _loadAddedPids();
  }
  
  Future<void> _loadAddedPids() async {
    final prefs = await SharedPreferences.getInstance();
    final savedPids = prefs.getStringList('custom_extended_pids') ?? [];
    setState(() {
      _addedPids = savedPids.toSet();
    });
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
      _supported = [];
      _obdbData = null;
      _pidMap = {};
    });
    
    try {
      final client = ConnectionManager.instance.client as ObdClient?;
      if (client == null) {
        setState(() {
          _error = 'Not connected. Please CONNECT first.';
          _loading = false;
        });
        return;
      }

      // 1. Get supported Extended PIDs from ECU
      final list = await client.getExtendedSupportedPids();
      
      // 2. Try to fetch Extended PIDs data
      ObdbData? obdbData;
      try {
        String? make;
        String? model;
        int? year;
        
        // Use session vehicle info first (from dialog)
        if (_sessionMake != null && _sessionMake!.isNotEmpty && 
            _sessionModel != null && _sessionModel!.isNotEmpty) {
          make = _sessionMake;
          model = _sessionModel;
          year = _sessionYear;
          print('🔍 Vehicle-Specific Data: Using session info - Make: $make, Model: $model, Year: $year');
        } else {
          // Try to get make/model from VIN first
          final vehicle = ConnectionManager.instance.vehicle;
          if (vehicle != null && vehicle.vin != null && vehicle.vin!.isNotEmpty && vehicle.vin! != '-') {
            final vinData = await VinDecoderService.decodeVin(vehicle.vin!);
            if (vinData != null) {
              make = vinData['Make'];
              model = vinData['Model'];
              final yearStr = vinData['Year'] ?? '';
              year = yearStr.isNotEmpty ? int.tryParse(yearStr) : null;
              print('🔍 Vehicle-Specific Data: VIN decoded - Make: $make, Model: $model, Year: $year');
            }
          }
          
          // Fallback to vehicle make/model if VIN decode fails
          if ((make == null || make.isEmpty) && vehicle != null) {
            make = vehicle.make ?? 'Unknown';
            model = vehicle.model ?? 'Unknown';
            year = vehicle.year;
            print('🔍 Vehicle-Specific Data: Using vehicle make/model - Make: $make, Model: $model, Year: $year');
          }
          
          // Save to session
          _sessionMake = make;
          _sessionModel = model;
          _sessionYear = year;
        }
        
        // Always fetch Extended PIDs (generic from Wikipedia if no make/model)
        if (make != null && make.isNotEmpty && model != null && model.isNotEmpty) {
          obdbData = await ObdbService.fetchWithCache(
            make: make,
            model: model,
            year: year,
          );
        } else {
          // Fetch generic Extended PIDs even without make/model
          obdbData = await ObdbService.fetchWithCache(
            make: 'Generic',
            model: 'Vehicle',
            year: null,
          );
        }
        
        if (obdbData == null) {
          print('⚠️ Vehicle-Specific Data: No Extended PIDs data found');
        } else {
          print('✅ Vehicle-Specific Data: Loaded ${obdbData.pids.length} Extended PIDs');
        }
      } catch (e) {
        print('Error fetching Extended PIDs data: $e');
        // Continue without Extended PIDs data
      }

      // 3. Create PID map for quick lookup
      final pidMap = <String, ObdbPid>{};
      if (obdbData != null) {
        for (final pid in obdbData.pids) {
          // Normalize PID format (remove leading 0 if needed)
          final pidHex = pid.pid.toUpperCase();
          pidMap[pidHex] = pid;
        }
      }

      setState(() {
        _supported = list;
        _obdbData = obdbData;
        _pidMap = pidMap;
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
          else ...[
            IconButton(
              icon: const Icon(Icons.edit),
              onPressed: _loading ? null : _showVehicleInfoDialog,
              tooltip: 'Set Vehicle Info',
            ),
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: _loading ? null : _load,
              tooltip: 'Refresh',
            ),
          ],
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
    // Show OBDb metadata if available
    final hasObdbData = _obdbData != null;
    final hasSupportedPids = _supported.isNotEmpty;

    if (!hasSupportedPids && !hasObdbData) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.info_outline, size: 56, color: Colors.white54),
              const SizedBox(height: 12),
              const Text(
                'No extended PIDs data available.',
                style: TextStyle(color: Colors.white70),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              const Text(
                'Extended PID ranges: 0121-0140, 0141-0160, 0161-0180',
                style: TextStyle(color: Colors.white54, fontSize: 12),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              const Text(
                'OBDb data will be loaded automatically if VIN is available.',
                style: TextStyle(color: Colors.white38, fontSize: 11),
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
        // OBDb Metadata Card
        if (hasObdbData) _buildObdbMetadataCard(_obdbData!.metadata),
        
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
                'Supported Extended PIDs: ${_supported.length}',
                style: const TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w600),
              ),
              if (hasObdbData)
                Text(
                  'OBDb PIDs available: ${_obdbData!.pids.length}',
                  style: const TextStyle(color: Colors.white54, fontSize: 12),
                ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        
        // Extended PIDs List
        if (_supported.isEmpty && hasObdbData)
          // Show all OBDb PIDs if ECU doesn't report support
          ..._obdbData!.pids.map((pid) => _buildPidCard(pid, isSupported: false))
        else
          // Show only supported PIDs with OBDb info if available
          ..._supported.map((pid) {
            final obdbPid = _pidMap[pid] ?? _pidMap[pid.toUpperCase()];
            if (obdbPid != null) {
              return _buildPidCard(obdbPid, isSupported: true);
            } else {
              // Fallback: show basic info if no OBDb data
              return _buildBasicPidCard(pid);
            }
          }),
      ],
    );
  }

  Widget _buildObdbMetadataCard(ObdbMetadata metadata) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.greenAccent.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.greenAccent.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.check_circle, color: Colors.greenAccent, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'OBDb Data: ${metadata.make} ${metadata.model}',
                  style: const TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w600),
                ),
                Text(
                  'Years: ${metadata.years} | Version: ${metadata.version}',
                  style: const TextStyle(color: Colors.white54, fontSize: 11),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPidCard(ObdbPid pid, {required bool isSupported}) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      color: Colors.white.withValues(alpha: 0.08),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: InkWell(
        onTap: () {
          // Show details dialog
          _showPidDetails(pid);
        },
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    isSupported ? Icons.extension : Icons.extension_outlined,
                    color: isSupported ? Colors.cyanAccent : Colors.white54,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      pid.name,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  if (isSupported)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.greenAccent.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Text(
                        'Supported',
                        style: TextStyle(color: Colors.greenAccent, fontSize: 10, fontWeight: FontWeight.w600),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  _buildInfoChip('PID', pid.pid, Colors.blueAccent),
                  const SizedBox(width: 6),
                  _buildInfoChip('Formula', pid.formula, Colors.orangeAccent),
                  const SizedBox(width: 6),
                  if (pid.unit.isNotEmpty)
                    _buildInfoChip('Unit', pid.unit, Colors.purpleAccent),
                ],
              ),
              if (pid.description != null && pid.description!.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  pid.description!,
                  style: const TextStyle(color: Colors.white54, fontSize: 12),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  if (_addedPids.contains(pid.pid))
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.greenAccent.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.greenAccent.withValues(alpha: 0.5)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.check_circle, size: 16, color: Colors.greenAccent),
                          const SizedBox(width: 6),
                          const Text(
                            'Added',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.greenAccent,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    )
                  else
                    TextButton.icon(
                      onPressed: () => _addToDashboard(pid),
                      icon: const Icon(Icons.add_circle_outline, size: 16),
                      label: const Text('Add to Dashboard', style: TextStyle(fontSize: 12)),
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.cyanAccent,
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBasicPidCard(String pid) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      color: Colors.white.withValues(alpha: 0.08),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: ListTile(
        leading: const Icon(Icons.extension, color: Colors.cyanAccent),
        title: Text('Extended PID $pid', style: const TextStyle(color: Colors.white)),
        subtitle: const Text(
          'Manufacturer/ECU-specific support reported via bitmap',
          style: TextStyle(color: Colors.white54, fontSize: 12),
        ),
      ),
    );
  }

  Widget _buildInfoChip(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        '$label: $value',
        style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w600),
      ),
    );
  }

  void _showPidDetails(ObdbPid pid) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1C1F2A),
        title: Text(
          pid.name,
          style: const TextStyle(color: Colors.white),
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildDetailRow('PID', pid.pid),
              _buildDetailRow('Mode', pid.mode),
              _buildDetailRow('Formula', pid.formula),
              if (pid.unit.isNotEmpty) _buildDetailRow('Unit', pid.unit),
              if (pid.category != null) _buildDetailRow('Category', pid.category!),
              if (pid.description != null && pid.description!.isNotEmpty) ...[
                const SizedBox(height: 12),
                const Text(
                  'Description:',
                  style: TextStyle(color: Colors.white70, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 4),
                Text(
                  pid.description!,
                  style: const TextStyle(color: Colors.white54),
                ),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.pop(context);
              _addToDashboard(pid);
            },
            icon: const Icon(Icons.add),
            label: const Text('Add to Dashboard'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.cyanAccent,
              foregroundColor: Colors.black,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              '$label:',
              style: const TextStyle(color: Colors.white70, fontWeight: FontWeight.w600),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTestVinButton(String label, String vin) {
    return ElevatedButton.icon(
      onPressed: () => _testWithVin(vin),
      icon: const Icon(Icons.flash_on, size: 16),
      label: Text(label, style: const TextStyle(fontSize: 11)),
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.blueAccent,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        minimumSize: const Size(0, 32),
      ),
    );
  }

  Future<void> _testWithVin(String vin) async {
    setState(() {
      _loading = true;
      _error = null;
      _obdbData = null;
      _pidMap = {};
    });

    try {
      // Decode VIN
      final vinData = await VinDecoderService.decodeVin(vin);
      if (vinData == null) {
        setState(() {
          _error = 'Failed to decode VIN. Please try another VIN.';
          _loading = false;
        });
        return;
      }

      final make = vinData['Make'] ?? '';
      final model = vinData['Model'] ?? '';
      final yearStr = vinData['Year'] ?? '';
      final year = yearStr.isNotEmpty ? int.tryParse(yearStr) : null;

      if (make.isEmpty || model.isEmpty) {
        setState(() {
          _error = 'VIN decoded but make/model not found. Try another VIN.';
          _loading = false;
        });
        return;
      }

      // Fetch OBDb data
      final obdbData = await ObdbService.fetchWithCache(
        make: make,
        model: model,
        year: year,
        forceRefresh: true,
      );

      // Create PID map
      final pidMap = <String, ObdbPid>{};
      if (obdbData != null) {
        for (final pid in obdbData.pids) {
          final pidHex = pid.pid.toUpperCase();
          pidMap[pidHex] = pid;
        }
      }

      setState(() {
        _obdbData = obdbData;
        _pidMap = pidMap;
        _loading = false;
        if (obdbData == null) {
          _error = 'No OBDb data found for $make $model.\n\n'
              'Possible reasons:\n'
              '• Vehicle not in OBDb database yet\n'
              '• Make/Model format mismatch\n'
              '• Check console logs for fetch URL\n\n'
              'Try: https://github.com/OBDb/${make.toLowerCase().replaceAll(' ', '-')}-${model.toLowerCase().replaceAll(' ', '-')}';
        }
      });
    } catch (e) {
      setState(() {
        _error = 'Error testing with VIN: ${e.toString()}';
        _loading = false;
      });
    }
  }

  Future<void> _showVehicleInfoDialog({bool autoShow = false}) async {
    final vehicle = ConnectionManager.instance.vehicle;
    String? selectedMake = vehicle?.make;
    String? selectedModel = vehicle?.model;
    int? selectedYear = vehicle?.year;
    
    final makeController = TextEditingController(text: selectedMake ?? '');
    final modelController = TextEditingController(text: selectedModel ?? '');
    final yearController = TextEditingController(text: selectedYear?.toString() ?? '');

    final result = await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => _VehicleInfoScreen(
          autoShow: autoShow,
          makeController: makeController,
          modelController: modelController,
          yearController: yearController,
          onConfirm: (make, model, year) {
            setState(() {
              _sessionMake = make;
              _sessionModel = model;
              _sessionYear = year;
            });
            _loadWithVehicleInfo(make: make, model: model, year: year);
          },
        ),
        fullscreenDialog: true,
      ),
    );
  }

  Future<void> _loadWithVehicleInfo({
    required String make,
    required String model,
    int? year,
  }) async {
    setState(() {
      _loading = true;
      _error = null;
      _obdbData = null;
      _pidMap = {};
    });

    try {
      // Fetch Extended PIDs với make/model/year đã chọn
      final obdbData = await ObdbService.fetchWithCache(
        make: make,
        model: model,
        year: year,
        forceRefresh: true,
      );

      // Create PID map
      final pidMap = <String, ObdbPid>{};
      if (obdbData != null) {
        for (final pid in obdbData.pids) {
          final pidHex = pid.pid.toUpperCase();
          pidMap[pidHex] = pid;
        }
      }

      setState(() {
        _obdbData = obdbData;
        _pidMap = pidMap;
        _loading = false;
        if (obdbData == null) {
          _error = 'No Extended PIDs data found for $make $model.\n\n'
              'This vehicle may not be in the database yet.';
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Loaded ${obdbData.pids.length} Extended PIDs for $make $model'),
              duration: const Duration(seconds: 2),
            ),
          );
        }
      });
    } catch (e) {
      setState(() {
        _error = 'Error loading Extended PIDs: ${e.toString()}';
        _loading = false;
      });
    }
  }

  void _addToDashboard(ObdbPid pid) async {
    try {
      // Save Extended PID to SharedPreferences for Dashboard to read
      final prefs = await SharedPreferences.getInstance();
      final savedPids = prefs.getStringList('custom_extended_pids') ?? [];
      
      // Check if already added
      if (savedPids.contains(pid.pid)) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${pid.name} (${pid.pid}) is already in dashboard'),
            duration: const Duration(seconds: 2),
          ),
        );
        return;
      }
      
      // Save PID info as JSON
      savedPids.add(pid.pid);
      await prefs.setStringList('custom_extended_pids', savedPids);
      
      // Also save full info for Dashboard to use (as JSON string)
      final pidData = {
        'pid': pid.pid,
        'name': pid.name,
        'formula': pid.formula,
        'unit': pid.unit,
        'mode': pid.mode,
        if (pid.min != null) 'min': pid.min,
        if (pid.max != null) 'max': pid.max,
        if (pid.description != null) 'description': pid.description,
        if (pid.category != null) 'category': pid.category,
      };
      
      await prefs.setString('extended_pid_data_${pid.pid}', jsonEncode(pidData));
      
      // Update added PIDs set
      setState(() {
        _addedPids.add(pid.pid);
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Added ${pid.name} (${pid.pid}) to dashboard'),
            duration: const Duration(seconds: 2),
            action: SnackBarAction(
              label: 'View',
              textColor: Colors.cyanAccent,
              onPressed: () {
                Navigator.of(context).pushNamed('/dashboard');
              },
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error adding PID: ${e.toString()}'),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }
  }
}

class _VehicleInfoScreen extends StatefulWidget {
  final bool autoShow;
  final TextEditingController makeController;
  final TextEditingController modelController;
  final TextEditingController yearController;
  final Function(String, String, int?) onConfirm;

  const _VehicleInfoScreen({
    required this.autoShow,
    required this.makeController,
    required this.modelController,
    required this.yearController,
    required this.onConfirm,
  });

  @override
  State<_VehicleInfoScreen> createState() => _VehicleInfoScreenState();
}

class _VehicleInfoScreenState extends State<_VehicleInfoScreen> {
  int _currentStep = 0;
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

  bool _canProceedToNext() {
    switch (_currentStep) {
      case 0:
        return widget.makeController.text.trim().isNotEmpty;
      case 1:
        return widget.modelController.text.trim().isNotEmpty;
      case 2:
        return true; // Year is optional
      default:
        return false;
    }
  }

  void _nextStep() {
    if (_currentStep < 2 && _canProceedToNext()) {
      setState(() {
        _currentStep++;
      });
    }
  }

  void _previousStep() {
    if (_currentStep > 0) {
      setState(() {
        _currentStep--;
      });
    }
  }

  void _confirm() {
    final make = widget.makeController.text.trim();
    final model = widget.modelController.text.trim();
    final yearStr = widget.yearController.text.trim();
    final year = yearStr.isNotEmpty ? int.tryParse(yearStr) : null;
    
    if (make.isEmpty || model.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter Make and Model'),
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }
    
    Navigator.pop(context);
    widget.onConfirm(make, model, year);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1C1F2A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1C1F2A),
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
            
            // Step indicator
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: Row(
                children: [
                  _buildStepIndicator(0, 'Make'),
                  Expanded(
                    child: Container(
                      height: 2,
                      margin: const EdgeInsets.symmetric(horizontal: 8),
                      decoration: BoxDecoration(
                        color: _currentStep > 0 
                            ? Colors.blueAccent 
                            : Colors.white.withValues(alpha: 0.2),
                      ),
                    ),
                  ),
                  _buildStepIndicator(1, 'Model'),
                  Expanded(
                    child: Container(
                      height: 2,
                      margin: const EdgeInsets.symmetric(horizontal: 8),
                      decoration: BoxDecoration(
                        color: _currentStep > 1 
                            ? Colors.blueAccent 
                            : Colors.white.withValues(alpha: 0.2),
                      ),
                    ),
                  ),
                  _buildStepIndicator(2, 'Year'),
                ],
              ),
            ),
            
          // Content
          Expanded(
            child: _currentStep == 0
                ? Padding(
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
                              borderSide: const BorderSide(color: Colors.blueAccent, width: 2),
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
                              return InkWell(
                                onTap: () {
                                  widget.makeController.text = make;
                                  setState(() {});
                                },
                                child: Container(
                                  margin: const EdgeInsets.only(bottom: 8),
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                                  decoration: BoxDecoration(
                                    color: isSelected
                                        ? Colors.blueAccent.withValues(alpha: 0.2)
                                        : Colors.white.withValues(alpha: 0.05),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: isSelected
                                          ? Colors.blueAccent
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
                                        const Icon(Icons.check_circle, color: Colors.blueAccent, size: 24),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  )
                : SingleChildScrollView(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                    if (_currentStep == 1) ...[
                      const Text(
                        'Enter vehicle model:',
                        style: TextStyle(color: Colors.white70, fontSize: 16),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: widget.modelController,
                        style: const TextStyle(color: Colors.white, fontSize: 16),
                        onChanged: (_) => setState(() {}), // Update to enable Next button
                        decoration: InputDecoration(
                          labelText: 'Model *',
                          labelStyle: const TextStyle(color: Colors.white70),
                          hintText: 'e.g., Camry, Civic, F-150',
                          hintStyle: const TextStyle(color: Colors.white38),
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
                            borderSide: const BorderSide(color: Colors.blueAccent, width: 2),
                          ),
                        ),
                      ),
                    ],
                    if (_currentStep == 2) ...[
                      const Text(
                        'Enter vehicle year (optional):',
                        style: TextStyle(color: Colors.white70, fontSize: 16),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: widget.yearController,
                        style: const TextStyle(color: Colors.white, fontSize: 16),
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          labelText: 'Year (Optional)',
                          labelStyle: const TextStyle(color: Colors.white70),
                          hintText: 'e.g., 2024',
                          hintStyle: const TextStyle(color: Colors.white38),
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
                            borderSide: const BorderSide(color: Colors.blueAccent, width: 2),
                          ),
                        ),
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                          LengthLimitingTextInputFormatter(4),
                        ],
                      ),
                    ],
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
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  if (_currentStep > 0)
                    TextButton(
                      onPressed: _previousStep,
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      ),
                      child: const Text('Previous', style: TextStyle(color: Colors.white70, fontSize: 16)),
                    )
                  else
                    const SizedBox(width: 80),
                  Row(
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
                      if (_currentStep < 2)
                        ElevatedButton(
                          onPressed: _canProceedToNext() ? _nextStep : null,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blueAccent,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
                            disabledBackgroundColor: Colors.blueAccent.withValues(alpha: 0.3),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: const Text('Next', style: TextStyle(fontSize: 16)),
                        )
                      else
                        ElevatedButton(
                          onPressed: _confirm,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.greenAccent,
                            foregroundColor: Colors.black87,
                            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: const Text('Confirm', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStepIndicator(int step, String label) {
    final isActive = _currentStep == step;
    final isCompleted = _currentStep > step;
    
    return Column(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isActive || isCompleted
                ? Colors.blueAccent
                : Colors.white.withValues(alpha: 0.2),
            border: Border.all(
              color: isActive ? Colors.blueAccent : Colors.white.withValues(alpha: 0.3),
              width: 2,
            ),
          ),
          child: Center(
            child: isCompleted
                ? const Icon(Icons.check, color: Colors.white, size: 20)
                : Text(
                    '${step + 1}',
                    style: TextStyle(
                      color: isActive ? Colors.white : Colors.white70,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: TextStyle(
            color: isActive ? Colors.white : Colors.white54,
            fontSize: 12,
            fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
      ],
    );
  }
}
