import 'package:flutter/material.dart';

import '../widgets/vehicle_list_content.dart';
import '../widgets/maintenance_list_content.dart';
import '../services/connection_manager.dart';

class MultiVehicleScreen extends StatefulWidget {
  final int initialTab;

  const MultiVehicleScreen({super.key, this.initialTab = 0});

  @override
  State<MultiVehicleScreen> createState() => _MultiVehicleScreenState();
}

class _MultiVehicleScreenState extends State<MultiVehicleScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 2,
      vsync: this,
      initialIndex: widget.initialTab,
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final vehicle = ConnectionManager.instance.vehicle;
    
    return Scaffold(
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
          const VehicleListContent(showAppBar: false),
          MaintenanceListContent(vehicleId: vehicle?.id, showAppBar: false),
        ],
      ),
    );
  }
}

