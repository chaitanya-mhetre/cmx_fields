import 'package:flutter/widgets.dart';

import 'cmx_field_status.dart';
import 'cmx_field_theme.dart';

/// Mixin for a field's [State] that removes the repetitive plumbing every
/// `cmx_fields` widget needs: a managed [FocusNode], a shake
/// [AnimationController], status tracking, and theme resolution.
///
/// Usage:
/// ```dart
/// class _MyFieldState extends State<MyField>
///     with TickerProviderStateMixin, CmxFieldStateMixin<MyField> {
///   @override
///   void initState() {
///     super.initState();
///     initCmxField(focusNode: widget.focusNode);
///   }
///   @override
///   void dispose() {
///     disposeCmxField();
///     super.dispose();
///   }
/// }
/// ```
mixin CmxFieldStateMixin<T extends StatefulWidget> on State<T>, TickerProvider {
  FocusNode? _ownedFocusNode;
  late FocusNode _focusNode;
  late final AnimationController _shakeController;

  CmxFieldStatus _status = CmxFieldStatus.idle;
  bool _enabled = true;

  /// The active focus node (provided by the widget, or owned internally).
  FocusNode get focusNode => _focusNode;

  /// Whether the field is currently focused.
  bool get isFocused => _focusNode.hasFocus;

  /// The current status.
  CmxFieldStatus get status => _status;

  /// The shake animation (0..1) to hand to [CmxFieldScaffold].
  Animation<double> get shakeAnimation => _shakeController;

  /// Initializes the field. Call from `initState`.
  ///
  /// Pass the widget's own [focusNode] if it exposes one; otherwise an internal
  /// node is created and disposed automatically.
  void initCmxField({FocusNode? focusNode, bool enabled = true}) {
    _enabled = enabled;
    if (focusNode != null) {
      _focusNode = focusNode;
    } else {
      _ownedFocusNode = FocusNode();
      _focusNode = _ownedFocusNode!;
    }
    _focusNode.addListener(_handleFocusChange);
    _shakeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _syncStatusFromFocus();
  }

  /// Disposes owned resources. Call from `dispose`.
  void disposeCmxField() {
    _focusNode.removeListener(_handleFocusChange);
    _ownedFocusNode?.dispose();
    _shakeController.dispose();
  }

  void _handleFocusChange() {
    if (!mounted) return;
    _syncStatusFromFocus();
  }

  void _syncStatusFromFocus() {
    if (!_enabled) {
      _setStatusInternal(CmxFieldStatus.disabled);
      return;
    }
    // Don't clobber an explicit error/valid/loading state on mere focus change.
    if (_status == CmxFieldStatus.error ||
        _status == CmxFieldStatus.loading ||
        _status == CmxFieldStatus.valid) {
      return;
    }
    _setStatusInternal(
      _focusNode.hasFocus ? CmxFieldStatus.focused : CmxFieldStatus.idle,
    );
  }

  void _setStatusInternal(CmxFieldStatus next) {
    if (_status == next) return;
    setState(() => _status = next);
  }

  /// Sets the field's [status] and rebuilds.
  void setStatus(CmxFieldStatus next) => _setStatusInternal(next);

  /// Updates the enabled flag and recomputes status.
  void setEnabled(bool enabled) {
    _enabled = enabled;
    _syncStatusFromFocus();
  }

  /// Clears any error/valid override and returns the field to its
  /// focus-derived status (idle or focused).
  void resetStatus() {
    _status =
        _focusNode.hasFocus ? CmxFieldStatus.focused : CmxFieldStatus.idle;
    if (mounted) setState(() {});
  }

  /// Triggers the shake animation and moves the field into its error state.
  ///
  /// Respects reduced-motion: the status still flips, but no motion plays.
  void triggerShake() {
    setStatus(CmxFieldStatus.error);
    final reduce = MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    if (reduce) return;
    _shakeController
      ..reset()
      ..forward();
  }

  /// Resolves the effective theme: the inherited [CmxFieldThemeProvider] theme
  /// with any per-field overrides applied on top.
  CmxFieldTheme resolveTheme(
    BuildContext context, {
    Color? focusedColor,
    Color? errorColor,
    Color? successColor,
    Color? borderColor,
    Color? backgroundColor,
    Color? fillColor,
    double? borderRadius,
    double? borderWidth,
    CmxBorderStyle? borderStyle,
    EdgeInsets? contentPadding,
    TextStyle? labelStyle,
    TextStyle? hintStyle,
    TextStyle? inputStyle,
  }) {
    final base = CmxFieldThemeProvider.of(context);
    return base.copyWith(
      focusedColor: focusedColor,
      errorColor: errorColor,
      successColor: successColor,
      borderColor: borderColor,
      backgroundColor: backgroundColor,
      fillColor: fillColor,
      borderRadius: borderRadius,
      borderWidth: borderWidth,
      borderStyle: borderStyle,
      contentPadding: contentPadding,
      labelStyle: labelStyle,
      hintStyle: hintStyle,
      inputStyle: inputStyle,
    );
  }
}
