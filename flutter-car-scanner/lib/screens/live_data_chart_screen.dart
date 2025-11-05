import 'dart:async';

import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter_car_scanner/models/obd_live_data.dart';
import 'package:flutter_car_scanner/services/obd_client.dart';
import 'package:flutter_car_scanner/screens/live_data_select_screen.dart';

class LiveDataChartScreen extends StatefulWidget {
  final List<LiveMetric> selectedMetrics;
  final ObdClient client;

  const LiveDataChartScreen({
    super.key,
    required this.selectedMetrics,
    required this.client,
  });

  @override
  State<LiveDataChartScreen> createState() => _LiveDataChartScreenState();
}

class _LiveDataChartScreenState extends State<LiveDataChartScreen> {
  // Data storage for each metric
  final List<FlSpot> _rpm = [];
  final List<FlSpot> _speed = [];
  final List<FlSpot> _coolant = [];
  final List<FlSpot> _intake = [];
  final List<FlSpot> _throttle = [];
  final List<FlSpot> _fuel = [];
  final List<FlSpot> _load = [];
  final List<FlSpot> _map = [];
  final List<FlSpot> _baro = [];
  final List<FlSpot> _maf = [];
  final List<FlSpot> _voltage = [];
  final List<FlSpot> _ambient = [];
  final List<FlSpot> _lambda = [];
  final List<FlSpot> _fuelSystemStatus = [];
  final List<FlSpot> _timingAdvance = [];
  final List<FlSpot> _runtimeSinceStart = [];
  final List<FlSpot> _distanceWithMIL = [];
  final List<FlSpot> _commandedPurge = [];
  final List<FlSpot> _warmupsSinceClear = [];
  final List<FlSpot> _distanceSinceClear = [];
  final List<FlSpot> _catalystTemp = [];
  final List<FlSpot> _absoluteLoad = [];
  final List<FlSpot> _commandedEquivRatio = [];
  final List<FlSpot> _relativeThrottle = [];
  final List<FlSpot> _absoluteThrottleB = [];
  final List<FlSpot> _absoluteThrottleC = [];
  final List<FlSpot> _pedalPositionD = [];
  final List<FlSpot> _pedalPositionE = [];
  final List<FlSpot> _pedalPositionF = [];
  final List<FlSpot> _commandedThrottleActuator = [];
  final List<FlSpot> _timeRunWithMIL = [];
  final List<FlSpot> _timeSinceCodesCleared = [];
  final List<FlSpot> _maxEquivRatio = [];
  final List<FlSpot> _maxAirFlow = [];
  final List<FlSpot> _fuelType = [];
  final List<FlSpot> _ethanolFuel = [];
  final List<FlSpot> _absEvapPressure = [];
  final List<FlSpot> _evapPressure = [];
  final List<FlSpot> _shortTermO2Trim1 = [];
  final List<FlSpot> _longTermO2Trim1 = [];
  final List<FlSpot> _shortTermO2Trim2 = [];
  final List<FlSpot> _longTermO2Trim2 = [];
  final List<FlSpot> _shortTermO2Trim3 = [];
  final List<FlSpot> _longTermO2Trim3 = [];
  final List<FlSpot> _shortTermO2Trim4 = [];
  final List<FlSpot> _longTermO2Trim4 = [];
  final List<FlSpot> _catalystTemp1 = [];
  final List<FlSpot> _catalystTemp2 = [];
  final List<FlSpot> _catalystTemp3 = [];
  final List<FlSpot> _catalystTemp4 = [];
  final List<FlSpot> _fuelPressure = [];
  final List<FlSpot> _shortTermFuelTrim1 = [];
  final List<FlSpot> _longTermFuelTrim1 = [];
  final List<FlSpot> _shortTermFuelTrim2 = [];
  final List<FlSpot> _longTermFuelTrim2 = [];

  int _tick = 0;
  StreamSubscription<ObdLiveData>? _dataSubscription;

  @override
  void initState() {
    super.initState();
    _dataSubscription = widget.client.dataStream.listen(_onData);
    _applyEnabledPidsForChart();
  }

  @override
  void dispose() {
    // Cancel subscription để tránh memory leak
    // Không disconnect client vì nó được quản lý bởi ConnectionManager
    _dataSubscription?.cancel();
    super.dispose();
  }

