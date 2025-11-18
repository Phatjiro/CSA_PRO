import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/vehicle.dart';
import '../services/vehicle_service.dart';
import '../data/car_makes.dart';

class VehicleFormScreen extends StatefulWidget {
  final Vehicle? vehicle;
  final bool isOnboarding;

  const VehicleFormScreen({super.key, this.vehicle, this.isOnboarding = false});

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
  final _makeSearchController = TextEditingController();
  int _onboardingStep = 0;
  String? _selectedMake;
  bool _showAdditionalFields = false;

  @override
  void initState() {
    super.initState();
    _makeController.text = widget.vehicle?.make ?? '';
    if (widget.vehicle != null) {
      _nicknameController.text = widget.vehicle!.nickname;
      _vinController.text = widget.vehicle!.vin ?? '';
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
    _makeSearchController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    if (widget.isOnboarding && _selectedMake != null) {
      _makeController.text = _selectedMake!;
    }

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
        automaticallyImplyLeading: !widget.isOnboarding,
        title: Text(
          widget.isOnboarding
              ? (_onboardingStep == 0 ? 'Choose your make' : 'Name your car')
              : widget.vehicle == null
                  ? 'Add Vehicle'
                  : 'Edit Vehicle',
        ),
        backgroundColor: const Color(0xFFE91E63),
        foregroundColor: Colors.white,
        actions: [
          if (!widget.isOnboarding)
            TextButton(
              onPressed: _save,
              child: const Text('Save'),
            ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: widget.isOnboarding ? _buildOnboardingContent() : _buildFullForm(),
      ),
    );
  }

  Widget _buildOnboardingContent() {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 300),
      child: _onboardingStep == 0 ? _buildMakeStep() : _buildNicknameStep(),
    );
  }

  Widget _buildMakeStep() {
    final makes = CarMakes.getAll()
        .where((make) => make.toLowerCase().contains(_makeSearchController.text.toLowerCase()))
        .toList();
    const accent = Color(0xFFE91E63);
    return Scaffold(
      key: const ValueKey('make-step'),
      backgroundColor: Colors.transparent,
      body: Column(
        children: [
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Select vehicle manufacturer',
                    style: TextStyle(fontSize: 16, color: Colors.white70),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _makeSearchController,
                    style: const TextStyle(color: Colors.white, fontSize: 16),
                    decoration: InputDecoration(
                      hintText: 'Search manufacturer...',
                      hintStyle: const TextStyle(color: Colors.white38),
                      prefixIcon: const Icon(Icons.search, color: Colors.white54),
                      filled: true,
                      fillColor: Colors.white.withValues(alpha: 0.08),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.15)),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.15)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: accent, width: 2),
                      ),
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                  const SizedBox(height: 16),
                  Expanded(
                    child: ListView.builder(
                      itemCount: makes.length,
                      itemBuilder: (context, index) {
                        final make = makes[index];
                        final selected = _selectedMake == make;
                        return Container(
                          margin: const EdgeInsets.only(bottom: 10),
                          child: Material(
                            color: Colors.transparent,
                            child: InkWell(
                              onTap: () => setState(() => _selectedMake = make),
                              borderRadius: BorderRadius.circular(12),
                              splashColor: accent.withValues(alpha: 0.25),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                                decoration: BoxDecoration(
                                  color: selected ? accent.withValues(alpha: 0.18) : Colors.white.withValues(alpha: 0.04),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: selected ? accent : Colors.white.withValues(alpha: 0.08),
                                    width: selected ? 2 : 1,
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        make,
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 16,
                                          fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
                                        ),
                                      ),
                                    ),
                                    if (selected)
                                      const Icon(Icons.check_circle, color: accent),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.15),
              border: Border(
                top: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
              ),
            ),
            child: SafeArea(
              top: false,
              child: Row(
                children: [
                  SizedBox(
                    width: 110,
                    child: OutlinedButton(
                      onPressed: () async {
                        // Skip: tự động tạo vehicle với nickname "My Car" và chuyển thẳng đến connect
                        _selectedMake = null;
                        _nicknameController.text = 'My Car';
                        
                        final vehicle = Vehicle(
                          id: DateTime.now().millisecondsSinceEpoch.toString(),
                          nickname: 'My Car',
                          vin: null,
                          make: null,
                          model: null,
                          year: null,
                          color: null,
                          createdAt: DateTime.now(),
                        );

                        await VehicleService.save(vehicle);
                        if (mounted) {
                          Navigator.pop(context, vehicle);
                        }
                      },
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white,
                        side: BorderSide(color: Colors.white.withValues(alpha: 0.4)),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: const Text(
                        'Skip',
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),
                  const Spacer(),
                  SizedBox(
                    width: 140,
                    child: ElevatedButton(
                      onPressed: () {
                        setState(() => _onboardingStep = 1);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: accent,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                      ),
                      child: const Text(
                        'Next',
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNicknameStep() {
    const accent = Color(0xFFE91E63);
    return Scaffold(
      key: const ValueKey('nickname-step'),
      backgroundColor: Colors.transparent,
      body: Column(
        children: [
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Name your car',
                    style: TextStyle(fontSize: 16, color: Colors.white70),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _nicknameController,
                    style: const TextStyle(color: Colors.white, fontSize: 16),
                    decoration: InputDecoration(
                      hintText: 'Enter vehicle nickname...',
                      hintStyle: const TextStyle(color: Colors.white38),
                      prefixIcon: const Icon(Icons.directions_car, color: Colors.white54),
                      filled: true,
                      fillColor: Colors.white.withValues(alpha: 0.08),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.15)),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.15)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: accent, width: 2),
                      ),
                      errorBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Colors.red, width: 1),
                      ),
                      focusedErrorBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Colors.red, width: 2),
                      ),
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Please enter a nickname';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  // Additional fields (collapsible)
                  InkWell(
                    onTap: () => setState(() => _showAdditionalFields = !_showAdditionalFields),
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.04),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.08),
                          width: 1,
                        ),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.info_outline, color: Colors.white54, size: 20),
                          const SizedBox(width: 12),
                          const Expanded(
                            child: Text(
                              'Additional information (optional)',
                              style: TextStyle(color: Colors.white70, fontSize: 14),
                            ),
                          ),
                          Icon(
                            _showAdditionalFields ? Icons.expand_less : Icons.expand_more,
                            color: Colors.white54,
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (_showAdditionalFields) ...[
                    const SizedBox(height: 12),
                    // VIN field
                    TextFormField(
                      controller: _vinController,
                      style: const TextStyle(color: Colors.white, fontSize: 14),
                      decoration: InputDecoration(
                        labelText: 'VIN (optional)',
                        labelStyle: const TextStyle(color: Colors.white54),
                        hintText: '17-character VIN',
                        hintStyle: const TextStyle(color: Colors.white38),
                        filled: true,
                        fillColor: Colors.white.withValues(alpha: 0.06),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide(color: accent.withValues(alpha: 0.5), width: 1.5),
                        ),
                      ),
                      maxLength: 17,
                      textCapitalization: TextCapitalization.characters,
                    ),
                    const SizedBox(height: 10),
                    // Model and Year in row
                    Row(
                      children: [
                        Expanded(
                          flex: 2,
                          child: TextFormField(
                            controller: _modelController,
                            style: const TextStyle(color: Colors.white, fontSize: 14),
                            decoration: InputDecoration(
                              labelText: 'Model (optional)',
                              labelStyle: const TextStyle(color: Colors.white54),
                              hintText: 'e.g., Camry',
                              hintStyle: const TextStyle(color: Colors.white38),
                              filled: true,
                              fillColor: Colors.white.withValues(alpha: 0.06),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                                borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                                borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                                borderSide: BorderSide(color: accent.withValues(alpha: 0.5), width: 1.5),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          flex: 1,
                          child: TextFormField(
                            controller: _yearController,
                            style: const TextStyle(color: Colors.white, fontSize: 14),
                            decoration: InputDecoration(
                              labelText: 'Year (optional)',
                              labelStyle: const TextStyle(color: Colors.white54),
                              hintText: '2024',
                              hintStyle: const TextStyle(color: Colors.white38),
                              filled: true,
                              fillColor: Colors.white.withValues(alpha: 0.06),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                                borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                                borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                                borderSide: BorderSide(color: accent.withValues(alpha: 0.5), width: 1.5),
                              ),
                            ),
                            keyboardType: TextInputType.number,
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly,
                              LengthLimitingTextInputFormatter(4),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    // Color field
                    TextFormField(
                      controller: _colorController,
                      style: const TextStyle(color: Colors.white, fontSize: 14),
                      decoration: InputDecoration(
                        labelText: 'Color (optional)',
                        labelStyle: const TextStyle(color: Colors.white54),
                        hintText: 'e.g., Red, Blue, Black',
                        hintStyle: const TextStyle(color: Colors.white38),
                        filled: true,
                        fillColor: Colors.white.withValues(alpha: 0.06),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide(color: accent.withValues(alpha: 0.5), width: 1.5),
                        ),
                      ),
                    ),
                  ],
                  const Spacer(),
                ],
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.15),
              border: Border(
                top: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
              ),
            ),
            child: SafeArea(
              top: false,
              child: Row(
                children: [
                  SizedBox(
                    width: 110,
                    child: OutlinedButton(
                      onPressed: () => setState(() => _onboardingStep = 0),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white,
                        side: BorderSide(color: Colors.white.withValues(alpha: 0.4)),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: const Text(
                        'Back',
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),
                  const Spacer(),
                  SizedBox(
                    width: 140,
                    child: ElevatedButton(
                      onPressed: () {
                        if (_formKey.currentState!.validate()) {
                          _save();
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: accent,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                      ),
                      child: const Text(
                        'Next',
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFullForm() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
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
        RawAutocomplete<String>(
          optionsBuilder: (textEditingValue) {
            final query = textEditingValue.text.trim().toLowerCase();
            if (query.isEmpty) {
              return CarMakes.getPopularOnly();
            }
            return CarMakes.getAll().where(
              (make) => make.toLowerCase().contains(query),
            );
          },
          onSelected: (selection) {
            _makeController.text = selection;
          },
          displayStringForOption: (option) => option,
          fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) {
            if (controller.text.isEmpty && _makeController.text.isNotEmpty) {
              controller.text = _makeController.text;
            }
            controller.addListener(() {
              if (_makeController.text != controller.text) {
                _makeController.text = controller.text;
              }
            });
            return TextFormField(
              controller: controller,
              focusNode: focusNode,
              decoration: const InputDecoration(
                labelText: 'Make',
                hintText: 'Start typing (e.g., Toyota)',
                border: OutlineInputBorder(),
              ),
            );
          },
          optionsViewBuilder: (context, onSelected, options) {
            if (options.isEmpty) {
              return const SizedBox.shrink();
            }
            return Align(
              alignment: Alignment.topLeft,
              child: Material(
                elevation: 4,
                borderRadius: BorderRadius.circular(8),
                child: SizedBox(
                  height: 200,
                  width: MediaQuery.of(context).size.width - 64,
                  child: ListView.builder(
                    padding: EdgeInsets.zero,
                    itemCount: options.length,
                    itemBuilder: (context, index) {
                      final option = options.elementAt(index);
                      return ListTile(
                        title: Text(option),
                        onTap: () => onSelected(option),
                      );
                    },
                  ),
                ),
              ),
            );
          },
        ),
        const SizedBox(height: 16),
        Row(
          children: [
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
        TextFormField(
          controller: _colorController,
          decoration: const InputDecoration(
            labelText: 'Color',
            hintText: 'e.g., Red, Blue, Black',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 24),
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
    );
  }
}

