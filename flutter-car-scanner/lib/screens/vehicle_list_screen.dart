import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../models/vehicle.dart';
import '../services/vehicle_service.dart';
import '../services/maintenance_service.dart';
import 'vehicle_form_screen.dart';
import 'maintenance_list_screen.dart';

class VehicleListScreen extends StatefulWidget {
  const VehicleListScreen({super.key});

  @override
  State<VehicleListScreen> createState() => _VehicleListScreenState();
}

class _VehicleListScreenState extends State<VehicleListScreen> {
  @override
  void initState() {
    super.initState();
    VehicleService.init();
  }

  Future<void> _deleteVehicle(Vehicle vehicle) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Vehicle?'),
        content: Text('Are you sure you want to delete "${vehicle.displayName}"? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await VehicleService.delete(vehicle.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Deleted "${vehicle.displayName}"')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Vehicles'),
        backgroundColor: const Color(0xFFF39C12),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () async {
              final result = await Navigator.of(context).push<Vehicle?>(
                MaterialPageRoute(
                  builder: (_) => const VehicleFormScreen(),
                ),
              );
              if (result != null && mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Added "${result.displayName}"')),
                );
              }
            },
          ),
        ],
      ),
      body: StreamBuilder<BoxEvent>(
        stream: VehicleService.watch(),
        builder: (context, _) {
          final vehicles = VehicleService.all();

          if (vehicles.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.directions_car_outlined,
                    size: 64,
                    color: Colors.white.withOpacity(0.5),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No vehicles yet',
                    style: TextStyle(
                      fontSize: 18,
                      color: Colors.white.withOpacity(0.7),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Tap + to add your first vehicle',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.white.withOpacity(0.5),
                    ),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: vehicles.length,
            itemBuilder: (context, index) {
              final vehicle = vehicles[index];
              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                color: Colors.white.withOpacity(0.05),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: Colors.blueAccent.withOpacity(0.3),
                    child: const Icon(Icons.directions_car, color: Colors.white70),
                  ),
                  title: Row(
                    children: [
                      Expanded(
                        child: Text(
                          vehicle.displayName,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                      // Maintenance badge
                      Builder(
                        builder: (context) {
                          final maintenanceItems = MaintenanceService.getByVehicle(vehicle.id);
                          final overdue = maintenanceItems.where((item) => item.isOverdue(null)).length;
                          final dueSoon = maintenanceItems.where((item) => item.isDueSoon(null)).length;
                          
                          if (overdue > 0) {
                            return Container(
                              margin: const EdgeInsets.only(left: 8),
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.redAccent,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                '$overdue',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            );
                          } else if (dueSoon > 0) {
                            return Container(
                              margin: const EdgeInsets.only(left: 8),
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.orangeAccent,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                '$dueSoon',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            );
                          }
                          return const SizedBox.shrink();
                        },
                      ),
                    ],
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (vehicle.shortInfo != 'No info')
                        Text(
                          vehicle.shortInfo,
                          style: TextStyle(fontSize: 12, color: Colors.white70),
                        ),
                      if (vehicle.vin != null)
                        Text(
                          'VIN: ${vehicle.vin}',
                          style: TextStyle(fontSize: 11, color: Colors.white60),
                        ),
                      if (vehicle.lastConnected != null)
                        Text(
                          'Last connected: ${_formatDate(vehicle.lastConnected!)}',
                          style: TextStyle(fontSize: 11, color: Colors.white60),
                        ),
                    ],
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.build, size: 20),
                        tooltip: 'Maintenance',
                        onPressed: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => MaintenanceListScreen(vehicleId: vehicle.id),
                            ),
                          );
                        },
                      ),
                      IconButton(
                        icon: const Icon(Icons.edit, size: 20),
                        onPressed: () async {
                          final result = await Navigator.of(context).push<Vehicle?>(
                            MaterialPageRoute(
                              builder: (_) => VehicleFormScreen(vehicle: vehicle),
                            ),
                          );
                          if (result != null && mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Updated "${result.displayName}"')),
                            );
                          }
                        },
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete, size: 20),
                        onPressed: () => _deleteVehicle(vehicle),
                      ),
                    ],
                  ),
                  onTap: () async {
                    final result = await Navigator.of(context).push<Vehicle?>(
                      MaterialPageRoute(
                        builder: (_) => VehicleFormScreen(vehicle: vehicle),
                      ),
                    );
                    if (result != null && mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Updated "${result.displayName}"')),
                      );
                    }
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);

    if (diff.inDays == 0) {
      return 'Today';
    } else if (diff.inDays == 1) {
      return 'Yesterday';
    } else if (diff.inDays < 7) {
      return '${diff.inDays} days ago';
    } else {
      return '${date.day}/${date.month}/${date.year}';
    }
  }
}