  void _onData(ObdLiveData data) {
    if (!mounted) return;
    setState(() {
      _tick++;
      final x = _tick.toDouble();

      // Add data for each selected metric
      if (widget.selectedMetrics.contains(LiveMetric.rpm)) _rpm.add(FlSpot(x, data.engineRpm.toDouble()));
      if (widget.selectedMetrics.contains(LiveMetric.speed)) _speed.add(FlSpot(x, data.vehicleSpeedKmh.toDouble()));
      if (widget.selectedMetrics.contains(LiveMetric.coolant)) _coolant.add(FlSpot(x, data.coolantTempC.toDouble()));
      if (widget.selectedMetrics.contains(LiveMetric.intake)) _intake.add(FlSpot(x, data.intakeTempC.toDouble()));
      if (widget.selectedMetrics.contains(LiveMetric.throttle)) _throttle.add(FlSpot(x, data.throttlePositionPercent.toDouble()));
      if (widget.selectedMetrics.contains(LiveMetric.fuel)) _fuel.add(FlSpot(x, data.fuelLevelPercent.toDouble()));
      if (widget.selectedMetrics.contains(LiveMetric.load)) _load.add(FlSpot(x, data.engineLoadPercent.toDouble()));
      if (widget.selectedMetrics.contains(LiveMetric.map)) _map.add(FlSpot(x, data.mapKpa.toDouble()));
      if (widget.selectedMetrics.contains(LiveMetric.baro)) _baro.add(FlSpot(x, data.baroKpa.toDouble()));
      if (widget.selectedMetrics.contains(LiveMetric.maf)) _maf.add(FlSpot(x, data.mafGs.toDouble()));
      if (widget.selectedMetrics.contains(LiveMetric.voltage)) _voltage.add(FlSpot(x, data.voltageV));
      if (widget.selectedMetrics.contains(LiveMetric.ambient)) _ambient.add(FlSpot(x, data.ambientTempC.toDouble()));
      if (widget.selectedMetrics.contains(LiveMetric.lambda)) _lambda.add(FlSpot(x, data.lambda));
      if (widget.selectedMetrics.contains(LiveMetric.fuelSystemStatus)) _fuelSystemStatus.add(FlSpot(x, data.fuelSystemStatus.toDouble()));
      if (widget.selectedMetrics.contains(LiveMetric.timingAdvance)) _timingAdvance.add(FlSpot(x, data.timingAdvance.toDouble()));
      if (widget.selectedMetrics.contains(LiveMetric.runtimeSinceStart)) _runtimeSinceStart.add(FlSpot(x, data.runtimeSinceStart.toDouble()));
      if (widget.selectedMetrics.contains(LiveMetric.distanceWithMIL)) _distanceWithMIL.add(FlSpot(x, data.distanceWithMIL.toDouble()));
      if (widget.selectedMetrics.contains(LiveMetric.commandedPurge)) _commandedPurge.add(FlSpot(x, data.commandedPurge.toDouble()));
      if (widget.selectedMetrics.contains(LiveMetric.warmupsSinceClear)) _warmupsSinceClear.add(FlSpot(x, data.warmupsSinceClear.toDouble()));
      if (widget.selectedMetrics.contains(LiveMetric.distanceSinceClear)) _distanceSinceClear.add(FlSpot(x, data.distanceSinceClear.toDouble()));
      if (widget.selectedMetrics.contains(LiveMetric.catalystTemp)) _catalystTemp.add(FlSpot(x, data.catalystTemp.toDouble()));
      if (widget.selectedMetrics.contains(LiveMetric.absoluteLoad)) _absoluteLoad.add(FlSpot(x, data.absoluteLoad.toDouble()));
      if (widget.selectedMetrics.contains(LiveMetric.commandedEquivRatio)) _commandedEquivRatio.add(FlSpot(x, data.commandedEquivRatio));
      if (widget.selectedMetrics.contains(LiveMetric.relativeThrottle)) _relativeThrottle.add(FlSpot(x, data.relativeThrottle.toDouble()));
      if (widget.selectedMetrics.contains(LiveMetric.absoluteThrottleB)) _absoluteThrottleB.add(FlSpot(x, data.absoluteThrottleB.toDouble()));
      if (widget.selectedMetrics.contains(LiveMetric.absoluteThrottleC)) _absoluteThrottleC.add(FlSpot(x, data.absoluteThrottleC.toDouble()));
      if (widget.selectedMetrics.contains(LiveMetric.pedalPositionD)) _pedalPositionD.add(FlSpot(x, data.pedalPositionD.toDouble()));
      if (widget.selectedMetrics.contains(LiveMetric.pedalPositionE)) _pedalPositionE.add(FlSpot(x, data.pedalPositionE.toDouble()));
      if (widget.selectedMetrics.contains(LiveMetric.pedalPositionF)) _pedalPositionF.add(FlSpot(x, data.pedalPositionF.toDouble()));
      if (widget.selectedMetrics.contains(LiveMetric.commandedThrottleActuator)) _commandedThrottleActuator.add(FlSpot(x, data.commandedThrottleActuator.toDouble()));
      if (widget.selectedMetrics.contains(LiveMetric.timeRunWithMIL)) _timeRunWithMIL.add(FlSpot(x, data.timeRunWithMIL.toDouble()));
      if (widget.selectedMetrics.contains(LiveMetric.timeSinceCodesCleared)) _timeSinceCodesCleared.add(FlSpot(x, data.timeSinceCodesCleared.toDouble()));
      if (widget.selectedMetrics.contains(LiveMetric.maxEquivRatio)) _maxEquivRatio.add(FlSpot(x, data.maxEquivRatio));
      if (widget.selectedMetrics.contains(LiveMetric.maxAirFlow)) _maxAirFlow.add(FlSpot(x, data.maxAirFlow.toDouble()));
      if (widget.selectedMetrics.contains(LiveMetric.fuelType)) _fuelType.add(FlSpot(x, data.fuelType.toDouble()));
      if (widget.selectedMetrics.contains(LiveMetric.ethanolFuel)) _ethanolFuel.add(FlSpot(x, data.ethanolFuel.toDouble()));
      if (widget.selectedMetrics.contains(LiveMetric.absEvapPressure)) _absEvapPressure.add(FlSpot(x, data.absEvapPressure.toDouble()));
      if (widget.selectedMetrics.contains(LiveMetric.evapPressure)) _evapPressure.add(FlSpot(x, data.evapPressure.toDouble()));
      if (widget.selectedMetrics.contains(LiveMetric.shortTermO2Trim1)) _shortTermO2Trim1.add(FlSpot(x, data.shortTermO2Trim1.toDouble()));
      if (widget.selectedMetrics.contains(LiveMetric.longTermO2Trim1)) _longTermO2Trim1.add(FlSpot(x, data.longTermO2Trim1.toDouble()));
      if (widget.selectedMetrics.contains(LiveMetric.shortTermO2Trim2)) _shortTermO2Trim2.add(FlSpot(x, data.shortTermO2Trim2.toDouble()));
      if (widget.selectedMetrics.contains(LiveMetric.longTermO2Trim2)) _longTermO2Trim2.add(FlSpot(x, data.longTermO2Trim2.toDouble()));
      if (widget.selectedMetrics.contains(LiveMetric.shortTermO2Trim3)) _shortTermO2Trim3.add(FlSpot(x, data.shortTermO2Trim3.toDouble()));
      if (widget.selectedMetrics.contains(LiveMetric.longTermO2Trim3)) _longTermO2Trim3.add(FlSpot(x, data.longTermO2Trim3.toDouble()));
      if (widget.selectedMetrics.contains(LiveMetric.shortTermO2Trim4)) _shortTermO2Trim4.add(FlSpot(x, data.shortTermO2Trim4.toDouble()));
      if (widget.selectedMetrics.contains(LiveMetric.longTermO2Trim4)) _longTermO2Trim4.add(FlSpot(x, data.longTermO2Trim4.toDouble()));
      if (widget.selectedMetrics.contains(LiveMetric.catalystTemp1)) _catalystTemp1.add(FlSpot(x, data.catalystTemp1.toDouble()));
      if (widget.selectedMetrics.contains(LiveMetric.catalystTemp2)) _catalystTemp2.add(FlSpot(x, data.catalystTemp2.toDouble()));
      if (widget.selectedMetrics.contains(LiveMetric.catalystTemp3)) _catalystTemp3.add(FlSpot(x, data.catalystTemp3.toDouble()));
      if (widget.selectedMetrics.contains(LiveMetric.catalystTemp4)) _catalystTemp4.add(FlSpot(x, data.catalystTemp4.toDouble()));
      if (widget.selectedMetrics.contains(LiveMetric.fuelPressure)) _fuelPressure.add(FlSpot(x, data.fuelPressure.toDouble()));
      if (widget.selectedMetrics.contains(LiveMetric.shortTermFuelTrim1)) _shortTermFuelTrim1.add(FlSpot(x, data.shortTermFuelTrim1.toDouble()));
      if (widget.selectedMetrics.contains(LiveMetric.longTermFuelTrim1)) _longTermFuelTrim1.add(FlSpot(x, data.longTermFuelTrim1.toDouble()));
      if (widget.selectedMetrics.contains(LiveMetric.shortTermFuelTrim2)) _shortTermFuelTrim2.add(FlSpot(x, data.shortTermFuelTrim2.toDouble()));
      if (widget.selectedMetrics.contains(LiveMetric.longTermFuelTrim2)) _longTermFuelTrim2.add(FlSpot(x, data.longTermFuelTrim2.toDouble()));

      // Keep only the last 120 points (approx 30 seconds at 250ms interval)
      const maxPoints = 120;
      if (_rpm.length > maxPoints) _rpm.removeAt(0);
      if (_speed.length > maxPoints) _speed.removeAt(0);
      if (_coolant.length > maxPoints) _coolant.removeAt(0);
      if (_intake.length > maxPoints) _intake.removeAt(0);
      if (_throttle.length > maxPoints) _throttle.removeAt(0);
      if (_fuel.length > maxPoints) _fuel.removeAt(0);
      if (_load.length > maxPoints) _load.removeAt(0);
      if (_map.length > maxPoints) _map.removeAt(0);
      if (_baro.length > maxPoints) _baro.removeAt(0);
      if (_maf.length > maxPoints) _maf.removeAt(0);
      if (_voltage.length > maxPoints) _voltage.removeAt(0);
      if (_ambient.length > maxPoints) _ambient.removeAt(0);
      if (_lambda.length > maxPoints) _lambda.removeAt(0);
      if (_fuelSystemStatus.length > maxPoints) _fuelSystemStatus.removeAt(0);
      if (_timingAdvance.length > maxPoints) _timingAdvance.removeAt(0);
      if (_runtimeSinceStart.length > maxPoints) _runtimeSinceStart.removeAt(0);
      if (_distanceWithMIL.length > maxPoints) _distanceWithMIL.removeAt(0);
      if (_commandedPurge.length > maxPoints) _commandedPurge.removeAt(0);
      if (_warmupsSinceClear.length > maxPoints) _warmupsSinceClear.removeAt(0);
      if (_distanceSinceClear.length > maxPoints) _distanceSinceClear.removeAt(0);
      if (_catalystTemp.length > maxPoints) _catalystTemp.removeAt(0);
      if (_absoluteLoad.length > maxPoints) _absoluteLoad.removeAt(0);
      if (_commandedEquivRatio.length > maxPoints) _commandedEquivRatio.removeAt(0);
      if (_relativeThrottle.length > maxPoints) _relativeThrottle.removeAt(0);
      if (_absoluteThrottleB.length > maxPoints) _absoluteThrottleB.removeAt(0);
      if (_absoluteThrottleC.length > maxPoints) _absoluteThrottleC.removeAt(0);
      if (_pedalPositionD.length > maxPoints) _pedalPositionD.removeAt(0);
      if (_pedalPositionE.length > maxPoints) _pedalPositionE.removeAt(0);
      if (_pedalPositionF.length > maxPoints) _pedalPositionF.removeAt(0);
      if (_commandedThrottleActuator.length > maxPoints) _commandedThrottleActuator.removeAt(0);
      if (_timeRunWithMIL.length > maxPoints) _timeRunWithMIL.removeAt(0);
      if (_timeSinceCodesCleared.length > maxPoints) _timeSinceCodesCleared.removeAt(0);
      if (_maxEquivRatio.length > maxPoints) _maxEquivRatio.removeAt(0);
      if (_maxAirFlow.length > maxPoints) _maxAirFlow.removeAt(0);
      if (_fuelType.length > maxPoints) _fuelType.removeAt(0);
      if (_ethanolFuel.length > maxPoints) _ethanolFuel.removeAt(0);
      if (_absEvapPressure.length > maxPoints) _absEvapPressure.removeAt(0);
      if (_evapPressure.length > maxPoints) _evapPressure.removeAt(0);
      if (_shortTermO2Trim1.length > maxPoints) _shortTermO2Trim1.removeAt(0);
      if (_longTermO2Trim1.length > maxPoints) _longTermO2Trim1.removeAt(0);
      if (_shortTermO2Trim2.length > maxPoints) _shortTermO2Trim2.removeAt(0);
      if (_longTermO2Trim2.length > maxPoints) _longTermO2Trim2.removeAt(0);
      if (_shortTermO2Trim3.length > maxPoints) _shortTermO2Trim3.removeAt(0);
      if (_longTermO2Trim3.length > maxPoints) _longTermO2Trim3.removeAt(0);
      if (_shortTermO2Trim4.length > maxPoints) _shortTermO2Trim4.removeAt(0);
      if (_longTermO2Trim4.length > maxPoints) _longTermO2Trim4.removeAt(0);
      if (_catalystTemp1.length > maxPoints) _catalystTemp1.removeAt(0);
      if (_catalystTemp2.length > maxPoints) _catalystTemp2.removeAt(0);
      if (_catalystTemp3.length > maxPoints) _catalystTemp3.removeAt(0);
      if (_catalystTemp4.length > maxPoints) _catalystTemp4.removeAt(0);
      if (_fuelPressure.length > maxPoints) _fuelPressure.removeAt(0);
      if (_shortTermFuelTrim1.length > maxPoints) _shortTermFuelTrim1.removeAt(0);
      if (_longTermFuelTrim1.length > maxPoints) _longTermFuelTrim1.removeAt(0);
      if (_shortTermFuelTrim2.length > maxPoints) _shortTermFuelTrim2.removeAt(0);
      if (_longTermFuelTrim2.length > maxPoints) _longTermFuelTrim2.removeAt(0);
    });
  }

