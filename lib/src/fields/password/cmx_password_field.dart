import 'package:flutter/material.dart';

import '../../core/cmx_animations.dart';
import '../../core/cmx_field_mixin.dart';
import '../../core/cmx_field_scaffold.dart';
import '../../core/cmx_field_theme.dart';
import '../../core/cmx_validators.dart';
import 'strength_indicator.dart';

/// A production-grade, animated password input built on the `cmx_fields` core.
///
/// Features:
/// * An animated show/hide eye toggle (eye <-> eye-off) in the suffix.
/// * A lock icon prefix that performs a subtle pulse when the field gains
///   focus (honoring reduced motion).
/// * A live strength bar beneath the field that updates as the user types.
/// * An optional rules checklist beneath the field.
/// * Validation that combines a caller-supplied [validator] with an optional
///   minimum-strength requirement ([minStrength]); failures show an error and
///   trigger the field's shake.
///
/// Works standalone and inside a [Form]: when placed in a form it registers a
/// hidden [FormField] so that `Form.validate()` runs the combined validator,
/// surfaces the error, and shakes the field.
class CmxPasswordField extends StatefulWidget {
  /// Creates a password field.
  const CmxPasswordField({
    super.key,
    this.label,
    this.hint,
    this.controller,
    this.focusNode,
    this.enabled = true,
    this.obscureInitially = true,
    this.showStrengthIndicator = true,
    this.showRules = false,
    this.rules,
    this.minStrength,
    this.onChanged,
    this.onSubmitted,
    this.validator,
    this.textInputAction,
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

  /// External text controller. When null an internal one is created.
  final TextEditingController? controller;

  /// External focus node. When null an internal one is created.
  final FocusNode? focusNode;

  /// Whether the field is interactive.
  final bool enabled;

  /// Whether the password starts obscured (hidden).
  final bool obscureInitially;

  /// Whether to render the live strength bar beneath the field.
  final bool showStrengthIndicator;

  /// Whether to render the rules checklist beneath the field.
  final bool showRules;

  /// The rules to evaluate/display; defaults to [kDefaultPasswordRules].
  final List<PasswordRule>? rules;

  /// The minimum acceptable [PasswordStrength]. When set, validation fails if
  /// the entered password is weaker than this level.
  final PasswordStrength? minStrength;

  /// Called whenever the text changes.
  final ValueChanged<String>? onChanged;

  /// Called when the user submits the field.
  final ValueChanged<String>? onSubmitted;

  /// Caller-supplied validator, composed with the [minStrength] check.
  final CmxValidator<String>? validator;

  /// The keyboard action button.
  final TextInputAction? textInputAction;

  /// Override for the focused accent color.
  final Color? focusedColor;

  /// Override for the error color.
  final Color? errorColor;

  /// Override for the success color.
  final Color? successColor;

  /// Override for the resting border color.
  final Color? borderColor;

  /// Override for the field background color.
  final Color? backgroundColor;

  /// Override for the [CmxBorderStyle.filled] fill color.
  final Color? fillColor;

  /// Override for the corner radius.
  final double? borderRadius;

  /// Override for the border stroke width.
  final double? borderWidth;

  /// Override for the border style.
  final CmxBorderStyle? borderStyle;

  /// Override for the inner content padding.
  final EdgeInsets? contentPadding;

  /// Override for the label text style.
  final TextStyle? labelStyle;

  /// Override for the hint text style.
  final TextStyle? hintStyle;

  /// Override for the input text style.
  final TextStyle? inputStyle;

  @override
  State<CmxPasswordField> createState() => _CmxPasswordFieldState();
}

class _CmxPasswordFieldState extends State<CmxPasswordField>
    with TickerProviderStateMixin, CmxFieldStateMixin<CmxPasswordField> {
  TextEditingController? _ownedController;
  late TextEditingController _controller;
  late AnimationController _lockPulseController;

  bool _obscured = true;
  String? _errorText;

  @override
  void initState() {
    super.initState();
    _obscured = widget.obscureInitially;
    _controller =
        widget.controller ?? (_ownedController = TextEditingController());
    initCmxField(focusNode: widget.focusNode, enabled: widget.enabled);
    _lockPulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    focusNode.addListener(_handleFocusPulse);
  }

  @override
  void didUpdateWidget(covariant CmxPasswordField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.enabled != oldWidget.enabled) {
      setEnabled(widget.enabled);
    }
  }

  @override
  void dispose() {
    focusNode.removeListener(_handleFocusPulse);
    _lockPulseController.dispose();
    _ownedController?.dispose();
    disposeCmxField();
    super.dispose();
  }

  void _handleFocusPulse() {
    if (!mounted) return;
    if (focusNode.hasFocus && !CmxAnimations.reduceMotion(context)) {
      _lockPulseController
        ..reset()
        ..forward();
    }
  }

  /// The effective rule set.
  List<PasswordRule> get _rules => widget.rules ?? kDefaultPasswordRules;

  /// The current strength of the entered password.
  PasswordStrength get _strength =>
      PasswordStrengthChecker.check(_controller.text);

  /// Runs the combined validator: the [minStrength] check first (when set),
  /// then the caller-supplied [validator].
  String? _runValidation(String? value) {
    final text = value ?? '';
    final min = widget.minStrength;
    if (min != null && min != PasswordStrength.none) {
      final strength = PasswordStrengthChecker.check(text);
      if (strength.index < min.index) {
        return 'Password is too weak (minimum: ${min.label})';
      }
    }
    return widget.validator?.call(value);
  }

  /// Used by the embedded [FormField] to validate, surface the error and shake.
  ///
  /// Validates the *live* controller text (not the [FormField]'s captured
  /// value) so it always reflects what the user currently sees.
  String? _formValidate(String? _) {
    final error = _runValidation(_controller.text);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      setState(() => _errorText = error);
      if (error != null) {
        triggerShake();
      } else {
        resetStatus();
      }
    });
    return error;
  }

  void _handleChanged(String value) {
    setState(() {
      // Recompute strength + label-float via isEmpty; clear stale errors.
      if (_errorText != null && _runValidation(value) == null) {
        _errorText = null;
        resetStatus();
      }
    });
    widget.onChanged?.call(value);
  }

  void _toggleObscured() {
    setState(() => _obscured = !_obscured);
  }

  Widget _buildEyeToggle(CmxFieldTheme theme) {
    final reduce = CmxAnimations.reduceMotion(context);
    return IconButton(
      tooltip: _obscured ? 'Show password' : 'Hide password',
      splashRadius: 22,
      onPressed: widget.enabled ? _toggleObscured : null,
      icon: AnimatedSwitcher(
        duration: reduce ? Duration.zero : const Duration(milliseconds: 220),
        transitionBuilder: (child, animation) => FadeTransition(
          opacity: animation,
          child: ScaleTransition(scale: animation, child: child),
        ),
        child: Icon(
          _obscured ? Icons.visibility_off_outlined : Icons.visibility_outlined,
          key: ValueKey<bool>(_obscured),
          color: theme.labelColor,
        ),
      ),
    );
  }

  Widget _buildLockPrefix(CmxFieldTheme theme) {
    final lock = Padding(
      padding: const EdgeInsetsDirectional.only(start: 12, end: 8),
      child: Icon(
        Icons.lock_outline,
        size: 20,
        color: isFocused ? theme.focusedColor : theme.labelColor,
      ),
    );
    return CmxAnimations.pulse(
      controller: _lockPulseController,
      enabled: !CmxAnimations.reduceMotion(context),
      child: lock,
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

    final fieldBox = CmxFieldScaffold(
      theme: theme,
      status: status,
      isEmpty: _controller.text.isEmpty,
      label: widget.label,
      hint: widget.hint,
      errorText: _errorText,
      enabled: widget.enabled,
      showCheckmark: false,
      prefix: _buildLockPrefix(theme),
      suffix: _buildEyeToggle(theme),
      shakeAnimation: shakeAnimation,
      child: TextField(
        controller: _controller,
        focusNode: focusNode,
        enabled: widget.enabled,
        obscureText: _obscured,
        obscuringCharacter: '•',
        enableSuggestions: false,
        autocorrect: false,
        textInputAction: widget.textInputAction,
        style: theme.inputStyle,
        decoration: null,
        onChanged: _handleChanged,
        onSubmitted: widget.onSubmitted,
      ),
    );

    // Hidden FormField so Form.validate() drives our combined validator.
    final formBridge = FormField<String>(
      enabled: widget.enabled,
      initialValue: _controller.text,
      validator: _formValidate,
      builder: (_) => const SizedBox.shrink(),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        fieldBox,
        formBridge,
        if (widget.showStrengthIndicator) ...<Widget>[
          const SizedBox(height: 8),
          StrengthIndicator(strength: _strength),
        ],
        if (widget.showRules) ...<Widget>[
          const SizedBox(height: 8),
          PasswordRulesChecklist(
            rules: _rules,
            password: _controller.text,
          ),
        ],
      ],
    );
  }
}
