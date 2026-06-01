/// A multi-line, auto-expanding text-area field for `cmx_fields`.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/cmx_animations.dart';
import '../core/cmx_field_mixin.dart';
import '../core/cmx_field_scaffold.dart';
import '../core/cmx_field_theme.dart';
import '../core/cmx_validators.dart';

/// A polished, animated multi-line text-area input.
///
/// Features:
/// * Auto-expanding height: while [autoExpand] is true the underlying
///   [TextField] grows from [minLines] up to [maxLines] (or without bound when
///   [maxLines] is `null`) as the user types, wrapped in an [AnimatedSize] for a
///   smooth height transition (reduced-motion safe). When [autoExpand] is false
///   the field is fixed at [maxLines] rows.
/// * A live character counter rendered beneath the field, bottom-aligned to the
///   trailing edge. When [maxLength] is set it reads `47 / 200`; otherwise it
///   shows the running count `47`. The counter switches to the theme error
///   color once usage reaches 90% of [maxLength].
/// * Hard length enforcement via [MaxLengthEnforcement.enforced] so input never
///   exceeds [maxLength]; Flutter's built-in counter is suppressed in favour of
///   the custom counter.
///
/// Works standalone and inside a [Form]; it builds an internal [FormField] so
/// `Form.validate()` triggers [validator], shows the error and shakes.
class CmxTextAreaField extends StatefulWidget {
  /// Creates a multi-line text-area field.
  const CmxTextAreaField({
    super.key,
    this.label,
    this.hint,
    this.controller,
    this.focusNode,
    this.enabled = true,
    this.maxLength,
    this.minLines = 3,
    this.maxLines = 6,
    this.showCounter = true,
    this.autoExpand = true,
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
  })  : assert(minLines > 0, 'minLines must be greater than 0'),
        assert(
          maxLines == null || maxLines >= minLines,
          'maxLines must be null or >= minLines',
        ),
        assert(
          maxLength == null || maxLength > 0,
          'maxLength must be null or greater than 0',
        );

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

  /// Optional hard cap on the number of characters; `null` means unlimited.
  final int? maxLength;

  /// The minimum number of visible text rows (the floor height).
  final int minLines;

  /// The maximum number of visible text rows before the field scrolls.
  ///
  /// `null` lets the field grow without bound as content is added.
  final int? maxLines;

  /// Whether to render the character counter beneath the field.
  final bool showCounter;

  /// Whether the field grows with its content from [minLines] to [maxLines].
  ///
  /// When false the field is fixed at [maxLines] rows.
  final bool autoExpand;

  /// Called whenever the entered text changes.
  final ValueChanged<String>? onChanged;

  /// Called when the user submits from the keyboard.
  final ValueChanged<String>? onSubmitted;

  /// Validates the current text; return an error string or `null`.
  final CmxValidator<String>? validator;

  /// The keyboard action button; defaults to [TextInputAction.newline].
  final TextInputAction? textInputAction;

  /// When validation runs automatically inside a [Form].
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

  @override
  State<CmxTextAreaField> createState() => _CmxTextAreaFieldState();
}

