import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../models/vehicle.dart';
import '../services/vehicle_service.dart';
import '../screens/vehicle_form_screen.dart';

class VehiclePicker extends StatefulWidget {
  final Vehicle? selectedVehicle;
  final Function(Vehicle) onVehicleSelected;

  const VehiclePicker({
    super.key,
    this.selectedVehicle,
    required this.onVehicleSelected,
  });

  @override
  State<VehiclePicker> createState() => _VehiclePickerState();
}

class _VehiclePickerState extends State<VehiclePicker> {
  @override
  void initState() {
    super.initState();
    VehicleService.init();
  }

  Future<void> _showVehicleDialog() async {
    final vehicles = VehicleService.all();
    
    // If no vehicles, prompt to create one
    if (vehicles.isEmpty) {
      final result = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('No Vehicles'),
          content: const Text('You need to add a vehicle first before connecting.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Add Vehicle'),
            ),
          ],
        ),
      );

      if (result == true && mounted) {
        final newVehicle = await Navigator.of(context).push<Vehicle?>(
          MaterialPageRoute(
            builder: (_) => const VehicleFormScreen(),
          ),
        );
        if (newVehicle != null) {
          widget.onVehicleSelected(newVehicle);
        }
      }
      return;
    }

    // Show vehicle selection dialog
    final selected = await showDialog<Vehicle>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Select Vehicle'),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: vehicles.length + 1, // +1 for "Add New" option
            itemBuilder: (context, index) {
              if (index == 0) {
                return ListTile(
                  leading: const Icon(Icons.add_circle_outline),
                  title: const Text('Add New Vehicle'),
                  onTap: () => Navigator.pop(context, null), // Signal to add new
                );
              }

              final vehicle = vehicles[index - 1];
              final isSelected = widget.selectedVehicle?.id == vehicle.id;

              return ListTile(
                leading: CircleAvatar(
                  backgroundColor: isSelected ? Colors.blueAccent : Colors.white.withOpacity(0.1),
                  child: Icon(
                    isSelected ? Icons.check : Icons.directions_car,
                    color: isSelected ? Colors.white : Colors.white70,
                  ),
                ),
                title: Text(
                  vehicle.displayName,
                  style: TextStyle(
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
                subtitle: vehicle.shortInfo != 'No info'
                    ? Text(vehicle.shortInfo, style: const TextStyle(fontSize: 12))
                    : null,
                selected: isSelected,
                onTap: () => Navigator.pop(context, vehicle),
              );
            },
          ),
        ),
      ),
    );

    if (selected != null && mounted) {
      widget.onVehicleSelected(selected);
    } else if (selected == null && mounted) {
      // User tapped "Add New", open form
      final newVehicle = await Navigator.of(context).push<Vehicle?>(
        MaterialPageRoute(
          builder: (_) => const VehicleFormScreen(),
        ),
      );
      if (newVehicle != null) {
        widget.onVehicleSelected(newVehicle);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final selectedVehicle = widget.selectedVehicle;

    return InkWell(
      onTap: _showVehicleDialog,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.white.withOpacity(0.2)),
          borderRadius: BorderRadius.circular(8),
          color: Colors.white.withOpacity(0.05),
        ),
        child: Row(
          children: [
            Icon(Icons.directions_car, color: Colors.white70, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    selectedVehicle?.displayName ?? 'Select Vehicle',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: selectedVehicle != null ? Colors.white : Colors.white70,
                    ),
                  ),
                  if (selectedVehicle != null && selectedVehicle.shortInfo != 'No info')
                    Text(
                      selectedVehicle.shortInfo,
                      style: TextStyle(fontSize: 11, color: Colors.white60),
                    ),
                ],
              ),
            ),
            Icon(Icons.arrow_drop_down, color: Colors.white70),
          ],
        ),
      ),
    );
  }
}

