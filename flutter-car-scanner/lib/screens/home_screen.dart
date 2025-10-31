import 'package:flutter/material.dart';
import 'dart:math' as math;

import 'connect_screen.dart';
import 'dashboard_screen.dart';
import '../services/connection_manager.dart';
import 'acceleration_tests_screen.dart';
import 'emission_tests_screen.dart';
import 'live_data_select_screen.dart';
import 'read_codes_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/prefs_keys.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _showAll = true; // default show all per request

  @override
  void initState() {
    super.initState();
    _loadPrefs();
  }

  Future<void> _loadPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getBool(PrefsKeys.homeShowAll);
    if (saved != null) {
      setState(() => _showAll = saved);
    }
  }

  Future<void> _toggleMode() async {
    setState(() => _showAll = !_showAll);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(PrefsKeys.homeShowAll, _showAll);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Car Scanner'),
        actions: [
          IconButton(
            tooltip: 'Settings',
            icon: const Icon(Icons.settings),
            onPressed: () {}, // placeholder
          ),
          IconButton(
            tooltip: _showAll ? 'Show groups' : 'Show all',
            icon: Icon(_showAll ? Icons.view_module : Icons.view_list),
            onPressed: _toggleMode,
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final groups = <_Group>[
                    _Group('Basic Diagnostics', const Color(0xFF1E88E5), Icons.health_and_safety, [
                      _MenuItem(Icons.bug_report, 'Read & Clear Codes', _Action.openReadCodes),
                      _MenuItem(Icons.save_alt, 'Freeze Frame', _Action.openPlaceholder),
                      _MenuItem(Icons.warning_amber, 'MIL Status', _Action.openPlaceholder),
                    ]),
                    _Group('Monitoring & Reporting', const Color(0xFF2ECC71), Icons.monitor_heart, [
                      _MenuItem(Icons.menu_book, 'Logbook', _Action.placeholder),
                      _MenuItem(Icons.show_chart, 'Live Data', _Action.openLiveData),
                      _MenuItem(Icons.analytics, 'Mode 6 Scan', _Action.placeholder),
                    ]),
                    _Group('Maintenance Service', const Color(0xFFF39C12), Icons.build_circle, [
                      _MenuItem(Icons.build, 'Service Tools', _Action.placeholder),
                      _MenuItem(Icons.science, 'Emission Tools', _Action.openEmission),
                      _MenuItem(Icons.fact_check, 'Emission Check', _Action.placeholder),
                      _MenuItem(Icons.directions_car_filled, 'Vehicle Info', _Action.placeholder),
                    ]),
                    _Group('Smart Features', const Color(0xFF7D3C98), Icons.psychology, [
                      _MenuItem(Icons.support_agent, 'AI Mechanic', _Action.placeholder),
                      _MenuItem(Icons.attach_money, 'Repair Cost', _Action.placeholder),
                      _MenuItem(Icons.waves, 'Issue Forecast', _Action.placeholder),
                      _MenuItem(Icons.history, 'Incident History', _Action.placeholder),
                    ]),
                    _Group('Smart Features+', const Color(0xFFE91E63), Icons.dashboard_customize, [
                      _MenuItem(Icons.speed, 'Custom Dashboard', _Action.openDashboard),
                      _MenuItem(Icons.directions_car, 'Multi Vehicle', _Action.placeholder),
                      _MenuItem(Icons.sports_motorsports, 'Racing Mode', _Action.openAcceleration),
                    ]),
                    _Group('Specialized Features', const Color(0xFF9B59B6), Icons.security, [
                      _MenuItem(Icons.shield, 'Security Scan', _Action.placeholder),
                      _MenuItem(Icons.car_repair, 'Vehicle-Specific Data', _Action.placeholder),
                      _MenuItem(Icons.bubble_chart, 'O2 Test', _Action.placeholder),
                      _MenuItem(Icons.battery_full, 'Battery Detection', _Action.placeholder),
                    ]),
                  ];

                  if (_showAll) {
                    return ListView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                      itemCount: groups.length,
                      itemBuilder: (context, index) {
                        final g = groups[index];
                        return _Section(title: g.title, color: g.color, items: g.items);
                      },
                    );
                  }
                  return _RadialMenu(groups: groups);
                },
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
  final _Action action;
  const _MenuItem(this.icon, this.title, this.action);
}

