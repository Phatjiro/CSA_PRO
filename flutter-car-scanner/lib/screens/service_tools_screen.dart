import 'package:flutter/material.dart';
import 'package:flutter_car_scanner/services/connection_manager.dart';
import 'package:flutter_car_scanner/services/obd_client.dart';
import 'maintenance_list_screen.dart';

class ServiceToolsScreen extends StatefulWidget {
  const ServiceToolsScreen({super.key});

  @override
  State<ServiceToolsScreen> createState() => _ServiceToolsScreenState();
}

class _ServiceToolsScreenState extends State<ServiceToolsScreen> {
  bool _clearing = false;
  String? _message;

  bool get _isConnected => ConnectionManager.instance.client != null;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Service Tools'),
        backgroundColor: const Color(0xFFF39C12),
        foregroundColor: Colors.white,
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _buildDisclaimer(),
            const SizedBox(height: 16),
            _sectionTitle('Quick Actions'),
            _quickActions(),
            const SizedBox(height: 16),
            _sectionTitle('Guides & Information'),
            _guideCard(
              title: 'Oil Service Reset',
              bullets: [
                'Most vehicles require manufacturer-specific tools/menus',
                'This app can track oil changes via Maintenance Log',
                'For ECU reset, refer to manufacturer procedure',
              ],
              color: Colors.orangeAccent,
            ),
            _guideCard(
              title: 'TPMS Reset',
              bullets: [
                'Many cars reset via in-dash menu (after tire fill/rotation)',
                'Some require driving for a few minutes at speed',
                'Manufacturer-specific tools needed for direct sensor programming',
              ],
              color: Colors.blueAccent,
            ),
            _guideCard(
              title: 'Brake Pad Wear Reset',
              bullets: [
                'Often requires service menu or manufacturer scanner',
                'Replace wear sensor if applicable',
                'This app does not perform ECU resets',
              ],
              color: Colors.cyanAccent,
            ),
            _guideCard(
              title: 'DPF Regeneration',
              bullets: [
                'Active regen usually triggered automatically by ECU',
                'Forced regen requires manufacturer-specific tool',
                'Not supported in this app to ensure safety',
              ],
              color: Colors.purpleAccent,
            ),
            _guideCard(
              title: 'Battery Registration',
              bullets: [
                'Some brands (BMW/Audi) require registration via factory tool',
                'This app cannot perform registration',
                'Use dealer or specialized scanner',
              ],
              color: Colors.redAccent,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDisclaimer() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.06),
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Text(
        'Important: Service resets are manufacturer-specific and often require special tools. This section provides safe, basic actions and guidance. It does not perform ECU write operations.',
        style: TextStyle(color: Colors.white70, fontSize: 12),
      ),
    );
  }

  Widget _quickActions() {
    return Column(
      children: [
        Card(
          color: Colors.white.withOpacity(0.08),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: ListTile(
            leading: const Icon(Icons.fact_check, color: Colors.greenAccent),
            title: const Text('Open Maintenance Log', style: TextStyle(color: Colors.white)),
            subtitle: const Text('Track oil changes and scheduled services', style: TextStyle(color: Colors.white54, fontSize: 12)),
            trailing: const Icon(Icons.chevron_right, color: Colors.white54),
            onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const MaintenanceListScreen())),
          ),
        ),
        const SizedBox(height: 8),
        Card(
          color: Colors.white.withOpacity(0.08),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: ListTile(
            leading: const Icon(Icons.delete_sweep, color: Colors.orangeAccent),
            title: const Text('Clear DTC (Mode 04)', style: TextStyle(color: Colors.white)),
            subtitle: const Text('Turn off MIL after fixing issues (may reset readiness)', style: TextStyle(color: Colors.white54, fontSize: 12)),
            trailing: _clearing
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.play_arrow, color: Colors.white54),
            onTap: _clearing ? null : _confirmClearDtc,
          ),
        ),
        if (_message != null) ...[
          const SizedBox(height: 8),
          Text(_message!, style: const TextStyle(color: Colors.white70, fontSize: 12)),
        ]
      ],
    );
  }

  Future<void> _confirmClearDtc() async {
    if (!_isConnected) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Not connected. Please CONNECT first.')),
      );
      return;
    }
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm Clear DTC'),
        content: const Text('This will clear stored and pending DTCs and may reset readiness monitors. Proceed?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Clear')),
        ],
      ),
    );
    if (ok != true) return;

    try {
      setState(() {
        _clearing = true;
        _message = null;
      });
      final client = ConnectionManager.instance.client as ObdClient?;
      await client?.clearDtc();
      setState(() {
        _clearing = false;
        _message = 'DTC cleared successfully.';
      });
    } catch (e) {
      setState(() {
        _clearing = false;
        _message = 'Failed to clear DTC: ${e.toString()}';
      });
    }
  }

  Widget _sectionTitle(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(text, style: const TextStyle(color: Colors.white70, fontWeight: FontWeight.bold)),
    );
  }

  Widget _guideCard({required String title, required List<String> bullets, required Color color}) {
    return Card(
      color: Colors.white.withOpacity(0.06),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: color.withOpacity(0.3))),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.info_outline, color: color),
                const SizedBox(width: 8),
                Text(title, style: TextStyle(color: color, fontWeight: FontWeight.w600)),
              ],
            ),
            const SizedBox(height: 8),
            ...bullets.map((b) => Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('• ', style: TextStyle(color: Colors.white70)),
                      Expanded(child: Text(b, style: const TextStyle(color: Colors.white70))),
                    ],
                  ),
                )),
          ],
        ),
      ),
    );
  }
}
