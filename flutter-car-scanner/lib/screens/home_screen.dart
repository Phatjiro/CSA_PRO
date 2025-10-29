import 'package:flutter/material.dart';

import 'connect_screen.dart';
import 'dashboard_screen.dart';
import '../services/connection_manager.dart';
import 'acceleration_tests_screen.dart';
import 'emission_tests_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final items = <_MenuItem>[
      _MenuItem(Icons.speed, 'Dashboard'),
      _MenuItem(Icons.show_chart, 'Live data'),
      _MenuItem(Icons.list_alt, 'All sensors'),
      _MenuItem(Icons.engineering, 'Diagnostic trouble codes'),
      _MenuItem(Icons.save_alt, 'Freeze frame'),
      _MenuItem(Icons.assignment_turned_in, 'Noncontinuous\nMonitors'),
      _MenuItem(Icons.shopping_cart, 'Upgrade to Car\nScanner Pro'),
      _MenuItem(Icons.garage, 'My cars'),
      _MenuItem(Icons.settings, 'Settings'),
      _MenuItem(Icons.local_gas_station, 'Statistics'),
      _MenuItem(Icons.memory, 'ECU identifiers'),
      _MenuItem(Icons.fiber_manual_record, 'Data recording'),
      _MenuItem(Icons.precision_manufacturing, 'Acceleration tests'),
      _MenuItem(Icons.science, 'Emission tests'),
    ];

    return Scaffold(
      appBar: AppBar(title: const Text('Car Scanner')),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: GridView.builder(
                padding: const EdgeInsets.all(16),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  mainAxisSpacing: 24,
                  crossAxisSpacing: 16,
                  childAspectRatio: 0.9,
                ),
                itemCount: items.length,
                itemBuilder: (context, index) => _MenuTile(
                  item: items[index],
                  onTap: () {
                    if (items[index].title.startsWith('Dashboard')) {
                      final client = ConnectionManager.instance.client;
                      if (client == null) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Chưa kết nối. Hãy CONNECT trước.')),
                        );
                        return;
                      }
                      Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => DashboardScreen(client: client)),
                      );
                    } else if (items[index].title.startsWith('Acceleration')) {
                      final client = ConnectionManager.instance.client;
                      if (client == null) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Chưa kết nối. Hãy CONNECT trước.')),
                        );
                        return;
                      }
                      Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const AccelerationTestsScreen()),
                      );
                    } else if (items[index].title.startsWith('Emission tests')) {
                      final client = ConnectionManager.instance.client;
                      if (client == null) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Chưa kết nối. Hãy CONNECT trước.')),
                        );
                        return;
                      }
                      Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const EmissionTestsScreen()),
                      );
                    }
                  },
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(builder: (_) => const ConnectScreen()),
                        );
                      },
                      child: const Text('CONNECT'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: null,
                      child: const Text('Demo'),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: ValueListenableBuilder<bool>(
                valueListenable: ConnectionManager.instance.isConnected,
                builder: (context, connected, _) {
                  return Text(
                    connected ? 'ELM connection: Connected' : 'ELM connection: Disconnected',
                    style: TextStyle(color: connected ? Colors.greenAccent : Colors.redAccent),
                  );
                },
              ),
            )
          ],
        ),
      ),
    );
  }
}

class _MenuItem {
  final IconData icon;
  final String title;
  const _MenuItem(this.icon, this.title);
}

class _MenuTile extends StatelessWidget {
  final _MenuItem item;
  final VoidCallback? onTap;
  const _MenuTile({required this.item, this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(item.icon, size: 42, color: Colors.blueGrey.shade200),
          const SizedBox(height: 8),
          Text(
            item.title,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 13),
            maxLines: 2,
          ),
        ],
      ),
    );
  }
}


