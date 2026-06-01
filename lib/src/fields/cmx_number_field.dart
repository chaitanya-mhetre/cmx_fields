/// A polished numeric input field for `cmx_fields` with live digit grouping,
/// decimal clamping, optional steppers, currency prefix and min/max validation.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/cmx_field_mixin.dart';
import '../core/cmx_field_scaffold.dart';
import '../core/cmx_field_theme.dart';
import '../core/cmx_validators.dart';

/// The thousands-grouping convention applied to the integer part of a number.
enum NumberGrouping {
  /// No separators (e.g. `1234567`).
  none,

  /// Western grouping in threes (e.g. `1,234,567`).
  western,

  /// Indian grouping: first three digits, then twos (e.g. `12,34,567`).
  indian,
}

/// An as-you-type [TextInputFormatter] for numeric input.
///
/// It keeps only digits, at most one decimal point (when [decimalPlaces] is
/// greater than zero) and an optional leading `-` (when [allowNegative]). It
/// clamps the fractional part to [decimalPlaces] and re-inserts grouping
/// separators on the integer part per [grouping]. The cursor is placed at the
/// end of the formatted text, which is stable and predictable.
///
/// The transformation logic is exposed via the pure static [format] and
/// [parse] helpers so it is fully unit-testable without a widget.
class CmxNumberFormatter extends TextInputFormatter {
  /// Creates a numeric formatter.
  const CmxNumberFormatter({
    this.grouping = NumberGrouping.western,
    this.decimalPlaces = 0,
    this.allowNegative = false,
  });

  /// The grouping convention applied to the integer part.
  final NumberGrouping grouping;

  /// The maximum number of fractional digits. `0` disables the decimal point.
  final int decimalPlaces;

  /// Whether a leading `-` sign is permitted.
  final bool allowNegative;

  static bool _isDigit(int codeUnit) => codeUnit >= 0x30 && codeUnit <= 0x39;

  /// Sanitizes [input] into a normalized numeric string consisting of an
  /// optional leading `-`, digits, and at most one `.`.
  ///
  /// Honors [allowNegative] (a single leading minus) and [decimalPlaces]
  /// (whether a decimal point is allowed at all, and how many fractional
  /// digits are kept). Grouping separators and any other characters are
  /// dropped. Returns the raw numeric string *without* grouping separators.
  static String sanitize(
    String input, {
    NumberGrouping grouping = NumberGrouping.western,
    int decimalPlaces = 0,
    bool allowNegative = false,
  }) {
    final negative = allowNegative && input.contains('-');
    final allowDot = decimalPlaces > 0;

    final intPart = StringBuffer();
    final fracPart = StringBuffer();
    var seenDot = false;
    // Once a '.' appears, no further digits belong to the integer part. When
    // decimals are disabled we drop everything after the first '.' entirely.
    var afterDot = false;
    for (final unit in input.codeUnits) {
      if (_isDigit(unit)) {
        if (afterDot) {
          if (allowDot && fracPart.length < decimalPlaces) {
            fracPart.writeCharCode(unit);
          }
        } else {
          intPart.writeCharCode(unit);
        }
      } else if (unit == 0x2E /* . */) {
        afterDot = true;
        if (allowDot) seenDot = true;
      }
      // ',' and any other character are ignored (grouping separators, etc.).
    }

    final buffer = StringBuffer();
    if (negative) buffer.write('-');
    buffer.write(intPart.toString());
    if (allowDot && seenDot) {
      buffer.write('.');
      buffer.write(fracPart.toString());
    }
    return buffer.toString();
  }

