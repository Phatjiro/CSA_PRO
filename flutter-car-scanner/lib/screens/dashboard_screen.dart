import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_gauges/gauges.dart';

import '../models/obd_live_data.dart';
import '../services/obd_client.dart';

class DashboardScreen extends StatefulWidget {
  final ObdClient client;
  const DashboardScreen({super.key, required this.client});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  ObdLiveData _data = const ObdLiveData(engineRpm: 0, vehicleSpeedKmh: 0, coolantTempC: 0);

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
        child: Column(
          children: [
            Expanded(
              flex: 2,
              child: _rpmGauge(_data.engineRpm),
            ),
            Expanded(
              flex: 1,
              child: Row(
                children: [
                  Expanded(child: _tile('Speed', '${_data.vehicleSpeedKmh}', unit: 'km/h')),
                  Expanded(child: _coolantGauge(_data.coolantTempC)),
                ],
              ),
            ),
            const SizedBox(height: 6),
          ],
        ),
      ),
    );
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
}