  List<LineChartBarData> _getLineBars() {
    final List<LineChartBarData> bars = [];
    int colorIndex = 0;
    final colors = [
      Colors.red,
      Colors.blue,
      Colors.green,
      Colors.orange,
      Colors.purple,
      Colors.teal,
      Colors.pink,
      Colors.indigo,
      Colors.amber,
      Colors.cyan,
    ];

    // Helper function to add a line bar
    void addLineBar(List<FlSpot> data, String label) {
      if (data.isNotEmpty) {
        bars.add(LineChartBarData(
          spots: data,
          isCurved: true,
          color: colors[colorIndex % colors.length],
          barWidth: 2,
          isStrokeCapRound: true,
          dotData: const FlDotData(show: false),
          belowBarData: BarAreaData(show: false),
        ));
        colorIndex++;
      }
    }

    // Add line bars for selected metrics
    if (widget.selectedMetrics.contains(LiveMetric.rpm)) addLineBar(_rpm, 'RPM');
    if (widget.selectedMetrics.contains(LiveMetric.speed)) addLineBar(_speed, 'Speed');
    if (widget.selectedMetrics.contains(LiveMetric.coolant)) addLineBar(_coolant, 'Coolant');
    if (widget.selectedMetrics.contains(LiveMetric.intake)) addLineBar(_intake, 'Intake');
    if (widget.selectedMetrics.contains(LiveMetric.throttle)) addLineBar(_throttle, 'Throttle');
    if (widget.selectedMetrics.contains(LiveMetric.fuel)) addLineBar(_fuel, 'Fuel');
    if (widget.selectedMetrics.contains(LiveMetric.load)) addLineBar(_load, 'Load');
    if (widget.selectedMetrics.contains(LiveMetric.map)) addLineBar(_map, 'MAP');
    if (widget.selectedMetrics.contains(LiveMetric.baro)) addLineBar(_baro, 'Baro');
    if (widget.selectedMetrics.contains(LiveMetric.maf)) addLineBar(_maf, 'MAF');
    if (widget.selectedMetrics.contains(LiveMetric.voltage)) addLineBar(_voltage, 'Voltage');
    if (widget.selectedMetrics.contains(LiveMetric.ambient)) addLineBar(_ambient, 'Ambient');
    if (widget.selectedMetrics.contains(LiveMetric.lambda)) addLineBar(_lambda, 'Lambda');
    if (widget.selectedMetrics.contains(LiveMetric.fuelSystemStatus)) addLineBar(_fuelSystemStatus, 'Fuel System');
    if (widget.selectedMetrics.contains(LiveMetric.timingAdvance)) addLineBar(_timingAdvance, 'Timing');
    if (widget.selectedMetrics.contains(LiveMetric.runtimeSinceStart)) addLineBar(_runtimeSinceStart, 'Runtime');
    if (widget.selectedMetrics.contains(LiveMetric.distanceWithMIL)) addLineBar(_distanceWithMIL, 'MIL Distance');
    if (widget.selectedMetrics.contains(LiveMetric.commandedPurge)) addLineBar(_commandedPurge, 'Purge');
    if (widget.selectedMetrics.contains(LiveMetric.warmupsSinceClear)) addLineBar(_warmupsSinceClear, 'Warm-ups');
    if (widget.selectedMetrics.contains(LiveMetric.distanceSinceClear)) addLineBar(_distanceSinceClear, 'Clear Distance');
    if (widget.selectedMetrics.contains(LiveMetric.catalystTemp)) addLineBar(_catalystTemp, 'Catalyst');
    if (widget.selectedMetrics.contains(LiveMetric.absoluteLoad)) addLineBar(_absoluteLoad, 'Abs Load');
    if (widget.selectedMetrics.contains(LiveMetric.commandedEquivRatio)) addLineBar(_commandedEquivRatio, 'Equiv Ratio');
    if (widget.selectedMetrics.contains(LiveMetric.relativeThrottle)) addLineBar(_relativeThrottle, 'Rel Throttle');
    if (widget.selectedMetrics.contains(LiveMetric.absoluteThrottleB)) addLineBar(_absoluteThrottleB, 'Abs Throttle B');
    if (widget.selectedMetrics.contains(LiveMetric.absoluteThrottleC)) addLineBar(_absoluteThrottleC, 'Abs Throttle C');
    if (widget.selectedMetrics.contains(LiveMetric.pedalPositionD)) addLineBar(_pedalPositionD, 'Pedal D');
    if (widget.selectedMetrics.contains(LiveMetric.pedalPositionE)) addLineBar(_pedalPositionE, 'Pedal E');
    if (widget.selectedMetrics.contains(LiveMetric.pedalPositionF)) addLineBar(_pedalPositionF, 'Pedal F');
    if (widget.selectedMetrics.contains(LiveMetric.commandedThrottleActuator)) addLineBar(_commandedThrottleActuator, 'Throttle Act');
    if (widget.selectedMetrics.contains(LiveMetric.timeRunWithMIL)) addLineBar(_timeRunWithMIL, 'MIL Time');
    if (widget.selectedMetrics.contains(LiveMetric.timeSinceCodesCleared)) addLineBar(_timeSinceCodesCleared, 'Clear Time');
    if (widget.selectedMetrics.contains(LiveMetric.maxEquivRatio)) addLineBar(_maxEquivRatio, 'Max Equiv');
    if (widget.selectedMetrics.contains(LiveMetric.maxAirFlow)) addLineBar(_maxAirFlow, 'Max Air Flow');
    if (widget.selectedMetrics.contains(LiveMetric.fuelType)) addLineBar(_fuelType, 'Fuel Type');
    if (widget.selectedMetrics.contains(LiveMetric.ethanolFuel)) addLineBar(_ethanolFuel, 'Ethanol');
    if (widget.selectedMetrics.contains(LiveMetric.absEvapPressure)) addLineBar(_absEvapPressure, 'Abs Evap');
    if (widget.selectedMetrics.contains(LiveMetric.evapPressure)) addLineBar(_evapPressure, 'Evap');
    if (widget.selectedMetrics.contains(LiveMetric.shortTermO2Trim1)) addLineBar(_shortTermO2Trim1, 'ST O2 1');
    if (widget.selectedMetrics.contains(LiveMetric.longTermO2Trim1)) addLineBar(_longTermO2Trim1, 'LT O2 1');
    if (widget.selectedMetrics.contains(LiveMetric.shortTermO2Trim2)) addLineBar(_shortTermO2Trim2, 'ST O2 2');
    if (widget.selectedMetrics.contains(LiveMetric.longTermO2Trim2)) addLineBar(_longTermO2Trim2, 'LT O2 2');
    if (widget.selectedMetrics.contains(LiveMetric.shortTermO2Trim3)) addLineBar(_shortTermO2Trim3, 'ST O2 3');
    if (widget.selectedMetrics.contains(LiveMetric.longTermO2Trim3)) addLineBar(_longTermO2Trim3, 'LT O2 3');
    if (widget.selectedMetrics.contains(LiveMetric.shortTermO2Trim4)) addLineBar(_shortTermO2Trim4, 'ST O2 4');
    if (widget.selectedMetrics.contains(LiveMetric.longTermO2Trim4)) addLineBar(_longTermO2Trim4, 'LT O2 4');
    if (widget.selectedMetrics.contains(LiveMetric.catalystTemp1)) addLineBar(_catalystTemp1, 'Cat 1');
    if (widget.selectedMetrics.contains(LiveMetric.catalystTemp2)) addLineBar(_catalystTemp2, 'Cat 2');
    if (widget.selectedMetrics.contains(LiveMetric.catalystTemp3)) addLineBar(_catalystTemp3, 'Cat 3');
    if (widget.selectedMetrics.contains(LiveMetric.catalystTemp4)) addLineBar(_catalystTemp4, 'Cat 4');
    if (widget.selectedMetrics.contains(LiveMetric.fuelPressure)) addLineBar(_fuelPressure, 'Fuel Press');
    if (widget.selectedMetrics.contains(LiveMetric.shortTermFuelTrim1)) addLineBar(_shortTermFuelTrim1, 'ST Fuel 1');
    if (widget.selectedMetrics.contains(LiveMetric.longTermFuelTrim1)) addLineBar(_longTermFuelTrim1, 'LT Fuel 1');
    if (widget.selectedMetrics.contains(LiveMetric.shortTermFuelTrim2)) addLineBar(_shortTermFuelTrim2, 'ST Fuel 2');
    if (widget.selectedMetrics.contains(LiveMetric.longTermFuelTrim2)) addLineBar(_longTermFuelTrim2, 'LT Fuel 2');

    return bars;
  }

