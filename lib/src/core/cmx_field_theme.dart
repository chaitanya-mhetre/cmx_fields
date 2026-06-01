import 'package:flutter/widgets.dart';

/// The shape/decoration style applied to a field's container.
enum CmxBorderStyle {
  /// A full border on all four sides.
  outlined,

  /// A single underline beneath the field.
  underline,

  /// A filled background with no visible border line.
  filled,

  /// A fully rounded "pill" border.
  rounded,

  /// No border and no background — padding only.
  none,
}

/// Immutable visual configuration shared by every `cmx_fields` widget.
///
/// Provide one via [CmxFieldThemeProvider] to theme all descendant fields at
/// once, or pass overrides directly to an individual field. Individual field
/// props always win over the inherited theme.
@immutable
class CmxFieldTheme {
  /// Creates a field theme. All values have modern-minimal indigo defaults.
  const CmxFieldTheme({
    this.focusedColor = const Color(0xFF5C6BC0), // indigo 400
    this.errorColor = const Color(0xFFE53935), // red 600
    this.successColor = const Color(0xFF43A047), // green 600
    this.borderColor = const Color(0xFFBDBDBD), // grey 400
    this.backgroundColor = const Color(0x00000000), // transparent
    this.fillColor = const Color(0xFFF5F5F7),
    this.labelColor = const Color(0xFF757575), // grey 600
    this.borderRadius = 14.0,
    this.borderWidth = 1.5,
    this.borderStyle = CmxBorderStyle.outlined,
    this.contentPadding =
        const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
    this.labelStyle,
    this.hintStyle,
    this.inputStyle,
    this.errorStyle,
  });

  /// Accent color used for the border/label while focused.
  final Color focusedColor;

  /// Color used for the border, label and error text in the error state.
  final Color errorColor;

  /// Color used for the success checkmark / flash.
  final Color successColor;

  /// Resting border color (idle, unfocused, no error).
  final Color borderColor;

  /// Background painted behind the field for all styles.
  final Color backgroundColor;

  /// Background used specifically by [CmxBorderStyle.filled].
  final Color fillColor;

  /// Resting label color.
  final Color labelColor;

  /// Corner radius for the field container (ignored by
  /// [CmxBorderStyle.underline]/[CmxBorderStyle.none]).
  final double borderRadius;

  /// Stroke width of the border.
  final double borderWidth;

  /// The border/decoration shape.
  final CmxBorderStyle borderStyle;

  /// Inner padding around the editable content.
  final EdgeInsets contentPadding;

  /// Optional style override for the floating label.
  final TextStyle? labelStyle;

  /// Optional style override for the hint/placeholder.
  final TextStyle? hintStyle;

  /// Optional style override for entered text.
  final TextStyle? inputStyle;

  /// Optional style override for the error text.
  final TextStyle? errorStyle;

  /// Returns a copy with the given fields replaced.
  CmxFieldTheme copyWith({
    Color? focusedColor,
    Color? errorColor,
    Color? successColor,
    Color? borderColor,
    Color? backgroundColor,
    Color? fillColor,
    Color? labelColor,
    double? borderRadius,
    double? borderWidth,
    CmxBorderStyle? borderStyle,
    EdgeInsets? contentPadding,
    TextStyle? labelStyle,
    TextStyle? hintStyle,
    TextStyle? inputStyle,
    TextStyle? errorStyle,
  }) {
    return CmxFieldTheme(
      focusedColor: focusedColor ?? this.focusedColor,
      errorColor: errorColor ?? this.errorColor,
      successColor: successColor ?? this.successColor,
      borderColor: borderColor ?? this.borderColor,
      backgroundColor: backgroundColor ?? this.backgroundColor,
      fillColor: fillColor ?? this.fillColor,
      labelColor: labelColor ?? this.labelColor,
      borderRadius: borderRadius ?? this.borderRadius,
      borderWidth: borderWidth ?? this.borderWidth,
      borderStyle: borderStyle ?? this.borderStyle,
      contentPadding: contentPadding ?? this.contentPadding,
      labelStyle: labelStyle ?? this.labelStyle,
      hintStyle: hintStyle ?? this.hintStyle,
      inputStyle: inputStyle ?? this.inputStyle,
      errorStyle: errorStyle ?? this.errorStyle,
    );
  }

  /// Returns a copy with every non-null value of [other] applied over this.
  CmxFieldTheme merge(CmxFieldTheme? other) {
    if (other == null) return this;
    return copyWith(
      focusedColor: other.focusedColor,
      errorColor: other.errorColor,
      successColor: other.successColor,
      borderColor: other.borderColor,
      backgroundColor: other.backgroundColor,
      fillColor: other.fillColor,
      labelColor: other.labelColor,
      borderRadius: other.borderRadius,
      borderWidth: other.borderWidth,
      borderStyle: other.borderStyle,
      contentPadding: other.contentPadding,
      labelStyle: other.labelStyle,
      hintStyle: other.hintStyle,
      inputStyle: other.inputStyle,
      errorStyle: other.errorStyle,
    );
  }

  @override
  bool operator ==(Object other) {
    return other is CmxFieldTheme &&
        other.focusedColor == focusedColor &&
        other.errorColor == errorColor &&
        other.successColor == successColor &&
        other.borderColor == borderColor &&
        other.backgroundColor == backgroundColor &&
        other.fillColor == fillColor &&
        other.labelColor == labelColor &&
        other.borderRadius == borderRadius &&
        other.borderWidth == borderWidth &&
        other.borderStyle == borderStyle &&
        other.contentPadding == contentPadding &&
        other.labelStyle == labelStyle &&
        other.hintStyle == hintStyle &&
        other.inputStyle == inputStyle &&
        other.errorStyle == errorStyle;
  }

  @override
  int get hashCode => Object.hash(
        focusedColor,
        errorColor,
        successColor,
        borderColor,
        backgroundColor,
        fillColor,
        labelColor,
        borderRadius,
        borderWidth,
        borderStyle,
        contentPadding,
        labelStyle,
        hintStyle,
        inputStyle,
        errorStyle,
      );
}

/// Propagates a [CmxFieldTheme] to all descendant `cmx_fields` widgets.
///
/// ```dart
/// CmxFieldThemeProvider(
///   theme: CmxFieldTheme(focusedColor: Colors.indigo, borderRadius: 16),
///   child: MyForm(),
/// )
/// ```
class CmxFieldThemeProvider extends InheritedWidget {
  /// Creates a theme provider wrapping [child].
  const CmxFieldThemeProvider({
    super.key,
    required this.theme,
    required super.child,
  });

  /// The theme applied to descendants.
  final CmxFieldTheme theme;

  /// Returns the nearest inherited theme, or a default [CmxFieldTheme].
  static CmxFieldTheme of(BuildContext context) {
    final provider =
        context.dependOnInheritedWidgetOfExactType<CmxFieldThemeProvider>();
    return provider?.theme ?? const CmxFieldTheme();
  }

  /// Returns the nearest inherited theme without creating a dependency,
  /// or `null` if none is present.
  static CmxFieldTheme? maybeOf(BuildContext context) {
    final provider =
        context.getInheritedWidgetOfExactType<CmxFieldThemeProvider>();
    return provider?.theme;
  }

  @override
  bool updateShouldNotify(CmxFieldThemeProvider oldWidget) =>
      oldWidget.theme != theme;
}
