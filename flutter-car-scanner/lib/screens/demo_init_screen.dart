import 'dart:async';
import 'package:flutter/material.dart';

import '../services/connection_manager.dart';
import '../services/vehicle_service.dart';
import '../models/vehicle.dart';

class _DemoInitContent extends StatefulWidget {
  const _DemoInitContent();

  @override
  State<_DemoInitContent> createState() => _DemoInitContentState();
}

class _DemoInitContentState extends State<_DemoInitContent> {
  final List<_StepItem> _steps = [
    _StepItem('Init ELM327', Icons.memory),
    _StepItem('Set protocol', Icons.tune),
    _StepItem('Load DTC/Readiness', Icons.fact_check),
    _StepItem('Seed live data', Icons.bolt),
    _StepItem('Finalize demo', Icons.verified),
  ];

  int _current = 0;
  bool _done = false;
  Timer? _timer;
  double _progress = 0.0; // 0..1 continuous
  bool _showSuccess = false;

  @override
  void initState() {
    super.initState();
    _runSequence();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _runSequence() async {
    // Smooth fake loading over ~3 seconds
    const totalMs = 3000;
    const tickMs = 16; // ~60fps
    int elapsed = 0;
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(milliseconds: tickMs), (t) async {
      elapsed += tickMs;
      final p = (elapsed / totalMs).clamp(0.0, 1.0);
      if (!mounted) return;
      setState(() {
        _progress = p;
        _current = (_progress * _steps.length).clamp(0, (_steps.length - 1).toDouble()).floor();
      });
      if (p >= 1.0) {
        t.cancel();
        // Perform actual demo connection at the end
        Vehicle? v = ConnectionManager.instance.vehicle;
        v ??= VehicleService.all().isNotEmpty ? VehicleService.all().first : null;
        await ConnectionManager.instance.connectDemo(vehicle: v);
        if (!mounted) return;
        setState(() { _done = true; _showSuccess = true; });
        await Future.delayed(const Duration(milliseconds: 800));
        if (!mounted) return;
        Navigator.of(context).pop();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final progress = _done ? 1.0 : _progress;
    const Color accent = Color(0xFFE91E63); // fixed accent
    const Color success = Color(0xFF2ECC71); // green
    const List<Color> multi = <Color>[
      Color(0xFF1E88E5), // blue
      Color(0xFF2ECC71), // green
      Color(0xFFF39C12), // yellow
      Color(0xFFE91E63), // red-pink
      Color(0xFF9B59B6), // purple
      Color(0xFF1E88E5), // loop back
    ];
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: Container(
          decoration: BoxDecoration(
            color: const Color(0xFF121212),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white12),
          ),
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              // Icon block (compact)
              SizedBox(
                width: 96,
                height: 90,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      width: 76,
                      height: 52,
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 220),
                        transitionBuilder: (c, a) => ScaleTransition(scale: a, child: c),
                        child: _showSuccess
                            ? Transform.rotate(
                                key: const ValueKey('car-success'),
                                angle: -0.12,
                                child: _CarFillIcon(
                                  progress: 1.0,
                                  baseColor: Colors.white24,
                                  fillColor: success,
                                  size: 52,
                                  icon: Icons.directions_car,
                                ),
                              )
                            : Transform.rotate(
                                key: const ValueKey('car-progress'),
                                angle: -0.12,
                                child: _CarFillIcon(
                                  progress: progress,
                                  baseColor: Colors.white24,
                                  fillColor: accent,
                                  size: 52,
                                  icon: Icons.directions_car,
                                ),
                              ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      width: 76,
                      height: 16,
                      child: AnimatedOpacity(
                        duration: const Duration(milliseconds: 180),
                        opacity: _showSuccess ? 0.0 : 1.0,
                        child: Center(
                          child: Text(
                            '${(progress * 100).round()}%',
                            style: const TextStyle(fontSize: 11, color: Colors.white70, fontWeight: FontWeight.w700),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              // Text block
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('Demo Setup', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 8),
                    Text(
                      _steps[_current].title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 6),
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 250),
                      child: _showSuccess
                          ? Row(
                              key: const ValueKey('ready'),
                              children: const [
                                Icon(Icons.verified, size: 18, color: success),
                                SizedBox(width: 6),
                                Text('Demo ready', style: TextStyle(color: success, fontWeight: FontWeight.w700)),
                              ],
                            )
                          : const Text('This may take a few seconds.', key: ValueKey('wait'), style: TextStyle(color: Colors.white70)),
                    ),
                  ],
                ),
              )
            ],
          ),
        ),
      ),
    );
  }
}

class _StepItem {
  final String title;
  final IconData icon;
  const _StepItem(this.title, this.icon);
}

// List details removed to keep popup compact and avoid flicker

class _CarFillIcon extends StatelessWidget {
  final double progress; // 0..1
  final Color baseColor;
  final Color fillColor;
  final double size;
  final IconData icon;
  const _CarFillIcon({super.key, required this.progress, required this.baseColor, required this.fillColor, this.size = 36, required this.icon});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final w = constraints.maxWidth;
          final h = constraints.maxHeight;
          final fillW = (w * progress).clamp(0, w).toDouble();
          return Stack(
            children: [
              // Base car (gray/dark)
              Icon(icon, color: baseColor, size: size),
              // Filled portion clipped from left to right
              ClipRect(
                clipper: _RectClipper(width: fillW, height: h.toDouble()),
                child: Icon(icon, color: fillColor, size: size),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _RectClipper extends CustomClipper<Rect> {
  final double width;
  final double height;
  _RectClipper({required this.width, required this.height});
  @override
  Rect getClip(Size size) => Rect.fromLTWH(0, 0, width, height);
  @override
  bool shouldReclip(covariant _RectClipper oldClipper) => oldClipper.width != width || oldClipper.height != height;
}

Future<void> showDemoInitDialog(BuildContext context) async {
  await showDialog(
    context: context,
    barrierDismissible: false,
    builder: (ctx) {
      return Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Material(
            color: Colors.transparent,
            child: _DemoInitContent(),
          ),
        ),
      );
    },
  );
}