  void _applyEnabledPidsForChart() {
    final required = <String>{'010C', '010D', '0105'}; // always include RPM/Speed/Coolant
    for (final m in widget.selectedMetrics) {
      required.addAll(_pidsForMetric(m));
    }
    widget.client.setEnabledPids(required);
  }

  Set<String> _pidsForMetric(LiveMetric m) {
    switch (m) {
      case LiveMetric.rpm: return {'010C'};
      case LiveMetric.speed: return {'010D'};
      case LiveMetric.coolant: return {'0105'};
      case LiveMetric.intake: return {'010F'};
      case LiveMetric.throttle: return {'0111'};
      case LiveMetric.fuel: return {'012F'};
      case LiveMetric.load: return {'0104'};
      case LiveMetric.map: return {'010B'};
      case LiveMetric.baro: return {'0133'};
      case LiveMetric.maf: return {'0110'};
      case LiveMetric.voltage: return {'0142'};
      case LiveMetric.ambient: return {'0146'};
      case LiveMetric.lambda: return {'015E'};
      case LiveMetric.fuelSystemStatus: return {'0103'};
      case LiveMetric.timingAdvance: return {'010E'};
      case LiveMetric.runtimeSinceStart: return {'011F'};
      case LiveMetric.distanceWithMIL: return {'0121'};
      case LiveMetric.commandedPurge: return {'012E'};
      case LiveMetric.warmupsSinceClear: return {'0130'};
      case LiveMetric.distanceSinceClear: return {'0131'};
      case LiveMetric.catalystTemp: return {'013C'};
      case LiveMetric.absoluteLoad: return {'0143'};
      case LiveMetric.commandedEquivRatio: return {'0144'};
      case LiveMetric.relativeThrottle: return {'0145'};
      case LiveMetric.absoluteThrottleB: return {'0147'};
      case LiveMetric.absoluteThrottleC: return {'0148'};
      case LiveMetric.pedalPositionD: return {'0149'};
      case LiveMetric.pedalPositionE: return {'014A'};
      case LiveMetric.pedalPositionF: return {'014B'};
      case LiveMetric.commandedThrottleActuator: return {'014C'};
      case LiveMetric.timeRunWithMIL: return {'014D'};
      case LiveMetric.timeSinceCodesCleared: return {'014E'};
      case LiveMetric.maxEquivRatio: return {'014F'};
      case LiveMetric.maxAirFlow: return {'0150'};
      case LiveMetric.fuelType: return {'0151'};
      case LiveMetric.ethanolFuel: return {'0152'};
      case LiveMetric.absEvapPressure: return {'0153'};
      case LiveMetric.evapPressure: return {'0154'};
      case LiveMetric.shortTermO2Trim1: return {'0155'};
      case LiveMetric.longTermO2Trim1: return {'0156'};
      case LiveMetric.shortTermO2Trim2: return {'0157'};
      case LiveMetric.longTermO2Trim2: return {'0158'};
      case LiveMetric.shortTermO2Trim3: return {'0159'};
      case LiveMetric.longTermO2Trim3: return {'015A'};
      case LiveMetric.shortTermO2Trim4: return {'015B'};
      case LiveMetric.longTermO2Trim4: return {'015C'};
      case LiveMetric.catalystTemp1: return {'013C'};
      case LiveMetric.catalystTemp2: return {'013D'};
      case LiveMetric.catalystTemp3: return {'013E'};
      case LiveMetric.catalystTemp4: return {'013F'};
      case LiveMetric.fuelPressure: return {'010A'};
      case LiveMetric.shortTermFuelTrim1: return {'0106'};
      case LiveMetric.longTermFuelTrim1: return {'0107'};
      case LiveMetric.shortTermFuelTrim2: return {'0108'};
      case LiveMetric.longTermFuelTrim2: return {'0109'};
    }
  }

