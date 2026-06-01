/// A tap-to-pick date field for `cmx_fields`.
library;

import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../core/cmx_animations.dart';
import '../core/cmx_field_mixin.dart';
import '../core/cmx_field_scaffold.dart';
import '../core/cmx_field_theme.dart';
import '../core/cmx_validators.dart';

/// Which native picker [CmxDateField] presents when tapped.
enum DatePickerStyle {
  /// Always use the Material [showDatePicker] dialog.
  material,

  /// Always use a [CupertinoDatePicker] hosted in a modal bottom sheet.
  cupertino,

  /// Use the Cupertino picker on iOS/macOS and the Material picker elsewhere.
  adaptive,
}

/// A tiny, pure, dependency-free date formatter.
///
/// Supports a useful subset of the common skeleton tokens so patterns like
/// `dd/MM/yyyy`, `MMM d, yyyy` and `d MMMM yyyy` render correctly without the
/// `intl` package. All names are hardcoded English.
///
/// Supported tokens (longest-match-first):
///
/// | Token  | Meaning                       | Example |
/// |--------|-------------------------------|---------|
/// | `yyyy` | 4-digit year                  | `2026`  |
/// | `yy`   | 2-digit year                  | `26`    |
/// | `MMMM` | full month name               | `June`  |
/// | `MMM`  | abbreviated month name        | `Jun`   |
/// | `MM`   | zero-padded month             | `06`    |
/// | `M`    | month                         | `6`     |
/// | `dd`   | zero-padded day of month      | `01`    |
/// | `d`    | day of month                  | `1`     |
/// | `EEE`  | abbreviated weekday name      | `Mon`   |
///
/// Any character that is not part of a recognized token is emitted verbatim,
/// so separators such as `/`, `-`, `,` and spaces pass through untouched.
class CmxDateFormat {
  const CmxDateFormat._();

  /// Full English month names, indexed by `month - 1`.
  static const List<String> monthNames = <String>[
    'January',
    'February',
    'March',
    'April',
    'May',
    'June',
    'July',
    'August',
    'September',
    'October',
    'November',
    'December',
  ];

  /// Abbreviated English month names, indexed by `month - 1`.
  static const List<String> monthAbbreviations = <String>[
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];

  /// Abbreviated English weekday names, indexed by `DateTime.weekday - 1`
  /// (so index 0 is Monday).
  static const List<String> weekdayAbbreviations = <String>[
    'Mon',
    'Tue',
    'Wed',
    'Thu',
    'Fri',
    'Sat',
    'Sun',
  ];

  /// Tokens recognized by [format], ordered longest-first so that greedy
  /// matching never mistakes (e.g.) `MM` for two `M` tokens.
  static const List<String> _tokens = <String>[
    'yyyy',
    'yy',
    'MMMM',
    'MMM',
    'MM',
    'M',
    'EEE',
    'dd',
    'd',
  ];

  /// Formats [date] according to [pattern] using the supported tokens.
  static String format(DateTime date, String pattern) {
    final buffer = StringBuffer();
    var i = 0;
    while (i < pattern.length) {
      final matched = _matchTokenAt(pattern, i);
      if (matched == null) {
        buffer.write(pattern[i]);
        i += 1;
        continue;
      }
      buffer.write(_expand(matched, date));
      i += matched.length;
    }
    return buffer.toString();
  }

  static String? _matchTokenAt(String pattern, int index) {
    for (final token in _tokens) {
      if (pattern.startsWith(token, index)) return token;
    }
    return null;
  }

  static String _expand(String token, DateTime date) {
    switch (token) {
      case 'yyyy':
        return date.year.toString().padLeft(4, '0');
      case 'yy':
        return (date.year % 100).toString().padLeft(2, '0');
      case 'MMMM':
        return monthNames[date.month - 1];
      case 'MMM':
        return monthAbbreviations[date.month - 1];
      case 'MM':
        return date.month.toString().padLeft(2, '0');
      case 'M':
        return date.month.toString();
      case 'EEE':
        return weekdayAbbreviations[date.weekday - 1];
      case 'dd':
        return date.day.toString().padLeft(2, '0');
      case 'd':
        return date.day.toString();
      default:
        return token;
    }
  }
}

