import 'package:flutter/material.dart';
import 'package:flutter_car_scanner/services/connection_manager.dart';
import 'package:flutter_car_scanner/screens/live_data_chart_screen.dart';

enum LiveMetric {
  // Core metrics
  rpm, speed, coolant, intake, throttle, fuel, load, map, baro, maf, voltage, ambient, lambda,
  // Additional metrics from images
  fuelSystemStatus, timingAdvance, runtimeSinceStart, distanceWithMIL, commandedPurge,
  warmupsSinceClear, distanceSinceClear, catalystTemp, absoluteLoad, commandedEquivRatio,
  relativeThrottle, absoluteThrottleB, absoluteThrottleC, pedalPositionD, pedalPositionE,
  pedalPositionF, commandedThrottleActuator, timeRunWithMIL, timeSinceCodesCleared,
  maxEquivRatio, maxAirFlow, fuelType, ethanolFuel, absEvapPressure, evapPressure,
  shortTermO2Trim1, longTermO2Trim1, shortTermO2Trim2, longTermO2Trim2,
  shortTermO2Trim3, longTermO2Trim3, shortTermO2Trim4, longTermO2Trim4,
  catalystTemp1, catalystTemp2, catalystTemp3, catalystTemp4, fuelPressure,
  shortTermFuelTrim1, longTermFuelTrim1, shortTermFuelTrim2, longTermFuelTrim2
}

class LiveDataSelectScreen extends StatefulWidget {
  const LiveDataSelectScreen({super.key});

  @override
  State<LiveDataSelectScreen> createState() => _LiveDataSelectScreenState();
}

class _LiveDataSelectScreenState extends State<LiveDataSelectScreen> {
  final Map<LiveMetric, bool> _selected = {
    // Core metrics - some selected by default
    LiveMetric.rpm: true,
    LiveMetric.speed: true,
    LiveMetric.coolant: false,
    LiveMetric.intake: false,
    LiveMetric.throttle: false,
    LiveMetric.fuel: false,
    LiveMetric.load: false,
    LiveMetric.map: false,
    LiveMetric.baro: false,
    LiveMetric.maf: false,
    LiveMetric.voltage: false,
    LiveMetric.ambient: false,
    LiveMetric.lambda: false,
    // Additional metrics - all false by default
    LiveMetric.fuelSystemStatus: false,
    LiveMetric.timingAdvance: false,
    LiveMetric.runtimeSinceStart: false,
    LiveMetric.distanceWithMIL: false,
    LiveMetric.commandedPurge: false,
    LiveMetric.warmupsSinceClear: false,
    LiveMetric.distanceSinceClear: false,
    LiveMetric.catalystTemp: false,
    LiveMetric.absoluteLoad: false,
    LiveMetric.commandedEquivRatio: false,
    LiveMetric.relativeThrottle: false,
    LiveMetric.absoluteThrottleB: false,
    LiveMetric.absoluteThrottleC: false,
    LiveMetric.pedalPositionD: false,
    LiveMetric.pedalPositionE: false,
    LiveMetric.pedalPositionF: false,
    LiveMetric.commandedThrottleActuator: false,
    LiveMetric.timeRunWithMIL: false,
    LiveMetric.timeSinceCodesCleared: false,
    LiveMetric.maxEquivRatio: false,
    LiveMetric.maxAirFlow: false,
    LiveMetric.fuelType: false,
    LiveMetric.ethanolFuel: false,
    LiveMetric.absEvapPressure: false,
    LiveMetric.evapPressure: false,
    LiveMetric.shortTermO2Trim1: false,
    LiveMetric.longTermO2Trim1: false,
    LiveMetric.shortTermO2Trim2: false,
    LiveMetric.longTermO2Trim2: false,
    LiveMetric.shortTermO2Trim3: false,
    LiveMetric.longTermO2Trim3: false,
    LiveMetric.shortTermO2Trim4: false,
    LiveMetric.longTermO2Trim4: false,
    LiveMetric.catalystTemp1: false,
    LiveMetric.catalystTemp2: false,
    LiveMetric.catalystTemp3: false,
    LiveMetric.catalystTemp4: false,
    LiveMetric.fuelPressure: false,
    LiveMetric.shortTermFuelTrim1: false,
    LiveMetric.longTermFuelTrim1: false,
    LiveMetric.shortTermFuelTrim2: false,
    LiveMetric.longTermFuelTrim2: false,
  };

