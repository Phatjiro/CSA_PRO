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
  late final ObdClient _client;
  late final TabController _tab;
  bool _loading = false;
  bool _milOn = false;
  int _count = 0;
  List<String> _stored = [];
  List<String> _pending = [];
  List<String> _permanent = [];

  @override
  void initState() {
    super.initState();
    _client = ConnectionManager.instance.client!;
    _tab = TabController(length: 3, vsync: this);
    _refreshAll();
  }

  Future<void> _refreshAll() async {
    setState(() => _loading = true);
    try {
      final mil = await _client.readMilAndCount();
      final stored = await _client.readStoredDtc();
      final pending = await _client.readPendingDtc();
      final permanent = await _client.readPermanentDtc();
      setState(() {
        _milOn = mil.$1;
        _count = mil.$2;
        _stored = stored;
        _pending = pending;
        _permanent = permanent;
      });
    } catch (_) {}
    setState(() => _loading = false);
  }

  Future<void> _clear() async {
    final ok = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(
      title: const Text('Clear DTCs?'),
      content: const Text('This will turn off MIL (if no codes reappear) and reset readiness.'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
        ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Clear')),
      ],
    )) ?? false;
    if (!ok) return;
    setState(() => _loading = true);
    try { await _client.clearDtc(); } catch (_) {}
    await _refreshAll();
  }

  @override
  void dispose() { _tab.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Read Codes'),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _loading ? null : _refreshAll),
          TextButton(onPressed: _loading ? null : _clear, child: const Text('Clear', style: TextStyle(color: Colors.white)))
        ],
        bottom: TabBar(
          controller: _tab,
          tabs: const [
            Tab(text: 'Stored'),
            Tab(text: 'Pending'),
            Tab(text: 'Permanent'),
          ],
        ),
      ),
      body: Column(
        children: [
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
          Expanded(
            child: TabBarView(
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
    return ListView.separated(
      itemCount: codes.length,
      separatorBuilder: (_, __) => const Divider(height: 1, color: Colors.white12),
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemBuilder: (context, index) {
        final dtcCode = codes[index];
        final description = DtcHelper.getDescription(dtcCode);
        final howToRead = DtcHelper.getHowToRead(dtcCode);
        
        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          color: Colors.white.withOpacity(0.08),
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            leading: const Icon(Icons.error_outline, color: Colors.redAccent, size: 28),
            title: Text(
              dtcCode,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 18,
                color: Colors.white,
              ),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 4),
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
                const SizedBox(height: 4),
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
            onTap: () => DtcHelper.searchOnGoogle(dtcCode),
            trailing: const Icon(Icons.search, color: Colors.white54),
          ),
        );
      },
    );
  }
}
