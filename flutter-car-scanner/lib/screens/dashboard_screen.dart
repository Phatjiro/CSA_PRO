import 'dart:async';

import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_gauges/gauges.dart';

import '../models/obd_live_data.dart';
import '../services/obd_client.dart';

enum Metric {
  // Core
  rpm, speed, coolant, intake, throttle, fuel, load, map, baro, maf, voltage, ambient, lambda,
  // Extended
  fuelSystemStatus, timingAdvance, runtimeSinceStart, distanceWithMIL, commandedPurge,
  warmupsSinceClear, distanceSinceClear, catalystTemp, absoluteLoad, commandedEquivRatio,
  relativeThrottle, absoluteThrottleB, absoluteThrottleC, pedalPositionD, pedalPositionE,
  pedalPositionF, commandedThrottleActuator, timeRunWithMIL, timeSinceCodesCleared,
  maxEquivRatio, maxAirFlow, fuelType, ethanolFuel, absEvapPressure, evapPressure,
  shortTermO2Trim1, longTermO2Trim1, shortTermO2Trim2, longTermO2Trim2,
  shortTermO2Trim3, longTermO2Trim3, shortTermO2Trim4, longTermO2Trim4,
  catalystTemp1, catalystTemp2, catalystTemp3, catalystTemp4, fuelPressure,
  shortTermFuelTrim1, longTermFuelTrim1, shortTermFuelTrim2, longTermFuelTrim2,
}
enum PageLayout { large, grid6, grid9 }

class DashboardScreen extends StatefulWidget {
  final ObdClient client;
  const DashboardScreen({super.key, required this.client});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  static const Duration _staleAfter = Duration(seconds: 2);
  final Map<Metric, DateTime> _lastUpdated = <Metric, DateTime>{};
  StreamSubscription<ObdLiveData>? _dataSubscription;
  ObdLiveData _data = const ObdLiveData(
    engineRpm: 0,
    vehicleSpeedKmh: 0,
    coolantTempC: 0,
    intakeTempC: 0,
    throttlePositionPercent: 0,
    fuelLevelPercent: 0,
    engineLoadPercent: 0,
    mapKpa: 0,
    baroKpa: 0,
    mafGs: 0,
    voltageV: 0,
    ambientTempC: 0,
    lambda: 0,
    fuelSystemStatus: 0,
    timingAdvance: 0,
    runtimeSinceStart: 0,
    distanceWithMIL: 0,
    commandedPurge: 0,
    warmupsSinceClear: 0,
    distanceSinceClear: 0,
    catalystTemp: 0,
    absoluteLoad: 0,
    commandedEquivRatio: 0,
    relativeThrottle: 0,
    absoluteThrottleB: 0,
    absoluteThrottleC: 0,
    pedalPositionD: 0,
    pedalPositionE: 0,
    pedalPositionF: 0,
    commandedThrottleActuator: 0,
    timeRunWithMIL: 0,
    timeSinceCodesCleared: 0,
    maxEquivRatio: 0,
    maxAirFlow: 0,
    fuelType: 0,
    ethanolFuel: 0,
    absEvapPressure: 0,
    evapPressure: 0,
    shortTermO2Trim1: 0,
    longTermO2Trim1: 0,
    shortTermO2Trim2: 0,
    longTermO2Trim2: 0,
    shortTermO2Trim3: 0,
    longTermO2Trim3: 0,
    shortTermO2Trim4: 0,
    longTermO2Trim4: 0,
    catalystTemp1: 0,
    catalystTemp2: 0,
    catalystTemp3: 0,
    catalystTemp4: 0,
    fuelPressure: 0,
    shortTermFuelTrim1: 0,
    longTermFuelTrim1: 0,
    shortTermFuelTrim2: 0,
    longTermFuelTrim2: 0,
    o2SensorVoltage1: 0.0,
    o2SensorVoltage2: 0.0,
    o2SensorVoltage3: 0.0,
    o2SensorVoltage4: 0.0,
    o2SensorVoltage5: 0.0,
    o2SensorVoltage6: 0.0,
    o2SensorVoltage7: 0.0,
    o2SensorVoltage8: 0.0,
    engineOilTempC: 0,
    engineFuelRate: 0.0,
    driverDemandTorque: 0,
    actualTorque: 0,
    referenceTorque: 0,
  );

  final ValueNotifier<int> _page = ValueNotifier<int>(0);
  // Selections per page
  List<Metric> page1 = const [Metric.rpm, Metric.speed, Metric.coolant];
  // Page 2 & 3: common metrics only (9 mỗi trang)
  List<Metric> page2 = const [
    Metric.intake,
    Metric.throttle,
    Metric.fuel,
    Metric.load,
    Metric.map,
    Metric.maf,
    Metric.voltage,
    Metric.ambient,
    Metric.lambda,
  ];
  // Page 3: extended metrics (tránh trùng Page 2)
  List<Metric> page3 = const [
    Metric.baro,
    Metric.timingAdvance,
    Metric.fuelPressure,
    Metric.catalystTemp1,
    Metric.catalystTemp2,
    Metric.catalystTemp3,
    Metric.catalystTemp4,
    Metric.commandedEquivRatio,
    Metric.relativeThrottle,
  ];
  PageLayout page1Layout = PageLayout.large; // big RPM + 2 tiles
  PageLayout page2Layout = PageLayout.grid9;  // 3x3 grid (max 9)
  PageLayout page3Layout = PageLayout.grid9;  // 3x3 grid (max 9)

