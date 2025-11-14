import 'dart:async';
import 'package:flutter/material.dart';

class _ScanDialogContent extends StatefulWidget {
  const _ScanDialogContent();

  @override
  State<_ScanDialogContent> createState() => _ScanDialogContentState();
}

class _ScanDialogContentState extends State<_ScanDialogContent> with TickerProviderStateMixin {
  final List<_StepItem> _steps = [
    _StepItem('Scanning ECU...', Icons.memory),
    _StepItem('Reading sensors...', Icons.sensors),
    _StepItem('Loading live data...', Icons.bolt),
    _StepItem('Finalizing scan...', Icons.verified),
  ];

  int _current = 0;
  bool _done = false;
  Timer? _timer;
  double _progress = 0.0;
  bool _showSuccess = false;
  late AnimationController _shimmerController;
  late AnimationController _pulseController;
  late AnimationController _scaleController;
  late Animation<double> _shimmerAnimation;
  late Animation<double> _pulseAnimation;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    // Shimmer animation for progress bar
    _shimmerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();
    _shimmerAnimation = Tween<double>(begin: -2.0, end: 2.0).animate(
      CurvedAnimation(parent: _shimmerController, curve: Curves.linear),
    );
    
    // Pulse animation for glow effect
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 0.3, end: 0.6).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
    
    // Scale animation for success
    _scaleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _scaleAnimation = CurvedAnimation(
      parent: _scaleController,
      curve: Curves.elasticOut,
    );
    
    _runSequence();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _shimmerController.dispose();
    _pulseController.dispose();
    _scaleController.dispose();
    super.dispose();
  }

  Future<void> _runSequence() async {
    // Smooth fake loading over ~2.5 seconds
    const totalMs = 2500;
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
        if (!mounted) return;
        setState(() { _done = true; _showSuccess = true; });
        _scaleController.forward();
        await Future.delayed(const Duration(milliseconds: 800));
        if (!mounted) return;
        Navigator.of(context).pop(true); // Return true to indicate success
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final progress = _done ? 1.0 : _progress;
    const Color accent = Color(0xFFE91E63);
    const Color success = Color(0xFF2ECC71);
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: AnimatedBuilder(
          animation: _scaleAnimation,
          builder: (context, child) {
            return Transform.scale(
              scale: _showSuccess ? 1.0 + (_scaleAnimation.value * 0.05) : 1.0,
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      const Color(0xFF1C1F2A),
                      const Color(0xFF1A1D28),
                      const Color(0xFF1C1F2A),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.5),
                    width: 1.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.5),
                      blurRadius: 30,
                      offset: const Offset(0, 15),
                      spreadRadius: -5,
                    ),
                    BoxShadow(
                      color: const Color(0xFF2196F3).withValues(alpha: 0.1),
                      blurRadius: 20,
                      offset: const Offset(0, 0),
                    ),
                  ],
                ),
                child: child,
              ),
            );
          },
          child: Container(
            padding: const EdgeInsets.all(24),
            child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header with gradient text
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ShaderMask(
                          shaderCallback: (bounds) => LinearGradient(
                            colors: [
                              Colors.white,
                              Colors.white.withValues(alpha: 0.9),
                            ],
                          ).createShader(bounds),
                          child: const Text(
                            'Vehicle Scan',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        AnimatedSwitcher(
                          duration: const Duration(milliseconds: 300),
                          transitionBuilder: (child, animation) {
                            return FadeTransition(
                              opacity: animation,
                              child: SlideTransition(
                                position: Tween<Offset>(
                                  begin: const Offset(0.0, 0.1),
                                  end: Offset.zero,
                                ).animate(animation),
                                child: child,
                              ),
                            );
                          },
                          child: _showSuccess
                              ? Row(
                                  key: const ValueKey('ready'),
                                  children: [
                                    TweenAnimationBuilder<double>(
                                      tween: Tween(begin: 0.0, end: 1.0),
                                      duration: const Duration(milliseconds: 400),
                                      builder: (context, value, child) {
                                        return Transform.scale(
                                          scale: value,
                                          child: const Icon(
                                            Icons.verified,
                                            size: 20,
                                            color: success,
                                          ),
                                        );
                                      },
                                    ),
                                    const SizedBox(width: 8),
                                    ShaderMask(
                                      shaderCallback: (bounds) => LinearGradient(
                                        colors: [success, success.withValues(alpha: 0.8)],
                                      ).createShader(bounds),
                                      child: const Text(
                                        'Scan complete',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.w700,
                                          fontSize: 15,
                                        ),
                                      ),
                                    ),
                                  ],
                                )
                              : Row(
                                  key: ValueKey('step-$_current'),
                                  children: [
                                    Icon(
                                      _steps[_current].icon,
                                      size: 16,
                                      color: const Color(0xFF2196F3),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        _steps[_current].title,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w600,
                                          color: Colors.white,
                                          letterSpacing: 0.3,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                        ),
                      ],
                    ),
                  ),
                  if (!_showSuccess)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: const Color(0xFF2196F3).withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: const Color(0xFF2196F3).withValues(alpha: 0.3),
                          width: 1,
                        ),
                      ),
                      child: Text(
                        '${(progress * 100).round()}%',
                        style: const TextStyle(
                          fontSize: 13,
                          color: Color(0xFF2196F3),
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 24),
              // Modern progress bar with shimmer effect
              LayoutBuilder(
                builder: (context, constraints) {
                  final barWidth = constraints.maxWidth;
                  return AnimatedBuilder(
                    animation: Listenable.merge([_shimmerAnimation, _pulseAnimation]),
                    builder: (context, child) {
                      return ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: Container(
                          height: 10,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(10),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.2),
                                blurRadius: 4,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Stack(
                            children: [
                              // Background
                              Container(
                                width: double.infinity,
                                height: 10,
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.08),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                              // Progress fill with professional gradient
                              AnimatedContainer(
                                duration: const Duration(milliseconds: 200),
                                curve: Curves.easeOutCubic,
                                width: barWidth * progress,
                                height: 10,
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: _showSuccess
                                        ? [
                                            success,
                                            const Color(0xFF27AE60),
                                            success.withValues(alpha: 0.9),
                                          ]
                                        : [
                                            const Color(0xFF2196F3),
                                            const Color(0xFF1E88E5),
                                            const Color(0xFF1976D2),
                                            const Color(0xFF1565C0),
                                          ],
                                    begin: Alignment.centerLeft,
                                    end: Alignment.centerRight,
                                  ),
                                  borderRadius: BorderRadius.circular(10),
                                  boxShadow: _showSuccess
                                      ? [
                                          BoxShadow(
                                            color: success.withValues(alpha: 0.6),
                                            blurRadius: 12,
                                            spreadRadius: 2,
                                          ),
                                        ]
                                      : [
                                          BoxShadow(
                                            color: const Color(0xFF2196F3).withValues(alpha: _pulseAnimation.value),
                                            blurRadius: 10,
                                            spreadRadius: 1,
                                          ),
                                        ],
                                ),
                              ),
                              // Shimmer effect
                              if (!_showSuccess && progress > 0)
                                Positioned.fill(
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(10),
                                    child: Transform.translate(
                                      offset: Offset(
                                        _shimmerAnimation.value * barWidth,
                                        0,
                                      ),
                                      child: Container(
                                        width: barWidth * 0.3,
                                        decoration: BoxDecoration(
                                          gradient: LinearGradient(
                                            colors: [
                                              Colors.transparent,
                                              Colors.white.withValues(alpha: 0.3),
                                              Colors.transparent,
                                            ],
                                            begin: Alignment.centerLeft,
                                            end: Alignment.centerRight,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ],
          ),
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

Future<bool> showScanDialog(BuildContext context) async {
  final result = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) {
      return Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Material(
            color: Colors.transparent,
            child: _ScanDialogContent(),
          ),
        ),
      );
    },
  );
  return result ?? false;
}