  /// Inserts [grouping] separators into the integer portion of [intDigits],
  /// which must contain digits only (no sign, no separators).
  static String groupInteger(String intDigits, NumberGrouping grouping) {
    if (intDigits.length <= 3 || grouping == NumberGrouping.none) {
      return intDigits;
    }
    switch (grouping) {
      case NumberGrouping.none:
        return intDigits;
      case NumberGrouping.western:
        final out = StringBuffer();
        final firstGroup = intDigits.length % 3;
        var index = 0;
        if (firstGroup > 0) {
          out.write(intDigits.substring(0, firstGroup));
          index = firstGroup;
        }
        while (index < intDigits.length) {
          if (out.isNotEmpty) out.write(',');
          out.write(intDigits.substring(index, index + 3));
          index += 3;
        }
        return out.toString();
      case NumberGrouping.indian:
        // Last three digits are one group; preceding digits group in twos.
        final last3 = intDigits.substring(intDigits.length - 3);
        var rest = intDigits.substring(0, intDigits.length - 3);
        final groups = <String>[];
        while (rest.length > 2) {
          groups.insert(0, rest.substring(rest.length - 2));
          rest = rest.substring(0, rest.length - 2);
        }
        if (rest.isNotEmpty) groups.insert(0, rest);
        return '${groups.join(',')},$last3';
    }
  }

  /// Formats [input] into a grouped display string.
  ///
  /// [input] may contain existing separators, a sign and a decimal point; it is
  /// first [sanitize]d and then re-grouped. Returns the empty string for input
  /// with no numeric content.
  static String format(
    String input, {
    NumberGrouping grouping = NumberGrouping.western,
    int decimalPlaces = 0,
    bool allowNegative = false,
  }) {
    final clean = sanitize(
      input,
      grouping: grouping,
      decimalPlaces: decimalPlaces,
      allowNegative: allowNegative,
    );
    if (clean.isEmpty || clean == '-') return clean;

    final negative = clean.startsWith('-');
    var body = negative ? clean.substring(1) : clean;

    String fraction = '';
    final dotIndex = body.indexOf('.');
    final hasDot = dotIndex >= 0;
    if (hasDot) {
      fraction = body.substring(dotIndex + 1);
      body = body.substring(0, dotIndex);
    }

    final grouped = groupInteger(body, grouping);
    final out = StringBuffer();
    if (negative) out.write('-');
    out.write(grouped.isEmpty && hasDot ? '0' : grouped);
    if (hasDot) {
      out.write('.');
      out.write(fraction);
    }
    return out.toString();
  }

  /// Parses [input] (a possibly grouped/typed string) into a [num], or `null`
  /// when there is no parseable numeric content.
  static num? parse(
    String input, {
    NumberGrouping grouping = NumberGrouping.western,
    int decimalPlaces = 0,
    bool allowNegative = false,
  }) {
    final clean = sanitize(
      input,
      grouping: grouping,
      decimalPlaces: decimalPlaces,
      allowNegative: allowNegative,
    );
    if (clean.isEmpty || clean == '-' || clean == '.' || clean == '-.') {
      return null;
    }
    return num.tryParse(clean);
  }

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final formatted = format(
      newValue.text,
      grouping: grouping,
      decimalPlaces: decimalPlaces,
      allowNegative: allowNegative,
    );
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}

/// A refined numeric input with live digit grouping, decimal clamping,
/// optional increment/decrement steppers, a currency prefix and min/max
/// validation.
///
/// Features:
/// * Live formatting via [CmxNumberFormatter] honoring [grouping],
///   [decimalPlaces] and [allowNegative].
/// * Optional `-` / `+` [showSteppers] that change the value by [stepValue],
///   clamped to [min]/[max] and disabled at the bounds.
/// * A [currencySymbol] rendered as a leading prefix.
/// * Min/max enforcement surfaced via [validator] and a brief error-border
///   flash (with shake, reduced-motion safe) when a typed or stepped value
///   exceeds the bounds.
///
/// Works standalone and inside a [Form]; it builds an internal [FormField] so
/// `Form.validate()` triggers [validator], shows the error and shakes.
class CmxNumberField extends StatefulWidget {
  /// Creates a number field.
  const CmxNumberField({
    super.key,
    this.label,
    this.hint,
    this.controller,
    this.focusNode,
    this.enabled = true,
    this.min,
    this.max,
    this.decimalPlaces = 0,
    this.showSteppers = false,
    this.stepValue = 1,
    this.currencySymbol,
    this.grouping = NumberGrouping.western,
    this.allowNegative = false,
    this.initialValue,
    this.onChanged,
    this.onSubmitted,
    this.validator,
    this.textInputAction,
    this.autovalidateMode = AutovalidateMode.disabled,
    this.focusedColor,
    this.errorColor,
    this.successColor,
    this.borderColor,
    this.backgroundColor,
    this.fillColor,
    this.borderRadius,
    this.borderWidth,
    this.borderStyle,
    this.contentPadding,
    this.labelStyle,
    this.hintStyle,
    this.inputStyle,
  });