class _MenuTile extends StatelessWidget {
  final _MenuItem item;
  final VoidCallback? onTap;
  final Color? accent;
  const _MenuTile({required this.item, this.onTap, this.accent});

  @override
  Widget build(BuildContext context) {
    final accentColor = accent ?? Colors.blueGrey.shade300;
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.white.withOpacity(0.04),
              Colors.white.withOpacity(0.02),
            ],
          ),
          border: Border.all(color: Colors.white.withOpacity(0.06), width: 1),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.2),
              blurRadius: 10,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [accentColor.withOpacity(0.9), accentColor.withOpacity(0.5)],
                ),
                boxShadow: [
                  BoxShadow(color: accentColor.withOpacity(0.4), blurRadius: 10, offset: const Offset(0, 4)),
                ],
              ),
              child: Icon(item.icon, size: 24, color: Colors.white),
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 32, // reserve space for up to 2 lines
              child: Text(
                item.title,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                maxLines: 2,
                softWrap: true,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

enum _Action { openDashboard, openLiveData, openAcceleration, openEmission, openReadCodes, openPlaceholder, placeholder }

class _Section extends StatelessWidget {
  final String title;
  final Color color;
  final List<_MenuItem> items;
  const _Section({required this.title, required this.color, required this.items});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            color.withOpacity(0.18),
            color.withOpacity(0.06),
          ],
        ),
        border: Border.all(color: Colors.white.withOpacity(0.08), width: 1),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.25), blurRadius: 16, offset: const Offset(0, 8)),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.9),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(title, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.white)),
                ),
              ],
            ),
            const SizedBox(height: 12),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                mainAxisSpacing: 8,
                crossAxisSpacing: 8,
                childAspectRatio: 1.3,
              ),
              itemCount: items.length,
              itemBuilder: (context, index) {
                final it = items[index];
                return _MenuTile(
                  item: it,
                  accent: color,
                  onTap: () {
                    switch (it.action) {
                      case _Action.openDashboard:
                        final client = ConnectionManager.instance.client;
                        if (client == null) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Not connected. Please CONNECT first.')),
                          );
                          return;
                        }
                        Navigator.of(context).push(MaterialPageRoute(builder: (_) => DashboardScreen(client: client)));
                        break;
                      case _Action.openLiveData:
                        final client = ConnectionManager.instance.client;
                        if (client == null) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Not connected. Please CONNECT first.')),
                          );
                          return;
                        }
                        Navigator.of(context).push(MaterialPageRoute(builder: (_) => const LiveDataSelectScreen()));
                        break;
                      case _Action.openAcceleration:
                        final clientA = ConnectionManager.instance.client;
                        if (clientA == null) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Not connected. Please CONNECT first.')),
                          );
                          return;
                        }
                        Navigator.of(context).push(MaterialPageRoute(builder: (_) => const AccelerationTestsScreen()));
                        break;
                      case _Action.openEmission:
                        final clientE = ConnectionManager.instance.client;
                        if (clientE == null) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Not connected. Please CONNECT first.')),
                          );
                          return;
                        }
                        Navigator.of(context).push(MaterialPageRoute(builder: (_) => const EmissionTestsScreen()));
                        break;
                      case _Action.openReadCodes:
                        final clientR = ConnectionManager.instance.client;
                        if (clientR == null) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Not connected. Please CONNECT first.')),
                          );
                          return;
                        }
                        Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ReadCodesScreen()));
                        break;
                      case _Action.openPlaceholder:
                      case _Action.placeholder:
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Coming soon: ${it.title}')),
                        );
                        break;
                    }
                  },
                );
              },
            )
          ],
        ),
      ),
    );
  }
}

