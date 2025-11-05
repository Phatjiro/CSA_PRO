import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/vehicle.dart';
import '../services/vehicle_service.dart';

class VehicleFormScreen extends StatefulWidget {
  final Vehicle? vehicle;

  const VehicleFormScreen({super.key, this.vehicle});

  @override
  State<VehicleFormScreen> createState() => _VehicleFormScreenState();
}

class _VehicleFormScreenState extends State<VehicleFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nicknameController = TextEditingController();
  final _vinController = TextEditingController();
  final _makeController = TextEditingController();
  final _modelController = TextEditingController();
  final _yearController = TextEditingController();
  final _colorController = TextEditingController();

  @override
  void initState() {
    super.initState();
    if (widget.vehicle != null) {
      _nicknameController.text = widget.vehicle!.nickname;
      _vinController.text = widget.vehicle!.vin ?? '';
      _makeController.text = widget.vehicle!.make ?? '';
      _modelController.text = widget.vehicle!.model ?? '';
      _yearController.text = widget.vehicle!.year?.toString() ?? '';
      _colorController.text = widget.vehicle!.color ?? '';
    }
  }

  @override
  void dispose() {
    _nicknameController.dispose();
    _vinController.dispose();
    _makeController.dispose();
    _modelController.dispose();
    _yearController.dispose();
    _colorController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    final vehicle = widget.vehicle != null
        ? widget.vehicle!.copyWith(
            nickname: _nicknameController.text.trim(),
            vin: _vinController.text.trim().isEmpty ? null : _vinController.text.trim().toUpperCase(),
            make: _makeController.text.trim().isEmpty ? null : _makeController.text.trim(),
            model: _modelController.text.trim().isEmpty ? null : _modelController.text.trim(),
            year: _yearController.text.trim().isEmpty ? null : int.tryParse(_yearController.text.trim()),
            color: _colorController.text.trim().isEmpty ? null : _colorController.text.trim(),
          )
        : Vehicle(
            id: DateTime.now().millisecondsSinceEpoch.toString(),
            nickname: _nicknameController.text.trim(),
            vin: _vinController.text.trim().isEmpty ? null : _vinController.text.trim().toUpperCase(),
            make: _makeController.text.trim().isEmpty ? null : _makeController.text.trim(),
            model: _modelController.text.trim().isEmpty ? null : _modelController.text.trim(),
            year: _yearController.text.trim().isEmpty ? null : int.tryParse(_yearController.text.trim()),
            color: _colorController.text.trim().isEmpty ? null : _colorController.text.trim(),
            createdAt: DateTime.now(),
          );

    await VehicleService.save(vehicle);
    if (mounted) {
      Navigator.pop(context, vehicle);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.vehicle == null ? 'Add Vehicle' : 'Edit Vehicle'),
        backgroundColor: const Color(0xFFE91E63),
        foregroundColor: Colors.white,
        actions: [
          TextButton(
            onPressed: _save,
            child: const Text('Save'),
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Nickname (required)
            TextFormField(
              controller: _nicknameController,
              decoration: const InputDecoration(
                labelText: 'Nickname *',
                hintText: 'e.g., My Car, Mom\'s Car',
                border: OutlineInputBorder(),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Please enter a nickname';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),

            // VIN (optional)
            TextFormField(
              controller: _vinController,
              decoration: const InputDecoration(
                labelText: 'VIN',
                hintText: '17-character vehicle identification number',
                border: OutlineInputBorder(),
                helperText: 'Will be auto-detected when connected',
              ),
              maxLength: 17,
              textCapitalization: TextCapitalization.characters,
            ),
            const SizedBox(height: 16),

            // Make, Model, Year row
            Row(
              children: [
                Expanded(
                  flex: 2,
                  child: TextFormField(
                    controller: _makeController,
                    decoration: const InputDecoration(
                      labelText: 'Make',
                      hintText: 'e.g., Toyota',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: TextFormField(
                    controller: _modelController,
                    decoration: const InputDecoration(
                      labelText: 'Model',
                      hintText: 'e.g., Camry',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 1,
                  child: TextFormField(
                    controller: _yearController,
                    decoration: const InputDecoration(
                      labelText: 'Year',
                      hintText: '2024',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.number,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(4),
                    ],
                    validator: (value) {
                      if (value != null && value.isNotEmpty) {
                        final year = int.tryParse(value);
                        if (year == null || year < 1900 || year > DateTime.now().year + 1) {
                          return 'Invalid year';
                        }
                      }
                      return null;
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Color (optional)
            TextFormField(
              controller: _colorController,
              decoration: const InputDecoration(
                labelText: 'Color',
                hintText: 'e.g., Red, Blue, Black',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 24),

            // Info text
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.blueAccent, size: 20),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      widget.vehicle == null
                          ? 'You can connect to your vehicle later and the VIN will be auto-detected.'
                          : 'VIN will be updated automatically when you connect to this vehicle.',
                      style: TextStyle(fontSize: 12, color: Colors.white70),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

