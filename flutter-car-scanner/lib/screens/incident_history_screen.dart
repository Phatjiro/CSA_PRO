import 'package:flutter/material.dart';
import 'package:flutter_car_scanner/services/connection_manager.dart';
import 'package:flutter_car_scanner/services/vin_decoder_service.dart';

class IncidentHistoryScreen extends StatefulWidget {
  const IncidentHistoryScreen({super.key});

  @override
  State<IncidentHistoryScreen> createState() => _IncidentHistoryScreenState();
}

class _IncidentHistoryScreenState extends State<IncidentHistoryScreen> {
  bool _loading = false;
  bool _decodingVin = false;
  String? _error;
  Map<String, String>? _vinDecoded;
  String? _currentVin;

  @override
  void initState() {
    super.initState();
    _loadVin();
  }

  void _loadVin() {
    final vehicle = ConnectionManager.instance.vehicle;
    if (vehicle?.vin != null && vehicle!.vin!.isNotEmpty) {
      _currentVin = vehicle.vin;
      _decodeVin(vehicle.vin!);
    } else {
      // Try to get VIN from connection
      _getVinFromConnection();
    }
  }

  Future<void> _getVinFromConnection() async {
    final client = ConnectionManager.instance.client;
    if (client == null) return;

    try {
      final vin = await client.readVin();
      if (vin != null && vin.isNotEmpty && vin != '-') {
        setState(() {
          _currentVin = vin;
        });
        _decodeVin(vin);
      }
    } catch (_) {
      // Silent fail
    }
  }

  Future<void> _decodeVin(String vin) async {
    if (vin.isEmpty || vin == '-') return;

    setState(() {
      _decodingVin = true;
      _error = null;
      _vinDecoded = null;
    });

    try {
      final decoded = await VinDecoderService.decodeVin(vin);
      setState(() {
        _vinDecoded = decoded;
        _decodingVin = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Failed to decode VIN: ${e.toString()}';
        _decodingVin = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Incident History'),
        backgroundColor: const Color(0xFF7D3C98),
        foregroundColor: Colors.white,
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
        children: [
          // Info banner about Carfax
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.blue.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.blue.withOpacity(0.3)),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline, color: Colors.blue.shade300, size: 20),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'For detailed accident history, title records, and service history, please use Carfax or similar paid services.',
                    style: TextStyle(fontSize: 12, color: Colors.white.withOpacity(0.9)),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // VIN Section
          if (_currentVin != null && _currentVin!.isNotEmpty && _currentVin != '-') ...[
            _sectionTitle('VIN'),
            _tile('VIN', _currentVin!),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (_decodingVin)
                  const Padding(
                    padding: EdgeInsets.all(8.0),
                    child: SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  )
                else
                  TextButton.icon(
                    icon: const Icon(Icons.search, size: 16),
                    label: const Text('Decode VIN'),
                    onPressed: () => _decodeVin(_currentVin!),
                  ),
              ],
            ),
            const SizedBox(height: 16),
          ] else
            Container(
              padding: const EdgeInsets.all(16),
              child: Center(
                child: Column(
                  children: [
                    Icon(Icons.info_outline, size: 48, color: Colors.white.withOpacity(0.5)),
                    const SizedBox(height: 8),
                    Text(
                      'No VIN available',
                      style: TextStyle(color: Colors.white.withOpacity(0.7)),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Connect to vehicle to read VIN automatically',
                      style: TextStyle(fontSize: 12, color: Colors.white.withOpacity(0.5)),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),

          // VIN Decoded Information
          if (_vinDecoded != null) ...[
            const SizedBox(height: 8),
            _sectionTitle('Vehicle Information'),
            for (final entry in _vinDecoded!.entries)
              _tile(entry.key, entry.value),
            const SizedBox(height: 16),
          ],

          // Error message
          if (_error != null)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                _error!,
                style: TextStyle(color: Colors.red.shade300, fontSize: 12),
              ),
            ),

          // Note about limitations
          const SizedBox(height: 24),
          _sectionTitle('Available Information'),
          _infoTile(
            'Vehicle Specifications',
            'Make, Model, Year, Engine, Body Type, Drive Type, Fuel Type, Transmission',
            Icons.check_circle,
            Colors.green,
          ),
          const SizedBox(height: 12),
          _sectionTitle('Not Available (Requires Paid Service)'),
          _infoTile(
            'Accident History',
            'Carfax or AutoCheck required (\$0.50-\$2 per report)',
            Icons.remove_circle,
            Colors.orange,
          ),
          _infoTile(
            'Title Brand Information',
            'Salvage, Rebuilt, Flood damage records',
            Icons.remove_circle,
            Colors.orange,
          ),
          _infoTile(
            'Service Records',
            'Maintenance and repair history',
            Icons.remove_circle,
            Colors.orange,
          ),
          _infoTile(
            'Insurance Claims',
            'Claims history from insurance databases',
            Icons.remove_circle,
            Colors.orange,
          ),
          _infoTile(
            'Market Value',
            'KBB or Edmunds valuation data',
            Icons.remove_circle,
            Colors.orange,
          ),
        ],
        ),
      ),
    );
  }

  Widget _sectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, top: 8),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w700,
          color: Colors.white,
        ),
      ),
    );
  }

  Widget _tile(String title, String value) {
    return Container(
      margin: const EdgeInsets.only(bottom: 4),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            title,
            style: TextStyle(color: Colors.white.withOpacity(0.7)),
          ),
          Text(
            value,
            style: const TextStyle(
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _infoTile(String title, String description, IconData icon, Color color) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: color),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.white.withOpacity(0.6),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

