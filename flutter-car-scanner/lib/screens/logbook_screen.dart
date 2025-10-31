import 'package:flutter/material.dart';
import 'package:flutter_car_scanner/services/log_service.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'dart:io';

class LogbookScreen extends StatefulWidget {
  const LogbookScreen({super.key});

  @override
  State<LogbookScreen> createState() => _LogbookScreenState();
}

class _LogbookScreenState extends State<LogbookScreen> {
  @override
  void initState() {
    super.initState();
    LogService.init();
  }

  @override
  Widget build(BuildContext context) {
    final entries = LogService.all();
    return Scaffold(
      appBar: AppBar(
        title: const Text('Logbook'),
        backgroundColor: const Color(0xFF2ECC71),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.ios_share),
            onPressed: entries.isEmpty ? null : () async {
              final file = await _exportCsv(entries);
              if (file != null) {
                await Share.shareXFiles([XFile(file.path)], text: 'OBD Logbook');
              }
            },
            tooltip: 'Export CSV',
          ),
          IconButton(
            icon: const Icon(Icons.delete_sweep),
            onPressed: () async {
              await LogService.clear();
              setState(() {});
            },
            tooltip: 'Clear',
          ),
        ],
      ),
      body: entries.isEmpty
          ? const Center(child: Text('No logs'))
          : ListView.separated(
              itemCount: entries.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final e = entries[index];
                final type = (e['type'] ?? '').toString();
                final ts = (e['ts'] ?? '').toString();
                final subtitle = _subtitleFor(e);
                final icon = _iconFor(type);
                return ListTile(
                  leading: Icon(icon, color: Colors.white70),
                  title: Text(type),
                  subtitle: Text(subtitle, style: const TextStyle(color: Colors.white60)),
                  trailing: Text(ts.split('T').join(' '), style: const TextStyle(fontSize: 12, color: Colors.white54)),
                );
              },
            ),
    );
  }

  IconData _iconFor(String type) {
    switch (type) {
      case 'read_codes': return Icons.bug_report;
      case 'clear_codes': return Icons.cleaning_services;
      case 'freeze_frame': return Icons.save_alt;
      case 'mode06': return Icons.analytics;
      default: return Icons.event_note;
    }
  }

  String _subtitleFor(Map<String, dynamic> e) {
    final type = (e['type'] ?? '').toString();
    if (type == 'read_codes') {
      final mil = e['mil'] == true ? 'MIL ON' : 'MIL OFF';
      final stored = e['storedCount'] ?? 0;
      final dtcs = (e['dtcs'] as List?)?.join(', ') ?? '';
      return '$mil • Stored: $stored${dtcs.isNotEmpty ? ' • $dtcs' : ''}';
    }
    if (type == 'clear_codes') {
      final mil = e['mil'] == true ? 'MIL ON' : 'MIL OFF';
      final stored = e['storedCount'] ?? 0;
      return 'After clear → $mil • Stored: $stored';
    }
    if (type == 'freeze_frame') {
      final rpm = e['ff']?['010C'];
      final spd = e['ff']?['010D'];
      return 'RPM: ${rpm ?? '-'} • Speed: ${spd ?? '-'}';
    }
    if (type == 'mode06') {
      final pass = e['passCount'] ?? 0;
      final total = e['total'] ?? 0;
      return 'PASS: $pass / $total';
    }
    return '';
  }

  Future<File?> _exportCsv(List<Map<String, dynamic>> entries) async {
    try {
      final buffer = StringBuffer();
      // Header
      buffer.writeln('timestamp,type,mil,storedCount,dtcs');
      for (final e in entries.reversed) {
        final ts = (e['ts'] ?? '').toString();
        final type = (e['type'] ?? '').toString();
        final mil = e['mil'] == true ? 'ON' : (e.containsKey('mil') ? 'OFF' : '');
        final stored = (e['storedCount'] ?? '').toString();
        final dtcs = (e['dtcs'] is List) ? (e['dtcs'] as List).join('|') : '';
        buffer.writeln(_csv([ts, type, mil, stored, dtcs]));
      }
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/obd_logbook.csv');
      await file.writeAsString(buffer.toString());
      return file;
    } catch (_) {
      return null;
    }
  }

  String _csv(List<String> cols) {
    return cols.map((v) {
      final s = v.replaceAll('"', '""');
      return '"$s"';
    }).join(',');
  }
}