  String _searchQuery = '';

  List<LiveMetric> get _filteredMetrics {
    if (_searchQuery.isEmpty) return LiveMetric.values;
    return LiveMetric.values.where((metric) {
      final labels = <LiveMetric, String>{
        LiveMetric.rpm: 'Engine RPM',
        LiveMetric.speed: 'Vehicle speed',
        LiveMetric.coolant: 'Coolant temperature',
        LiveMetric.intake: 'Intake air temperature',
        LiveMetric.throttle: 'Throttle position',
        LiveMetric.fuel: 'Fuel level',
        LiveMetric.load: 'Engine load',
        LiveMetric.map: 'MAP (kPa)',
        LiveMetric.baro: 'Barometric pressure (kPa)',
        LiveMetric.maf: 'MAF (g/s)',
        LiveMetric.voltage: 'Control module voltage (V)',
        LiveMetric.ambient: 'Ambient temp (°C)',
        LiveMetric.lambda: 'Equivalence ratio (λ)',
        LiveMetric.fuelSystemStatus: 'Fuel system status',
        LiveMetric.timingAdvance: 'Timing advance',
        LiveMetric.runtimeSinceStart: 'Runtime since start',
        LiveMetric.distanceWithMIL: 'Distance with MIL on',
        LiveMetric.commandedPurge: 'Commanded purge',
        LiveMetric.warmupsSinceClear: 'Warm-ups since clear',
        LiveMetric.distanceSinceClear: 'Distance since clear',
        LiveMetric.catalystTemp: 'Catalyst temperature',
        LiveMetric.absoluteLoad: 'Absolute load value',
        LiveMetric.commandedEquivRatio: 'Commanded equiv ratio',
        LiveMetric.relativeThrottle: 'Relative throttle',
        LiveMetric.absoluteThrottleB: 'Absolute throttle B',
        LiveMetric.absoluteThrottleC: 'Absolute throttle C',
        LiveMetric.pedalPositionD: 'Pedal position D',
        LiveMetric.pedalPositionE: 'Pedal position E',
        LiveMetric.pedalPositionF: 'Pedal position F',
        LiveMetric.commandedThrottleActuator: 'Throttle actuator',
        LiveMetric.timeRunWithMIL: 'Time run with MIL',
        LiveMetric.timeSinceCodesCleared: 'Time since codes cleared',
        LiveMetric.maxEquivRatio: 'Max equiv ratio',
        LiveMetric.maxAirFlow: 'Max air flow',
        LiveMetric.fuelType: 'Fuel type',
        LiveMetric.ethanolFuel: 'Ethanol fuel %',
        LiveMetric.absEvapPressure: 'Abs evap pressure',
        LiveMetric.evapPressure: 'Evap pressure',
        LiveMetric.shortTermO2Trim1: 'ST O2 trim Bank 1',
        LiveMetric.longTermO2Trim1: 'LT O2 trim Bank 1',
        LiveMetric.shortTermO2Trim2: 'ST O2 trim Bank 2',
        LiveMetric.longTermO2Trim2: 'LT O2 trim Bank 2',
        LiveMetric.shortTermO2Trim3: 'ST O2 trim Bank 3',
        LiveMetric.longTermO2Trim3: 'LT O2 trim Bank 3',
        LiveMetric.shortTermO2Trim4: 'ST O2 trim Bank 4',
        LiveMetric.longTermO2Trim4: 'LT O2 trim Bank 4',
        LiveMetric.catalystTemp1: 'Catalyst temp 1',
        LiveMetric.catalystTemp2: 'Catalyst temp 2',
        LiveMetric.catalystTemp3: 'Catalyst temp 3',
        LiveMetric.catalystTemp4: 'Catalyst temp 4',
        LiveMetric.fuelPressure: 'Fuel pressure',
        LiveMetric.shortTermFuelTrim1: 'ST fuel trim Bank 1',
        LiveMetric.longTermFuelTrim1: 'LT fuel trim Bank 1',
        LiveMetric.shortTermFuelTrim2: 'ST fuel trim Bank 2',
        LiveMetric.longTermFuelTrim2: 'LT fuel trim Bank 2',
      };
      final label = labels[metric] ?? metric.name;
      return label.toLowerCase().contains(_searchQuery);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final labels = <LiveMetric, String>{
      // Core metrics
      LiveMetric.rpm: 'Engine RPM',
      LiveMetric.speed: 'Vehicle speed',
      LiveMetric.coolant: 'Coolant temperature',
      LiveMetric.intake: 'Intake air temperature',
      LiveMetric.throttle: 'Throttle position',
      LiveMetric.fuel: 'Fuel level',
      LiveMetric.load: 'Engine load',
      LiveMetric.map: 'MAP (kPa)',
      LiveMetric.baro: 'Barometric pressure (kPa)',
      LiveMetric.maf: 'MAF (g/s)',
      LiveMetric.voltage: 'Control module voltage (V)',
      LiveMetric.ambient: 'Ambient temp (°C)',
      LiveMetric.lambda: 'Equivalence ratio (λ)',
      // Additional metrics
      LiveMetric.fuelSystemStatus: 'Fuel system status',
      LiveMetric.timingAdvance: 'Timing advance',
      LiveMetric.runtimeSinceStart: 'Runtime since start',
      LiveMetric.distanceWithMIL: 'Distance with MIL on',
      LiveMetric.commandedPurge: 'Commanded purge',
      LiveMetric.warmupsSinceClear: 'Warm-ups since clear',
      LiveMetric.distanceSinceClear: 'Distance since clear',
      LiveMetric.catalystTemp: 'Catalyst temperature',
      LiveMetric.absoluteLoad: 'Absolute load value',
      LiveMetric.commandedEquivRatio: 'Commanded equiv ratio',
      LiveMetric.relativeThrottle: 'Relative throttle',
      LiveMetric.absoluteThrottleB: 'Absolute throttle B',
      LiveMetric.absoluteThrottleC: 'Absolute throttle C',
      LiveMetric.pedalPositionD: 'Pedal position D',
      LiveMetric.pedalPositionE: 'Pedal position E',
      LiveMetric.pedalPositionF: 'Pedal position F',
      LiveMetric.commandedThrottleActuator: 'Throttle actuator',
      LiveMetric.timeRunWithMIL: 'Time run with MIL',
      LiveMetric.timeSinceCodesCleared: 'Time since codes cleared',
      LiveMetric.maxEquivRatio: 'Max equiv ratio',
      LiveMetric.maxAirFlow: 'Max air flow',
      LiveMetric.fuelType: 'Fuel type',
      LiveMetric.ethanolFuel: 'Ethanol fuel %',
      LiveMetric.absEvapPressure: 'Abs evap pressure',
      LiveMetric.evapPressure: 'Evap pressure',
      LiveMetric.shortTermO2Trim1: 'ST O2 trim Bank 1',
      LiveMetric.longTermO2Trim1: 'LT O2 trim Bank 1',
      LiveMetric.shortTermO2Trim2: 'ST O2 trim Bank 2',
      LiveMetric.longTermO2Trim2: 'LT O2 trim Bank 2',
      LiveMetric.shortTermO2Trim3: 'ST O2 trim Bank 3',
      LiveMetric.longTermO2Trim3: 'LT O2 trim Bank 3',
      LiveMetric.shortTermO2Trim4: 'ST O2 trim Bank 4',
      LiveMetric.longTermO2Trim4: 'LT O2 trim Bank 4',
      LiveMetric.catalystTemp1: 'Catalyst temp 1',
      LiveMetric.catalystTemp2: 'Catalyst temp 2',
      LiveMetric.catalystTemp3: 'Catalyst temp 3',
      LiveMetric.catalystTemp4: 'Catalyst temp 4',
      LiveMetric.fuelPressure: 'Fuel pressure',
      LiveMetric.shortTermFuelTrim1: 'ST fuel trim Bank 1',
      LiveMetric.longTermFuelTrim1: 'LT fuel trim Bank 1',
      LiveMetric.shortTermFuelTrim2: 'ST fuel trim Bank 2',
      LiveMetric.longTermFuelTrim2: 'LT fuel trim Bank 2',
    };

    return Scaffold(
      appBar: AppBar(
        title: const Text('Select Live Data'),
        backgroundColor: const Color(0xFF2E7D32),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Column(
        children: [
          // Compact header
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            color: const Color(0xFF2E7D32).withOpacity(0.1),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Select metrics to display',
                  style: TextStyle(fontSize: 14, color: Colors.grey[700]),
                ),
                Text(
                  '${_selected.values.where((v) => v).length} selected',
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
          // Compact metrics list with search
          Expanded(
            child: Column(
              children: [
                // Search bar
                Container(
                  padding: const EdgeInsets.all(16),
                  child: TextField(
                    decoration: InputDecoration(
                      hintText: 'Search metrics...',
                      prefixIcon: const Icon(Icons.search, size: 20),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(color: Colors.grey[300]!),
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                    onChanged: (value) {
                      setState(() {
                        _searchQuery = value.toLowerCase();
                      });
                    },
                  ),
                ),
                // Filtered metrics list
                Expanded(
                  child: Theme(
                    data: Theme.of(context).copyWith(
                      checkboxTheme: CheckboxThemeData(
                        side: BorderSide(color: Colors.white.withOpacity(0.5)),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                        fillColor: MaterialStateProperty.resolveWith((states) {
                          if (states.contains(MaterialState.selected)) return const Color(0xFF2E7D32);
                          return Colors.transparent; // tránh chói trên nền tối khi chưa chọn
                        }),
                        checkColor: MaterialStateProperty.all(Colors.white),
                      ),
                    ),
                    child: ListView.builder(
                      padding: const EdgeInsets.only(bottom: 12),
                      itemCount: _filteredMetrics.length,
                      itemBuilder: (context, index) {
                      final metric = _filteredMetrics[index];
                      final isSelected = _selected[metric] ?? false;
                      final label = labels[metric] ?? metric.name;

                        return Container(
                        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
                        decoration: BoxDecoration(
                            color: isSelected 
                                ? const Color(0xFF2E7D32).withOpacity(0.12)
                                : Colors.white.withOpacity(0.04),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                              color: isSelected 
                                  ? const Color(0xFF2E7D32)
                                  : Colors.white.withOpacity(0.08),
                            width: 1,
                          ),
                        ),
                        child: CheckboxListTile(
                          title: Text(
                            label,
                            style: TextStyle(
                              fontSize: 13,
                                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                                color: isSelected ? const Color(0xFF2E7D32) : Colors.white70,
                            ),
                          ),
                          value: isSelected,
                          onChanged: (value) {
                            setState(() {
                              _selected[metric] = value ?? false;
                            });
                          },
                          activeColor: const Color(0xFF2E7D32),
                          dense: true,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        ),
                      );
                    },
                  ),
                ),
                ),
              ],
            ),
          ),
          // Compact action buttons (SafeArea để không bị che bởi bottom bar)
          SafeArea(
            top: false,
            child: Container(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.white.withOpacity(0.04),
                    Colors.white.withOpacity(0.02),
                  ],
                ),
                border: Border(
                  top: BorderSide(color: Colors.white.withOpacity(0.06), width: 1),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.25),
                    blurRadius: 12,
                    offset: const Offset(0, -6),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () {
                        setState(() {
                          _selected.updateAll((key, value) => false);
                        });
                      },
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        foregroundColor: Colors.white,
                        side: BorderSide(color: Colors.white.withOpacity(0.24), width: 1),
                      ),
                      child: const Text('Clear All'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _selected.values.any((v) => v)
                          ? () {
                              final selectedMetrics = _selected.entries
                                  .where((e) => e.value)
                                  .map((e) => e.key)
                                  .toList();
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => LiveDataChartScreen(
                                    selectedMetrics: selectedMetrics,
                                    client: ConnectionManager.instance.client!,
                                  ),
                                ),
                              );
                            }
                          : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF2E7D32),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        elevation: 0,
                      ),
                      child: const Text('View Chart'),
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
}