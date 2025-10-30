import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_gauges/gauges.dart';

import '../models/obd_live_data.dart';
import '../services/obd_client.dart';

enum Metric { rpm, speed, coolant, intake, throttle, fuel, load, map, baro, maf, voltage, ambient, lambda }
enum PageLayout { large, grid6, grid9 }

class DashboardScreen extends StatefulWidget {
  final ObdClient client;
  const DashboardScreen({super.key, required this.client});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
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
  List<Metric> page3 = const [
    Metric.map,
    Metric.baro,
    Metric.maf,
    Metric.fuel,
    Metric.throttle,
    Metric.load,
    Metric.voltage,
    Metric.ambient,
    Metric.lambda,
  ];
  PageLayout page1Layout = PageLayout.large; // big RPM + 2 tiles
  PageLayout page2Layout = PageLayout.grid9;  // 3x3 grid (max 9)
  PageLayout page3Layout = PageLayout.grid9;  // 3x3 grid (max 9)

  @override
  void initState() {
    super.initState();
    widget.client.dataStream.listen((event) {
      setState(() {
        _data = event;
      });
    });
    // Ban đầu, chỉ bật các PIDs cho trang 1 (RPM, Speed, Coolant)
    _applyEnabledPidsForPage(0);
  }

  @override
  void dispose() {
    widget.client.disconnect();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Live Dashboard'),
        actions: [
          IconButton(
            onPressed: _openConfigure,
            icon: const Icon(Icons.tune),
            tooltip: 'Configure',
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Center(
              child: Text(widget.client.isConnected ? 'Connected' : 'Disconnected',
                  style: TextStyle(color: widget.client.isConnected ? Colors.greenAccent : Colors.redAccent)),
            ),
          )
        ],
      ),
      body: SafeArea(
        minimum: const EdgeInsets.only(bottom: 12),
        child: PageView(
          onPageChanged: (i) {
            _page.value = i;
            _applyEnabledPidsForPage(i);
          },
          children: [
            _pageContent(page1, page1Layout),
            _pageContent(page2, page2Layout),
            _pageContent(page3, page3Layout),
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
    switch (m) {
      case Metric.speed:
        return _tile('Speed', '${_data.vehicleSpeedKmh}', unit: 'km/h');
      case Metric.coolant:
        return _coolantGauge(_data.coolantTempC);
      case Metric.intake:
        return _tile('Intake temp', '${_data.intakeTempC}', unit: '°C');
      case Metric.throttle:
        return _tile('Throttle', '${_data.throttlePositionPercent}', unit: '%');
      case Metric.fuel:
        return _tile('Fuel level', '${_data.fuelLevelPercent}', unit: '%');
      case Metric.load:
        return _tile('Engine load', '${_data.engineLoadPercent}', unit: '%');
      case Metric.map:
        return _tile('MAP', '${_data.mapKpa}', unit: 'kPa');
      case Metric.baro:
        return _tile('Baro', '${_data.baroKpa}', unit: 'kPa');
      case Metric.maf:
        return _tile('MAF', '${_data.mafGs}', unit: 'g/s');
      case Metric.voltage:
        return _tile('Voltage', _format1(_data.voltageV), unit: 'V');
      case Metric.ambient:
        return _tile('Ambient', '${_data.ambientTempC}', unit: '°C');
      case Metric.lambda:
        return _tile('Lambda', _format2(_data.lambda));
      case Metric.rpm:
        return _rpmGauge(_data.engineRpm);
    }
  }

  Widget _tile(String title, String value, {String? unit}) {
    return Container(
      margin: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: const Color(0xFF0D47A1).withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(title, style: const TextStyle(fontSize: 12, color: Colors.white70)),
          const Spacer(),
          Text(value, style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold)),
          if (unit != null)
            Text(unit, style: const TextStyle(fontSize: 12, color: Colors.white70)),
          const Spacer(),
        ],
      ),
    );
  }

  String _format1(double v) => v.toStringAsFixed(1);
  String _format2(double v) => v.toStringAsFixed(2);

  Widget _rpmGauge(int rpm) {
    return Padding(
      padding: const EdgeInsets.all(8),
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
            GaugeAnnotation(widget: Text('$rpm', style: const TextStyle(fontSize: 24)), positionFactor: 0.75, angle: 90),
            const GaugeAnnotation(widget: Text('Engine RPM\nrpm', textAlign: TextAlign.center), angle: 90, positionFactor: 1.2),
          ],
        )
      ]),
    );
  }

  Widget _coolantGauge(int tempC) {
    return Padding(
      padding: const EdgeInsets.all(8),
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
            GaugeAnnotation(widget: Text('$tempC', style: const TextStyle(fontSize: 20)), positionFactor: 0.7, angle: 90),
            const GaugeAnnotation(widget: Text('Coolant temp.\n°C', textAlign: TextAlign.center), angle: 90, positionFactor: 1.22),
          ],
        )
      ]),
    );
  }

  void _openConfigure() {
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) {
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
        };

        return DraggableScrollableSheet(
          initialChildSize: 0.8,
          minChildSize: 0.5,
          maxChildSize: 0.95,
          expand: false,
          builder: (context, controller) {
            return StatefulBuilder(
              builder: (context, setModalState) {
                return SingleChildScrollView(
                  controller: controller,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Text('Trang 1', style: TextStyle(fontWeight: FontWeight.w600)),
                            const SizedBox(width: 12),
                            DropdownButton<PageLayout>(
                              value: page1Layout,
                              onChanged: (v) => setModalState(() => setState(() => page1Layout = v ?? PageLayout.large)),
                              items: const [
                                DropdownMenuItem(value: PageLayout.large, child: Text('Large (RPM + 2)')),
                                DropdownMenuItem(value: PageLayout.grid6, child: Text('Grid 2x3 (6)')),
                                DropdownMenuItem(value: PageLayout.grid9, child: Text('Grid 3x3 (9)')),
                              ],
                            ),
                          ],
                        ),
                        Wrap(
                          spacing: 8,
                          children: all
                              .map((m) => FilterChip(
                                    label: Text(labels[m]!),
                                    selected: page1.contains(m),
                                    onSelected: (v) {
                                      setState(() {
                                        final cap = page1Layout == PageLayout.grid9 ? 9 : (page1Layout == PageLayout.grid6 ? 6 : 3);
                                        if (v) {
                                          if (!page1.contains(m) && page1.length < cap) page1 = [...page1, m];
                                        } else {
                                          page1 = page1.where((e) => e != m).toList();
                                        }
                                      });
                                      setModalState(() {});
                                    },
                                  ))
                              .toList(),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            const Text('Trang 2', style: TextStyle(fontWeight: FontWeight.w600)),
                            const SizedBox(width: 12),
                            DropdownButton<PageLayout>(
                              value: page2Layout,
                              onChanged: (v) => setModalState(() => setState(() => page2Layout = v ?? PageLayout.grid6)),
                              items: const [
                                DropdownMenuItem(value: PageLayout.large, child: Text('Large (RPM + 2)')),
                                DropdownMenuItem(value: PageLayout.grid6, child: Text('Grid 2x3 (6)')),
                                DropdownMenuItem(value: PageLayout.grid9, child: Text('Grid 3x3 (9)')),
                              ],
                            ),
                          ],
                        ),
                        Wrap(
                          spacing: 8,
                          children: all
                              .map((m) => FilterChip(
                                    label: Text(labels[m] ?? m.name),
                                    selected: page2.contains(m),
                                    onSelected: (v) {
                                      setState(() {
                                        final cap = page2Layout == PageLayout.grid9 ? 9 : (page2Layout == PageLayout.grid6 ? 6 : 3);
                                        if (v) {
                                          if (!page2.contains(m) && page2.length < cap) page2 = [...page2, m];
                                        } else {
                                          page2 = page2.where((e) => e != m).toList();
                                        }
                                      });
                                      setModalState(() {});
                                    },
                                  ))
                              .toList(),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            const Text('Trang 3', style: TextStyle(fontWeight: FontWeight.w600)),
                            const SizedBox(width: 12),
                            DropdownButton<PageLayout>(
                              value: page3Layout,
                              onChanged: (v) => setModalState(() => setState(() => page3Layout = v ?? PageLayout.grid6)),
                              items: const [
                                DropdownMenuItem(value: PageLayout.large, child: Text('Large (RPM + 2)')),
                                DropdownMenuItem(value: PageLayout.grid6, child: Text('Grid 2x3 (6)')),
                                DropdownMenuItem(value: PageLayout.grid9, child: Text('Grid 3x3 (9)')),
                              ],
                            ),
                          ],
                        ),
                        Wrap(
                          spacing: 8,
                          children: all
                              .map((m) => FilterChip(
                                    label: Text(labels[m] ?? m.name),
                                    selected: page3.contains(m),
                                    onSelected: (v) {
                                      setState(() {
                                        final cap = page3Layout == PageLayout.grid9 ? 9 : (page3Layout == PageLayout.grid6 ? 6 : 3);
                                        if (v) {
                                          if (!page3.contains(m) && page3.length < cap) page3 = [...page3, m];
                                        } else {
                                          page3 = page3.where((e) => e != m).toList();
                                        }
                                      });
                                      setModalState(() {});
                                    },
                                  ))
                              .toList(),
                        ),
                        const SizedBox(height: 12),
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
    // Luôn đảm bảo các PID của Page 1 (RPM, Speed, Coolant)
    final required = <Metric>{Metric.rpm, Metric.speed, Metric.coolant};
    if (pageIndex == 1) {
      required.addAll(page2);
    } else if (pageIndex == 2) {
      required.addAll(page3);
    }
    final pids = _metricsToPids(required.toList());
    widget.client.setEnabledPids(pids);
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
}


