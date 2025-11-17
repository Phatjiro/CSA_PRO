import 'package:flutter/material.dart';
import 'dart:async';
import '../services/connection_manager.dart';
import '../models/obd_live_data.dart';

class AllSensorsScreen extends StatefulWidget {
  const AllSensorsScreen({super.key});

  @override
  State<AllSensorsScreen> createState() => _AllSensorsScreenState();
}

class _AllSensorsScreenState extends State<AllSensorsScreen> {
  StreamSubscription<ObdLiveData>? _subscription;
  ObdLiveData? _liveData;
  String _filterCategory = 'All';
  
  final List<String> _categories = [
    'All',
    'Engine',
    'Temperature',
    'Fuel',
    'Air',
    'Throttle',
    'O2 Sensors',
    'Calculated',
    'Advanced',
  ];

  Set<String>? _previousEnabledPids;

  @override
  void initState() {
    super.initState();
    _enableAllPids();
    _startListening();
  }

  @override
  void dispose() {
    _subscription?.cancel();
    _restorePreviousPids();
    super.dispose();
  }

  void _enableAllPids() {
    final client = ConnectionManager.instance.client;
    if (client == null) return;
    
    // Save current enabled PIDs
    _previousEnabledPids = Set<String>.from(client.enabledPids);
    
    // Enable ALL PIDs for All Sensors screen - với async polling sẽ nhanh!
    client.setEnabledPids({
      '010C', '010D', '0105', '010F', '0111', '012F', '0104', '010B', '0133',
      '0110', '0142', '0146', '015E', '0103', '010E', '011F', '0121', '012E',
      '0130', '0131', '013C', '0143', '0144', '0145', '0147', '0148', '0149',
      '014A', '014B', '014C', '014D', '014E', '014F', '0150', '0151', '0152',
      '0153', '0154', '0155', '0156', '0157', '0158', '0159', '015A', '015B',
      '015C', '015F', '0160', '0106', '0107', '0108', '0109', '010A',
      '013D', '013E', '013F',
      // New PIDs - O2 Sensors (0114-011B), Oil Temp (015C), Fuel Rate (015F), Torque (0161-0163)
      '0114', '0115', '0116', '0117', '0118', '0119', '011A', '011B',
      '0161', '0162', '0163',
    });
    
    // Trigger immediate poll to refresh data
    client.pollNow();
  }

  void _restorePreviousPids() {
    final client = ConnectionManager.instance.client;
    if (client == null || _previousEnabledPids == null) return;
    
    // Restore previous enabled PIDs when leaving screen
    client.setEnabledPids(_previousEnabledPids!);
  }

  void _startListening() {
    final client = ConnectionManager.instance.client;
    if (client == null) return;
    
    _subscription = client.dataStream.listen((data) {
      if (mounted) {
        setState(() {
          _liveData = data;
        });
      }
    });
  }

  String _formatValue(int value, String fallback) {
    return value == 0 ? fallback : '$value';
  }
  
  String _formatDoubleValue(double value, String fallback) {
    return value == 0.0 ? fallback : value.toStringAsFixed(2);
  }

