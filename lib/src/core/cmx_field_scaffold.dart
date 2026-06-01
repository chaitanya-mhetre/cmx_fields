import 'package:flutter/material.dart';

import 'cmx_animations.dart';
import 'cmx_field_status.dart';
import 'cmx_field_theme.dart';

/// The shared visual shell that every `cmx_fields` widget renders into.
///
/// It owns *only* presentation: the animated border (per [CmxBorderStyle]),
/// floating label, prefix/suffix slots, the valid checkmark, the loading
/// indicator, the error row, and the shake wrapper. It knows nothing about any
/// specific field's input logic — fields pass their editable [child] plus a
/// [status] and the scaffold reacts identically for all of them.
///
/// It is built on top of [InputDecorator] (the primitive [TextField] uses) so
/// floating-label behavior, border tweening, RTL and accessibility are
/// inherited rather than reimplemented.
class CmxFieldScaffold extends StatelessWidget {
  /// Creates a field scaffold.
  const CmxFieldScaffold({
    super.key,
    required this.theme,
    required this.status,
    required this.child,
    required this.isEmpty,
    this.label,
    this.hint,
    this.helperText,
    this.errorText,
    this.prefix,
    this.suffix,
    this.showCheckmark = true,
    this.enabled = true,
    this.shakeAnimation,
    this.isDense = false,
    this.suffixIconConstraints,
  });

  /// Resolved theme to paint with.
  final CmxFieldTheme theme;

  /// Current field status (drives colors, checkmark, loading).
  final CmxFieldStatus status;

  /// The editable content (e.g. an [EditableText]/[TextField]).
  final Widget child;

  /// Whether the field currently has no value (controls label float).
  final bool isEmpty;

  /// Floating label text.
  final String? label;

  /// Placeholder shown when empty and focused.
  final String? hint;

  /// Persistent helper text shown below the field.
  final String? helperText;

  /// Error text; when non-null the field renders its error state.
  final String? errorText;

  /// Leading widget (icon, flag, currency symbol, …).
  final Widget? prefix;

  /// Trailing widget; superseded by the loading/checkmark affix when active.
  final Widget? suffix;

  /// Whether to show the success checkmark in the [CmxFieldStatus.valid] state.
  final bool showCheckmark;

  /// Whether the field is interactive.
  final bool enabled;

  /// Optional shake animation (0..1) wrapping the whole field.
  final Animation<double>? shakeAnimation;

  /// Whether to use a denser vertical layout.
  final bool isDense;

  /// Tight bounds for [suffix] inside [InputDecoration].
  ///
  /// When null, Material's default (~48×48) applies. Use a smaller box for
  /// compact affixes such as the phone fill-progress ring.
  final BoxConstraints? suffixIconConstraints;

  bool get _isError => errorText != null || status.isError;

  InputBorder _border(Color color) {
    final side = BorderSide(color: color, width: theme.borderWidth);
    switch (theme.borderStyle) {
      case CmxBorderStyle.outlined:
        return OutlineInputBorder(
          borderRadius: BorderRadius.circular(theme.borderRadius),
          borderSide: side,
        );
      case CmxBorderStyle.rounded:
        return OutlineInputBorder(
          borderRadius: BorderRadius.circular(40),
          borderSide: side,
        );
      case CmxBorderStyle.underline:
        return UnderlineInputBorder(borderSide: side);
      case CmxBorderStyle.filled:
        return OutlineInputBorder(
          borderRadius: BorderRadius.circular(theme.borderRadius),
          borderSide: BorderSide.none,
        );
      case CmxBorderStyle.none:
        return InputBorder.none;
    }
  }

  Widget? _buildSuffix(BuildContext context) {
    if (status.isLoading) {
      return Padding(
        padding: const EdgeInsetsDirectional.only(end: 12),
        child: SizedBox(
          width: 18,
          height: 18,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            valueColor: AlwaysStoppedAnimation<Color>(theme.focusedColor),
          ),
        ),
      );
    }
    if (status.isValid && showCheckmark) {
      return Padding(
        padding: const EdgeInsetsDirectional.only(end: 12),
        child: CmxCheckmark(visible: true, color: theme.successColor),
      );
    }
    return suffix;
  }

  @override
  Widget build(BuildContext context) {
    final filled = theme.borderStyle == CmxBorderStyle.filled ||
        theme.backgroundColor.a != 0;
    final fillColor = theme.borderStyle == CmxBorderStyle.filled
        ? theme.fillColor
        : theme.backgroundColor;

    final idleColor = status.isValid ? theme.successColor : theme.borderColor;
    final activeColor =
        status.isValid ? theme.successColor : theme.focusedColor;

    final labelStyle = (theme.labelStyle ?? const TextStyle())
        .copyWith(color: theme.labelColor);
    final floatingLabelStyle = (theme.labelStyle ?? const TextStyle())
        .copyWith(color: _isError ? theme.errorColor : activeColor);

    final decoration = InputDecoration(
      labelText: label,
      hintText: hint,
      helperText: helperText,
      errorText: errorText,
      filled: filled,
      fillColor: fillColor,
      isDense: isDense,
      contentPadding: theme.contentPadding,
      prefixIcon: prefix,
      suffixIcon: _buildSuffix(context),
      suffixIconConstraints: suffixIconConstraints,
      enabled: enabled,
      labelStyle: labelStyle,
      floatingLabelStyle: floatingLabelStyle,
      hintStyle: theme.hintStyle,
      errorStyle: theme.errorStyle?.copyWith(color: theme.errorColor) ??
          TextStyle(color: theme.errorColor),
      border: _border(theme.borderColor),
      enabledBorder: _border(idleColor),
      focusedBorder: _border(activeColor),
      disabledBorder: _border(theme.borderColor.withValues(alpha: 0.4)),
      errorBorder: _border(theme.errorColor),
      focusedErrorBorder: _border(theme.errorColor),
    );

    Widget field = AnimatedTheme(
      data: Theme.of(context).copyWith(
        // InputDecorator reads these for cursor/selection-adjacent visuals.
        colorScheme: Theme.of(context)
            .colorScheme
            .copyWith(error: theme.errorColor, primary: theme.focusedColor),
      ),
      duration: const Duration(milliseconds: 220),
      child: InputDecorator(
        decoration: decoration,
        baseStyle: theme.inputStyle,
        isEmpty: isEmpty,
        isFocused: status.isFocused,
        expands: false,
        child: child,
      ),
    );

    final shake = shakeAnimation;
    if (shake != null) {
      field = CmxAnimations.shake(
        controller: shake,
        enabled: !CmxAnimations.reduceMotion(context),
        child: field,
      );
    }
    return field;
  }
}
