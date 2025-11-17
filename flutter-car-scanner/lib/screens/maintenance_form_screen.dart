import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/maintenance_item.dart';
import '../services/maintenance_service.dart';
import '../utils/maintenance_templates.dart';

class MaintenanceFormScreen extends StatefulWidget {
  final String vehicleId;
  final MaintenanceItem? item;

  const MaintenanceFormScreen({
    super.key,
    required this.vehicleId,
    this.item,
  });

  @override
  State<MaintenanceFormScreen> createState() => _MaintenanceFormScreenState();
}

class _MaintenanceFormScreenState extends State<MaintenanceFormScreen> {
  final _formKey = GlobalKey<FormState>();
  String? _selectedTemplate;
  final _nameController = TextEditingController();
  final _intervalKmController = TextEditingController();
  final _intervalDaysController = TextEditingController();
  final _lastKmController = TextEditingController();
  DateTime? _lastDoneDate;

  @override
  void initState() {
    super.initState();
    if (widget.item != null) {
      _nameController.text = widget.item!.name;
      _intervalKmController.text = widget.item!.intervalKm.toString();
      _intervalDaysController.text = widget.item!.intervalDays.toString();
      _lastKmController.text = widget.item!.lastDoneKm?.toString() ?? '';
      _lastDoneDate = widget.item!.lastDoneDate;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _intervalKmController.dispose();
    _intervalDaysController.dispose();
    _lastKmController.dispose();
    super.dispose();
  }

  void _onTemplateSelected(String? templateKey) {
    if (templateKey == null || templateKey.isEmpty) return;

    final template = MaintenanceTemplates.getTemplate(templateKey);
    if (template != null) {
      setState(() {
        _selectedTemplate = templateKey;
        _nameController.text = template.name;
        _intervalKmController.text = template.intervalKm.toString();
        _intervalDaysController.text = template.intervalDays.toString();
      });
    }
  }

  Future<void> _selectDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _lastDoneDate ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      setState(() => _lastDoneDate = picked);
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    final intervalKm = int.parse(_intervalKmController.text);
    final intervalDays = int.parse(_intervalDaysController.text);
    final lastDoneKm = _lastKmController.text.isEmpty
        ? null
        : int.tryParse(_lastKmController.text);

    final item = widget.item != null
        ? widget.item!.copyWith(
            name: _nameController.text.trim(),
            intervalKm: intervalKm,
            intervalDays: intervalDays,
            lastDoneDate: _lastDoneDate,
            lastDoneKm: lastDoneKm,
          )
        : MaintenanceItem(
            id: DateTime.now().millisecondsSinceEpoch.toString(),
            vehicleId: widget.vehicleId,
            name: _nameController.text.trim(),
            intervalKm: intervalKm,
            intervalDays: intervalDays,
            lastDoneDate: _lastDoneDate,
            lastDoneKm: lastDoneKm,
            createdAt: DateTime.now(),
          );

    await MaintenanceService.save(item);
    if (mounted) {
      Navigator.pop(context, item);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.item == null ? 'Add Maintenance' : 'Edit Maintenance'),
        backgroundColor: const Color(0xFFE91E63),
        foregroundColor: Colors.white,
        actions: [
          TextButton(
            onPressed: _save,
            child: const Text('Save', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Quick templates
            Card(
              color: Colors.blue.withValues(alpha: 0.1),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.auto_awesome, color: Colors.blueAccent, size: 20),
                        const SizedBox(width: 8),
                        const Text(
                          'Quick Add',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: MaintenanceTemplates.templateKeys.map((key) {
                        final template = MaintenanceTemplates.getTemplate(key)!;
                        return FilterChip(
                          label: Text(template.name),
                          selected: _selectedTemplate == key,
                          onSelected: (selected) {
                            if (selected) {
                              _onTemplateSelected(key);
                            } else {
                              setState(() => _selectedTemplate = null);
                            }
                          },
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Name
            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Name *',
                hintText: 'e.g., Oil Change',
                border: OutlineInputBorder(),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Please enter a name';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),

            // Interval
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _intervalKmController,
                    decoration: const InputDecoration(
                      labelText: 'Every (km) *',
                      hintText: '5000',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Required';
                      }
                      final km = int.tryParse(value);
                      if (km == null || km <= 0) {
                        return 'Invalid';
                      }
                      return null;
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _intervalDaysController,
                    decoration: const InputDecoration(
                      labelText: 'Every (days) *',
                      hintText: '180',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Required';
                      }
                      final days = int.tryParse(value);
                      if (days == null || days <= 0) {
                        return 'Invalid';
                      }
                      return null;
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Example: Every 5000 km or 180 days (6 months)',
              style: TextStyle(fontSize: 11, color: Colors.white70),
            ),
            const SizedBox(height: 16),

            // Last done
            Text(
              'Last Done (Optional)',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colors.white70,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: InkWell(
                    onTap: _selectDate,
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.white30),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.calendar_today, size: 20, color: Colors.white70),
                          const SizedBox(width: 12),
                          Text(
                            _lastDoneDate != null
                                ? '${_lastDoneDate!.day}/${_lastDoneDate!.month}/${_lastDoneDate!.year}'
                                : 'Select date',
                            style: TextStyle(
                              color: _lastDoneDate != null
                                  ? Colors.white
                                  : Colors.white60,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _lastKmController,
                    decoration: const InputDecoration(
                      labelText: 'At km',
                      hintText: '48000',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Fill this to track when maintenance was last done',
              style: TextStyle(fontSize: 11, color: Colors.white70),
            ),
          ],
        ),
      ),
    );
  }
}