  List<_SensorItem> _getAllSensors() {
    if (_liveData == null) return [];
    
    final all = <_SensorItem>[
      // Engine (Always polled)
      _SensorItem('Engine RPM', '${_liveData!.engineRpm}', 'RPM', Icons.speed, 'Engine'),
      _SensorItem('Vehicle Speed', '${_liveData!.vehicleSpeedKmh}', 'km/h', Icons.speed, 'Engine'),
      _SensorItem('Engine Load', '${_liveData!.engineLoadPercent}', '%', Icons.tune, 'Engine'),
      _SensorItem('Timing Advance', '${_liveData!.timingAdvance}', '°', Icons.access_time, 'Engine'),
      _SensorItem('Runtime Since Start', '${_liveData!.runtimeSinceStart}', 's', Icons.timer, 'Engine'),
      
      // Temperature
      _SensorItem('Coolant Temp', '${_liveData!.coolantTempC}', '°C', Icons.thermostat, 'Temperature'),
      _SensorItem('Intake Air Temp', '${_liveData!.intakeTempC}', '°C', Icons.air, 'Temperature'),
      _SensorItem('Ambient Temp', '${_liveData!.ambientTempC}', '°C', Icons.wb_sunny, 'Temperature'),
      _SensorItem('Catalyst Temp', '${_liveData!.catalystTemp}', '°C', Icons.filter_alt, 'Temperature'),
      _SensorItem('Catalyst Temp B1S1', '${_liveData!.catalystTemp1}', '°C', Icons.filter_1, 'Temperature'),
      _SensorItem('Catalyst Temp B2S1', '${_liveData!.catalystTemp2}', '°C', Icons.filter_2, 'Temperature'),
      _SensorItem('Catalyst Temp B1S2', '${_liveData!.catalystTemp3}', '°C', Icons.filter_3, 'Temperature'),
      _SensorItem('Catalyst Temp B2S2', '${_liveData!.catalystTemp4}', '°C', Icons.filter_4, 'Temperature'),
      
      // Fuel
      _SensorItem('Fuel Level', '${_liveData!.fuelLevelPercent}', '%', Icons.local_gas_station, 'Fuel'),
      _SensorItem('Fuel System Status', '${_liveData!.fuelSystemStatus}', '', Icons.settings, 'Fuel'),
      _SensorItem('Fuel Type', '${_liveData!.fuelType}', '', Icons.oil_barrel, 'Fuel'),
      _SensorItem('Fuel Pressure', '${_liveData!.fuelPressure}', 'kPa', Icons.compress, 'Fuel'),
      _SensorItem('Ethanol Fuel', '${_liveData!.ethanolFuel}', '%', Icons.eco, 'Fuel'),
      _SensorItem('Lambda', '${_liveData!.lambda.toStringAsFixed(2)}', '', Icons.analytics, 'Fuel'),
      _SensorItem('Commanded Equiv Ratio', '${_liveData!.commandedEquivRatio.toStringAsFixed(2)}', '', Icons.balance, 'Fuel'),
      _SensorItem('Max Equiv Ratio', '${_liveData!.maxEquivRatio.toStringAsFixed(2)}', '', Icons.trending_up, 'Fuel'),
      _SensorItem('Short Term Fuel Trim 1', '${_liveData!.shortTermFuelTrim1}', '%', Icons.tune, 'Fuel'),
      _SensorItem('Long Term Fuel Trim 1', '${_liveData!.longTermFuelTrim1}', '%', Icons.tune, 'Fuel'),
      _SensorItem('Short Term Fuel Trim 2', '${_liveData!.shortTermFuelTrim2}', '%', Icons.tune, 'Fuel'),
      _SensorItem('Long Term Fuel Trim 2', '${_liveData!.longTermFuelTrim2}', '%', Icons.tune, 'Fuel'),
      
      // Air
      _SensorItem('MAF', '${_liveData!.mafGs}', 'g/s', Icons.air, 'Air'),
      _SensorItem('MAP', '${_liveData!.mapKpa}', 'kPa', Icons.compress, 'Air'),
      _SensorItem('Barometric Pressure', '${_liveData!.baroKpa}', 'kPa', Icons.speed, 'Air'),
      _SensorItem('Max Air Flow', '${_liveData!.maxAirFlow}', 'g/s', Icons.arrow_upward, 'Air'),
      
      // Throttle
      _SensorItem('Throttle Position', '${_liveData!.throttlePositionPercent}', '%', Icons.speed, 'Throttle'),
      _SensorItem('Relative Throttle', '${_liveData!.relativeThrottle}', '%', Icons.straighten, 'Throttle'),
      _SensorItem('Absolute Throttle B', '${_liveData!.absoluteThrottleB}', '%', Icons.straighten, 'Throttle'),
      _SensorItem('Absolute Throttle C', '${_liveData!.absoluteThrottleC}', '%', Icons.straighten, 'Throttle'),
      _SensorItem('Pedal Position D', '${_liveData!.pedalPositionD}', '%', Icons.pedal_bike, 'Throttle'),
      _SensorItem('Pedal Position E', '${_liveData!.pedalPositionE}', '%', Icons.pedal_bike, 'Throttle'),
      _SensorItem('Pedal Position F', '${_liveData!.pedalPositionF}', '%', Icons.pedal_bike, 'Throttle'),
      _SensorItem('Commanded Throttle Actuator', '${_liveData!.commandedThrottleActuator}', '%', Icons.settings_input_component, 'Throttle'),
      
      // Advanced
      _SensorItem('Battery Voltage', '${_liveData!.voltageV.toStringAsFixed(1)}', 'V', Icons.battery_full, 'Advanced'),
      _SensorItem('Absolute Load', '${_liveData!.absoluteLoad}', '%', Icons.fitness_center, 'Advanced'),
      _SensorItem('Distance With MIL', '${_liveData!.distanceWithMIL}', 'km', Icons.warning, 'Advanced'),
      _SensorItem('Commanded Purge', '${_liveData!.commandedPurge}', '%', Icons.air, 'Advanced'),
      _SensorItem('Warmups Since Clear', '${_liveData!.warmupsSinceClear}', '', Icons.wb_sunny, 'Advanced'),
      _SensorItem('Distance Since Clear', '${_liveData!.distanceSinceClear}', 'km', Icons.straighten, 'Advanced'),
      _SensorItem('Time Run With MIL', '${_liveData!.timeRunWithMIL}', 'min', Icons.timer, 'Advanced'),
      _SensorItem('Time Since Codes Cleared', '${_liveData!.timeSinceCodesCleared}', 'min', Icons.timer_off, 'Advanced'),
      _SensorItem('Abs Evap Pressure', '${_liveData!.absEvapPressure}', 'kPa', Icons.compress, 'Advanced'),
      _SensorItem('Evap Pressure', '${_liveData!.evapPressure}', 'kPa', Icons.compress, 'Advanced'),
      _SensorItem('Short Term O2 Trim 1', '${_liveData!.shortTermO2Trim1}', '%', Icons.tune, 'Advanced'),
      _SensorItem('Long Term O2 Trim 1', '${_liveData!.longTermO2Trim1}', '%', Icons.tune, 'Advanced'),
      _SensorItem('Short Term O2 Trim 2', '${_liveData!.shortTermO2Trim2}', '%', Icons.tune, 'Advanced'),
      _SensorItem('Long Term O2 Trim 2', '${_liveData!.longTermO2Trim2}', '%', Icons.tune, 'Advanced'),
      _SensorItem('Short Term O2 Trim 3', '${_liveData!.shortTermO2Trim3}', '%', Icons.tune, 'Advanced'),
      _SensorItem('Long Term O2 Trim 3', '${_liveData!.longTermO2Trim3}', '%', Icons.tune, 'Advanced'),
      _SensorItem('Short Term O2 Trim 4', '${_liveData!.shortTermO2Trim4}', '%', Icons.tune, 'Advanced'),
      _SensorItem('Long Term O2 Trim 4', '${_liveData!.longTermO2Trim4}', '%', Icons.tune, 'Advanced'),
      
      // O2 Sensors (voltage)
      _SensorItem('O2 Sensor 1 Voltage', '${_liveData!.o2SensorVoltage1.toStringAsFixed(3)}', 'V', Icons.sensors, 'O2 Sensors'),
      _SensorItem('O2 Sensor 2 Voltage', '${_liveData!.o2SensorVoltage2.toStringAsFixed(3)}', 'V', Icons.sensors, 'O2 Sensors'),
      _SensorItem('O2 Sensor 3 Voltage', '${_liveData!.o2SensorVoltage3.toStringAsFixed(3)}', 'V', Icons.sensors, 'O2 Sensors'),
      _SensorItem('O2 Sensor 4 Voltage', '${_liveData!.o2SensorVoltage4.toStringAsFixed(3)}', 'V', Icons.sensors, 'O2 Sensors'),
      _SensorItem('O2 Sensor 5 Voltage', '${_liveData!.o2SensorVoltage5.toStringAsFixed(3)}', 'V', Icons.sensors, 'O2 Sensors'),
      _SensorItem('O2 Sensor 6 Voltage', '${_liveData!.o2SensorVoltage6.toStringAsFixed(3)}', 'V', Icons.sensors, 'O2 Sensors'),
      _SensorItem('O2 Sensor 7 Voltage', '${_liveData!.o2SensorVoltage7.toStringAsFixed(3)}', 'V', Icons.sensors, 'O2 Sensors'),
      _SensorItem('O2 Sensor 8 Voltage', '${_liveData!.o2SensorVoltage8.toStringAsFixed(3)}', 'V', Icons.sensors, 'O2 Sensors'),
      
      // Engine Performance
      _SensorItem('Engine Oil Temp', '${_liveData!.engineOilTempC}', '°C', Icons.oil_barrel, 'Engine'),
      _SensorItem('Engine Fuel Rate', '${_liveData!.engineFuelRate.toStringAsFixed(2)}', 'L/h', Icons.local_gas_station, 'Fuel'),
      _SensorItem('Driver Demand Torque', '${_liveData!.driverDemandTorque}', '%', Icons.drive_eta, 'Engine'),
      _SensorItem('Actual Torque', '${_liveData!.actualTorque}', '%', Icons.speed, 'Engine'),
      _SensorItem('Reference Torque', '${_liveData!.referenceTorque}', 'Nm', Icons.fitness_center, 'Engine'),
      
      // Calculated Values
      _SensorItem('Fuel Economy', '${_liveData!.fuelEconomyL100km.toStringAsFixed(1)}', 'L/100km', Icons.eco, 'Calculated'),
      _SensorItem('Engine Power', '${_liveData!.enginePowerKw.toStringAsFixed(1)}', 'kW', Icons.power, 'Calculated'),
      _SensorItem('Engine Power', '${_liveData!.enginePowerHp.toStringAsFixed(1)}', 'HP', Icons.power_settings_new, 'Calculated'),
      _SensorItem('Acceleration', '${_liveData!.acceleration.toStringAsFixed(2)}', 'm/s²', Icons.speed, 'Calculated'),
      _SensorItem('Air/Fuel Ratio', '${_liveData!.airFuelRatio.toStringAsFixed(2)}', 'AFR', Icons.air, 'Calculated'),
      _SensorItem('Volumetric Efficiency', '${_liveData!.volumetricEfficiency.toStringAsFixed(1)}', '%', Icons.donut_large, 'Calculated'),
      _SensorItem('Average Speed', '${_liveData!.averageSpeed.toStringAsFixed(1)}', 'km/h', Icons.av_timer, 'Calculated'),
      _SensorItem('Distance Traveled', '${_liveData!.distanceTraveled.toStringAsFixed(2)}', 'km', Icons.straighten, 'Calculated'),
      _SensorItem('Trip Time', '${(_liveData!.tripTime ~/ 60)}', 'min', Icons.timer, 'Calculated'),
    ];
    
    // Filter by category
    if (_filterCategory == 'All') {
      return all;
    }
    return all.where((s) => s.category == _filterCategory).toList();
  }

