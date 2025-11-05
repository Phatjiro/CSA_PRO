import 'dart:async';

import 'package:flutter/material.dart';

import '../services/connection_manager.dart';
import '../services/obd_client.dart';

class AccelerationTestsScreen extends StatefulWidget {
  const AccelerationTestsScreen({super.key});

  @override
  State<AccelerationTestsScreen> createState() => _AccelerationTestsScreenState();
}

class _AccelerationTestsScreenState extends State<AccelerationTestsScreen> {
  late final ObdClient _client;
  StreamSubscription? _sub;
  int _currentSpeed = 0;

  // Default test ranges
  final List<_AccelTest> _tests = [
    _AccelTest(0, 20),
    _AccelTest(0, 30),
    _AccelTest(0, 40),
    _AccelTest(0, 60),
    _AccelTest(0, 80),
    _AccelTest(80, 120),
    _AccelTest(0, 100),
    _AccelTest(0, 120),
    _AccelTest(100, 200),
    _AccelTest(0, 200),
  ];

  @override
  void initState() {
    super.initState();
    _client = ConnectionManager.instance.client!;
    _sub = _client.dataStream.listen((data) {
      if (!mounted) return;
      final speed = data.vehicleSpeedKmh;
      _currentSpeed = speed;
      for (final t in _tests) {
        t.feed(speed);
      }
      setState(() {});
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: Text('$_currentSpeed km/h'),
        backgroundColor: const Color(0xFFE91E63),
        foregroundColor: Colors.white,
      ),
      body: SafeArea(
        child: ListView.separated(
          padding: const EdgeInsets.only(bottom: 16),
          itemCount: _tests.length,
          separatorBuilder: (_, __) => const Divider(height: 1),
          itemBuilder: (context, index) {
            final t = _tests[index];
            return ListTile(
              title: Text('Acceleration time:\n${t.startKmh}-${t.endKmh} km/h'),
              subtitle: Text(t.isRunning
                  ? 'Running...'
                  : t.durationMs == null
                      ? '00:00.000'
                      : _formatMs(t.durationMs!)),
              trailing: IconButton(
                icon: const Icon(Icons.refresh),
                onPressed: () => setState(() => t.reset()),
              ),
              onTap: () => setState(() => t.reset()),
            );
          },
        ),
      ),
    );
  }

  String _formatMs(int ms) {
    final minutes = (ms ~/ 60000).toString().padLeft(2, '0');
    final seconds = ((ms % 60000) ~/ 1000).toString().padLeft(2, '0');
    final millis = (ms % 1000).toString().padLeft(3, '0');
    return '$minutes:$seconds.$millis';
  }
}

class _AccelTest {
  final int startKmh;
  final int endKmh;
  int? durationMs;
  bool isRunning = false;
  int? _startEpochMs;
  int _prevSpeed = 0;

  _AccelTest(this.startKmh, this.endKmh);

  void reset() {
    durationMs = null;
    isRunning = false;
    _startEpochMs = null;
  }

  void feed(int speedKmh) {
    // Start when crossing startKmh upward
    if (!isRunning && durationMs == null && _prevSpeed < startKmh && speedKmh >= startKmh) {
      isRunning = true;
      _startEpochMs = DateTime.now().millisecondsSinceEpoch;
    }
    // Stop when crossing endKmh upward
    if (isRunning && _prevSpeed < endKmh && speedKmh >= endKmh) {
      final end = DateTime.now().millisecondsSinceEpoch;
      durationMs = end - (_startEpochMs ?? end);
      isRunning = false;
    }
    // Nếu xe dừng hẳn, cho phép test chạy lại
    if (!isRunning && speedKmh < startKmh - 2 && _prevSpeed < startKmh - 2) {
      // giữ kết quả, nhưng cho phép arm lại lần mới khi vượt start
    }
    _prevSpeed = speedKmh;
  }
}


