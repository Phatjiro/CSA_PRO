import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_gauges/gauges.dart';

import '../models/obd_live_data.dart';
import '../services/obd_client.dart';

enum Metric { rpm, speed, coolant, intake, throttle, fuel }

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
  );

  final ValueNotifier<int> _page = ValueNotifier<int>(0);
  // Selections: exactly 3 metrics per page
  List<Metric> page1 = const [Metric.rpm, Metric.speed, Metric.coolant];
  List<Metric> page2 = const [Metric.intake, Metric.throttle, Metric.fuel];

  @override
  void initState() {
    super.initState();
    widget.client.dataStream.listen((event) {
      setState(() {
        _data = event;
      });
    });
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
          onPageChanged: (i) => _page.value = i,
          children: [
            _pageContent(page1),
            _pageContent(page2),
          ],
        ),
      ),
    );
  }

  Widget _pageContent(List<Metric> metrics) {
    // Layout: if contains rpm -> big gauge on top, else two columns
    final hasRpm = metrics.contains(Metric.rpm);
    if (hasRpm) {
      return Column(
        children: [
          Expanded(flex: 2, child: _rpmGauge(_data.engineRpm)),
          Expanded(
            flex: 1,
            child: Row(children: _smallTiles(metrics.where((m) => m != Metric.rpm).toList())),
          ),
        ],
      );
    }
    return Column(
      children: [
        Expanded(
          child: Row(children: _smallTiles(metrics.take(2).toList())),
        ),
        Expanded(
          child: Row(children: _smallTiles(metrics.skip(2).take(2).toList())),
        ),
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontSize: 16, color: Colors.white70)),
          const Spacer(),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(value, style: const TextStyle(fontSize: 48, fontWeight: FontWeight.bold)),
              if (unit != null) ...[
                const SizedBox(width: 6),
                Text(unit, style: const TextStyle(fontSize: 16, color: Colors.white70)),
              ],
            ],
          ),
        ],
      ),
    );
  }

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
      builder: (context) {
        final all = Metric.values;
        final labels = {
          Metric.rpm: 'RPM',
          Metric.speed: 'Speed',
          Metric.coolant: 'Coolant temp',
          Metric.intake: 'Intake temp',
          Metric.throttle: 'Throttle position',
          Metric.fuel: 'Fuel level',
        };

        bool selected(List<Metric> list, Metric m) => list.contains(m);
        void toggle(List<Metric> list, Metric m, VoidCallback refresh) {
          if (list.contains(m)) {
            list = list.where((e) => e != m).toList();
          } else {
            if (list.length >= 3) return; // limit 3 per page
            list = [...list, m];
          }
          setState(() {
            if (identical(list, page1)) {
              page1 = list;
            }
          });
          refresh();
        }

        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Trang 1 (tối đa 3 mục)', style: TextStyle(fontWeight: FontWeight.w600)),
                  Wrap(
                    spacing: 8,
                    children: all
                        .map((m) => FilterChip(
                              label: Text(labels[m]!),
                              selected: page1.contains(m),
                              onSelected: (v) {
                                setState(() {
                                  if (v) {
                                    if (!page1.contains(m) && page1.length < 3) page1 = [...page1, m];
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
                  const Text('Trang 2 (tối đa 3 mục)', style: TextStyle(fontWeight: FontWeight.w600)),
                  Wrap(
                    spacing: 8,
                    children: all
                        .map((m) => FilterChip(
                              label: Text(labels[m]!),
                              selected: page2.contains(m),
                              onSelected: (v) {
                                setState(() {
                                  if (v) {
                                    if (!page2.contains(m) && page2.length < 3) page2 = [...page2, m];
                                  } else {
                                    page2 = page2.where((e) => e != m).toList();
                                  }
                                });
                                setModalState(() {});
                              },
                            ))
                        .toList(),
                  ),
                  const SizedBox(height: 8),
                ],
              ),
            );
          },
        );
      },
    );
  }
}