class _GroupCard extends StatelessWidget {
  final String title;
  final Color color;
  final IconData icon;
  final List<_MenuItem> items;
  const _GroupCard({required this.title, required this.color, required this.icon, required this.items});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => _openChooser(context),
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          gradient: LinearGradient(
            colors: [color.withOpacity(0.16), color.withOpacity(0.06)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          border: Border.all(color: Colors.white.withOpacity(0.08)),
        ),
        child: Row(
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(colors: [color.withOpacity(0.9), color.withOpacity(0.5)]),
              ),
              child: Icon(icon, color: Colors.white, size: 30),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 4),
                  Text('Tap to view features', style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 12)),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: Colors.white.withOpacity(0.8))
          ],
        ),
      ),
    );
  }

  void _openChooser(BuildContext context) {
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) {
        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.65,
          maxChildSize: 0.95,
          builder: (context, controller) {
            return Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: LinearGradient(colors: [color.withOpacity(0.9), color.withOpacity(0.5)]),
                        ),
                        child: Icon(icon, color: Colors.white),
                      ),
                      const SizedBox(width: 10),
                      Expanded(child: Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700))),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: GridView.builder(
                      controller: controller,
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        mainAxisSpacing: 14,
                        crossAxisSpacing: 14,
                        childAspectRatio: 1.15,
                      ),
                      itemCount: items.length,
                      itemBuilder: (context, index) {
                        final it = items[index];
                        return _MenuTile(item: it, accent: color, onTap: () {
                          Navigator.pop(context);
                          switch (it.action) {
                            case _Action.openDashboard:
                              final client = ConnectionManager.instance.client;
                              if (client == null) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Not connected. Please CONNECT first.')),
                                );
                                return;
                              }
                              Navigator.of(context).push(MaterialPageRoute(builder: (_) => DashboardScreen(client: client)));
                              break;
                            case _Action.openLiveData:
                              final client = ConnectionManager.instance.client;
                              if (client == null) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Not connected. Please CONNECT first.')),
                                );
                                return;
                              }
                              Navigator.of(context).push(MaterialPageRoute(builder: (_) => const LiveDataSelectScreen()));
                              break;
                            case _Action.openAcceleration:
                              final clientA = ConnectionManager.instance.client;
                              if (clientA == null) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Not connected. Please CONNECT first.')),
                                );
                                return;
                              }
                              Navigator.of(context).push(MaterialPageRoute(builder: (_) => const AccelerationTestsScreen()));
                              break;
                            case _Action.openEmission:
                              final clientE = ConnectionManager.instance.client;
                              if (clientE == null) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Not connected. Please CONNECT first.')),
                                );
                                return;
                              }
                              Navigator.of(context).push(MaterialPageRoute(builder: (_) => const EmissionTestsScreen()));
                              break;
                            case _Action.openReadCodes:
                              Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ReadCodesScreen()));
                              break;
                            case _Action.openPlaceholder:
                            case _Action.placeholder:
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('Coming soon: ${it.title}')),
                              );
                              break;
                          }
                        });
                      },
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

class _Group {
  final String title;
  final Color color;
  final IconData icon;
  final List<_MenuItem> items;
  const _Group(this.title, this.color, this.icon, this.items);
}

Widget _radialButton(BuildContext context, _Group g, Offset center, double r, double angle) {
  // Align by the whole tile (icon 72 + gap 6 + label ~16 => ~94 height, width = 110)
  const double tileWidth = 110;
  const double halfTileWidth = tileWidth / 2; // 55
  const double halfTileHeight = 48; // approx (72 + 6 + 18)/2
  final x = center.dx + r * math.cos(angle) - halfTileWidth;
  final y = center.dy + r * math.sin(angle) - halfTileHeight;
  return Positioned(
    left: x,
    top: y,
    child: _RadialButton(
      color: g.color,
      icon: g.icon,
      title: g.title,
      onPressed: () => _openGroupChooser(context, g),
    ),
  );
}

class _RadialMenu extends StatefulWidget {
  final List<_Group> groups;
  const _RadialMenu({required this.groups});

  @override
  State<_RadialMenu> createState() => _RadialMenuState();
}

class _RadialMenuState extends State<_RadialMenu> {
  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = math.min(constraints.maxWidth, constraints.maxHeight - 120);
        final radius = size * 0.38;
        final center = Offset(constraints.maxWidth / 2, (constraints.maxHeight - 120) / 2);

