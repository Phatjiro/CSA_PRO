import 'package:flutter/material.dart';
import 'package:flutter_car_scanner/services/connection_manager.dart';
import 'package:flutter_car_scanner/services/obd_client.dart';
import 'package:flutter_car_scanner/services/log_service.dart';

class FreezeFrameScreen extends StatefulWidget {
  const FreezeFrameScreen({super.key});

  @override
  State<FreezeFrameScreen> createState() => _FreezeFrameScreenState();
}

class _FreezeFrameScreenState extends State<FreezeFrameScreen> {
  ObdClient? _client;
  bool _loading = false;
  String? _error;
  bool _hasSnapshot = false;

  int? rpm;
  int? speed;
  int? ect;
  int? iat;
  int? maf;
  int? throttle;

  @override
  void initState() {
    super.initState();
    _client = ConnectionManager.instance.client;
    _refresh();
  }

  Future<void> _refresh() async {
    if (_client == null) {
      setState(() => _error = 'Not connected. Please CONNECT first.');
      return;
    }
    setState(() { _loading = true; _error = null; });
    try {
      // Mode 02: replace 42 -> 41 to reuse decoders
      final raw020C = await _client!.requestPid('020C');
      final raw020D = await _client!.requestPid('020D');
      final raw0205 = await _client!.requestPid('0205');
      final raw020F = await _client!.requestPid('020F');
      final raw0210 = await _client!.requestPid('0210');
      final raw0211 = await _client!.requestPid('0211');

      // Detect snapshot existence
      final allRaw = [raw020C, raw020D, raw0205, raw020F, raw0210, raw0211];
      final anyHasData = allRaw.any((s) {
        final t = s.trim().toUpperCase();
        return t.contains('42') && !t.contains('NO DATA');
      });

      final r020C = raw020C.replaceAll('42 0C', '41 0C').replaceAll('420C', '410C');
      final r020D = raw020D.replaceAll('42 0D', '41 0D').replaceAll('420D', '410D');
      final r0205 = raw0205.replaceAll('42 05', '41 05').replaceAll('4205', '4105');
      final r020F = raw020F.replaceAll('42 0F', '41 0F').replaceAll('420F', '410F');
      final r0210 = raw0210.replaceAll('42 10', '41 10').replaceAll('4210', '4110');
      final r0211 = raw0211.replaceAll('42 11', '41 11').replaceAll('4211', '4111');

      setState(() {
        rpm = _parseRpm(r020C);
        speed = _parseSpeed(r020D);
        ect = _parseCoolantTemp(r0205);
        iat = _parseIntakeTemp(r020F);
        maf = _parseMaf(r0210);
        throttle = _parseThrottle(r0211);
        _hasSnapshot = anyHasData;
        _loading = false;
      });
      if (anyHasData) {
        await LogService.add({
          'type': 'freeze_frame',
          'ff': {
            '010C': rpm,
            '010D': speed,
            '0105': ect,
            '010F': iat,
            '0110': maf,
            '0111': throttle,
          }
        });
      }
    } catch (e) {
      setState(() { _error = 'Error reading Freeze Frame: ${e.toString()}'; _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Freeze Frame'),
        backgroundColor: const Color(0xFF1E88E5),
        foregroundColor: Colors.white,
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _loading ? null : _refresh),
        ],
      ),
      body: Column(
        children: [
          if (_loading) const LinearProgressIndicator(minHeight: 2),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(_error!, style: const TextStyle(color: Colors.redAccent)),
            ),
          Expanded(
            child: _hasSnapshot
                ? GridView(
                    padding: const EdgeInsets.all(16),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      childAspectRatio: 1.6,
                      mainAxisSpacing: 10,
                      crossAxisSpacing: 10,
                    ),
                    children: [
                      _metric('RPM', rpm, unit: 'rpm'),
                      _metric('Speed', speed, unit: 'km/h'),
                      _metric('Coolant Temp', ect, unit: '°C'),
                      _metric('Intake Temp', iat, unit: '°C'),
                      _metric('MAF', maf, unit: 'g/s'),
                      _metric('Throttle', throttle, unit: '%'),
                    ],
                  )
                : Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: const [
                        Icon(Icons.image_not_supported, size: 48, color: Colors.white54),
                        SizedBox(height: 12),
                        Text('No Freeze Frame snapshot', style: TextStyle(color: Colors.white70)),
                        SizedBox(height: 6),
                        Text('Trigger a DTC or use emulator to capture one', style: TextStyle(color: Colors.white54, fontSize: 12)),
                      ],
                    ),
                  ),
          ),
          SafeArea(
            top: false,
            minimum: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: Text(
              'Freeze Frame is a snapshot of key sensor values at the moment a DTC was set. Use it to understand context (load, temp, speed) when the fault occurred.',
              style: const TextStyle(color: Colors.white70),
              textAlign: TextAlign.center,
            ),
          )
        ],
      ),
    );
  }

  Widget _metric(String title, int? value, {String? unit}) {
    return Card(
      color: Colors.white.withOpacity(0.08),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              value == null ? '—' : value.toString(),
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            Text(
              title + (unit != null ? ' ($unit)' : ''),
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white70),
            ),
          ],
        ),
      ),
    );
  }
}