  /// Floating label text.
  final String? label;

  /// Placeholder shown when empty and focused.
  final String? hint;

  /// Optional external controller for the editable text.
  final TextEditingController? controller;

  /// Optional external focus node.
  final FocusNode? focusNode;

  /// Whether the field is interactive.
  final bool enabled;

  /// Minimum acceptable value (inclusive). `null` means no lower bound.
  final num? min;

  /// Maximum acceptable value (inclusive). `null` means no upper bound.
  final num? max;

  /// Maximum number of fractional digits. `0` makes the field integer-only.
  final int decimalPlaces;

  /// Whether to render `-` / `+` stepper buttons.
  final bool showSteppers;

  /// The amount each stepper press changes the value.
  final num stepValue;

  /// Optional currency symbol rendered as a leading prefix (e.g. `₹`, `$`).
  final String? currencySymbol;

  /// The thousands-grouping convention applied to the integer part.
  final NumberGrouping grouping;

  /// Whether a leading `-` sign (negative values) is permitted.
  final bool allowNegative;

  /// The initial numeric value.
  final num? initialValue;

  /// Called whenever the parsed value changes (`null` when the field is empty).
  final ValueChanged<num?>? onChanged;

  /// Called when the user submits from the keyboard.
  final ValueChanged<num?>? onSubmitted;

  /// Validates the current value; return an error string or `null`.
  final CmxValidator<num>? validator;

  /// The keyboard action button.
  final TextInputAction? textInputAction;

  /// When validation runs automatically.
  final AutovalidateMode autovalidateMode;

  /// Override: accent color while focused.
  final Color? focusedColor;

  /// Override: error color.
  final Color? errorColor;

  /// Override: success color.
  final Color? successColor;

  /// Override: resting border color.
  final Color? borderColor;

  /// Override: field background color.
  final Color? backgroundColor;

  /// Override: fill color for the filled border style.
  final Color? fillColor;

  /// Override: corner radius.
  final double? borderRadius;

  /// Override: border stroke width.
  final double? borderWidth;

  /// Override: border/decoration style.
  final CmxBorderStyle? borderStyle;

  /// Override: inner content padding.
  final EdgeInsets? contentPadding;

  /// Override: floating label text style.
  final TextStyle? labelStyle;

  /// Override: hint text style.
  final TextStyle? hintStyle;

  /// Override: entered-text style.
  final TextStyle? inputStyle;

  /// Fails when empty.
  static CmxValidator<num> required([
    String message = 'Enter a number',
  ]) {
    return (num? value) => value == null ? message : null;
  }

  /// Validates [min] / [max] with clear messages (matches in-field stepping).
  static CmxValidator<num> inRange({
    num? min,
    num? max,
    String requiredMessage = 'Enter a number',
  }) {
    return (num? value) {
      if (value == null) return requiredMessage;
      if (min != null && value < min) {
        return 'Must be at least $min';
      }
      if (max != null && value > max) {
        return 'Must be at most $max';
      }
      return null;
    };
  }

  @override
  State<CmxNumberField> createState() => _CmxNumberFieldState();
}

