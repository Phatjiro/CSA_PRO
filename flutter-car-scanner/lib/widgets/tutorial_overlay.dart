import 'package:flutter/material.dart';

class TutorialOverlay extends StatelessWidget {
  final GlobalKey targetKey;
  final String title;
  final String description;
  final VoidCallback? onNext;
  final VoidCallback? onSkip;
  final bool isLastStep;
  final String? primaryActionLabel;
  final VoidCallback? onPrimaryAction;

  const TutorialOverlay({
    super.key,
    required this.targetKey,
    required this.title,
    required this.description,
    this.onNext,
    this.onSkip,
    this.isLastStep = false,
    this.primaryActionLabel,
    this.onPrimaryAction,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final RenderBox? targetBox = targetKey.currentContext?.findRenderObject() as RenderBox?;
        final RenderBox? overlayBox = context.findRenderObject() as RenderBox?;
        if (targetBox == null || !targetBox.attached || overlayBox == null) {
          return const SizedBox.shrink();
        }

        const padding = 12.0;
        final overlaySize = Size(constraints.maxWidth, constraints.maxHeight);
        final globalTargetOffset = targetBox.localToGlobal(Offset.zero);
        final localTargetOffset = overlayBox.globalToLocal(globalTargetOffset);
        final targetSize = targetBox.size;
        final rect = Rect.fromLTWH(
          localTargetOffset.dx - padding,
          localTargetOffset.dy - padding,
          targetSize.width + padding * 2,
          targetSize.height + padding * 2,
        );

        return Stack(
          children: [
            GestureDetector(
              onTap: onSkip,
              child: SizedBox.expand(
                child: CustomPaint(
                  painter: _SpotlightPainter(rect: rect),
                ),
              ),
            ),
            _ContentCard(
              title: title,
              description: description,
              onNext: onNext,
              onSkip: onSkip,
              isLastStep: isLastStep,
              overlaySize: overlaySize,
              targetRect: rect,
              primaryActionLabel: primaryActionLabel,
              onPrimaryAction: onPrimaryAction,
            ),
          ],
        );
      },
    );
  }
}

class _SpotlightPainter extends CustomPainter {
  final Rect rect;

  const _SpotlightPainter({required this.rect});

  @override
  void paint(Canvas canvas, Size size) {
    final overlayPaint = Paint()..color = Colors.black.withValues(alpha: 0.65);
    canvas.saveLayer(Offset.zero & size, Paint());
    canvas.drawRect(Offset.zero & size, overlayPaint);

    final clearPaint = Paint()..blendMode = BlendMode.clear;
    final rrect = RRect.fromRectAndRadius(rect, const Radius.circular(16));
    canvas.drawRRect(rrect, clearPaint);
    canvas.restore();

    final borderPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.7)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    canvas.drawRRect(rrect, borderPaint);
  }

  @override
  bool shouldRepaint(covariant _SpotlightPainter oldDelegate) => oldDelegate.rect != rect;
}

class _ContentCard extends StatelessWidget {
  final String title;
  final String description;
  final VoidCallback? onNext;
  final VoidCallback? onSkip;
  final bool isLastStep;
  final Size overlaySize;
  final Rect targetRect;
  final String? primaryActionLabel;
  final VoidCallback? onPrimaryAction;

  const _ContentCard({
    required this.title,
    required this.description,
    this.onNext,
    this.onSkip,
    required this.isLastStep,
    required this.overlaySize,
    required this.targetRect,
    this.primaryActionLabel,
    this.onPrimaryAction,
  });

  @override
  Widget build(BuildContext context) {
    final targetCenterY = targetRect.center.dy;
    final showAbove = targetCenterY > overlaySize.height / 2;
    double cardTop;
    if (showAbove) {
      cardTop = targetRect.top - 220;
    } else {
      cardTop = targetRect.bottom + 20;
    }
    cardTop = cardTop.clamp(20.0, overlaySize.height - 260.0);

    final cardLeft = (overlaySize.width - 320) / 2;
    final cardLeftClamped = cardLeft.clamp(16.0, overlaySize.width - 336.0);

    return Positioned(
      left: cardLeftClamped,
      top: cardTop,
      child: _TutorialCard(
        title: title,
        description: description,
        onNext: onNext,
        onSkip: onSkip,
        isLastStep: isLastStep,
        primaryActionLabel: primaryActionLabel,
        onPrimaryAction: onPrimaryAction,
      ),
    );
  }
}

class _TutorialCard extends StatelessWidget {
  final String title;
  final String description;
  final VoidCallback? onNext;
  final VoidCallback? onSkip;
  final bool isLastStep;
  final String? primaryActionLabel;
  final VoidCallback? onPrimaryAction;

  const _TutorialCard({
    required this.title,
    required this.description,
    this.onNext,
    this.onSkip,
    this.isLastStep = false,
    this.primaryActionLabel,
    this.onPrimaryAction,
  });

  @override
  Widget build(BuildContext context) {
    final showPrimaryAction = primaryActionLabel != null && onPrimaryAction != null;
    return Container(
      width: 320,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFF1C1F2A),
            const Color(0xFF1A1D28),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.3),
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.45),
            blurRadius: 30,
            offset: const Offset(0, 15),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF42A5F5).withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.lightbulb_outline,
                  color: Color(0xFF42A5F5),
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            description,
            style: TextStyle(
              fontSize: 14,
              color: Colors.white.withValues(alpha: 0.85),
              height: 1.5,
            ),
          ),
          if (showPrimaryAction) ...[
            const SizedBox(height: 14),
            OutlinedButton.icon(
              onPressed: onPrimaryAction,
              icon: const Icon(Icons.play_circle_outline, size: 18),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.white,
                side: BorderSide(color: Colors.white.withValues(alpha: 0.5)),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              label: Text(
                primaryActionLabel!,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
          ],
          const SizedBox(height: 18),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              if (onSkip != null)
                TextButton(
                  onPressed: onSkip,
                  child: Text(
                    'Skip',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.7),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed: onNext,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF42A5F5),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(
                  isLastStep ? 'Got it!' : 'Next',
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