  // Compute dynamic Y range across selected series for better visibility
  (double, double) _computeYRange() {
    double? minV;
    double? maxV;
    for (final m in widget.selectedMetrics) {
      final series = _seriesForMetric(m);
      for (final p in series) {
        if (minV == null || p.y < minV) {
          minV = p.y;
        }
        if (maxV == null || p.y > maxV) {
          maxV = p.y;
        }
      }
    }
    if (minV == null || maxV == null) {
      return (0, 100);
    }
    if (minV == maxV) {
      // expand a bit when flat line
      return (minV - 1, maxV + 1);
    }
    final padding = (maxV - minV) * 0.1; // 10% headroom
    return (minV - padding, maxV + padding);
  }

  List<FlSpot> _seriesForMetric(LiveMetric m) {
    switch (m) {
      case LiveMetric.rpm: return _rpm;
      case LiveMetric.speed: return _speed;
      case LiveMetric.coolant: return _coolant;
      case LiveMetric.intake: return _intake;
      case LiveMetric.throttle: return _throttle;
      case LiveMetric.fuel: return _fuel;
      case LiveMetric.load: return _load;
      case LiveMetric.map: return _map;
      case LiveMetric.baro: return _baro;
      case LiveMetric.maf: return _maf;
      case LiveMetric.voltage: return _voltage;
      case LiveMetric.ambient: return _ambient;
      case LiveMetric.lambda: return _lambda;
      case LiveMetric.fuelSystemStatus: return _fuelSystemStatus;
      case LiveMetric.timingAdvance: return _timingAdvance;
      case LiveMetric.runtimeSinceStart: return _runtimeSinceStart;
      case LiveMetric.distanceWithMIL: return _distanceWithMIL;
      case LiveMetric.commandedPurge: return _commandedPurge;
      case LiveMetric.warmupsSinceClear: return _warmupsSinceClear;
      case LiveMetric.distanceSinceClear: return _distanceSinceClear;
      case LiveMetric.catalystTemp: return _catalystTemp;
      case LiveMetric.absoluteLoad: return _absoluteLoad;
      case LiveMetric.commandedEquivRatio: return _commandedEquivRatio;
      case LiveMetric.relativeThrottle: return _relativeThrottle;
      case LiveMetric.absoluteThrottleB: return _absoluteThrottleB;
      case LiveMetric.absoluteThrottleC: return _absoluteThrottleC;
      case LiveMetric.pedalPositionD: return _pedalPositionD;
      case LiveMetric.pedalPositionE: return _pedalPositionE;
      case LiveMetric.pedalPositionF: return _pedalPositionF;
      case LiveMetric.commandedThrottleActuator: return _commandedThrottleActuator;
      case LiveMetric.timeRunWithMIL: return _timeRunWithMIL;
      case LiveMetric.timeSinceCodesCleared: return _timeSinceCodesCleared;
      case LiveMetric.maxEquivRatio: return _maxEquivRatio;
      case LiveMetric.maxAirFlow: return _maxAirFlow;
      case LiveMetric.fuelType: return _fuelType;
      case LiveMetric.ethanolFuel: return _ethanolFuel;
      case LiveMetric.absEvapPressure: return _absEvapPressure;
      case LiveMetric.evapPressure: return _evapPressure;
      case LiveMetric.shortTermO2Trim1: return _shortTermO2Trim1;
      case LiveMetric.longTermO2Trim1: return _longTermO2Trim1;
      case LiveMetric.shortTermO2Trim2: return _shortTermO2Trim2;
      case LiveMetric.longTermO2Trim2: return _longTermO2Trim2;
      case LiveMetric.shortTermO2Trim3: return _shortTermO2Trim3;
      case LiveMetric.longTermO2Trim3: return _longTermO2Trim3;
      case LiveMetric.shortTermO2Trim4: return _shortTermO2Trim4;
      case LiveMetric.longTermO2Trim4: return _longTermO2Trim4;
      case LiveMetric.catalystTemp1: return _catalystTemp1;
      case LiveMetric.catalystTemp2: return _catalystTemp2;
      case LiveMetric.catalystTemp3: return _catalystTemp3;
      case LiveMetric.catalystTemp4: return _catalystTemp4;
      case LiveMetric.fuelPressure: return _fuelPressure;
      case LiveMetric.shortTermFuelTrim1: return _shortTermFuelTrim1;
      case LiveMetric.longTermFuelTrim1: return _longTermFuelTrim1;
      case LiveMetric.shortTermFuelTrim2: return _shortTermFuelTrim2;
      case LiveMetric.longTermFuelTrim2: return _longTermFuelTrim2;
    }
  }

