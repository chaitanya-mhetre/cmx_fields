/// The flagship email input field for `cmx_fields`.
library;

import 'package:flutter/material.dart';

import '../core/cmx_animations.dart';
import '../core/cmx_field_mixin.dart';
import '../core/cmx_field_scaffold.dart';
import '../core/cmx_field_status.dart';
import '../core/cmx_field_theme.dart';
import '../core/cmx_fill_progress.dart';
import '../core/cmx_validators.dart';

/// A polished, animated email input.
///
/// Features:
/// * Live syntactic validation: as soon as the typed text is a valid email the
///   field flips to [CmxFieldStatus.valid] and the scaffold shows its green
///   checkmark. Invalid-but-non-empty input stays quiet (no intrusive error)
///   until the user blurs the field, submits, or [Form.validate] runs.
/// * An animated envelope prefix icon that transitions from the resting outline
///   to a filled, success-colored seal once the email becomes valid
///   (reduced-motion safe).
/// * A domain-suggestion overlay: once the text contains exactly one `@` the
///   field offers `localpart@domain` completions for a set of common providers
///   plus any [customDomains], filtered by the partial domain already typed.
///   Tapping a suggestion completes the field and closes the overlay.
///
/// Works standalone and inside a [Form]; it builds an internal [FormField] so
/// `Form.validate()` triggers [validator], shows the error and shakes.
class CmxEmailField extends StatefulWidget {
  /// Creates an email field.
  const CmxEmailField({
    super.key,
    this.label,
    this.hint,
    this.controller,
    this.focusNode,
    this.enabled = true,
    this.showSuggestions = true,
    this.showFillProgress = true,
    this.customDomains = const <String>[],
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

  /// Whether to show the domain-completion suggestion overlay.
  final bool showSuggestions;

  /// Whether to show the green fill-progress ring (and tick) in the suffix
  /// while typing. When `false`, the scaffold checkmark is used when valid.
  final bool showFillProgress;

  /// Extra domains appended to the built-in providers in suggestions.
  final List<String> customDomains;

  /// Called whenever the entered text changes.
  final ValueChanged<String>? onChanged;

  /// Called when the user submits from the keyboard.
  final ValueChanged<String>? onSubmitted;

  /// Validates the current text; return an error string or `null`.
  ///
  /// When omitted the field still validates syntactically for its own visual
  /// state, but a [Form] sees it as always valid.
  final CmxValidator<String>? validator;

  /// The keyboard action button; defaults to [TextInputAction.done].
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

  /// The built-in email providers offered as domain completions, in priority
  /// order. [customDomains] are appended after these.
  static const List<String> defaultDomains = <String>[
    'gmail.com',
    'yahoo.com',
    'outlook.com',
    'hotmail.com',
    'icloud.com',
  ];

  @override
  State<CmxEmailField> createState() => _CmxEmailFieldState();
}

class _CmxEmailFieldState extends State<CmxEmailField>
    with TickerProviderStateMixin, CmxFieldStateMixin<CmxEmailField> {
  late TextEditingController _controller;
  bool _ownsController = false;

  final LayerLink _layerLink = LayerLink();
  OverlayEntry? _overlayEntry;
  List<String> _suggestions = const <String>[];

  /// Validates email syntax exactly like [CmxValidators.email].
  static final CmxValidator<String> _syntaxValidator = CmxValidators.email();

  String? _errorText;

  @override
  void initState() {
    super.initState();
    initCmxField(focusNode: widget.focusNode, enabled: widget.enabled);

    _controller = widget.controller ?? TextEditingController();
    _ownsController = widget.controller == null;

    focusNode.addListener(_handleFocusChanged);
    _applyLiveStatus();
  }

  @override
  void didUpdateWidget(CmxEmailField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.enabled != oldWidget.enabled) {
      setEnabled(widget.enabled);
    }
  }

  @override
  void dispose() {
    _removeOverlay();
    focusNode.removeListener(_handleFocusChanged);
    if (_ownsController) _controller.dispose();
    disposeCmxField();
    super.dispose();
  }

  // --- Validity ---------------------------------------------------------------

  /// Whether the current text is a syntactically valid, non-empty email.
  bool get _isValidEmail {
    final text = _controller.text.trim();
    if (text.isEmpty) return false;
    return _syntaxValidator(text) == null;
  }

  /// Fill amount for the suffix ring while the user is typing an email.
  double _emailFillProgress(String text) {
    final t = text.trim();
    if (t.isEmpty) return 0;
    if (_syntaxValidator(t) == null) return 1;
    final at = t.indexOf('@');
    if (at < 0) {
      return (t.length / 6).clamp(0.08, 0.35);
    }
    final local = t.substring(0, at);
    final domain = t.substring(at + 1);
    if (local.isEmpty) return 0.25;
    if (domain.isEmpty) return 0.55;
    if (!domain.contains('.')) return 0.75;
    return 0.9;
  }

  /// Applies the live (non-intrusive) status from the current text.
  ///
  /// Valid input flips to [CmxFieldStatus.valid] so the checkmark shows;
  /// invalid input simply returns to the focus-derived state and never raises
  /// an error here — errors are surfaced only on blur/submit/Form.validate.
  void _applyLiveStatus() {
    if (!widget.enabled) return;
    if (_isValidEmail) {
      _errorText = null;
      setStatus(CmxFieldStatus.valid);
    } else if (status.isValid || status.isError) {
      _errorText = null;
      resetStatus();
    }
  }

  // --- Text changes -----------------------------------------------------------

  void _onTextChanged(FormFieldState<String> field) {
    setState(() {
      _applyLiveStatus();
      _updateSuggestions();
    });
    widget.onChanged?.call(_controller.text);
    field.didChange(_controller.text);
  }

  void _handleSubmitted(String value) {
    widget.onSubmitted?.call(value);
  }

  void _handleFocusChanged() {
    if (!mounted) return;
    if (isFocused) {
      _updateSuggestions();
    } else {
      _removeOverlay();
    }
  }

  // --- Domain suggestions overlay --------------------------------------------

  /// Computes the `localpart@domain` completions for the current text.
  ///
  /// Returns an empty list unless the text contains exactly one `@` and a
  /// non-empty local part. The (possibly empty) partial domain after the `@`
  /// filters the candidate domains by prefix; an already-complete match is not
  /// re-offered.
  List<String> _computeSuggestions() {
    final text = _controller.text.trim();
    final atCount = '@'.allMatches(text).length;
    if (atCount != 1) return const <String>[];

    final atIndex = text.indexOf('@');
    final local = text.substring(0, atIndex);
    if (local.isEmpty) return const <String>[];
    final partial = text.substring(atIndex + 1).toLowerCase();

    final domains = <String>[
      ...CmxEmailField.defaultDomains,
      ...widget.customDomains,
    ];

    final results = <String>[];
    final seen = <String>{};
    for (final domain in domains) {
      if (!domain.toLowerCase().startsWith(partial)) continue;
      if (domain.toLowerCase() == partial) continue;
      if (!seen.add(domain.toLowerCase())) continue;
      results.add('$local@$domain');
      if (results.length >= 6) break;
    }
    return results;
  }

  void _updateSuggestions() {
    if (!widget.showSuggestions || !isFocused || !widget.enabled) {
      _removeOverlay();
      return;
    }
    final next = _computeSuggestions();
    if (next.isEmpty) {
      _removeOverlay();
      return;
    }
    _suggestions = next;
    _showOverlay();
  }

  void _showOverlay() {
    final overlay = Overlay.maybeOf(context);
    if (overlay == null) return;
    if (_overlayEntry == null) {
      _overlayEntry = OverlayEntry(builder: _buildOverlay);
      overlay.insert(_overlayEntry!);
    } else {
      _overlayEntry!.markNeedsBuild();
    }
  }

  void _removeOverlay() {
    _overlayEntry?.remove();
    _overlayEntry = null;
  }

  Widget _buildOverlay(BuildContext context) {
    final theme = Theme.of(context);
    return Positioned(
      width: 320,
      child: CompositedTransformFollower(
        link: _layerLink,
        showWhenUnlinked: false,
        offset: const Offset(0, 56),
        child: Material(
          elevation: 4,
          borderRadius: BorderRadius.circular(12),
          color: theme.colorScheme.surface,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 220),
            child: ListView.builder(
              padding: EdgeInsets.zero,
              shrinkWrap: true,
              itemCount: _suggestions.length,
              itemBuilder: (context, index) {
                final suggestion = _suggestions[index];
                return ListTile(
                  dense: true,
                  leading: const Icon(Icons.alternate_email, size: 20),
                  title: Text(suggestion),
                  onTap: () => _applySuggestion(suggestion),
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  void _applySuggestion(String suggestion) {
    setState(() {
      _controller.value = TextEditingValue(
        text: suggestion,
        selection: TextSelection.collapsed(offset: suggestion.length),
      );
      _applyLiveStatus();
    });
    widget.onChanged?.call(suggestion);
    _removeOverlay();
  }

  // --- Suffix (fill progress) ------------------------------------------------

  Widget? _buildSuffix(CmxFieldTheme theme) {
    final text = _controller.text.trim();
    if (text.isEmpty) return null;

    if (!widget.showFillProgress) {
      if (!_isValidEmail) return null;
      return Padding(
        padding: const EdgeInsetsDirectional.only(end: 12),
        child: CmxCheckmark(
          visible: true,
          color: theme.successColor,
          size: 22,
          strokeWidth: 2.5,
        ),
      );
    }

    return CmxFillProgress(
      progress: _emailFillProgress(text),
      valid: _isValidEmail,
      color: theme.successColor,
    );
  }

  // --- Animated envelope prefix ----------------------------------------------

  Widget _buildEnvelopePrefix(CmxFieldTheme theme) {
    final valid = _isValidEmail;
    final reduce = CmxAnimations.reduceMotion(context);
    final restColor = isFocused ? theme.focusedColor : theme.labelColor;
    final color = valid ? theme.successColor : restColor;
    return Padding(
      padding: const EdgeInsetsDirectional.only(start: 12, end: 8),
      child: AnimatedSwitcher(
        duration: reduce ? Duration.zero : const Duration(milliseconds: 240),
        transitionBuilder: (child, animation) => ScaleTransition(
          scale: animation,
          child: FadeTransition(opacity: animation, child: child),
        ),
        child: Icon(
          valid ? Icons.mark_email_read : Icons.mail_outline,
          key: ValueKey<bool>(valid),
          color: color,
          size: 22,
        ),
      ),
    );
  }

  // --- FormField glue ---------------------------------------------------------

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
      _applyLiveStatus();
    }
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

    return FormField<String>(
      initialValue: _controller.text,
      enabled: widget.enabled,
      autovalidateMode: widget.autovalidateMode,
      validator: _runValidator,
      builder: (FormFieldState<String> field) {
        // Mirror the FormField's error into our scaffold/shake after the frame
        // (e.g. when Form.validate() runs externally).
        if (field.errorText != _errorText) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) _handleFieldStateChanged(field);
          });
        }

        return CompositedTransformTarget(
          link: _layerLink,
          child: CmxFieldScaffold(
            theme: theme,
            status: status,
            isEmpty: _controller.text.isEmpty,
            enabled: widget.enabled,
            label: widget.label,
            hint: widget.hint,
            errorText: _errorText,
            prefix: _buildEnvelopePrefix(theme),
            suffix: _buildSuffix(theme),
            suffixIconConstraints: const BoxConstraints(
              minWidth: 48,
              minHeight: 36,
              maxWidth: 48,
              maxHeight: 36,
            ),
            showCheckmark: !widget.showFillProgress,
            shakeAnimation: shakeAnimation,
            child: TextField(
              controller: _controller,
              focusNode: focusNode,
              enabled: widget.enabled,
              decoration: null,
              keyboardType: TextInputType.emailAddress,
              textInputAction: widget.textInputAction ?? TextInputAction.done,
              autocorrect: false,
              enableSuggestions: false,
              style: theme.inputStyle,
              onChanged: (_) => _onTextChanged(field),
              onSubmitted: _handleSubmitted,
            ),
          ),
        );
      },
    );
  }
}