  @override
  void initState() {
    super.initState();
    _dataSubscription = widget.client.dataStream.listen((event) {
      if (mounted) {
        setState(() {
          _data = event;
          _markUpdatedFromEnabledPids();
        });
      }
    });
    // Ban đầu, chỉ bật các PIDs cho trang 1 (RPM, Speed, Coolant)
    _applyEnabledPidsForPage(0);
  }

  @override
  void dispose() {
    // Chỉ cancel subscription của màn hình này, không disconnect client
    // Client được quản lý bởi ConnectionManager và nên được giữ nguyên
    _dataSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Live Dashboard'),
        backgroundColor: const Color(0xFFE91E63),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            onPressed: _openConfigure,
            icon: const Icon(Icons.tune),
            tooltip: 'Configure',
          ),
        ],
      ),
      body: SafeArea(
        minimum: const EdgeInsets.only(bottom: 12),
        child: PageView(
          onPageChanged: (i) {
            _page.value = i;
            _applyEnabledPidsForPage(i);
            // Trigger immediate poll để có data ngay khi chuyển page
            widget.client.pollNow();
          },
          children: [
            _pageContent(page1, page1Layout),
            _pageContent(page2, page2Layout),
            _pageContent(page3, page3Layout),
            _allMetricsListPage(),
          ],
        ),
      ),
    );
  }

  Widget _pageContent(List<Metric> metrics, PageLayout layout) {
    if (layout == PageLayout.large && metrics.contains(Metric.rpm)) {
      return Column(
        children: [
          Expanded(flex: 2, child: _rpmGauge(_data.engineRpm)),
          Expanded(
            flex: 1,
            child: Row(children: _smallTiles(metrics.where((m) => m != Metric.rpm).take(2).toList())),
          ),
        ],
      );
    }
    if (layout == PageLayout.grid9) {
      final items = metrics.take(9).toList();
      return Column(
        children: [
          Expanded(child: Row(children: _smallTiles(items.take(3).toList()))),
          Expanded(child: Row(children: _smallTiles(items.skip(3).take(3).toList()))),
          Expanded(child: Row(children: _smallTiles(items.skip(6).take(3).toList()))),
        ],
      );
    }
    // grid6 default
    final items = metrics.take(6).toList();
    return Column(
      children: [
        Expanded(child: Row(children: _smallTiles(items.take(3).toList()))),
        Expanded(child: Row(children: _smallTiles(items.skip(3).take(3).toList()))),
      ],
    );
  }

  List<Widget> _smallTiles(List<Metric> ms) {
    return ms.map((m) => Expanded(child: _metricTile(m))).toList();
  }

  Widget _metricTile(Metric m) {
    final stale = _isStale(m);
    switch (m) {
      case Metric.speed:
        return _tile('Speed', stale ? '—' : '${_data.vehicleSpeedKmh}', unit: 'km/h', stale: stale);
      case Metric.coolant:
        return _coolantGauge(_data.coolantTempC, stale: stale);
      case Metric.intake:
        return _tile('Intake temp', stale ? '—' : '${_data.intakeTempC}', unit: '°C', stale: stale);
      case Metric.throttle:
        return _tile('Throttle', stale ? '—' : '${_data.throttlePositionPercent}', unit: '%', stale: stale);
      case Metric.fuel:
        return _tile('Fuel level', stale ? '—' : '${_data.fuelLevelPercent}', unit: '%', stale: stale);
      case Metric.load:
        return _tile('Engine load', stale ? '—' : '${_data.engineLoadPercent}', unit: '%', stale: stale);
      case Metric.map:
        return _tile('MAP', stale ? '—' : '${_data.mapKpa}', unit: 'kPa', stale: stale);
      case Metric.baro:
        return _tile('Baro', stale ? '—' : '${_data.baroKpa}', unit: 'kPa', stale: stale);
      case Metric.maf:
        return _tile('MAF', stale ? '—' : '${_data.mafGs}', unit: 'g/s', stale: stale);
      case Metric.voltage:
        return _tile('Voltage', stale ? '—' : _format1(_data.voltageV), unit: 'V', stale: stale);
      case Metric.ambient:
        return _tile('Ambient', stale ? '—' : '${_data.ambientTempC}', unit: '°C', stale: stale);
      case Metric.lambda:
        return _tile('Lambda', stale ? '—' : _format2(_data.lambda), stale: stale);
      case Metric.rpm:
        return _rpmGauge(_data.engineRpm, stale: stale);
      // Extended mappings
      case Metric.fuelSystemStatus:
        return _tile('Fuel system status', stale ? '—' : '${_data.fuelSystemStatus}', stale: stale);
      case Metric.timingAdvance:
        return _tile('Timing advance', stale ? '—' : '${_data.timingAdvance}', unit: '°', stale: stale);
      case Metric.runtimeSinceStart:
        return _tile('Runtime since start', stale ? '—' : '${_data.runtimeSinceStart}', unit: 's', stale: stale);
      case Metric.distanceWithMIL:
        return _tile('Distance with MIL', stale ? '—' : '${_data.distanceWithMIL}', unit: 'km', stale: stale);
      case Metric.commandedPurge:
        return _tile('Commanded purge', stale ? '—' : '${_data.commandedPurge}', unit: '%', stale: stale);
      case Metric.warmupsSinceClear:
        return _tile('Warm-ups since clear', stale ? '—' : '${_data.warmupsSinceClear}', stale: stale);
      case Metric.distanceSinceClear:
        return _tile('Distance since clear', stale ? '—' : '${_data.distanceSinceClear}', unit: 'km', stale: stale);
      case Metric.catalystTemp:
        return _tile('Catalyst temp', stale ? '—' : '${_data.catalystTemp}', unit: '°C', stale: stale);
      case Metric.absoluteLoad:
        return _tile('Absolute load', stale ? '—' : '${_data.absoluteLoad}', unit: '%', stale: stale);
      case Metric.commandedEquivRatio:
        return _tile('Commanded equiv ratio', stale ? '—' : _format2(_data.commandedEquivRatio), stale: stale);
      case Metric.relativeThrottle:
        return _tile('Relative throttle', stale ? '—' : '${_data.relativeThrottle}', unit: '%', stale: stale);
      case Metric.absoluteThrottleB:
        return _tile('Absolute throttle B', stale ? '—' : '${_data.absoluteThrottleB}', unit: '%', stale: stale);
      case Metric.absoluteThrottleC:
        return _tile('Absolute throttle C', stale ? '—' : '${_data.absoluteThrottleC}', unit: '%', stale: stale);
      case Metric.pedalPositionD:
        return _tile('Pedal position D', stale ? '—' : '${_data.pedalPositionD}', unit: '%', stale: stale);
      case Metric.pedalPositionE:
        return _tile('Pedal position E', stale ? '—' : '${_data.pedalPositionE}', unit: '%', stale: stale);
      case Metric.pedalPositionF:
        return _tile('Pedal position F', stale ? '—' : '${_data.pedalPositionF}', unit: '%', stale: stale);
      case Metric.commandedThrottleActuator:
        return _tile('Throttle actuator', stale ? '—' : '${_data.commandedThrottleActuator}', unit: '%', stale: stale);
      case Metric.timeRunWithMIL:
        return _tile('Time run with MIL', stale ? '—' : '${_data.timeRunWithMIL}', unit: 's', stale: stale);
      case Metric.timeSinceCodesCleared:
        return _tile('Time since codes cleared', stale ? '—' : '${_data.timeSinceCodesCleared}', unit: 's', stale: stale);
      case Metric.maxEquivRatio:
        return _tile('Max equiv ratio', stale ? '—' : _format2(_data.maxEquivRatio), stale: stale);
      case Metric.maxAirFlow:
        return _tile('Max air flow', stale ? '—' : '${_data.maxAirFlow}', unit: 'g/s', stale: stale);
      case Metric.fuelType:
        return _tile('Fuel type', stale ? '—' : '${_data.fuelType}', stale: stale);
      case Metric.ethanolFuel:
        return _tile('Ethanol fuel %', stale ? '—' : '${_data.ethanolFuel}', unit: '%', stale: stale);
      case Metric.absEvapPressure:
        return _tile('Abs evap pressure', stale ? '—' : '${_data.absEvapPressure}', unit: 'kPa', stale: stale);
      case Metric.evapPressure:
        return _tile('Evap pressure', stale ? '—' : '${_data.evapPressure}', unit: 'kPa', stale: stale);
      case Metric.shortTermO2Trim1:
        return _tile('ST O2 trim 1', stale ? '—' : '${_data.shortTermO2Trim1}', unit: '%', stale: stale);
      case Metric.longTermO2Trim1:
        return _tile('LT O2 trim 1', stale ? '—' : '${_data.longTermO2Trim1}', unit: '%', stale: stale);
      case Metric.shortTermO2Trim2:
        return _tile('ST O2 trim 2', stale ? '—' : '${_data.shortTermO2Trim2}', unit: '%', stale: stale);
      case Metric.longTermO2Trim2:
        return _tile('LT O2 trim 2', stale ? '—' : '${_data.longTermO2Trim2}', unit: '%', stale: stale);
      case Metric.shortTermO2Trim3:
        return _tile('ST O2 trim 3', stale ? '—' : '${_data.shortTermO2Trim3}', unit: '%', stale: stale);
      case Metric.longTermO2Trim3:
        return _tile('LT O2 trim 3', stale ? '—' : '${_data.longTermO2Trim3}', unit: '%', stale: stale);
      case Metric.shortTermO2Trim4:
        return _tile('ST O2 trim 4', stale ? '—' : '${_data.shortTermO2Trim4}', unit: '%', stale: stale);
      case Metric.longTermO2Trim4:
        return _tile('LT O2 trim 4', stale ? '—' : '${_data.longTermO2Trim4}', unit: '%', stale: stale);
      case Metric.catalystTemp1:
        return _tile('Catalyst temp 1', stale ? '—' : '${_data.catalystTemp1}', unit: '°C', stale: stale);
      case Metric.catalystTemp2:
        return _tile('Catalyst temp 2', stale ? '—' : '${_data.catalystTemp2}', unit: '°C', stale: stale);
      case Metric.catalystTemp3:
        return _tile('Catalyst temp 3', stale ? '—' : '${_data.catalystTemp3}', unit: '°C', stale: stale);
      case Metric.catalystTemp4:
        return _tile('Catalyst temp 4', stale ? '—' : '${_data.catalystTemp4}', unit: '°C', stale: stale);
      case Metric.fuelPressure:
        return _tile('Fuel pressure', stale ? '—' : '${_data.fuelPressure}', unit: 'kPa', stale: stale);
      case Metric.shortTermFuelTrim1:
        return _tile('ST fuel trim 1', stale ? '—' : '${_data.shortTermFuelTrim1}', unit: '%', stale: stale);
      case Metric.longTermFuelTrim1:
        return _tile('LT fuel trim 1', stale ? '—' : '${_data.longTermFuelTrim1}', unit: '%', stale: stale);
      case Metric.shortTermFuelTrim2:
        return _tile('ST fuel trim 2', stale ? '—' : '${_data.shortTermFuelTrim2}', unit: '%', stale: stale);
      case Metric.longTermFuelTrim2:
        return _tile('LT fuel trim 2', stale ? '—' : '${_data.longTermFuelTrim2}', unit: '%', stale: stale);
    }
  }

  Widget _tile(String title, String value, {String? unit, bool stale = false}) {
    return Container(
      margin: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: const Color(0xFF0D47A1).withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
      ),
      padding: const EdgeInsets.all(16),
      child: Opacity(
        opacity: stale ? 0.6 : 1,
        child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(title, 
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 12, color: Colors.white70)),
          const Spacer(),
          Text(value, 
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold)),
          if (unit != null)
            Text(unit, 
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 12, color: Colors.white70)),
          const Spacer(),
        ],
      ),
    ),
    );
  }

  String _format1(double v) => v.toStringAsFixed(1);
  String _format2(double v) => v.toStringAsFixed(2);

  Widget _rpmGauge(int rpm, {bool stale = false}) {
    return Padding(
      padding: const EdgeInsets.all(8),
      child: Opacity(
        opacity: stale ? 0.6 : 1,
        child: SfRadialGauge(axes: <RadialAxis>[
        RadialAxis(
          minimum: 0,
          maximum: 7000,
          interval: 1000,
          ranges: <GaugeRange>[
            GaugeRange(startValue: 0, endValue: 6000, color: const Color(0xFF1976D2)),
            GaugeRange(startValue: 6000, endValue: 7000, color: Colors.redAccent),
          ],
          pointers: <GaugePointer>[
            NeedlePointer(value: rpm.toDouble()),
          ],
          annotations: <GaugeAnnotation>[
            GaugeAnnotation(widget: Text(stale ? '—' : '$rpm', style: const TextStyle(fontSize: 24)), positionFactor: 0.75, angle: 90),
            const GaugeAnnotation(widget: Text('Engine RPM\nrpm', textAlign: TextAlign.center), angle: 90, positionFactor: 1.2),
          ],
        )
      ]),
      ),
    );
  }

  Widget _coolantGauge(int tempC, {bool stale = false}) {
    return Padding(
      padding: const EdgeInsets.all(8),
      child: Opacity(
        opacity: stale ? 0.6 : 1,
        child: SfRadialGauge(axes: <RadialAxis>[
        RadialAxis(
          minimum: -20,
          maximum: 120,
          ranges: <GaugeRange>[
            GaugeRange(startValue: -20, endValue: 90, color: const Color(0xFF1976D2)),
            GaugeRange(startValue: 90, endValue: 120, color: Colors.redAccent),
          ],
          pointers: <GaugePointer>[
            NeedlePointer(value: tempC.toDouble()),
          ],
          annotations: <GaugeAnnotation>[
            GaugeAnnotation(widget: Text(stale ? '—' : '$tempC', style: const TextStyle(fontSize: 20)), positionFactor: 0.7, angle: 90),
            const GaugeAnnotation(widget: Text('Coolant temp.\n°C', textAlign: TextAlign.center), angle: 90, positionFactor: 1.22),
          ],
        )
      ]),
      ),
    );
  }

  void _openConfigure() {
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) {
        final currentPage = _page.value;
        final all = Metric.values;
        final labels = {
          Metric.rpm: 'RPM',
          Metric.speed: 'Speed',
          Metric.coolant: 'Coolant temp',
          Metric.intake: 'Intake temp',
          Metric.throttle: 'Throttle position',
          Metric.fuel: 'Fuel level',
          Metric.load: 'Engine load',
          Metric.map: 'MAP kPa',
          Metric.baro: 'Baro kPa',
          Metric.maf: 'MAF g/s',
          Metric.voltage: 'Voltage V',
          Metric.ambient: 'Ambient °C',
          Metric.lambda: 'Lambda',
          // Extended
          Metric.fuelSystemStatus: 'Fuel system status',
          Metric.timingAdvance: 'Timing advance',
          Metric.runtimeSinceStart: 'Runtime since start',
          Metric.distanceWithMIL: 'Distance with MIL on',
          Metric.commandedPurge: 'Commanded purge',
          Metric.warmupsSinceClear: 'Warm-ups since clear',
          Metric.distanceSinceClear: 'Distance since clear',
          Metric.catalystTemp: 'Catalyst temperature',
          Metric.absoluteLoad: 'Absolute load value',
          Metric.commandedEquivRatio: 'Commanded equiv ratio',
          Metric.relativeThrottle: 'Relative throttle',
          Metric.absoluteThrottleB: 'Absolute throttle B',
          Metric.absoluteThrottleC: 'Absolute throttle C',
          Metric.pedalPositionD: 'Pedal position D',
          Metric.pedalPositionE: 'Pedal position E',
          Metric.pedalPositionF: 'Pedal position F',
          Metric.commandedThrottleActuator: 'Throttle actuator',
          Metric.timeRunWithMIL: 'Time run with MIL',
          Metric.timeSinceCodesCleared: 'Time since codes cleared',
          Metric.maxEquivRatio: 'Max equiv ratio',
          Metric.maxAirFlow: 'Max air flow',
          Metric.fuelType: 'Fuel type',
          Metric.ethanolFuel: 'Ethanol fuel %',
          Metric.absEvapPressure: 'Abs evap pressure',
          Metric.evapPressure: 'Evap pressure',
          Metric.shortTermO2Trim1: 'ST O2 trim 1',
          Metric.longTermO2Trim1: 'LT O2 trim 1',
          Metric.shortTermO2Trim2: 'ST O2 trim 2',
          Metric.longTermO2Trim2: 'LT O2 trim 2',
          Metric.shortTermO2Trim3: 'ST O2 trim 3',
          Metric.longTermO2Trim3: 'LT O2 trim 3',
          Metric.shortTermO2Trim4: 'ST O2 trim 4',
          Metric.longTermO2Trim4: 'LT O2 trim 4',
          Metric.catalystTemp1: 'Catalyst temp 1',
          Metric.catalystTemp2: 'Catalyst temp 2',
          Metric.catalystTemp3: 'Catalyst temp 3',
          Metric.catalystTemp4: 'Catalyst temp 4',
          Metric.fuelPressure: 'Fuel pressure',
          Metric.shortTermFuelTrim1: 'ST fuel trim 1',
          Metric.longTermFuelTrim1: 'LT fuel trim 1',
          Metric.shortTermFuelTrim2: 'ST fuel trim 2',
          Metric.longTermFuelTrim2: 'LT fuel trim 2',
        };

        List<Metric> getSelected() {
          if (currentPage == 0) return page1;
          if (currentPage == 1) return page2;
          return page3;
        }

        void setSelected(List<Metric> value) {
          if (currentPage == 0) page1 = value;
          else if (currentPage == 1) page2 = value;
          else page3 = value;
        }

        PageLayout getLayout() {
          if (currentPage == 0) return page1Layout;
          if (currentPage == 1) return page2Layout;
          return page3Layout;
        }

        void setLayout(PageLayout layout) {
          if (currentPage == 0) page1Layout = layout;
          else if (currentPage == 1) page2Layout = layout;
          else page3Layout = layout;
        }

        return DraggableScrollableSheet(
          initialChildSize: 0.7,
          minChildSize: 0.5,
          maxChildSize: 0.95,
          expand: false,
          builder: (context, controller) {
            return StatefulBuilder(
              builder: (context, setModalState) {
                final layout = getLayout();
                final selected = getSelected();
                final cap = layout == PageLayout.grid9 ? 9 : (layout == PageLayout.grid6 ? 6 : 3);

                return SingleChildScrollView(
                  controller: controller,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text('Page ${currentPage + 1}', style: const TextStyle(fontWeight: FontWeight.w600)),
                            const SizedBox(width: 12),
                            DropdownButton<PageLayout>(
                              value: layout,
                              onChanged: (v) => setModalState(() => setState(() => setLayout(v ?? layout))),
                              items: const [
                                DropdownMenuItem(value: PageLayout.large, child: Text('Large (RPM + 2)')),
                                DropdownMenuItem(value: PageLayout.grid6, child: Text('Grid 2x3 (6)')),
                                DropdownMenuItem(value: PageLayout.grid9, child: Text('Grid 3x3 (9)')),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 6,
                          children: all
                              .map((m) => FilterChip(
                                    label: Text(labels[m] ?? m.name),
                                    selected: selected.contains(m),
                                    onSelected: (v) {
                                      setState(() {
                                        var cur = List<Metric>.from(getSelected());
                                        if (v) {
                                          if (!cur.contains(m) && cur.length < cap) cur = [...cur, m];
                                        } else {
                                          cur = cur.where((e) => e != m).toList();
                                        }
                                        setSelected(cur);
                                      });
                                      setModalState(() {});
                                    },
                                  ))
                              .toList(),
                        ),
                      ],
                    ),
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  void _applyEnabledPidsForPage(int pageIndex) {
    // Enable ALL PIDs for Dashboard - serial polling với mutex đảm bảo ổn định
    final pids = _metricsToPids(Metric.values);
    // Debug: Uncomment to verify PIDs
    // print('🎯 Dashboard calling setEnabledPids with ${pids.length} PIDs');
    // print('🎯 PIDs include 010D? ${pids.contains('010D')}, 0105? ${pids.contains('0105')}');
    widget.client.setEnabledPids(pids);
  }

  void _markUpdatedFromEnabledPids() {
    final pids = widget.client.enabledPids;
    final now = DateTime.now();
    for (final pid in pids) {
      final metric = _pidToMetric(pid);
      if (metric != null) {
        _lastUpdated[metric] = now;
      }
    }
  }

  Metric? _pidToMetric(String pid) {
    switch (pid) {
      case '010C': return Metric.rpm;
      case '010D': return Metric.speed;
      case '0105': return Metric.coolant;
      case '010F': return Metric.intake;
      case '0111': return Metric.throttle;
      case '012F': return Metric.fuel;
      case '0104': return Metric.load;
      case '010B': return Metric.map;
      case '0133': return Metric.baro;
      case '0110': return Metric.maf;
      case '0142': return Metric.voltage;
      case '0146': return Metric.ambient;
      case '015E': return Metric.lambda;
      case '0103': return Metric.fuelSystemStatus;
      case '010E': return Metric.timingAdvance;
      case '011F': return Metric.runtimeSinceStart;
      case '0121': return Metric.distanceWithMIL;
      case '012E': return Metric.commandedPurge;
      case '0130': return Metric.warmupsSinceClear;
      case '0131': return Metric.distanceSinceClear;
      case '0143': return Metric.absoluteLoad;
      case '0144': return Metric.commandedEquivRatio;
      case '0145': return Metric.relativeThrottle;
      case '0147': return Metric.absoluteThrottleB;
      case '0148': return Metric.absoluteThrottleC;
      case '0149': return Metric.pedalPositionD;
      case '014A': return Metric.pedalPositionE;
      case '014B': return Metric.pedalPositionF;
      case '014C': return Metric.commandedThrottleActuator;
      case '014D': return Metric.timeRunWithMIL;
      case '014E': return Metric.timeSinceCodesCleared;
      case '014F': return Metric.maxEquivRatio;
      case '0150': return Metric.maxAirFlow;
      case '0151': return Metric.fuelType;
      case '0152': return Metric.ethanolFuel;
      case '0153': return Metric.absEvapPressure;
      case '0154': return Metric.evapPressure;
      case '0155': return Metric.shortTermO2Trim1;
      case '0156': return Metric.longTermO2Trim1;
      case '0157': return Metric.shortTermO2Trim2;
      case '0158': return Metric.longTermO2Trim2;
      case '0159': return Metric.shortTermO2Trim3;
      case '015A': return Metric.longTermO2Trim3;
      case '015B': return Metric.shortTermO2Trim4;
      case '015C': return Metric.longTermO2Trim4;
      case '013C': return Metric.catalystTemp1;
      case '013D': return Metric.catalystTemp2;
      case '013E': return Metric.catalystTemp3;
      case '013F': return Metric.catalystTemp4;
      case '010A': return Metric.fuelPressure;
    }
    return null;
  }

  bool _isStale(Metric m) {
    final t = _lastUpdated[m];
    if (t == null) return true;
    return DateTime.now().difference(t) > _staleAfter;
  }
  Set<String> _metricsToPids(List<Metric> ms) {
    final set = <String>{};
    for (final m in ms) {
      switch (m) {
        case Metric.rpm:
          set.add('010C');
          break;
        case Metric.speed:
          set.add('010D');
          break;
        case Metric.coolant:
          set.add('0105');
          break;
        case Metric.intake:
          set.add('010F');
          break;
        case Metric.throttle:
          set.add('0111');
          break;
        case Metric.fuel:
          set.add('012F');
          break;
        case Metric.load:
          set.add('0104');
          break;
        case Metric.map:
          set.add('010B');
          break;
        case Metric.baro:
          set.add('0133');
          break;
        case Metric.maf:
          set.add('0110');
          break;
        case Metric.voltage:
          set.add('0142');
          break;
        case Metric.ambient:
          set.add('0146');
          break;
        case Metric.lambda:
          set.add('015E');
          break;
        // Extended mapping
        case Metric.fuelSystemStatus:
          set.add('0103');
          break;
        case Metric.timingAdvance:
          set.add('010E');
          break;
        case Metric.runtimeSinceStart:
          set.add('011F');
          break;
        case Metric.distanceWithMIL:
          set.add('0121');
          break;
        case Metric.commandedPurge:
          set.add('012E');
          break;
        case Metric.warmupsSinceClear:
          set.add('0130');
          break;
        case Metric.distanceSinceClear:
          set.add('0131');
          break;
        case Metric.catalystTemp:
          set.add('013C');
          break;
        case Metric.absoluteLoad:
          set.add('0143');
          break;
        case Metric.commandedEquivRatio:
          set.add('0144');
          break;
        case Metric.relativeThrottle:
          set.add('0145');
          break;
        case Metric.absoluteThrottleB:
          set.add('0147');
          break;
        case Metric.absoluteThrottleC:
          set.add('0148');
          break;
        case Metric.pedalPositionD:
          set.add('0149');
          break;
        case Metric.pedalPositionE:
          set.add('014A');
          break;
        case Metric.pedalPositionF:
          set.add('014B');
          break;
        case Metric.commandedThrottleActuator:
          set.add('014C');
          break;
        case Metric.timeRunWithMIL:
          set.add('014D');
          break;
        case Metric.timeSinceCodesCleared:
          set.add('014E');
          break;
        case Metric.maxEquivRatio:
          set.add('014F');
          break;
        case Metric.maxAirFlow:
          set.add('0150');
          break;
        case Metric.fuelType:
          set.add('0151');
          break;
        case Metric.ethanolFuel:
          set.add('0152');
          break;
        case Metric.absEvapPressure:
          set.add('0153');
          break;
        case Metric.evapPressure:
          set.add('0154');
          break;
        case Metric.shortTermO2Trim1:
          set.add('0155');
          break;
        case Metric.longTermO2Trim1:
          set.add('0156');
          break;
        case Metric.shortTermO2Trim2:
          set.add('0157');
          break;
        case Metric.longTermO2Trim2:
          set.add('0158');
          break;
        case Metric.shortTermO2Trim3:
          set.add('0159');
          break;
        case Metric.longTermO2Trim3:
          set.add('015A');
          break;
        case Metric.shortTermO2Trim4:
          set.add('015B');
          break;
        case Metric.longTermO2Trim4:
          set.add('015C');
          break;
        case Metric.catalystTemp1:
          set.add('013C');
          break;
        case Metric.catalystTemp2:
          set.add('013D');
          break;
        case Metric.catalystTemp3:
          set.add('013E');
          break;
        case Metric.catalystTemp4:
          set.add('013F');
          break;
        case Metric.fuelPressure:
          set.add('010A');
          break;
        case Metric.shortTermFuelTrim1:
          set.add('0106');
          break;
        case Metric.longTermFuelTrim1:
          set.add('0107');
          break;
        case Metric.shortTermFuelTrim2:
          set.add('0108');
          break;
        case Metric.longTermFuelTrim2:
          set.add('0109');
          break;
      }
    }
    return set;
  }

  Widget _allMetricsPage() {
    final entries = <MapEntry<String, String>>[
      MapEntry('Engine RPM', '${_data.engineRpm} rpm'),
      MapEntry('Vehicle Speed', '${_data.vehicleSpeedKmh} km/h'),
      MapEntry('Coolant Temp', '${_data.coolantTempC} °C'),
      MapEntry('Intake Temp', '${_data.intakeTempC} °C'),
      MapEntry('Throttle Position', '${_data.throttlePositionPercent} %'),
      MapEntry('Fuel Level', '${_data.fuelLevelPercent} %'),
      MapEntry('Engine Load', '${_data.engineLoadPercent} %'),
      MapEntry('MAP', '${_data.mapKpa} kPa'),
      MapEntry('Baro', '${_data.baroKpa} kPa'),
      MapEntry('MAF', '${_data.mafGs} g/s'),
      MapEntry('Voltage', _format1(_data.voltageV) + ' V'),
      MapEntry('Ambient', '${_data.ambientTempC} °C'),
      MapEntry('Lambda', _format2(_data.lambda)),
      MapEntry('Fuel System Status', '${_data.fuelSystemStatus}'),
      MapEntry('Timing Advance', '${_data.timingAdvance} °'),
      MapEntry('Runtime Since Start', '${_data.runtimeSinceStart} s'),
      MapEntry('Distance with MIL', '${_data.distanceWithMIL} km'),
      MapEntry('Commanded Purge', '${_data.commandedPurge} %'),
      MapEntry('Warm-ups Since Clear', '${_data.warmupsSinceClear}'),
      MapEntry('Distance Since Clear', '${_data.distanceSinceClear} km'),
      MapEntry('Catalyst Temp', '${_data.catalystTemp} °C'),
      MapEntry('Absolute Load', '${_data.absoluteLoad} %'),
      MapEntry('Commanded Equiv Ratio', _format2(_data.commandedEquivRatio)),
      MapEntry('Relative Throttle', '${_data.relativeThrottle} %'),
      MapEntry('Abs Throttle B', '${_data.absoluteThrottleB} %'),
      MapEntry('Abs Throttle C', '${_data.absoluteThrottleC} %'),
      MapEntry('Pedal Position D', '${_data.pedalPositionD} %'),
      MapEntry('Pedal Position E', '${_data.pedalPositionE} %'),
      MapEntry('Pedal Position F', '${_data.pedalPositionF} %'),
      MapEntry('Throttle Actuator', '${_data.commandedThrottleActuator} %'),
      MapEntry('Time Run With MIL', '${_data.timeRunWithMIL} s'),
      MapEntry('Time Since Codes Cleared', '${_data.timeSinceCodesCleared} s'),
      MapEntry('Max Equiv Ratio', _format2(_data.maxEquivRatio)),
      MapEntry('Max Air Flow', '${_data.maxAirFlow} g/s'),
      MapEntry('Fuel Type', '${_data.fuelType}'),
      MapEntry('Ethanol Fuel %', '${_data.ethanolFuel} %'),
      MapEntry('Abs Evap Pressure', '${_data.absEvapPressure} kPa'),
      MapEntry('Evap Pressure', '${_data.evapPressure} kPa'),
      MapEntry('ST O2 Trim 1', '${_data.shortTermO2Trim1} %'),
      MapEntry('LT O2 Trim 1', '${_data.longTermO2Trim1} %'),
      MapEntry('ST O2 Trim 2', '${_data.shortTermO2Trim2} %'),
      MapEntry('LT O2 Trim 2', '${_data.longTermO2Trim2} %'),
      MapEntry('ST O2 Trim 3', '${_data.shortTermO2Trim3} %'),
      MapEntry('LT O2 Trim 3', '${_data.longTermO2Trim3} %'),
      MapEntry('ST O2 Trim 4', '${_data.shortTermO2Trim4} %'),
      MapEntry('LT O2 Trim 4', '${_data.longTermO2Trim4} %'),
      MapEntry('Catalyst Temp 1', '${_data.catalystTemp1} °C'),
      MapEntry('Catalyst Temp 2', '${_data.catalystTemp2} °C'),
      MapEntry('Catalyst Temp 3', '${_data.catalystTemp3} °C'),
      MapEntry('Catalyst Temp 4', '${_data.catalystTemp4} °C'),
      MapEntry('Fuel Pressure', '${_data.fuelPressure} kPa'),
      MapEntry('ST Fuel Trim 1', '${_data.shortTermFuelTrim1} %'),
      MapEntry('LT Fuel Trim 1', '${_data.longTermFuelTrim1} %'),
      MapEntry('ST Fuel Trim 2', '${_data.shortTermFuelTrim2} %'),
      MapEntry('LT Fuel Trim 2', '${_data.longTermFuelTrim2} %'),
    ];

    return Padding(
      padding: const EdgeInsets.all(8),
      child: GridView.builder(
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          mainAxisSpacing: 8,
          crossAxisSpacing: 8,
          childAspectRatio: 2.6,
        ),
        itemCount: entries.length,
        itemBuilder: (context, index) {
          final e = entries[index];
          return _tile(e.key, e.value);
        },
      ),
    );
  }

  Widget _allMetricsListPage() {
    final entries = <MapEntry<String, String>>[
      MapEntry('Engine RPM', '${_data.engineRpm} rpm'),
      MapEntry('Vehicle Speed', '${_data.vehicleSpeedKmh} km/h'),
      MapEntry('Coolant Temp', '${_data.coolantTempC} °C'),
      MapEntry('Intake Temp', '${_data.intakeTempC} °C'),
      MapEntry('Throttle Position', '${_data.throttlePositionPercent} %'),
      MapEntry('Fuel Level', '${_data.fuelLevelPercent} %'),
      MapEntry('Engine Load', '${_data.engineLoadPercent} %'),
      MapEntry('MAP', '${_data.mapKpa} kPa'),
      MapEntry('Baro', '${_data.baroKpa} kPa'),
      MapEntry('MAF', '${_data.mafGs} g/s'),
      MapEntry('Voltage', _format1(_data.voltageV) + ' V'),
      MapEntry('Ambient', '${_data.ambientTempC} °C'),
      MapEntry('Lambda', _format2(_data.lambda)),
      MapEntry('Fuel System Status', '${_data.fuelSystemStatus}'),
      MapEntry('Timing Advance', '${_data.timingAdvance} °'),
      MapEntry('Runtime Since Start', '${_data.runtimeSinceStart} s'),
      MapEntry('Distance with MIL', '${_data.distanceWithMIL} km'),
      MapEntry('Commanded Purge', '${_data.commandedPurge} %'),
      MapEntry('Warm-ups Since Clear', '${_data.warmupsSinceClear}'),
      MapEntry('Distance Since Clear', '${_data.distanceSinceClear} km'),
      MapEntry('Catalyst Temp', '${_data.catalystTemp} °C'),
      MapEntry('Absolute Load', '${_data.absoluteLoad} %'),
      MapEntry('Commanded Equiv Ratio', _format2(_data.commandedEquivRatio)),
      MapEntry('Relative Throttle', '${_data.relativeThrottle} %'),
      MapEntry('Abs Throttle B', '${_data.absoluteThrottleB} %'),
      MapEntry('Abs Throttle C', '${_data.absoluteThrottleC} %'),
      MapEntry('Pedal Position D', '${_data.pedalPositionD} %'),
      MapEntry('Pedal Position E', '${_data.pedalPositionE} %'),
      MapEntry('Pedal Position F', '${_data.pedalPositionF} %'),
      MapEntry('Throttle Actuator', '${_data.commandedThrottleActuator} %'),
      MapEntry('Time Run With MIL', '${_data.timeRunWithMIL} s'),
      MapEntry('Time Since Codes Cleared', '${_data.timeSinceCodesCleared} s'),
      MapEntry('Max Equiv Ratio', _format2(_data.maxEquivRatio)),
      MapEntry('Max Air Flow', '${_data.maxAirFlow} g/s'),
      MapEntry('Fuel Type', '${_data.fuelType}'),
      MapEntry('Ethanol Fuel %', '${_data.ethanolFuel} %'),
      MapEntry('Abs Evap Pressure', '${_data.absEvapPressure} kPa'),
      MapEntry('Evap Pressure', '${_data.evapPressure} kPa'),
      MapEntry('ST O2 Trim 1', '${_data.shortTermO2Trim1} %'),
      MapEntry('LT O2 Trim 1', '${_data.longTermO2Trim1} %'),
      MapEntry('ST O2 Trim 2', '${_data.shortTermO2Trim2} %'),
      MapEntry('LT O2 Trim 2', '${_data.longTermO2Trim2} %'),
      MapEntry('ST O2 Trim 3', '${_data.shortTermO2Trim3} %'),
      MapEntry('LT O2 Trim 3', '${_data.longTermO2Trim3} %'),
      MapEntry('ST O2 Trim 4', '${_data.shortTermO2Trim4} %'),
      MapEntry('LT O2 Trim 4', '${_data.longTermO2Trim4} %'),
      MapEntry('Catalyst Temp 1', '${_data.catalystTemp1} °C'),
      MapEntry('Catalyst Temp 2', '${_data.catalystTemp2} °C'),
      MapEntry('Catalyst Temp 3', '${_data.catalystTemp3} °C'),
      MapEntry('Catalyst Temp 4', '${_data.catalystTemp4} °C'),
      MapEntry('Fuel Pressure', '${_data.fuelPressure} kPa'),
      MapEntry('ST Fuel Trim 1', '${_data.shortTermFuelTrim1} %'),
      MapEntry('LT Fuel Trim 1', '${_data.longTermFuelTrim1} %'),
      MapEntry('ST Fuel Trim 2', '${_data.shortTermFuelTrim2} %'),
      MapEntry('LT Fuel Trim 2', '${_data.longTermFuelTrim2} %'),
    ];

    return ListView.separated(
      padding: const EdgeInsets.all(8),
      itemCount: entries.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final e = entries[index];
        return ListTile(
          dense: true,
          visualDensity: const VisualDensity(vertical: -2),
          title: Text(e.key),
          trailing: Text(e.value, style: const TextStyle(fontWeight: FontWeight.w600)),
        );
      },
    );
  }
}