  @override
  Widget build(BuildContext context) {
    final yRange = _computeYRange();
    final minY = yRange.$1;
    final maxY = yRange.$2;
    final range = (maxY - minY).abs();
    final yInterval = range <= 0 ? 1.0 : (range / 5).clamp(1, 100000).toDouble();
    return Scaffold(
      appBar: AppBar(
        title: const Text('Live Data Chart'),
        backgroundColor: const Color(0xFF2E7D32),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              setState(() {
                _tick = 0;
                _rpm.clear();
                _speed.clear();
                _coolant.clear();
                _intake.clear();
                _throttle.clear();
                _fuel.clear();
                _load.clear();
                _map.clear();
                _baro.clear();
                _maf.clear();
                _voltage.clear();
                _ambient.clear();
                _lambda.clear();
                _fuelSystemStatus.clear();
                _timingAdvance.clear();
                _runtimeSinceStart.clear();
                _distanceWithMIL.clear();
                _commandedPurge.clear();
                _warmupsSinceClear.clear();
                _distanceSinceClear.clear();
                _catalystTemp.clear();
                _absoluteLoad.clear();
                _commandedEquivRatio.clear();
                _relativeThrottle.clear();
                _absoluteThrottleB.clear();
                _absoluteThrottleC.clear();
                _pedalPositionD.clear();
                _pedalPositionE.clear();
                _pedalPositionF.clear();
                _commandedThrottleActuator.clear();
                _timeRunWithMIL.clear();
                _timeSinceCodesCleared.clear();
                _maxEquivRatio.clear();
                _maxAirFlow.clear();
                _fuelType.clear();
                _ethanolFuel.clear();
                _absEvapPressure.clear();
                _evapPressure.clear();
                _shortTermO2Trim1.clear();
                _longTermO2Trim1.clear();
                _shortTermO2Trim2.clear();
                _longTermO2Trim2.clear();
                _shortTermO2Trim3.clear();
                _longTermO2Trim3.clear();
                _shortTermO2Trim4.clear();
                _longTermO2Trim4.clear();
                _catalystTemp1.clear();
                _catalystTemp2.clear();
                _catalystTemp3.clear();
                _catalystTemp4.clear();
                _fuelPressure.clear();
                _shortTermFuelTrim1.clear();
                _longTermFuelTrim1.clear();
                _shortTermFuelTrim2.clear();
                _longTermFuelTrim2.clear();
              });
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Compact info bar
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            color: const Color(0xFF2E7D32).withValues(alpha: 0.1),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${widget.selectedMetrics.length} metrics selected',
                  style: TextStyle(fontSize: 12, color: Colors.grey[700]),
                ),
                Text(
                  'Data points: $_tick',
                  style: TextStyle(fontSize: 12, color: Colors.grey[700]),
                ),
              ],
            ),
          ),
          // Chart
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: LineChart(
                LineChartData(
                  gridData: const FlGridData(
                    show: true,
                    // interval set by leftTitles below
                  ),
                  titlesData: FlTitlesData(
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 44,
                        interval: yInterval,
                        getTitlesWidget: (value, meta) {
                          return Text(
                            value.toInt().toString(),
                            style: const TextStyle(fontSize: 10, color: Colors.white70),
                          );
                        },
                      ),
                    ),
                    rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        interval: 20,
                        getTitlesWidget: (value, meta) {
                          return Text(
                            '${(value * 0.25).toInt()}s',
                            style: const TextStyle(fontSize: 10),
                          );
                        },
                      ),
                    ),
                  ),
                  borderData: FlBorderData(show: true),
                  lineBarsData: _getLineBars(),
                  minX: _tick > 120 ? (_tick - 120).toDouble() : 0,
                  maxX: _tick.toDouble(),
                  minY: minY,
                  maxY: maxY,
                ),
              ),
            ),
          ),
          // Compact legend
          SafeArea(
            bottom: true,
            minimum: const EdgeInsets.only(bottom: 8),
            child: Container(
              height: 60,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: _getLineBars().asMap().entries.map((entry) {
                    final index = entry.key;
                    final colors = [
                      Colors.red, Colors.blue, Colors.green, Colors.orange, Colors.purple,
                      Colors.teal, Colors.pink, Colors.indigo, Colors.amber, Colors.cyan,
                    ];
                    return Container(
                      margin: const EdgeInsets.only(right: 12),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 12,
                            height: 12,
                            color: colors[index % colors.length],
                          ),
                          const SizedBox(width: 4),
                          Text(
                            _getMetricName(index),
                            style: const TextStyle(fontSize: 10),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _getMetricName(int index) {
    final selectedMetrics = widget.selectedMetrics;
    if (index < selectedMetrics.length) {
      final metric = selectedMetrics[index];
      switch (metric) {
        case LiveMetric.rpm: return 'RPM';
        case LiveMetric.speed: return 'Speed';
        case LiveMetric.coolant: return 'Coolant';
        case LiveMetric.intake: return 'Intake';
        case LiveMetric.throttle: return 'Throttle';
        case LiveMetric.fuel: return 'Fuel';
        case LiveMetric.load: return 'Load';
        case LiveMetric.map: return 'MAP';
        case LiveMetric.baro: return 'Baro';
        case LiveMetric.maf: return 'MAF';
        case LiveMetric.voltage: return 'Voltage';
        case LiveMetric.ambient: return 'Ambient';
        case LiveMetric.lambda: return 'Lambda';
        case LiveMetric.fuelSystemStatus: return 'Fuel System';
        case LiveMetric.timingAdvance: return 'Timing';
        case LiveMetric.runtimeSinceStart: return 'Runtime';
        case LiveMetric.distanceWithMIL: return 'MIL Dist';
        case LiveMetric.commandedPurge: return 'Purge';
        case LiveMetric.warmupsSinceClear: return 'Warm-ups';
        case LiveMetric.distanceSinceClear: return 'Clear Dist';
        case LiveMetric.catalystTemp: return 'Catalyst';
        case LiveMetric.absoluteLoad: return 'Abs Load';
        case LiveMetric.commandedEquivRatio: return 'Equiv Ratio';
        case LiveMetric.relativeThrottle: return 'Rel Throttle';
        case LiveMetric.absoluteThrottleB: return 'Abs Throttle B';
        case LiveMetric.absoluteThrottleC: return 'Abs Throttle C';
        case LiveMetric.pedalPositionD: return 'Pedal D';
        case LiveMetric.pedalPositionE: return 'Pedal E';
        case LiveMetric.pedalPositionF: return 'Pedal F';
        case LiveMetric.commandedThrottleActuator: return 'Throttle Act';
        case LiveMetric.timeRunWithMIL: return 'MIL Time';
        case LiveMetric.timeSinceCodesCleared: return 'Clear Time';
        case LiveMetric.maxEquivRatio: return 'Max Equiv';
        case LiveMetric.maxAirFlow: return 'Max Air Flow';
        case LiveMetric.fuelType: return 'Fuel Type';
        case LiveMetric.ethanolFuel: return 'Ethanol';
        case LiveMetric.absEvapPressure: return 'Abs Evap';
        case LiveMetric.evapPressure: return 'Evap';
        case LiveMetric.shortTermO2Trim1: return 'ST O2 1';
        case LiveMetric.longTermO2Trim1: return 'LT O2 1';
        case LiveMetric.shortTermO2Trim2: return 'ST O2 2';
        case LiveMetric.longTermO2Trim2: return 'LT O2 2';
        case LiveMetric.shortTermO2Trim3: return 'ST O2 3';
        case LiveMetric.longTermO2Trim3: return 'LT O2 3';
        case LiveMetric.shortTermO2Trim4: return 'ST O2 4';
        case LiveMetric.longTermO2Trim4: return 'LT O2 4';
        case LiveMetric.catalystTemp1: return 'Cat 1';
        case LiveMetric.catalystTemp2: return 'Cat 2';
        case LiveMetric.catalystTemp3: return 'Cat 3';
        case LiveMetric.catalystTemp4: return 'Cat 4';
        case LiveMetric.fuelPressure: return 'Fuel Press';
        case LiveMetric.shortTermFuelTrim1: return 'ST Fuel 1';
        case LiveMetric.longTermFuelTrim1: return 'LT Fuel 1';
        case LiveMetric.shortTermFuelTrim2: return 'ST Fuel 2';
        case LiveMetric.longTermFuelTrim2: return 'LT Fuel 2';
      }
    }
    return 'Unknown';
  }
}