import 'package:flutter/material.dart';

import '../widgets/vehicle_list_content.dart';
import '../widgets/maintenance_list_content.dart';
import '../services/connection_manager.dart';
import '../services/vehicle_service.dart';

class MultiVehicleScreen extends StatefulWidget {
  final int initialTab;
  final bool requireAtLeastOneVehicle;

  const MultiVehicleScreen({
    super.key,
    this.initialTab = 0,
    this.requireAtLeastOneVehicle = false,
  });

  @override
  State<MultiVehicleScreen> createState() => _MultiVehicleScreenState();
}

class _MultiVehicleScreenState extends State<MultiVehicleScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _checking = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 2,
      vsync: this,
      initialIndex: widget.initialTab,
    );
    if (widget.requireAtLeastOneVehicle) {
      VehicleService.init();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _maybeCloseIfVehicleExists();
      });
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _maybeCloseIfVehicleExists() async {
    if (!widget.requireAtLeastOneVehicle || _checking) return;
    _checking = true;
    try {
      if (VehicleService.all().isNotEmpty && mounted) {
        Navigator.of(context).maybePop(true);
      }
    } finally {
      _checking = false;
    }
  }

  Future<bool> _handleWillPop() async {
    if (!widget.requireAtLeastOneVehicle) return true;
    final hasVehicle = VehicleService.all().isNotEmpty;
    if (!hasVehicle && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please add at least one vehicle to continue')),
      );
    }
    return hasVehicle;
  }

  @override
  Widget build(BuildContext context) {
    final vehicle = ConnectionManager.instance.vehicle;
    
    final scaffold = Scaffold(
      appBar: AppBar(
        title: const Text('Multi Vehicle'),
        backgroundColor: const Color(0xFFE91E63),
        foregroundColor: Colors.white,
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          indicatorColor: Colors.white,
          tabs: const [
            Tab(text: 'Vehicles', icon: Icon(Icons.directions_car, size: 18)),
            Tab(text: 'Maintenance', icon: Icon(Icons.build, size: 18)),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          Stack(
            children: [
              const VehicleListContent(showAppBar: false),
              if (widget.requireAtLeastOneVehicle && VehicleService.all().isEmpty)
                Positioned(
                  left: 16,
                  right: 16,
                  top: 12,
                  child: Material(
                    borderRadius: BorderRadius.circular(12),
                    color: Colors.orange.withValues(alpha: 0.15),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Row(
                        children: const [
                          Icon(Icons.info, color: Colors.orangeAccent),
                          SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'Add your first vehicle to continue using the app.',
                              style: TextStyle(color: Colors.white, fontSize: 13),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),
          MaintenanceListContent(vehicleId: vehicle?.id, showAppBar: false),
        ],
      ),
    );

    if (!widget.requireAtLeastOneVehicle) return scaffold;
    return WillPopScope(
      onWillPop: _handleWillPop,
      child: scaffold,
    );
  }
}