/// A polished, animated date field that displays a formatted date and opens a
/// platform-appropriate picker when tapped.
///
/// The field itself is read-only text; tapping it (or its calendar affix)
/// presents a picker according to [pickerStyle]. The selected date is rendered
/// via [CmxDateFormat.format] using [dateFormat].
///
/// Works standalone and inside a [Form]: it builds an internal [FormField] so
/// `Form.validate()` triggers [validator], shows the error and shakes the
/// field. Reduced-motion and RTL are both honored.
class CmxDateField extends StatefulWidget {
  /// Creates a date field.
  const CmxDateField({
    super.key,
    this.label,
    this.hint,
    this.enabled = true,
    this.initialDate,
    this.firstDate,
    this.lastDate,
    this.dateFormat = 'dd/MM/yyyy',
    this.pickerStyle = DatePickerStyle.adaptive,
    this.focusNode,
    this.onChanged,
    this.validator,
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

  /// Floating label text (also acts as the placeholder while empty).
  final String? label;

  /// Placeholder shown when empty and focused.
  final String? hint;

  /// Whether the field is interactive.
  final bool enabled;

  /// The date selected initially, or `null` for an empty field.
  final DateTime? initialDate;

  /// The earliest selectable date. Defaults to `DateTime(1900)` when `null`.
  final DateTime? firstDate;

  /// The latest selectable date. Defaults to `DateTime(2100)` when `null`.
  final DateTime? lastDate;

  /// The pattern used to render the selected date (see [CmxDateFormat]).
  final String dateFormat;

  /// Which picker to present when the field is tapped.
  final DatePickerStyle pickerStyle;

  /// Optional external focus node.
  final FocusNode? focusNode;

  /// Called whenever the selected date changes.
  final ValueChanged<DateTime?>? onChanged;

  /// Validates the current date; return an error string or `null`.
  final CmxValidator<DateTime>? validator;

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

  /// Override: displayed-text style.
  final TextStyle? inputStyle;

  /// Fails when no date has been picked.
  static CmxValidator<DateTime> required([
    String message = 'Select a date',
  ]) {
    return (DateTime? value) => value == null ? message : null;
  }

  @override
  State<CmxDateField> createState() => _CmxDateFieldState();
}

class _CmxDateFieldState extends State<CmxDateField>
    with TickerProviderStateMixin, CmxFieldStateMixin<CmxDateField> {
  late final TextEditingController _controller;
  late final AnimationController _iconController;

  DateTime? _selected;
  String? _errorText;

  @override
  void initState() {
    super.initState();
    initCmxField(focusNode: widget.focusNode, enabled: widget.enabled);
    _controller = TextEditingController();
    _iconController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 320),
    );
    _selected = widget.initialDate;
    _syncControllerText();
  }