  void _showCategoryDialog() {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: const Color(0xFF16213E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Filter by Category',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              ..._categories.map((cat) {
                final isSelected = _filterCategory == cat;
                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: isSelected ? const Color(0xFF2ECC71) : Colors.white24,
                      width: isSelected ? 2 : 1,
                    ),
                  ),
                  child: Material(
                    color: isSelected ? const Color(0xFF2ECC71).withOpacity(0.2) : Colors.transparent,
                    borderRadius: BorderRadius.circular(8),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(8),
                      onTap: () {
                        setState(() {
                          _filterCategory = cat;
                        });
                        Navigator.pop(context);
                      },
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                        child: Row(
                          children: [
                            if (isSelected)
                              const Icon(Icons.check_circle, color: Color(0xFF2ECC71), size: 24),
                            if (isSelected)
                              const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                cat,
                                style: TextStyle(
                                  color: isSelected ? const Color(0xFF2ECC71) : Colors.white,
                                  fontSize: 16,
                                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final sensors = _getAllSensors();
    
    return Scaffold(
      backgroundColor: const Color(0xFF1A1A2E),
      appBar: AppBar(
        backgroundColor: const Color(0xFF2ECC71),
        foregroundColor: Colors.white,
        title: const Text('All Sensors'),
        actions: [
          IconButton(
            icon: const Icon(Icons.filter_list),
            onPressed: () => _showCategoryDialog(),
          ),
        ],
      ),
      body: _liveData == null
        ? Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF2ECC71)),
                ),
                const SizedBox(height: 16),
                Text(
                  'Loading sensors...',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.7),
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          )
        : Column(
            children: [
              // Summary header
              Container(
                padding: const EdgeInsets.all(16),
                margin: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      const Color(0xFF2ECC71).withValues(alpha: 0.2),
                      const Color(0xFF2ECC71).withValues(alpha: 0.05),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: const Color(0xFF2ECC71).withValues(alpha: 0.3),
                    width: 1,
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _SummaryItem(
                      icon: Icons.sensors,
                      label: 'Total Sensors',
                      value: '${sensors.length}',
                    ),
                    Container(
                      width: 1,
                      height: 40,
                      color: Colors.white.withValues(alpha: 0.1),
                    ),
                    _SummaryItem(
                      icon: Icons.category,
                      label: 'Category',
                      value: _filterCategory,
                    ),
                    Container(
                      width: 1,
                      height: 40,
                      color: Colors.white.withValues(alpha: 0.1),
                    ),
                    _SummaryItem(
                      icon: Icons.refresh,
                      label: 'Live',
                      value: 'Active',
                      valueColor: const Color(0xFF2ECC71),
                    ),
                  ],
                ),
              ),
              
              // Sensors list
              Expanded(
                child: SafeArea(
                  bottom: true,
                  child: ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    itemCount: sensors.length,
                    itemBuilder: (context, index) {
                      final sensor = sensors[index];
                      return _SensorCard(sensor: sensor);
                    },
                  ),
                ),
              ),
            ],
          ),
    );
  }
}