class _CmxTextAreaFieldState extends State<CmxTextAreaField>
    with TickerProviderStateMixin, CmxFieldStateMixin<CmxTextAreaField> {
  late TextEditingController _controller;
  bool _ownsController = false;

  String? _errorText;

  @override
  void initState() {
    super.initState();
    initCmxField(focusNode: widget.focusNode, enabled: widget.enabled);

    _controller = widget.controller ?? TextEditingController();
    _ownsController = widget.controller == null;
  }

  @override
  void didUpdateWidget(CmxTextAreaField oldWidget) {
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

  /// The current character count.
  int get _length => _controller.text.characters.length;

  /// Whether the counter should render in the error color (usage >= 90% of the
  /// cap). Returns false when no [maxLength] is set.
  bool get _counterAtLimit {
    final max = widget.maxLength;
    if (max == null) return false;
    return _length >= (max * 0.9);
  }

  /// The counter label: `47 / 200` when capped, otherwise `47`.
  String get _counterText {
    final max = widget.maxLength;
    if (max == null) return '$_length';
    return '$_length / $max';
  }

  void _onTextChanged(FormFieldState<String> field) {
    setState(() {
      // Re-derive live state: a non-empty error should clear once the user
      // edits, returning to the focus-derived status.
      if (status.isError || status.isValid) {
        _errorText = null;
        resetStatus();
      }
    });
    widget.onChanged?.call(_controller.text);
    field.didChange(_controller.text);
  }

  void _handleSubmitted(String value) {
    widget.onSubmitted?.call(value);
  }

  String? _runValidator(String? value) {
    if (widget.validator == null) return null;
    return widget.validator!(value);
  }

  void _handleFieldStateChanged(FormFieldState<String> field) {
    final error = field.errorText;
    if (error == _errorText) return;
    setState(() => _errorText = error);
    if (error != null) {
      triggerShake();
    } else {
      resetStatus();
    }
  }

  Widget _buildCounter(CmxFieldTheme theme) {
    final color = _counterAtLimit ? theme.errorColor : theme.labelColor;
    final baseStyle = theme.hintStyle ??
        const TextStyle(fontSize: 12, fontWeight: FontWeight.w500);
    return Padding(
      padding: const EdgeInsetsDirectional.only(top: 6, end: 4, start: 4),
      child: Align(
        alignment: AlignmentDirectional.centerEnd,
        child: Text(
          _counterText,
          style: baseStyle.copyWith(color: color, fontSize: 12),
          semanticsLabel: widget.maxLength == null
              ? '$_length characters'
              : '$_length of ${widget.maxLength} characters',
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

    final reduce = CmxAnimations.reduceMotion(context);

    // When auto-expanding, let Flutter grow the field from minLines to maxLines.
    // Otherwise pin it to a fixed maxLines-row box.
    final int effectiveMinLines;
    final int? effectiveMaxLines;
    if (widget.autoExpand) {
      effectiveMinLines = widget.minLines;
      effectiveMaxLines = widget.maxLines;
    } else {
      final fixed = widget.maxLines ?? widget.minLines;
      effectiveMinLines = fixed;
      effectiveMaxLines = fixed;
    }

    return FormField<String>(
      initialValue: _controller.text,
      enabled: widget.enabled,
      autovalidateMode: widget.autovalidateMode,
      validator: _runValidator,
      builder: (FormFieldState<String> field) {
        if (field.errorText != _errorText) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) _handleFieldStateChanged(field);
          });
        }

        final editable = TextField(
          controller: _controller,
          focusNode: focusNode,
          enabled: widget.enabled,
          decoration: null,
          keyboardType: TextInputType.multiline,
          textInputAction: widget.textInputAction ?? TextInputAction.newline,
          minLines: effectiveMinLines,
          maxLines: effectiveMaxLines,
          maxLength: widget.maxLength,
          maxLengthEnforcement: MaxLengthEnforcement.enforced,
          // Suppress Flutter's built-in counter; we render our own beneath.
          buildCounter: (
            context, {
            required int currentLength,
            required int? maxLength,
            required bool isFocused,
          }) =>
              null,
          style: theme.inputStyle,
          onChanged: (_) => _onTextChanged(field),
          onSubmitted: _handleSubmitted,
        );

        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            CmxFieldScaffold(
              theme: theme,
              status: status,
              isEmpty: _controller.text.isEmpty,
              enabled: widget.enabled,
              label: widget.label,
              hint: widget.hint,
              errorText: _errorText,
              showCheckmark: false,
              shakeAnimation: shakeAnimation,
              child: AnimatedSize(
                duration:
                    reduce ? Duration.zero : const Duration(milliseconds: 180),
                curve: Curves.easeOut,
                alignment: AlignmentDirectional.topStart,
                child: editable,
              ),
            ),
            if (widget.showCounter) _buildCounter(theme),
          ],
        );
      },
    );
  }
}
