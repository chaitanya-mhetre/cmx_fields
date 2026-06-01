import 'package:flutter/material.dart';

import 'cmx_animations.dart';

/// A circular fill indicator for field suffixes (phone, email, …).
///
/// The ring fills from 0 → 100% as the user types, then shows a drawn
/// checkmark when [valid] is true.
class CmxFillProgress extends StatelessWidget {
  /// Creates a fill-progress affix.
  const CmxFillProgress({
    super.key,
    required this.progress,
    required this.valid,
    required this.color,

    /// Outer diameter of the loader (not stroke width).
    this.size = 22,
    this.strokeWidth = 2.5,
  });

  /// Completion fraction in `0.0..1.0`.
  final double progress;

  /// Whether the value is fully valid (full ring + checkmark).
  final bool valid;

  /// The ring/checkmark color (typically the theme's success color).
  final Color color;

  /// Outer diameter of the loader circle in logical pixels.
  final double size;

  /// Ring stroke width.
  final double strokeWidth;

  static const double _indicatorDesignSize = 36;

  @override
  Widget build(BuildContext context) {
    final reduce = CmxAnimations.reduceMotion(context);
    final target = valid ? 1.0 : progress.clamp(0.0, 1.0);
    final checkSize = size * 0.72;
    final checkStroke = (strokeWidth * 0.85).clamp(1.5, strokeWidth);

    return Padding(
      padding: const EdgeInsetsDirectional.only(end: 12),
      child: SizedBox(
        width: size,
        height: size,
        child: TweenAnimationBuilder<double>(
          tween: Tween<double>(begin: 0, end: target),
          duration: reduce ? Duration.zero : const Duration(milliseconds: 280),
          curve: Curves.easeOut,
          builder: (context, value, _) {
            return Stack(
              alignment: Alignment.center,
              clipBehavior: Clip.none,
              children: [
                Transform.scale(
                  scale: size / _indicatorDesignSize,
                  alignment: Alignment.center,
                  child: SizedBox(
                    width: _indicatorDesignSize,
                    height: _indicatorDesignSize,
                    child: CircularProgressIndicator(
                      value: value,
                      strokeWidth: strokeWidth,
                      valueColor: AlwaysStoppedAnimation<Color>(color),
                      backgroundColor: color.withValues(alpha: 0.15),
                    ),
                  ),
                ),
                if (valid)
                  CmxCheckmark(
                    visible: true,
                    color: color,
                    size: checkSize,
                    strokeWidth: checkStroke,
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}