class _SensorItem {
  final String name;
  final String value;
  final String unit;
  final IconData icon;
  final String category;
  
  const _SensorItem(this.name, this.value, this.unit, this.icon, this.category);
}

class _SensorCard extends StatelessWidget {
  final _SensorItem sensor;
  
  const _SensorCard({required this.sensor});
  
  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.white.withValues(alpha: 0.08),
            Colors.white.withValues(alpha: 0.02),
          ],
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.1),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          // Icon
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: [
                  const Color(0xFF2ECC71).withValues(alpha: 0.3),
                  const Color(0xFF2ECC71).withValues(alpha: 0.1),
                ],
              ),
            ),
            child: Icon(
              sensor.icon,
              color: const Color(0xFF2ECC71),
              size: 22,
            ),
          ),
          const SizedBox(width: 12),
          
          // Name
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  sensor.name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  sensor.category,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.5),
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          
          // Value
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFF2ECC71).withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: const Color(0xFF2ECC71).withValues(alpha: 0.3),
                width: 1,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  sensor.value,
                  style: const TextStyle(
                    color: Color(0xFF2ECC71),
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (sensor.unit.isNotEmpty) ...[
                  const SizedBox(width: 4),
                  Text(
                    sensor.unit,
                    style: TextStyle(
                      color: const Color(0xFF2ECC71).withValues(alpha: 0.7),
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SummaryItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color? valueColor;
  
  const _SummaryItem({
    required this.icon,
    required this.label,
    required this.value,
    this.valueColor,
  });
  
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(
          icon,
          color: const Color(0xFF2ECC71),
          size: 24,
        ),
        const SizedBox(height: 6),
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.6),
            fontSize: 11,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: TextStyle(
            color: valueColor ?? Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