// Local parsers for Mode 01-like responses (after 42→41 normalization)
int _parseRpm(String response) {
  final cleaned = response.replaceAll(RegExp(r"\s+"), '');
  final i41 = cleaned.indexOf('410C');
  final i42 = cleaned.indexOf('420C');
  final i = i41 >= 0 ? i41 : i42;
  if (i >= 0 && cleaned.length >= i + 8) {
    final a = int.parse(cleaned.substring(i + 4, i + 6), radix: 16);
    final b = int.parse(cleaned.substring(i + 6, i + 8), radix: 16);
    return ((256 * a + b) ~/ 4);
  }
  return 0;
}

int _parseSpeed(String response) {
  final cleaned = response.replaceAll(RegExp(r"\s+"), '');
  final i41 = cleaned.indexOf('410D');
  final i42 = cleaned.indexOf('420D');
  final i = i41 >= 0 ? i41 : i42;
  if (i >= 0 && cleaned.length >= i + 6) {
    return int.parse(cleaned.substring(i + 4, i + 6), radix: 16);
  }
  return 0;
}

int _parseCoolantTemp(String response) {
  final cleaned = response.replaceAll(RegExp(r"\s+"), '');
  final i41 = cleaned.indexOf('4105');
  final i42 = cleaned.indexOf('4205');
  final i = i41 >= 0 ? i41 : i42;
  if (i >= 0 && cleaned.length >= i + 6) {
    final v = int.parse(cleaned.substring(i + 4, i + 6), radix: 16);
    return v - 40;
  }
  return 0;
}

int _parseIntakeTemp(String response) {
  final cleaned = response.replaceAll(RegExp(r"\s+"), '');
  final i41 = cleaned.indexOf('410F');
  final i42 = cleaned.indexOf('420F');
  final i = i41 >= 0 ? i41 : i42;
  if (i >= 0 && cleaned.length >= i + 6) {
    final v = int.parse(cleaned.substring(i + 4, i + 6), radix: 16);
    return v - 40;
  }
  return 0;
}

int _parseThrottle(String response) {
  final cleaned = response.replaceAll(RegExp(r"\s+"), '');
  final i41 = cleaned.indexOf('4111');
  final i42 = cleaned.indexOf('4211');
  final i = i41 >= 0 ? i41 : i42;
  if (i >= 0 && cleaned.length >= i + 6) {
    final v = int.parse(cleaned.substring(i + 4, i + 6), radix: 16);
    return ((v * 100) / 255).round();
  }
  return 0;
}

int _parseMaf(String response) {
  final cleaned = response.replaceAll(RegExp(r"\s+"), '');
  final i41 = cleaned.indexOf('4110');
  final i42 = cleaned.indexOf('4210');
  final i = i41 >= 0 ? i41 : i42;
  if (i >= 0 && cleaned.length >= i + 8) {
    final a = int.parse(cleaned.substring(i + 4, i + 6), radix: 16);
    final b = int.parse(cleaned.substring(i + 6, i + 8), radix: 16);
    return ((256 * a + b) / 100).round();
  }
  return 0;
}