  @override
  void didUpdateWidget(CmxDateField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.enabled != oldWidget.enabled) {
      setEnabled(widget.enabled);
    }
    if (widget.dateFormat != oldWidget.dateFormat) {
      _syncControllerText();
    }
  }

  @override
  void dispose() {
    _iconController.dispose();
    _controller.dispose();
    disposeCmxField();
    super.dispose();
  }

  DateTime get _effectiveFirstDate => widget.firstDate ?? DateTime(1900);

  DateTime get _effectiveLastDate => widget.lastDate ?? DateTime(2100);

  void _syncControllerText() {
    final date = _selected;
    _controller.text =
        date == null ? '' : CmxDateFormat.format(date, widget.dateFormat);
  }

  DateTime _clampToBounds(DateTime date) {
    final first = _effectiveFirstDate;
    final last = _effectiveLastDate;
    if (date.isBefore(first)) return first;
    if (date.isAfter(last)) return last;
    return date;
  }

  bool _useCupertino() {
    switch (widget.pickerStyle) {
      case DatePickerStyle.material:
        return false;
      case DatePickerStyle.cupertino:
        return true;
      case DatePickerStyle.adaptive:
        return defaultTargetPlatform == TargetPlatform.iOS ||
            defaultTargetPlatform == TargetPlatform.macOS;
    }
  }

  void _playIconTap() {
    if (CmxAnimations.reduceMotion(context)) return;
    _iconController
      ..reset()
      ..forward();
  }

  Future<void> _openPicker(FormFieldState<DateTime> field) async {
    if (!widget.enabled) return;
    _playIconTap();
    focusNode.requestFocus();

    final DateTime? picked;
    if (_useCupertino()) {
      picked = await _showCupertinoPicker();
    } else {
      picked = await showDatePicker(
        context: context,
        initialDate: _clampToBounds(_selected ?? DateTime.now()),
        firstDate: _effectiveFirstDate,
        lastDate: _effectiveLastDate,
      );
    }

    if (!mounted) return;
    // Returning focus to its resting state once the picker closes.
    if (picked == null) {
      focusNode.unfocus();
      return;
    }
    _applySelection(picked, field);
  }

  Future<DateTime?> _showCupertinoPicker() {
    final initial = _clampToBounds(_selected ?? DateTime.now());
    var temp = initial;
    return showModalBottomSheet<DateTime>(
      context: context,
      builder: (sheetContext) {
        final media = MediaQuery.of(sheetContext);
        return SafeArea(
          top: false,
          child: SizedBox(
            height: 280,
            child: Column(
              children: [
                Align(
                  alignment: AlignmentDirectional.centerEnd,
                  child: CupertinoButton(
                    onPressed: () =>
                        Navigator.of(sheetContext).pop<DateTime>(temp),
                    child: const Text('Done'),
                  ),
                ),
                Expanded(
                  child: MediaQuery(
                    data: media.copyWith(
                      textScaler: const TextScaler.linear(1),
                    ),
                    child: CupertinoDatePicker(
                      mode: CupertinoDatePickerMode.date,
                      initialDateTime: initial,
                      minimumDate: _effectiveFirstDate,
                      maximumDate: _effectiveLastDate,
                      onDateTimeChanged: (value) => temp = value,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _applySelection(DateTime picked, FormFieldState<DateTime> field) {
    // Normalize to a date-only value (drop any time component).
    final dateOnly = DateTime(picked.year, picked.month, picked.day);
    setState(() {
      _selected = dateOnly;
      _syncControllerText();
      if (_errorText != null) {
        _errorText = null;
        resetStatus();
      }
    });
    focusNode.unfocus();
    field.didChange(dateOnly);
    widget.onChanged?.call(dateOnly);
  }

  String? _runValidator(DateTime? value) => widget.validator?.call(value);

  void _handleFieldStateChanged(FormFieldState<DateTime> field) {
    final error = field.errorText;
    if (error == _errorText) return;
    setState(() => _errorText = error);
    if (error != null) {
      triggerShake();
    } else {
      resetStatus();
    }
  }

  Widget _buildCalendarSuffix(CmxFieldTheme theme, VoidCallback onTap) {
    // A combined scale + rotate pulse driven by the icon controller (0..1).
    final reduce = CmxAnimations.reduceMotion(context);
    return InkResponse(
      onTap: widget.enabled ? onTap : null,
      radius: 22,
      child: Padding(
        padding: const EdgeInsetsDirectional.only(end: 12),
        child: AnimatedBuilder(
          animation: _iconController,
          builder: (context, child) {
            if (reduce) return child!;
            final t = _iconController.value;
            // 0 -> 0.5 grows/rotates, 0.5 -> 1 settles back.
            final pulse = (t <= 0.5 ? t / 0.5 : (1 - t) / 0.5).clamp(0.0, 1.0);
            return Transform.rotate(
              angle: pulse * 0.35,
              child: Transform.scale(scale: 1 + pulse * 0.2, child: child),
            );
          },
          child: Icon(
            Icons.calendar_today_outlined,
            size: 20,
            color: widget.enabled
                ? theme.labelColor
                : theme.labelColor.withValues(alpha: 0.4),
          ),
        ),
      ),
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

    return FormField<DateTime>(
      initialValue: _selected,
      enabled: widget.enabled,
      autovalidateMode: widget.autovalidateMode,
      validator: _runValidator,
      builder: (FormFieldState<DateTime> field) {
        // Mirror the FormField's error into the scaffold/shake after the frame
        // (e.g. when Form.validate() runs externally).
        if (field.errorText != _errorText) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) _handleFieldStateChanged(field);
          });
        }

        return CmxFieldScaffold(
          theme: theme,
          status: status,
          isEmpty: _selected == null,
          enabled: widget.enabled,
          label: widget.label,
          hint: widget.hint,
          errorText: _errorText,
          suffix: _buildCalendarSuffix(theme, () => _openPicker(field)),
          shakeAnimation: shakeAnimation,
          child: TextField(
            controller: _controller,
            focusNode: focusNode,
            enabled: widget.enabled,
            readOnly: true,
            showCursor: false,
            mouseCursor: widget.enabled
                ? SystemMouseCursors.click
                : SystemMouseCursors.basic,
            decoration: null,
            style: theme.inputStyle,
            onTap: widget.enabled ? () => _openPicker(field) : null,
          ),
        );
      },
    );
  }
}
