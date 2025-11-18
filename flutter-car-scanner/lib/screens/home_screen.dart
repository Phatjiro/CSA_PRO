import 'package:flutter/material.dart';
import 'dart:async';

import 'connect_screen.dart';
import 'dashboard_screen.dart';
import '../services/connection_manager.dart';
import '../services/vehicle_service.dart';
import '../models/obd_live_data.dart';
import 'acceleration_tests_screen.dart';
import 'emission_tests_screen.dart';
import 'mode06_screen.dart';
import 'logbook_screen.dart';
import 'vehicle_info_screen.dart';
import 'o2_test_screen.dart';
import 'battery_detection_screen.dart';
import 'live_data_select_screen.dart';
import 'read_codes_screen.dart';
import 'freeze_frame_screen.dart';
import 'mil_status_screen.dart';
import 'emission_check_screen.dart';
import 'multi_vehicle_screen.dart';
import 'incident_history_screen.dart';
import 'ai_mechanic_screen.dart';
import 'issue_forecast_screen.dart';
import 'repair_cost_screen.dart';
import 'security_scan_screen.dart';
import 'ecu_data_screen.dart';
import 'service_tools_screen.dart';
import 'vehicle_specific_data_screen.dart';
import 'all_sensors_screen.dart';
import '../models/vehicle.dart';
import 'demo_init_screen.dart';
import 'settings_screen.dart';
import 'vehicle_form_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  Future<void> _handleConnectTap() async {
    await VehicleService.init();
    if (VehicleService.all().isEmpty) {
      await Navigator.of(context).push<Vehicle?>(
        MaterialPageRoute(
          builder: (_) => const VehicleFormScreen(isOnboarding: true),
          fullscreenDialog: true,
        ),
      );
      if (!mounted || VehicleService.all().isEmpty) return;
    }
    if (!mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const ConnectScreen()),
    );
  }
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Car Scanner'),
        actions: [
          IconButton(
            tooltip: 'Vehicles',
            icon: const Icon(Icons.directions_car),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const MultiVehicleScreen(initialTab: 0),
                ),
              );
            },
          ),
          IconButton(
            tooltip: 'Settings',
            icon: const Icon(Icons.settings),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const SettingsScreen()),
              );
            },
          ),
        ],
      ),
      body: SafeArea(
        child: Builder(
          builder: (context) {
            final groups = <_Group>[
                    _Group('Basic Diagnostics', const Color(0xFF1E88E5), Icons.health_and_safety, [
                      _MenuItem(Icons.bug_report, 'Read & Clear Codes', 'View and clear diagnostic trouble codes', _Action.openReadCodes),
                      _MenuItem(Icons.save_alt, 'Freeze Frame', 'Check snapshot data when DTC occurred', _Action.openFreezeFrame),
                      _MenuItem(Icons.warning_amber, 'MIL Status', 'Check engine light and readiness monitors', _Action.openMilStatus),
                    ]),
                    _Group('Monitoring & Reporting', const Color(0xFF2ECC71), Icons.monitor_heart, [
                      _MenuItem(Icons.menu_book, 'Logbook', 'Track your vehicle maintenance history', _Action.openLogbook),
                      _MenuItem(Icons.show_chart, 'Live Data', 'Monitor real-time sensor data', _Action.openLiveData),
                      _MenuItem(Icons.sensors, 'All Sensors', 'View all available sensors at once', _Action.openAllSensors),
                      _MenuItem(Icons.analytics, 'Mode 6 Scan', 'Advanced emissions test results', _Action.openMode06),
                    ]),
                    _Group('Maintenance Service', const Color(0xFFF39C12), Icons.build_circle, [
                      _MenuItem(Icons.build, 'Service Tools', 'Reset service intervals and more', _Action.openServiceTools),
                      _MenuItem(Icons.science, 'Emission Tools', 'Check O2 sensors and emission readiness', _Action.openEmission),
                      _MenuItem(Icons.fact_check, 'Emission Check', 'Quick emission system check', _Action.openEmissionCheck),
                      _MenuItem(Icons.directions_car_filled, 'Vehicle Info', 'View VIN, make, model and more', _Action.openVehicleInfo),
                    ]),
                    _Group('Smart Features', const Color(0xFF7D3C98), Icons.psychology, [
                      _MenuItem(Icons.support_agent, 'AI Mechanic', 'Get AI-powered repair suggestions', _Action.openAiMechanic),
                      _MenuItem(Icons.attach_money, 'Repair Cost', 'Estimate repair costs for issues', _Action.openRepairCost),
                      _MenuItem(Icons.waves, 'Issue Forecast', 'Predict potential future problems', _Action.openIssueForecast),
                      _MenuItem(Icons.history, 'Incident History', 'View past issues and repairs', _Action.openIncidentHistory),
                    ]),
                    _Group('Smart Features+', const Color(0xFFE91E63), Icons.dashboard_customize, [
                      _MenuItem(Icons.speed, 'Custom Dashboard', 'Create your own live data dashboard', _Action.openDashboard),
                      _MenuItem(Icons.directions_car, 'Multi Vehicle', 'Manage multiple vehicles', _Action.openVehicleList),
                      _MenuItem(Icons.sports_motorsports, 'Racing Mode', 'Test acceleration performance', _Action.openAcceleration),
                      _MenuItem(Icons.memory, 'ECU Data', 'View detailed ECU information', _Action.openEcuData),
                    ]),
                    _Group('Specialized Features', const Color(0xFF9B59B6), Icons.security, [
                      _MenuItem(Icons.shield, 'Security Scan', 'Comprehensive system security check', _Action.openSecurityScan),
                      _MenuItem(Icons.car_repair, 'Vehicle-Specific Data', 'Manufacturer-specific data', _Action.openVehicleSpecificData),
                      _MenuItem(Icons.bubble_chart, 'O2 Test', 'Oxygen sensor diagnostic test', _Action.openO2Test),
                      _MenuItem(Icons.battery_full, 'Battery Detection', 'Check battery health and voltage', _Action.openBatteryDetection),
                    ]),
                ];

            return ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
              children: [
                  // Connection section
                  ValueListenableBuilder<bool>(
                    valueListenable: ConnectionManager.instance.isConnected,
                    builder: (context, connected, _) {
                      return ValueListenableBuilder<Vehicle?>(
                        valueListenable: ConnectionManager.instance.currentVehicle,
                        builder: (context, vehicle, _) {
                          return Column(
                            children: [
                              // Status section
                              Container(
                                margin: const EdgeInsets.only(bottom: 16),
                                padding: const EdgeInsets.all(24),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(24),
                                  gradient: LinearGradient(
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                    colors: connected 
                                      ? [
                                          Colors.green.withValues(alpha: 0.15),
                                          Colors.green.withValues(alpha: 0.05),
                                        ]
                                      : [
                                          Colors.orange.withValues(alpha: 0.15),
                                          Colors.orange.withValues(alpha: 0.05),
                                        ],
                                  ),
                                  border: Border.all(
                                    color: connected 
                                      ? Colors.green.withValues(alpha: 0.3)
                                      : Colors.orange.withValues(alpha: 0.3),
                                    width: 2,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withValues(alpha: 0.2),
                                      blurRadius: 15,
                                      offset: const Offset(0, 5),
                                    ),
                                  ],
                                ),
                                child: Row(
                                  children: [
                                    _BigStatusButton(
                                      connected: connected,
                                      onConnectTap: _handleConnectTap,
                                    ),
                                    const SizedBox(width: 20),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.stretch,
                                        children: [
                                          // Status row
                                          Row(
                                            children: [
                                              TweenAnimationBuilder<double>(
                                                tween: Tween(begin: 0.8, end: 1.0),
                                                duration: const Duration(milliseconds: 800),
                                                curve: Curves.easeInOut,
                                                builder: (context, scale, child) {
                                                  return Transform.scale(
                                                    scale: scale,
                                                    child: Container(
                                                      width: 10,
                                                      height: 10,
                                                      decoration: BoxDecoration(
                                                        shape: BoxShape.circle,
                                                        color: connected ? Colors.greenAccent : Colors.orange,
                                                        boxShadow: [
                                                          BoxShadow(
                                                            color: connected 
                                                              ? Colors.greenAccent.withValues(alpha: 0.6)
                                                              : Colors.orange.withValues(alpha: 0.6),
                                                            blurRadius: 10,
                                                            spreadRadius: 2,
                                                          ),
                                                        ],
                                                      ),
                                                    ),
                                                  );
                                                },
                                              ),
                                              const SizedBox(width: 8),
                                              Expanded(
                                                child: Text(
                                                  connected ? 'Connected' : 'Ready to Connect',
                                                  style: TextStyle(
                                                    fontSize: 14,
                                                    fontWeight: FontWeight.w700,
                                                    color: connected ? Colors.greenAccent : Colors.orange,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 12),
                                          Text(
                                            connected 
                                              ? 'Ready for diagnostics and monitoring'
                                              : 'Connect your OBD adapter to diagnose vehicle issues',
                                            style: TextStyle(
                                              fontSize: 11,
                                              color: Colors.white.withValues(alpha: 0.7),
                                            ),
                                          ),
                                          const SizedBox(height: 16),
                                          if (!connected)
                                            OutlinedButton(
                                              onPressed: () {
                                                showDemoInitDialog(context);
                                              },
                                              style: OutlinedButton.styleFrom(
                                                padding: const EdgeInsets.symmetric(vertical: 12),
                                                side: const BorderSide(color: Colors.white54, width: 1.5),
                                                shape: RoundedRectangleBorder(
                                                  borderRadius: BorderRadius.circular(12),
                                                ),
                                              ),
                                              child: const Text('Try Demo', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                                            )
                                          else
                                            ElevatedButton.icon(
                                              onPressed: () async {
                                                try {
                                                  await ConnectionManager.instance.disconnect();
                                                  ScaffoldMessenger.of(context).showSnackBar(
                                                    const SnackBar(content: Text('Disconnected successfully')),
                                                  );
                                                } catch (_) {}
                                              },
                                              style: ElevatedButton.styleFrom(
                                                backgroundColor: Colors.redAccent,
                                                foregroundColor: Colors.white,
                                                padding: const EdgeInsets.symmetric(vertical: 12),
                                                shape: RoundedRectangleBorder(
                                                  borderRadius: BorderRadius.circular(12),
                                                ),
                                                elevation: 3,
                                              ),
                                              icon: const Icon(Icons.close, size: 18),
                                              label: const Text('DISCONNECT', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
                                            ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              // Vehicle info section (compact)
                              if (connected && vehicle != null)
                                Container(
                                  margin: const EdgeInsets.only(bottom: 16),
                                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(12),
                                    color: const Color(0xFF2196F3).withValues(alpha: 0.1),
                                    border: Border.all(
                                      color: const Color(0xFF2196F3).withValues(alpha: 0.2),
                                      width: 1,
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(
                                        Icons.directions_car,
                                        size: 18,
                                        color: const Color(0xFF2196F3).withValues(alpha: 0.8),
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: Text(
                                          vehicle.displayName,
                                          style: TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w600,
                                            color: Colors.white.withValues(alpha: 0.9),
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      if (vehicle.shortInfo != 'No info')
                                        Text(
                                          vehicle.shortInfo,
                                          style: TextStyle(
                                            fontSize: 11,
                                            color: Colors.white.withValues(alpha: 0.6),
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                            ],
                          );
                        },
                      );
                    },
                  ),
                  // Basic Vehicle Metrics (only when connected)
                  ValueListenableBuilder<bool>(
                    valueListenable: ConnectionManager.instance.isConnected,
                    builder: (context, connected, _) {
                      if (!connected) return const SizedBox.shrink();
                      final client = ConnectionManager.instance.client;
                      if (client == null) return const SizedBox.shrink();
                      
                      // Enable PIDs needed for basic metrics
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        client.setEnabledPids({
                          '010C', // RPM
                          '010D', // Speed
                          '0105', // Coolant Temp
                          '0111', // Throttle Position
                          '012F', // Fuel Level
                          '0142', // Control Module Voltage
                        });
                      });
                      
                      return StreamBuilder<ObdLiveData>(
                        stream: client.dataStream,
                        builder: (context, snapshot) {
                          if (!snapshot.hasData) {
                            return Container(
                              margin: const EdgeInsets.only(bottom: 16),
                              padding: const EdgeInsets.all(20),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(16),
                                gradient: LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  colors: [
                                    const Color(0xFF42A5F5).withValues(alpha: 0.15),
                                    const Color(0xFF42A5F5).withValues(alpha: 0.05),
                                  ],
                                ),
                                border: Border.all(color: Colors.white.withValues(alpha: 0.08), width: 1),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.25),
                                    blurRadius: 16,
                                    offset: const Offset(0, 8),
                                  ),
                                ],
                              ),
                              child: const Center(
                                child: Padding(
                                  padding: EdgeInsets.all(20),
                                  child: CircularProgressIndicator(),
                                ),
                              ),
                            );
                          }
                          
                          final data = snapshot.data!;
                          return _BasicMetricsWidget(data: data);
                        },
                      );
                    },
                  ),
                // Feature groups
                ...groups.map((g) => _Section(title: g.title, color: g.color, items: g.items)),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _MenuItem {
  final IconData icon;
  final String title;
  final String description;
  final _Action action;
  const _MenuItem(this.icon, this.title, this.description, this.action);
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
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.white.withValues(alpha: 0.06),
              Colors.white.withValues(alpha: 0.02),
            ],
          ),
          border: Border.all(color: Colors.white.withValues(alpha: 0.08), width: 1),
        ),
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [accentColor.withValues(alpha: 0.9), accentColor.withValues(alpha: 0.5)],
                ),
                boxShadow: [
                  BoxShadow(color: accentColor.withValues(alpha: 0.4), blurRadius: 8, offset: const Offset(0, 3)),
                ],
              ),
              child: Icon(item.icon, size: 24, color: Colors.white),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    item.title,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    item.description,
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.white.withValues(alpha: 0.6),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: Colors.white.withValues(alpha: 0.4), size: 18),
          ],
        ),
      ),
    );
  }
}


enum _Action { openDashboard, openLiveData, openAllSensors, openAcceleration, openEmission, openEmissionCheck, openReadCodes, openFreezeFrame, openMilStatus, openMode06, openLogbook, openVehicleInfo, openO2Test, openBatteryDetection, openVehicleList, openMaintenance, openIncidentHistory, openAiMechanic, openIssueForecast, openRepairCost, openSecurityScan, openVehicleSpecificData, openServiceTools, openEcuData, openPlaceholder, placeholder }

class _Section extends StatefulWidget {
  final String title;
  final Color color;
  final List<_MenuItem> items;
  const _Section({required this.title, required this.color, required this.items});

  @override
  State<_Section> createState() => _SectionState();
}

class _SectionState extends State<_Section> {
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
            widget.color.withValues(alpha: 0.15),
            widget.color.withValues(alpha: 0.05),
          ],
        ),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08), width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.25),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 0, vertical: 6),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      widget.title,
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                        letterSpacing: 0.3,
                        height: 1.2,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: widget.color.withValues(alpha: 0.4),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Text(
                      '${widget.items.length}',
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: widget.items.length,
              itemBuilder: (context, index) {
                final it = widget.items[index];
                return Padding(
                  padding: EdgeInsets.only(bottom: index < widget.items.length - 1 ? 8 : 0),
                  child: _MenuTile(
                    item: it,
                    accent: widget.color,
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
                        case _Action.openAllSensors:
                          final clientAS = ConnectionManager.instance.client;
                          if (clientAS == null) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Not connected. Please CONNECT first.')),
                            );
                            return;
                          }
                          Navigator.of(context).push(MaterialPageRoute(builder: (_) => const AllSensorsScreen()));
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
                        case _Action.openEmissionCheck:
                          final clientEC = ConnectionManager.instance.client;
                          if (clientEC == null) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Not connected. Please CONNECT first.')),
                            );
                            return;
                          }
                          Navigator.of(context).push(MaterialPageRoute(builder: (_) => const EmissionCheckScreen()));
                          break;
                        case _Action.openMode06:
                          final client06 = ConnectionManager.instance.client;
                          if (client06 == null) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Not connected. Please CONNECT first.')),
                            );
                            return;
                          }
                          Navigator.of(context).push(MaterialPageRoute(builder: (_) => const Mode06Screen()));
                          break;
                        case _Action.openServiceTools:
                          Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ServiceToolsScreen()));
                          break;
                        case _Action.openLogbook:
                          Navigator.of(context).push(MaterialPageRoute(builder: (_) => const LogbookScreen()));
                          break;
                        case _Action.openIncidentHistory:
                          Navigator.of(context).push(MaterialPageRoute(builder: (_) => const IncidentHistoryScreen()));
                          break;
                        case _Action.openAiMechanic:
                          Navigator.of(context).push(MaterialPageRoute(builder: (_) => const AiMechanicScreen()));
                          break;
                        case _Action.openIssueForecast:
                          Navigator.of(context).push(MaterialPageRoute(builder: (_) => const IssueForecastScreen()));
                          break;
                        case _Action.openRepairCost:
                          Navigator.of(context).push(MaterialPageRoute(builder: (_) => const RepairCostScreen()));
                          break;
                        case _Action.openSecurityScan:
                          Navigator.of(context).push(MaterialPageRoute(builder: (_) => const SecurityScanScreen()));
                          break;
                        case _Action.openEcuData:
                          Navigator.of(context).push(MaterialPageRoute(builder: (_) => const EcuDataScreen()));
                          break;
                        case _Action.openVehicleSpecificData:
                          final clientV = ConnectionManager.instance.client;
                          if (clientV == null) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Not connected. Please CONNECT first.')),
                            );
                            return;
                          }
                          Navigator.of(context).push(MaterialPageRoute(builder: (_) => const VehicleSpecificDataScreen()));
                          break;
                        case _Action.openVehicleInfo:
                          Navigator.of(context).push(MaterialPageRoute(builder: (_) => const VehicleInfoScreen()));
                          break;
                        case _Action.openVehicleList:
                          Navigator.of(context).push(MaterialPageRoute(
                            builder: (_) => const MultiVehicleScreen(initialTab: 0),
                          ));
                          break;
                        case _Action.openMaintenance:
                          Navigator.of(context).push(MaterialPageRoute(
                            builder: (_) => const MultiVehicleScreen(initialTab: 1),
                          ));
                          break;
                        case _Action.openO2Test:
                          final clientO2 = ConnectionManager.instance.client;
                          if (clientO2 == null) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Not connected. Please CONNECT first.')),
                            );
                            return;
                          }
                          Navigator.of(context).push(MaterialPageRoute(builder: (_) => const O2TestScreen()));
                          break;
                        case _Action.openBatteryDetection:
                          final clientBat = ConnectionManager.instance.client;
                          if (clientBat == null) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Not connected. Please CONNECT first.')),
                            );
                            return;
                          }
                          Navigator.of(context).push(MaterialPageRoute(builder: (_) => const BatteryDetectionScreen()));
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
                        case _Action.openFreezeFrame:
                          final clientF = ConnectionManager.instance.client;
                          if (clientF == null) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Not connected. Please CONNECT first.')),
                            );
                            return;
                          }
                          Navigator.of(context).push(MaterialPageRoute(builder: (_) => const FreezeFrameScreen()));
                          break;
                        case _Action.openMilStatus:
                          final clientM = ConnectionManager.instance.client;
                          if (clientM == null) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Not connected. Please CONNECT first.')),
                            );
                            return;
                          }
                          Navigator.of(context).push(MaterialPageRoute(builder: (_) => const MilStatusScreen()));
                          break;
                        case _Action.openPlaceholder:
                        case _Action.placeholder:
                        default:
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Coming soon: ${it.title}')),
                          );
                          break;
                      }
                    },
                  ),
                );
              },
            ),
          ],
        ),
      ),
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

