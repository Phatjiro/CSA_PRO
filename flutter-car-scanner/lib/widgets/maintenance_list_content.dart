import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../models/maintenance_item.dart';
import '../models/vehicle.dart';
import '../services/maintenance_service.dart';
import '../services/vehicle_service.dart';
import '../screens/maintenance_form_screen.dart';

class MaintenanceListContent extends StatefulWidget {
  final String? vehicleId;
  final bool showAppBar;

  const MaintenanceListContent({super.key, this.vehicleId, this.showAppBar = false});

  @override
  State<MaintenanceListContent> createState() => _MaintenanceListContentState();
}

class _MaintenanceListContentState extends State<MaintenanceListContent> {
  Vehicle? _selectedVehicle;
  List<Vehicle> _vehicles = [];

  @override
  void initState() {
    super.initState();
    MaintenanceService.init();
    VehicleService.init();
    _loadVehicles();
  }

  void _loadVehicles() {
    final vehicles = VehicleService.all();
    setState(() {
      _vehicles = vehicles;
      if (widget.vehicleId != null) {
        _selectedVehicle = vehicles.firstWhere(
          (v) => v.id == widget.vehicleId,
          orElse: () => vehicles.isNotEmpty ? vehicles.first : vehicles.first,
        );
      } else if (vehicles.isNotEmpty) {
        _selectedVehicle = vehicles.first;
      }
    });
  }