class _CmxNumberFieldState extends State<CmxNumberField>
    with TickerProviderStateMixin, CmxFieldStateMixin<CmxNumberField> {
  late TextEditingController _controller;
  bool _ownsController = false;

  num? _value;
  String? _errorText;

  @override
  void initState() {
    super.initState();
    initCmxField(focusNode: widget.focusNode, enabled: widget.enabled);

    _controller = widget.controller ?? TextEditingController();
    _ownsController = widget.controller == null;

    if (widget.initialValue != null) {
      _value = widget.initialValue;
      _controller.text = _formatValue(widget.initialValue!);
    } else {
      _value = CmxNumberFormatter.parse(
        _controller.text,
        grouping: widget.grouping,
        decimalPlaces: widget.decimalPlaces,
        allowNegative: widget.allowNegative,
      );
    }
  }

  @override
  void didUpdateWidget(CmxNumberField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.enabled != oldWidget.enabled) {
      setEnabled(widget.enabled);
    }
  }

  @override
  void dispose() {
    if (_ownsController) _controller.dispose();
    disposeCmxField();
    super.dispose();
  }

  CmxNumberFormatter get _formatter => CmxNumberFormatter(
        grouping: widget.grouping,
        decimalPlaces: widget.decimalPlaces,
        allowNegative: widget.allowNegative,
      );

  String _formatValue(num value) {
    final fixed = widget.decimalPlaces > 0
        ? value.toStringAsFixed(widget.decimalPlaces)
        : value.round().toString();
    return CmxNumberFormatter.format(
      fixed,
      grouping: widget.grouping,
      decimalPlaces: widget.decimalPlaces,
      allowNegative: widget.allowNegative,
    );
  }

  num? _parse(String text) => CmxNumberFormatter.parse(
        text,
        grouping: widget.grouping,
        decimalPlaces: widget.decimalPlaces,
        allowNegative: widget.allowNegative,
      );

  bool get _canDecrement {
    if (!widget.enabled) return false;
    if (widget.min == null) return true;
    return (_value ?? widget.min!) > widget.min!;
  }

  bool get _canIncrement {
    if (!widget.enabled) return false;
    if (widget.max == null) return true;
    return (_value ?? widget.max!) < widget.max!;
  }

  String? _boundsError(num value) {
    if (widget.min != null && value < widget.min!) {
      return 'Must be at least ${_formatValue(widget.min!)}';
    }
    if (widget.max != null && value > widget.max!) {
      return 'Must be at most ${_formatValue(widget.max!)}';
    }
    return null;
  }

  void _onTextChanged(FormFieldState<num?> field) {
    final parsed = _parse(_controller.text);
    setState(() {
      _value = parsed;
      if (_errorText != null) {
        _errorText = null;
        resetStatus();
      }
    });
    field.didChange(parsed);
    widget.onChanged?.call(parsed);
  }

  void _handleSubmitted(String _) {
    widget.onSubmitted?.call(_value);
  }

  void _step(num delta, FormFieldState<num?> field) {
    if (!widget.enabled) return;
    final base = _value ?? (widget.min ?? 0);
    var next = base + delta;
    final wasClamped = (widget.min != null && next < widget.min!) ||
        (widget.max != null && next > widget.max!);
    if (widget.min != null && next < widget.min!) next = widget.min!;
    if (widget.max != null && next > widget.max!) next = widget.max!;

    _value = next;
    _controller.text = _formatValue(next);
    setState(() {
      if (_errorText != null) {
        _errorText = null;
        resetStatus();
      }
    });
    field.didChange(next);
    widget.onChanged?.call(next);

    if (wasClamped) _flashError(_boundsError(base + delta));
  }

  void _flashError(String? message) {
    setState(() => _errorText = message);
    triggerShake();
  }

  String? _runValidator(num? value) {
    final bounds = value == null ? null : _boundsError(value);
    if (bounds != null) return bounds;
    return widget.validator?.call(value);
  }

  void _syncFieldError(FormFieldState<num?> field) {
    final error = field.errorText;
    if (error == _errorText) return;
    setState(() => _errorText = error);
    if (error != null) {
      triggerShake();
    } else {
      resetStatus();
    }
  }

  Widget _buildPrefix(CmxFieldTheme theme, FormFieldState<num?> field) {
    final children = <Widget>[];
    if (widget.showSteppers) {
      children.add(
        _StepperButton(
          icon: Icons.remove,
          color: theme.focusedColor,
          enabled: _canDecrement,
          onPressed: () => _step(-widget.stepValue, field),
          tooltip: 'Decrease',
        ),
      );
    }
    if (widget.currencySymbol != null) {
      children.add(
        Padding(
          padding: EdgeInsetsDirectional.only(
            start: widget.showSteppers ? 4 : 12,
            end: 4,
          ),
          child: Text(
            widget.currencySymbol!,
            style: (theme.inputStyle ?? const TextStyle())
                .copyWith(fontWeight: FontWeight.w600),
          ),
        ),
      );
    }
    if (children.isEmpty) return const SizedBox.shrink();
    return Row(mainAxisSize: MainAxisSize.min, children: children);
  }

  Widget? _buildSuffix(CmxFieldTheme theme, FormFieldState<num?> field) {
    if (!widget.showSteppers) return null;
    return _StepperButton(
      icon: Icons.add,
      color: theme.focusedColor,
      enabled: _canIncrement,
      onPressed: () => _step(widget.stepValue, field),
      tooltip: 'Increase',
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = resolveTheme(
      context,
      focusedColor: widget.focusedColor,
      errorColor: widget.errorColor,
      successColor: widget.successColor,
      borderColor: widget.borderColor,
      backgroundColor: widget.backgroundColor,
      fillColor: widget.fillColor,
      borderRadius: widget.borderRadius,
      borderWidth: widget.borderWidth,
      borderStyle: widget.borderStyle,
      contentPadding: widget.contentPadding,
      labelStyle: widget.labelStyle,
      hintStyle: widget.hintStyle,
      inputStyle: widget.inputStyle,
    );

    return FormField<num?>(
      initialValue: _value,
      enabled: widget.enabled,
      autovalidateMode: widget.autovalidateMode,
      validator: _runValidator,
      builder: (FormFieldState<num?> field) {
        if (field.errorText != _errorText) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) _syncFieldError(field);
          });
        }

        final prefix = _buildPrefix(theme, field);
        return CmxFieldScaffold(
          theme: theme,
          status: status,
          isEmpty: _controller.text.isEmpty,
          enabled: widget.enabled,
          label: widget.label,
          hint: widget.hint,
          errorText: _errorText,
          prefix: prefix is SizedBox ? null : prefix,
          suffix: _buildSuffix(theme, field),
          shakeAnimation: shakeAnimation,
          child: TextField(
            controller: _controller,
            focusNode: focusNode,
            enabled: widget.enabled,
            decoration: null,
            keyboardType: TextInputType.numberWithOptions(
              decimal: widget.decimalPlaces > 0,
              signed: widget.allowNegative,
            ),
            textInputAction: widget.textInputAction,
            style: theme.inputStyle,
            inputFormatters: [_formatter],
            onChanged: (_) => _onTextChanged(field),
            onSubmitted: _handleSubmitted,
          ),
        );
      },
    );
  }
}

/// A compact circular stepper button used by [CmxNumberField].
class _StepperButton extends StatelessWidget {
  const _StepperButton({
    required this.icon,
    required this.color,
    required this.enabled,
    required this.onPressed,
    required this.tooltip,
  });

  final IconData icon;
  final Color color;
  final bool enabled;
  final VoidCallback onPressed;
  final String tooltip;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsetsDirectional.symmetric(horizontal: 4),
      child: IconButton(
        icon: Icon(icon, size: 20),
        color: color,
        disabledColor: color.withValues(alpha: 0.35),
        onPressed: enabled ? onPressed : null,
        tooltip: tooltip,
        visualDensity: VisualDensity.compact,
        splashRadius: 20,
        constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
        padding: EdgeInsets.zero,
      ),
    );
  }
}
