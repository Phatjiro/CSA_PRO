import 'package:flutter/material.dart';
import 'package:flutter_car_scanner/services/connection_manager.dart';
import 'package:flutter_car_scanner/services/obd_client.dart';

class ClearCodesScreen extends StatefulWidget {
  const ClearCodesScreen({super.key});

  @override
  State<ClearCodesScreen> createState() => _ClearCodesScreenState();
}

class _ClearCodesScreenState extends State<ClearCodesScreen> {
  ObdClient? _client;
  bool _loading = false;
  bool _milOn = false;
  int _storedCount = 0;
  String? _error;

  @override
  void initState() {
    super.initState();
    _client = ConnectionManager.instance.client;
    _refreshMil();
  }

  Future<void> _refreshMil() async {
    if (_client == null) {
      setState(() => _error = 'Not connected. Please CONNECT first.');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final mil = await _client!.readMilAndCount();
      if (!mounted) return;
      setState(() {
        _milOn = mil.$1;
        _storedCount = mil.$2;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Error fetching MIL: ${e.toString()}';
        _loading = false;
      });
    }
  }

  Future<void> _clear() async {
    if (_client == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Not connected. Please CONNECT first.')),
      );
      return;
    }

    final ok = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Clear Trouble Codes?'),
            content: const Text(
              'This will clear stored and pending DTCs, turn off MIL, and reset readiness. Permanent DTCs remain.',
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
              ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Clear')),
            ],
          ),
        ) ??
        false;
    if (!ok) return;

    setState(() => _loading = true);
    try {
      await _client!.clearDtc();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('DTCs cleared successfully')),
      );
      await _refreshMil();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Error clearing DTC: ${e.toString()}';
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Clear Codes'),
        backgroundColor: const Color(0xFF1E88E5),
        foregroundColor: Colors.white,
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _loading ? null : _refreshMil),
        ],
      ),
      body: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            color: Colors.white.withValues(alpha: 0.04),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Text('MIL:', style: TextStyle(fontWeight: FontWeight.w700)),
                    const SizedBox(width: 8),
                    Text(
                      _milOn ? 'ON' : 'OFF',
                      style: TextStyle(
                        color: _milOn ? Colors.redAccent : Colors.greenAccent,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                Text('Stored: $_storedCount'),
              ],
            ),
          ),
          if (_loading) const LinearProgressIndicator(minHeight: 2),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(_error!, style: const TextStyle(color: Colors.redAccent)),
            ),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Text(
                'Clearing codes will reset readiness monitors. It might take a drive cycle to complete monitors again.',
                style: TextStyle(color: Colors.white70),
              ),
            ),
          ),
          const SizedBox(height: 20),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _loading ? null : _clear,
                icon: const Icon(Icons.cleaning_services),
                label: const Text('Clear Trouble Codes'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}


