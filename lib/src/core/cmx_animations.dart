import 'dart:math' as math;

import 'package:flutter/widgets.dart';

/// Reusable animations shared by every field.
///
/// Every helper honors [MediaQueryData.disableAnimations]; when animations are
/// disabled the widgets render in their resting state with no motion.
class CmxAnimations {
  const CmxAnimations._();

  /// Whether the platform/user has requested reduced motion.
  static bool reduceMotion(BuildContext context) =>
      MediaQuery.maybeOf(context)?.disableAnimations ?? false;

  /// Wraps [child] in a horizontal shake driven by [controller] (0..1).
  ///
  /// Translation path: 0 → 8 → -8 → 6 → -6 → 0 px.
  static Widget shake({
    required Widget child,
    required Animation<double> controller,
    bool enabled = true,
  }) {
    if (!enabled) return child;
    return AnimatedBuilder(
      animation: controller,
      builder: (context, c) {
        final t = controller.value;
        // Decaying sine gives a natural settle.
        final dx = math.sin(t * math.pi * 4) * 8 * (1 - t);
        return Transform.translate(offset: Offset(dx, 0), child: c);
      },
      child: child,
    );
  }

  /// Wraps [child] in a subtle scale pulse (1.0 → 1.02 → 1.0) driven by
  /// [controller] (0..1).
  static Widget pulse({
    required Widget child,
    required Animation<double> controller,
    bool enabled = true,
  }) {
    if (!enabled) return child;
    return AnimatedBuilder(
      animation: controller,
      builder: (context, c) {
        final t = controller.value;
        final scale = 1.0 + math.sin(t * math.pi) * 0.02;
        return Transform.scale(scale: scale, child: c);
      },
      child: child,
    );
  }

  /// A standard fade + slide-from-below transition for error/helper text.
  static Widget slideInError({
    required Widget child,
    required bool visible,
    bool enabled = true,
    Duration duration = const Duration(milliseconds: 220),
  }) {
    return AnimatedSwitcher(
      duration: enabled ? duration : Duration.zero,
      switchInCurve: Curves.easeOut,
      switchOutCurve: Curves.easeIn,
      transitionBuilder: (c, animation) {
        return FadeTransition(
          opacity: animation,
          child: SizeTransition(
            sizeFactor: animation,
            alignment: AlignmentDirectional.topStart,
            child: c,
          ),
        );
      },
      child:
          visible ? child : const SizedBox(width: double.infinity, height: 0),
    );
  }

  /// A color tween between [from] and [to] driven by [controller] (0..1).
  static Animation<Color?> borderColorTween({
    required Animation<double> controller,
    required Color from,
    required Color to,
  }) {
    return ColorTween(begin: from, end: to).animate(controller);
  }
}

/// A checkmark that draws itself in when [visible] becomes true.
///
/// Used as the "valid" affix on every field. Respects reduced motion.
class CmxCheckmark extends StatelessWidget {
  /// Creates an animated checkmark.
  const CmxCheckmark({
    super.key,
    required this.visible,
    required this.color,
    this.size = 20,
    this.strokeWidth = 2.5,
  });

  /// Whether the checkmark should be shown.
  final bool visible;

  /// Stroke color.
  final Color color;

  /// Square extent of the mark.
  final double size;

  /// Stroke width of the mark.
  final double strokeWidth;

  @override
  Widget build(BuildContext context) {
    final reduce = CmxAnimations.reduceMotion(context);
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: visible ? 1 : 0),
      duration: reduce ? Duration.zero : const Duration(milliseconds: 280),
      curve: Curves.easeOutCubic,
      builder: (context, value, _) {
        return Opacity(
          opacity: value.clamp(0.0, 1.0),
          child: CustomPaint(
            size: Size.square(size),
            painter: _CheckmarkPainter(
              progress: value,
              color: color,
              strokeWidth: strokeWidth,
            ),
          ),
        );
      },
    );
  }
}

class _CheckmarkPainter extends CustomPainter {
  _CheckmarkPainter({
    required this.progress,
    required this.color,
    required this.strokeWidth,
  });

  final double progress;
  final Color color;
  final double strokeWidth;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;

    final w = size.width;
    final h = size.height;
    final p1 = Offset(w * 0.18, h * 0.52);
    final p2 = Offset(w * 0.42, h * 0.74);
    final p3 = Offset(w * 0.82, h * 0.28);

    // First leg length proportion of the whole stroke.
    const legSplit = 0.4;
    final path = Path()..moveTo(p1.dx, p1.dy);
    if (progress <= legSplit) {
      final t = progress / legSplit;
      path.lineTo(
        p1.dx + (p2.dx - p1.dx) * t,
        p1.dy + (p2.dy - p1.dy) * t,
      );
    } else {
      final t = (progress - legSplit) / (1 - legSplit);
      path.lineTo(p2.dx, p2.dy);
      path.lineTo(
        p2.dx + (p3.dx - p2.dx) * t,
        p2.dy + (p3.dy - p2.dy) * t,
      );
    }
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_CheckmarkPainter old) =>
      old.progress != progress ||
      old.color != color ||
      old.strokeWidth != strokeWidth;
}