        return Stack(
          children: [
            Positioned(
              left: center.dx - 90,
              top: center.dy - 50,
              width: 180,
              height: 100,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: const [
                  Text('Car Scanner', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                  SizedBox(height: 6),
                  Text('Select a group', style: TextStyle(fontSize: 12, color: Colors.white70)),
                ],
              ),
            ),
            for (int i = 0; i < widget.groups.length; i++)
              _radialButton(context, widget.groups[i], center, radius, - math.pi / 2 + i * (2 * math.pi / widget.groups.length)),
          ],
        );
      },
    );
  }
}

class _RadialButton extends StatefulWidget {
  final Color color;
  final IconData icon;
  final String title;
  final VoidCallback onPressed;
  const _RadialButton({required this.color, required this.icon, required this.title, required this.onPressed});

  @override
  State<_RadialButton> createState() => _RadialButtonState();
}

class _RadialButtonState extends State<_RadialButton> with SingleTickerProviderStateMixin {
  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    super.dispose();
  }

  void _handleTap() => widget.onPressed();

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _handleTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(colors: [widget.color.withOpacity(0.9), widget.color.withOpacity(0.5)]),
              boxShadow: [BoxShadow(color: widget.color.withOpacity(0.4), blurRadius: 12, offset: const Offset(0, 6))],
            ),
            child: Icon(widget.icon, color: Colors.white, size: 34),
          ),
          const SizedBox(height: 6),
          SizedBox(
            width: 110,
            child: Text(
              widget.title,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 12, color: Colors.white.withOpacity(0.9), fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}

void _openGroupChooser(BuildContext context, _Group g) {
  showModalBottomSheet(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (context) {
      return DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.65,
        maxChildSize: 0.95,
        builder: (context, controller) {
          return Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(colors: [g.color.withOpacity(0.9), g.color.withOpacity(0.5)]),
                      ),
                      child: Icon(g.icon, color: Colors.white),
                    ),
                    const SizedBox(width: 10),
                    Expanded(child: Text(g.title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700))),
                  ],
                ),
                const SizedBox(height: 12),
                  Expanded(
                    child: GridView.builder(
                    controller: controller,
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        mainAxisSpacing: 14,
                        crossAxisSpacing: 14,
                        childAspectRatio: 1.15,
                      ),
                    itemCount: g.items.length,
                    itemBuilder: (context, index) {
                      final it = g.items[index];
                      return _MenuTile(item: it, accent: g.color, onTap: () {
                        Navigator.pop(context);
                        switch (it.action) {
                          case _Action.openDashboard:
                            final client = ConnectionManager.instance.client;
                            if (client == null) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Not connected. Please CONNECT first.')),
                              );
                              return;
                            }
                            Navigator.of(context).push(MaterialPageRoute(builder: (_) => DashboardScreen(client: client)));
                            break;
                          case _Action.openLiveData:
                            final client = ConnectionManager.instance.client;
                            if (client == null) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Not connected. Please CONNECT first.')),
                              );
                              return;
                            }
                            Navigator.of(context).push(MaterialPageRoute(builder: (_) => const LiveDataSelectScreen()));
                            break;
                          case _Action.openAcceleration:
                            final clientA = ConnectionManager.instance.client;
                            if (clientA == null) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Not connected. Please CONNECT first.')),
                              );
                              return;
                            }
                            Navigator.of(context).push(MaterialPageRoute(builder: (_) => const AccelerationTestsScreen()));
                            break;
                          case _Action.openEmission:
                            final clientE = ConnectionManager.instance.client;
                            if (clientE == null) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Not connected. Please CONNECT first.')),
                              );
                              return;
                            }
                            Navigator.of(context).push(MaterialPageRoute(builder: (_) => const EmissionTestsScreen()));
                            break;
                          case _Action.openReadCodes:
                            Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ReadCodesScreen()));
                            break;
                          case _Action.openPlaceholder:
                          case _Action.placeholder:
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Coming soon: ${it.title}')),
                            );
                            break;
                        }
                      });
                    },
                  ),
                ),
              ],
            ),
          );
        },
      );
    },
  );
}


