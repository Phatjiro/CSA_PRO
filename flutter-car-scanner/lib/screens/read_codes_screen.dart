import 'package:flutter/material.dart';
import 'package:flutter_car_scanner/services/obd_client.dart';
import 'package:flutter_car_scanner/services/connection_manager.dart';
import 'package:flutter_car_scanner/utils/dtc_helper.dart';

class ReadCodesScreen extends StatefulWidget {
  const ReadCodesScreen({super.key});
  @override
  State<ReadCodesScreen> createState() => _ReadCodesScreenState();
}

class _ReadCodesScreenState extends State<ReadCodesScreen> with SingleTickerProviderStateMixin {
  ObdClient? _client;
  late final TabController _tab;
  bool _loading = false;
  bool _milOn = false;
  int _count = 0;
  List<String> _stored = [];
  List<String> _pending = [];
  List<String> _permanent = [];
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _client = ConnectionManager.instance.client;
    _tab = TabController(length: 3, vsync: this);
    if (_client != null) {
      _refreshAll();
    } else {
      _errorMessage = 'Not connected. Please CONNECT first.';
    }
  }

  Future<void> _refreshAll() async {
    if (_client == null) {
      setState(() {
        _errorMessage = 'Not connected. Please CONNECT first.';
      });
      return;
    }
    setState(() {
      _loading = true;
      _errorMessage = null;
    });
    try {
      final mil = await _client!.readMilAndCount();
      final stored = await _client!.readStoredDtc();
      final pending = await _client!.readPendingDtc();
      final permanent = await _client!.readPermanentDtc();
      if (mounted) {
        setState(() {
          _milOn = mil.$1;
          _count = mil.$2;
          _stored = stored;
          _pending = pending;
          _permanent = permanent;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Error reading DTC: ${e.toString()}';
          _loading = false;
        });
      }
    }
  }

  Future<void> _clear() async {
    if (_client == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Not connected. Please CONNECT first.')),
      );
      return;
    }
    final ok = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(
      title: const Text('Clear DTCs?'),
      content: const Text('This will turn off MIL (if no codes reappear) and reset readiness.'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
        ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Clear')),
      ],
    )) ?? false;
    if (!ok) return;
    setState(() {
      _loading = true;
      _errorMessage = null;
    });
    try {
      await _client!.clearDtc();
      await _refreshAll();
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Error clearing DTC: ${e.toString()}';
          _loading = false;
        });
      }
    }
  }

  @override
  void dispose() { _tab.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Read Codes'),
        backgroundColor: const Color(0xFF1E88E5), // Blue - matches Basic Diagnostics group
        foregroundColor: Colors.white,
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _loading ? null : _refreshAll),
          TextButton(onPressed: _loading ? null : _clear, child: const Text('Clear', style: TextStyle(color: Colors.white)))
        ],
      ),
      body: Column(
        children: [
          // Move TabBar out of AppBar so tabs are not inside the blue header
          Container(
            color: Colors.transparent,
            child: TabBar(
              controller: _tab,
              tabs: const [
                Tab(text: 'Stored'),
                Tab(text: 'Pending'),
                Tab(text: 'Permanent'),
              ],
              labelColor: Colors.white,
              unselectedLabelColor: Colors.white70,
              indicatorColor: Colors.white,
            ),
          ),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            color: Colors.white.withOpacity(0.04),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('MIL: ${_milOn ? 'ON' : 'OFF'}'),
                Text('Stored count: $_count'),
              ],
            ),
          ),
          if (_errorMessage != null)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              margin: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.2),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.redAccent, width: 1),
              ),
              child: Row(
                children: [
                  const Icon(Icons.error_outline, color: Colors.redAccent),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      _errorMessage!,
                      style: const TextStyle(color: Colors.white),
                    ),
                  ),
                ],
              ),
            ),
          Expanded(
            child: _errorMessage != null && _client == null
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.wifi_off, size: 64, color: Colors.white54),
                        const SizedBox(height: 16),
                        const Text(
                          'Not connected',
                          style: TextStyle(color: Colors.white70, fontSize: 18),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Please CONNECT before using this feature',
                          style: TextStyle(color: Colors.white54, fontSize: 14),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  )
                : TabBarView(
                    controller: _tab,
                    children: [
                      _buildList(_stored, 'Stored'),
                      _buildList(_pending, 'Pending'),
                      _buildList(_permanent, 'Permanent'),
                    ],
                  ),
          )
        ],
      ),
    );
  }

  Widget _buildList(List<String> codes, String type) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (codes.isEmpty) {
      return Center(child: Text('NO DATA ($type)', style: const TextStyle(color: Colors.white54)));
    }
    return ListView.builder(
      itemCount: codes.length,
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemBuilder: (context, index) {
        final dtcCode = codes[index];
        final description = DtcHelper.getDescription(dtcCode);
        final howToRead = DtcHelper.getHowToRead(dtcCode);
        
        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          color: Colors.white.withOpacity(0.08),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () => DtcHelper.searchOnGoogle(dtcCode),
              borderRadius: BorderRadius.circular(12),
              splashColor: Colors.white.withOpacity(0.1),
              highlightColor: Colors.white.withOpacity(0.05),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.error_outline, color: Colors.redAccent, size: 28),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Text(
                                  dtcCode,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 18,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                              const Icon(Icons.search, color: Colors.white54, size: 20),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(
                            description,
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            howToRead,
                            style: TextStyle(
                              color: Colors.white54,
                              fontSize: 12,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              Icon(Icons.info_outline, size: 14, color: Colors.white54),
                              const SizedBox(width: 4),
                              Text(
                                'Tap to search on Google',
                                style: TextStyle(
                                  color: Colors.white54,
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