// Big animated status button
class _BigStatusButton extends StatefulWidget {
  final bool connected;
  final Future<void> Function()? onConnectTap;
  const _BigStatusButton({required this.connected, this.onConnectTap});

  @override
  State<_BigStatusButton> createState() => _BigStatusButtonState();
}

class _BigStatusButtonState extends State<_BigStatusButton> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat(reverse: true);

    _scaleAnimation = Tween<double>(begin: 1.0, end: 1.05).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );

    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.15).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isConnected = widget.connected;
    final mainColor = isConnected ? const Color(0xFF66BB6A) : const Color(0xFF42A5F5);
    final darkColor = isConnected ? const Color(0xFF43A047) : const Color(0xFF1976D2);
    
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Stack(
          alignment: Alignment.center,
          children: [
            // Pulsing glow effect (for both states)
            Transform.scale(
              scale: _pulseAnimation.value,
              child: Container(
                width: 140,
                height: 140,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      mainColor.withValues(alpha: isConnected ? 0.25 : 0.3),
                      mainColor.withValues(alpha: 0.0),
                    ],
                  ),
                ),
              ),
            ),
            // Main button
            Transform.scale(
              scale: _scaleAnimation.value,
              child: GestureDetector(
                onTap: isConnected
                    ? null
                    : () async {
                        if (widget.onConnectTap != null) {
                          await widget.onConnectTap!();
                        }
                      },
                child: Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [mainColor, darkColor],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: mainColor.withValues(alpha: 0.5),
                        blurRadius: 20,
                        spreadRadius: 4,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Center(
                    child: Text(
                      isConnected ? 'ACTIVE' : 'TAP TO\nCONNECT',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                        letterSpacing: 1.5,
                        height: 1.3,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

// Basic Vehicle Metrics Widget
class _BasicMetricsWidget extends StatelessWidget {
  final ObdLiveData data;
  
  const _BasicMetricsWidget({required this.data});

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
            const Color(0xFF42A5F5).withValues(alpha: 0.15),
            const Color(0xFF42A5F5).withValues(alpha: 0.05),
          ],
        ),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08), width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.25),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header (same style as section groups)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 0, vertical: 6),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Vehicle Status',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                        letterSpacing: 0.3,
                        height: 1.2,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            // Metrics Grid (3 columns x 2 rows)
            Row(
              children: [
                Expanded(
                  child: _MetricCard(
                    icon: Icons.speed,
                    label: 'RPM',
                    value: '${data.engineRpm}',
                    unit: '',
                    color: Colors.blueAccent,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _MetricCard(
                    icon: Icons.directions_car,
                    label: 'Speed',
                    value: '${data.vehicleSpeedKmh}',
                    unit: ' km/h',
                    color: Colors.greenAccent,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _MetricCard(
                    icon: Icons.thermostat,
                    label: 'Coolant',
                    value: '${data.coolantTempC}',
                    unit: '°C',
                    color: Colors.orangeAccent,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _MetricCard(
                    icon: Icons.trending_up,
                    label: 'Throttle',
                    value: '${data.throttlePositionPercent}',
                    unit: '%',
                    color: Colors.purpleAccent,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _MetricCard(
                    icon: Icons.local_gas_station,
                    label: 'Fuel',
                    value: '${data.fuelLevelPercent}',
                    unit: '%',
                    color: Colors.yellowAccent,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _MetricCard(
                    icon: Icons.battery_charging_full,
                    label: 'Voltage',
                    value: data.voltageV.toStringAsFixed(1),
                    unit: ' V',
                    color: Colors.cyanAccent,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final String unit;
  final Color color;

  const _MetricCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.unit,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.white.withValues(alpha: 0.08),
            Colors.white.withValues(alpha: 0.03),
          ],
        ),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: color),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.white.withValues(alpha: 0.7),
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Flexible(
                child: Text(
                  value,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                    height: 1.0,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (unit.isNotEmpty) ...[
                const SizedBox(width: 2),
                Padding(
                  padding: const EdgeInsets.only(bottom: 2),
                  child: Text(
                    unit,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.white.withValues(alpha: 0.6),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}