  Future<void> _markDone(MaintenanceItem item) async {
    final dateController = TextEditingController(
      text: DateTime.now().toString().split(' ')[0],
    );
    final kmController = TextEditingController();

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Mark "${item.name}" as Done'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: dateController,
              decoration: const InputDecoration(
                labelText: 'Date',
                hintText: 'YYYY-MM-DD',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: kmController,
              decoration: const InputDecoration(
                labelText: 'Odometer (km)',
                hintText: 'Optional',
              ),
              keyboardType: TextInputType.number,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              DateTime? date;
              try {
                date = DateTime.parse(dateController.text);
              } catch (_) {}

              Navigator.pop(context, {
                'date': date ?? DateTime.now(),
                'km': kmController.text.isEmpty
                    ? null
                    : int.tryParse(kmController.text),
              });
            },
            child: const Text('Done'),
          ),
        ],
      ),
    );

    if (result != null && _selectedVehicle != null) {
      await MaintenanceService.markDone(
        item.id,
        date: result['date'] as DateTime?,
        km: result['km'] as int?,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Marked "${item.name}" as done')),
        );
      }
    }
  }

  Widget _buildBody() {
    if (_vehicles.isEmpty) {
      return const Center(
        child: Text('Please add a vehicle first'),
      );
    }

    return Column(
      children: [
        // Vehicle selector (only if multiple vehicles)
        if (_vehicles.length > 1)
          Container(
            padding: const EdgeInsets.all(12),
            color: Colors.white.withValues(alpha: 0.05),
            child: DropdownButton<Vehicle>(
              value: _selectedVehicle,
              isExpanded: true,
              items: _vehicles.map((v) {
                return DropdownMenuItem(
                  value: v,
                  child: Text(v.displayName),
                );
              }).toList(),
              onChanged: (v) {
                setState(() => _selectedVehicle = v);
              },
            ),
          ),

        // Maintenance list
        Expanded(
          child: StreamBuilder<BoxEvent>(
            stream: MaintenanceService.watch(),
            builder: (context, _) {
              if (_selectedVehicle == null) {
                return const Center(child: Text('Select a vehicle'));
              }

              final items = MaintenanceService.getByVehicle(_selectedVehicle!.id);
              final overdue = MaintenanceService.getOverdue(_selectedVehicle!.id);
              final dueSoon = MaintenanceService.getDueSoon(_selectedVehicle!.id);

              if (items.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.build_circle_outlined,
                        size: 64,
                        color: Colors.white.withValues(alpha: 0.5),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'No maintenance items',
                        style: TextStyle(
                          fontSize: 18,
                          color: Colors.white.withValues(alpha: 0.7),
                        ),
                      ),
                      const SizedBox(height: 8),
                      ElevatedButton.icon(
                        icon: const Icon(Icons.add),
                        label: const Text('Add First Item'),
                        onPressed: () async {
                          final result = await Navigator.of(context).push<MaintenanceItem?>(
                            MaterialPageRoute(
                              builder: (_) => MaintenanceFormScreen(
                                vehicleId: _selectedVehicle!.id,
                              ),
                            ),
                          );
                          if (!mounted) return;
                          if (result != null) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Added "${result.name}"')),
                            );
                          }
                        },
                      ),
                    ],
                  ),
                );
              }

              return ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  // Overdue section
                  if (overdue.isNotEmpty) ...[
                    _buildSectionHeader('⚠️ Overdue', Colors.redAccent),
                    ...overdue.map((item) => _buildItemCard(item, true)),
                    const SizedBox(height: 16),
                  ],

                  // Due soon section
                  if (dueSoon.isNotEmpty && overdue.isEmpty) ...[
                    _buildSectionHeader('🔔 Due Soon', Colors.orangeAccent),
                    ...dueSoon.map((item) => _buildItemCard(item, false)),
                    const SizedBox(height: 16),
                  ],

                  // All items
                  _buildSectionHeader('All Items', Colors.white70),
                  ...items.map((item) => _buildItemCard(item, false)),
                ],
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildSectionHeader(String title, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12, top: 8),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.bold,
          color: color,
        ),
      ),
    );
  }

  Widget _buildItemCard(MaintenanceItem item, bool isOverdue) {
    final nextDueText = item.nextDueDate != null
        ? 'Due: ${_formatDate(item.nextDueDate!)}'
        : 'Due: Unknown';
    final nextKmText = item.nextDueKm != null
        ? 'At ${item.nextDueKm} km'
        : '';

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      color: isOverdue
          ? Colors.redAccent.withValues(alpha: 0.1)
          : Colors.white.withValues(alpha: 0.05),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: isOverdue
              ? Colors.redAccent
              : item.isDueSoon(null)
                  ? Colors.orangeAccent
                  : Colors.blueAccent,
          child: const Icon(Icons.build, color: Colors.white, size: 20),
        ),
        title: Text(
          item.name,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: isOverdue ? Colors.redAccent : Colors.white,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(
              'Every ${item.intervalKm} km or ${item.intervalDays ~/ 30} months',
              style: TextStyle(fontSize: 12, color: Colors.white70),
            ),
            if (item.lastDoneDate != null) ...[
              const SizedBox(height: 4),
              Text(
                'Last: ${_formatDate(item.lastDoneDate!)}',
                style: TextStyle(fontSize: 11, color: Colors.white60),
              ),
            ],
            const SizedBox(height: 4),
            Text(
              nextDueText,
              style: TextStyle(
                fontSize: 12,
                color: isOverdue ? Colors.redAccent : Colors.white70,
                fontWeight: isOverdue ? FontWeight.bold : FontWeight.normal,
              ),
            ),
            if (nextKmText.isNotEmpty)
              Text(
                nextKmText,
                style: TextStyle(fontSize: 11, color: Colors.white60),
              ),
          ],
        ),
        trailing: IconButton(
          icon: const Icon(Icons.check_circle_outline),
          onPressed: () => _markDone(item),
          tooltip: 'Mark as done',
        ),
        onTap: () async {
          final result = await Navigator.of(context).push<MaintenanceItem?>(
            MaterialPageRoute(
              builder: (_) => MaintenanceFormScreen(
                vehicleId: item.vehicleId,
                item: item,
              ),
            ),
          );
          if (!mounted) return;
          if (result != null) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Updated "${result.name}"')),
            );
          }
        },
      ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);

    if (diff.inDays == 0) return 'Today';
    if (diff.inDays == 1) return 'Yesterday';
    if (diff.inDays < 7) return '${diff.inDays} days ago';
    return '${date.day}/${date.month}/${date.year}';
  }

  Widget _buildFloatingActionButton() {
    if (_selectedVehicle == null) return const SizedBox.shrink();
    return FloatingActionButton(
      onPressed: () async {
        final result = await Navigator.of(context).push<MaintenanceItem?>(
          MaterialPageRoute(
            builder: (_) => MaintenanceFormScreen(
              vehicleId: _selectedVehicle!.id,
            ),
          ),
        );
        if (!mounted) return;
        if (result != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Added "${result.name}"')),
          );
        }
      },
      child: const Icon(Icons.add),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.showAppBar) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Maintenance'),
          backgroundColor: const Color(0xFFE91E63),
          foregroundColor: Colors.white,
          actions: [
            if (_selectedVehicle != null)
              IconButton(
                icon: const Icon(Icons.add),
                onPressed: () async {
                  final result = await Navigator.of(context).push<MaintenanceItem?>(
                    MaterialPageRoute(
                      builder: (_) => MaintenanceFormScreen(
                        vehicleId: _selectedVehicle!.id,
                      ),
                    ),
                  );
                  if (!mounted) return;
                  if (result != null) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Added "${result.name}"')),
                    );
                  }
                },
              ),
          ],
        ),
        body: _buildBody(),
      );
    }
    return Scaffold(
      body: _buildBody(),
      floatingActionButton: _buildFloatingActionButton(),
    );
  }
}

