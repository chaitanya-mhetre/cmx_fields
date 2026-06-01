import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/cmx_animations.dart';
import '../../core/cmx_field_theme.dart';

/// The visual style applied to each individual OTP box.
enum OtpFieldStyle {
  /// A full border drawn on all four sides of every box.
  outlined,

  /// A single underline beneath every box.
  underline,

  /// A filled background box with no visible border line.
  filled,

  /// A box with fully rounded corners.
  rounded,
}

/// A public controller for imperatively driving a [CmxOtpField].
///
/// Attach one by passing it to [CmxOtpField.controller]. The field reads the
/// current code through [value] and reacts to the imperative actions
/// [clear] and [shake].
///
/// The controller is wired to a single field at a time. When the field is
/// mounted it registers internal callbacks; when it is disposed it clears
/// them. Calling [clear] or [shake] while no field is attached is a safe
/// no-op.
///
/// ```dart
/// final otp = CmxOtpController();
/// // ...
/// CmxOtpField(controller: otp, length: 6);
/// // later:
/// if (otp.value != serverCode) {
///   otp.shake();
/// } else {
///   otp.clear();
/// }
/// ```
class CmxOtpController extends ChangeNotifier {
  /// Creates an OTP controller.
  CmxOtpController();

  /// Callback the attached field registers to expose its current code.
  String Function()? _valueGetter;

  /// Callback the attached field registers to perform a [clear].
  VoidCallback? onClearRequested;

  /// Callback the attached field registers to perform a [shake].
  VoidCallback? onShakeRequested;

  /// The concatenated code currently entered across all boxes.
  ///
  /// Returns an empty string when no field is attached.
  String get value => _valueGetter?.call() ?? '';

  /// Registers the attached field's value accessor. Internal.
  void attach(String Function() valueGetter) {
    _valueGetter = valueGetter;
  }

  /// Detaches the field's accessor and action callbacks. Internal.
  void detach() {
    _valueGetter = null;
    onClearRequested = null;
    onShakeRequested = null;
  }

  /// Clears every box and moves focus back to the first box.
  void clear() => onClearRequested?.call();

  /// Triggers the shake animation across all boxes simultaneously.
  void shake() => onShakeRequested?.call();
}

/// A segmented one-time-password (OTP) input field rendering a row of
/// single-character boxes.
///
/// Features:
/// * Auto-advance on entry and auto-retreat on backspace.
/// * Paste / OS-autofill distribution of a full code across all boxes.
/// * OS OTP autofill via [AutofillHints.oneTimeCode] (no native code).
/// * Shake-on-error and a success flash with a subtle scale bounce, both
///   honoring reduced motion.
/// * Optional obscuring of entered digits.
/// * Standalone use and [Form] integration via an internal [FormField].
///
/// The widget is RTL-safe: boxes lay out in the ambient text direction.
class CmxOtpField extends StatefulWidget {
  /// Creates an OTP field.
  const CmxOtpField({
    super.key,
    this.length = 6,
    this.controller,
    this.onChanged,
    this.onCompleted,
    this.autoReadSms = true,
    this.autoFocus = true,
    this.fieldStyle = OtpFieldStyle.outlined,
    this.boxSize = 52,
    this.spacing = 8,
    this.activeColor,
    this.inactiveColor,
    this.obscureText = false,
    this.obscuringCharacter = '•',
    this.validator,
    this.enabled = true,
    this.focusedColor,
    this.errorColor,
    this.successColor,
    this.borderRadius,
  })  : assert(length > 0, 'length must be greater than zero'),
        assert(boxSize > 0, 'boxSize must be greater than zero');

  /// The number of digit boxes (default `6`).
  final int length;

  /// Optional controller for imperative [CmxOtpController.clear] /
  /// [CmxOtpController.shake] and reading [CmxOtpController.value].
  final CmxOtpController? controller;

  /// Called with the concatenated code on every change.
  final ValueChanged<String>? onChanged;

  /// Called with the full code once every box is filled.
  final ValueChanged<String>? onCompleted;

  /// When `true` (default) wraps the boxes in an [AutofillGroup] and offers OS
  /// OTP autofill via [AutofillHints.oneTimeCode]. No native code is required.
  final bool autoReadSms;

  /// Whether the first box requests focus when the field is mounted
  /// (default `true`).
  final bool autoFocus;

  /// The visual style of each box (default [OtpFieldStyle.outlined]).
  final OtpFieldStyle fieldStyle;

  /// The width and height of each square box (default `52`).
  final double boxSize;

  /// Horizontal gap between boxes (default `8`).
  final double spacing;

  /// Border color of the active (focused) box. Defaults to the theme's
  /// focused color.
  final Color? activeColor;

  /// Border color of inactive (unfocused, non-error) boxes. Defaults to the
  /// theme's border color.
  final Color? inactiveColor;

  /// Whether entered digits are obscured (default `false`).
  final bool obscureText;

  /// The character used when [obscureText] is `true` (default `'•'`).
  final String obscuringCharacter;

  /// Validation callback run by [Form.validate]; receives the full code.
  final FormFieldValidator<String>? validator;

  /// Whether the field is interactive (default `true`).
  final bool enabled;

  /// Theme override for the focused accent color.
  final Color? focusedColor;

  /// Theme override for the error color.
  final Color? errorColor;

  /// Theme override for the success color.
  final Color? successColor;

  /// Theme override for the per-box corner radius.
  final double? borderRadius;

  /// Fails until every box is filled.
  static FormFieldValidator<String> complete(
    int length, {
    String? message,
  }) {
    return (String? value) {
      if (value == null || value.length < length) {
        return message ?? 'Enter all $length digits';
      }
      return null;
    };
  }

  @override
  State<CmxOtpField> createState() => _CmxOtpFieldState();
}

class _CmxOtpFieldState extends State<CmxOtpField>
    with TickerProviderStateMixin {
  late final List<TextEditingController> _controllers;
  late final List<FocusNode> _focusNodes;

  late final AnimationController _shakeController;
  late final AnimationController _successController;

  /// True while the success flash/bounce is playing.
  bool _showSuccess = false;

  /// Guards against re-entrant programmatic edits triggering listeners.
  bool _isDistributing = false;

  @override
  void initState() {
    super.initState();
    _controllers = List.generate(
      widget.length,
      (_) => TextEditingController(),
      growable: false,
    );
    _focusNodes = List.generate(
      widget.length,
      (_) => FocusNode(),
      growable: false,
    );

    _shakeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _successController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 420),
    );

    final controller = widget.controller;
    if (controller != null) {
      controller
        ..attach(_currentValue)
        ..onClearRequested = _handleClear
        ..onShakeRequested = triggerShake;
    }

    if (widget.autoFocus && widget.enabled) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _focusNodes.first.requestFocus();
      });
    }
  }

  @override
  void dispose() {
    widget.controller?.detach();
    for (final c in _controllers) {
      c.dispose();
    }
    for (final f in _focusNodes) {
      f.dispose();
    }
    _shakeController.dispose();
    _successController.dispose();
    super.dispose();
  }

  /// The concatenated code across all boxes.
  String _currentValue() => _controllers.map((c) => c.text).join();

  /// Whether every box currently holds a digit.
  bool get _isComplete =>
      _controllers.every((c) => c.text.isNotEmpty) &&
      _currentValue().length == widget.length;

  /// Triggers the shake animation on all boxes, honoring reduced motion.
  void triggerShake() {
    if (!mounted) return;
    if (CmxAnimations.reduceMotion(context)) return;
    _shakeController.forward(from: 0);
  }

  /// Plays the success flash + bounce, honoring reduced motion.
  void _flashSuccess() {
    if (!mounted) return;
    setState(() => _showSuccess = true);
    if (CmxAnimations.reduceMotion(context)) {
      _successController.value = 1;
    } else {
      _successController.forward(from: 0);
    }
  }

  /// Clears all boxes and focuses the first.
  void _handleClear() {
    if (!mounted) return;
    setState(() {
      _showSuccess = false;
    });
    for (final c in _controllers) {
      c.clear();
    }
    _successController.value = 0;
    _focusNodes.first.requestFocus();
    _notify(_currentValue());
  }

  /// Distributes [digits] across the boxes starting at [startIndex].
  void _distribute(String digits, int startIndex) {
    _isDistributing = true;
    var i = startIndex;
    for (final ch in digits.split('')) {
      if (i >= widget.length) break;
      _controllers[i].text = ch;
      i++;
    }
    _isDistributing = false;

    final lastFilled = i - 1;
    if (i >= widget.length) {
      _focusNodes[widget.length - 1].requestFocus();
    } else {
      _focusNodes[i].requestFocus();
    }
    // Keep cursor at end of the last filled box.
    if (lastFilled >= 0 && lastFilled < widget.length) {
      _controllers[lastFilled].selection = TextSelection.collapsed(
        offset: _controllers[lastFilled].text.length,
      );
    }
  }

  /// Handles a raw change in box [index] and returns the (possibly cleaned)
  /// single-character value the box should retain.
  void _onBoxChanged(int index, String raw, FormFieldState<String> field) {
    if (_isDistributing) return;

    final digits = raw.replaceAll(RegExp(r'[^0-9]'), '');

    if (digits.length > 1) {
      // Paste / autofill of a multi-character code.
      _distribute(digits, index);
    } else if (digits.isEmpty) {
      // User cleared the box (e.g. selecting and deleting).
      if (_controllers[index].text != '') {
        _controllers[index].text = '';
      }
    } else {
      // Single digit: keep it and advance.
      if (_controllers[index].text != digits) {
        _controllers[index].text = digits;
        _controllers[index].selection = const TextSelection.collapsed(
          offset: 1,
        );
      }
      if (index < widget.length - 1) {
        _focusNodes[index + 1].requestFocus();
      } else {
        _focusNodes[index].unfocus();
      }
    }

    _afterEdit(field);
  }

  /// Handles a backspace press on box [index] when it is empty: clears the
  /// previous box and moves focus to it.
  void _onBackspace(int index, FormFieldState<String> field) {
    if (_controllers[index].text.isEmpty && index > 0) {
      _controllers[index - 1].clear();
      _focusNodes[index - 1].requestFocus();
      _afterEdit(field);
    }
  }

  /// Pushes the current value to listeners and fires completion logic.
  void _afterEdit(FormFieldState<String> field) {
    final value = _currentValue();
    field.didChange(value);
    _notify(value);

    if (_isComplete) {
      widget.onCompleted?.call(value);
      _flashSuccess();
    } else if (_showSuccess) {
      setState(() => _showSuccess = false);
      _successController.value = 0;
    }
  }

  /// Notifies [CmxOtpField.onChanged] and rebuilds for box-state changes.
  void _notify(String value) {
    widget.onChanged?.call(value);
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final base = CmxFieldThemeProvider.of(context);
    final theme = base.copyWith(
      focusedColor: widget.focusedColor,
      errorColor: widget.errorColor,
      successColor: widget.successColor,
      borderRadius: widget.borderRadius,
    );

    return FormField<String>(
      initialValue: _currentValue(),
      enabled: widget.enabled,
      validator: widget.validator,
      builder: (field) {
        final hasError = field.hasError;
        if (hasError) {
          // Shake when validation reports an error.
          WidgetsBinding.instance.addPostFrameCallback((_) => triggerShake());
        }

        final boxes = List<Widget>.generate(widget.length, (index) {
          return Padding(
            padding: EdgeInsetsDirectional.only(
              end: index == widget.length - 1 ? 0 : widget.spacing,
            ),
            child: _buildBox(index, theme, hasError, field),
          );
        });

        final row = Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: boxes,
        );

        final shaken = CmxAnimations.shake(
          controller: _shakeController,
          enabled: !CmxAnimations.reduceMotion(context),
          child: row,
        );

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (widget.autoReadSms) AutofillGroup(child: shaken) else shaken,
            CmxAnimations.slideInError(
              visible: hasError,
              child: Padding(
                padding: const EdgeInsetsDirectional.only(top: 8, start: 4),
                child: Text(
                  field.errorText ?? '',
                  style: (theme.errorStyle ??
                          const TextStyle(fontSize: 12, height: 1.2))
                      .copyWith(color: theme.errorColor),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  /// Builds a single OTP box at [index].
  Widget _buildBox(
    int index,
    CmxFieldTheme theme,
    bool hasError,
    FormFieldState<String> field,
  ) {
    final focusNode = _focusNodes[index];
    final controller = _controllers[index];
    final isFocused = focusNode.hasFocus;
    final isFilled = controller.text.isNotEmpty;

    final activeColor = widget.activeColor ?? theme.focusedColor;
    final inactiveColor = widget.inactiveColor ?? theme.borderColor;

    Color borderColor;
    if (hasError) {
      borderColor = theme.errorColor;
    } else if (_showSuccess) {
      borderColor = theme.successColor;
    } else if (isFocused) {
      borderColor = activeColor;
    } else if (isFilled) {
      borderColor = activeColor;
    } else {
      borderColor = inactiveColor;
    }

    return AnimatedBuilder(
      animation: _successController,
      builder: (context, child) {
        // Subtle scale bounce on success.
        final t = _successController.value;
        final scale = _showSuccess ? 1.0 + 0.06 * _bounce(t) : 1.0;
        return Transform.scale(scale: scale, child: child);
      },
      child: SizedBox(
        width: widget.boxSize,
        height: widget.boxSize,
        child: DecoratedBox(
          decoration: _decorationFor(theme, borderColor),
          child: Focus(
            // Detect backspace on an already-empty box to retreat + clear.
            onKeyEvent: (node, event) {
              if (event is KeyDownEvent &&
                  event.logicalKey == LogicalKeyboardKey.backspace &&
                  controller.text.isEmpty) {
                _onBackspace(index, field);
              }
              return KeyEventResult.ignored;
            },
            child: Center(
              child: TextField(
                controller: controller,
                focusNode: focusNode,
                enabled: widget.enabled,
                obscureText: widget.obscureText,
                obscuringCharacter: widget.obscuringCharacter,
                textAlign: TextAlign.center,
                textAlignVertical: TextAlignVertical.center,
                keyboardType: TextInputType.number,
                maxLines: 1,
                showCursor: true,
                cursorColor: activeColor,
                enableSuggestions: false,
                autocorrect: false,
                autofillHints: widget.autoReadSms
                    ? const [AutofillHints.oneTimeCode]
                    : null,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                ],
                style: (theme.inputStyle ??
                        const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w600,
                        ))
                    .copyWith(height: 1),
                decoration: const InputDecoration(
                  isCollapsed: true,
                  isDense: true,
                  counterText: '',
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.zero,
                ),
                onChanged: (raw) => _onBoxChanged(index, raw, field),
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// A 0→1→0 bounce envelope for the success scale.
  double _bounce(double t) {
    // Peaks at t = 0.5, smooth ease in/out.
    return (t <= 0.5 ? t / 0.5 : (1 - t) / 0.5).clamp(0.0, 1.0);
  }

  /// Builds the [BoxDecoration] for a box given its resolved [borderColor].
  BoxDecoration _decorationFor(CmxFieldTheme theme, Color borderColor) {
    final radius = BorderRadius.circular(theme.borderRadius);
    switch (widget.fieldStyle) {
      case OtpFieldStyle.outlined:
        return BoxDecoration(
          color: theme.backgroundColor,
          borderRadius: radius,
          border: Border.all(color: borderColor, width: theme.borderWidth),
        );
      case OtpFieldStyle.rounded:
        return BoxDecoration(
          color: theme.backgroundColor,
          borderRadius: BorderRadius.circular(widget.boxSize / 2),
          border: Border.all(color: borderColor, width: theme.borderWidth),
        );
      case OtpFieldStyle.filled:
        return BoxDecoration(
          color: theme.fillColor,
          borderRadius: radius,
          border: Border.all(color: borderColor, width: theme.borderWidth),
        );
      case OtpFieldStyle.underline:
        return BoxDecoration(
          color: theme.backgroundColor,
          border: Border(
            bottom: BorderSide(
              color: borderColor,
              width: theme.borderWidth + 0.5,
            ),
          ),
        );
    }
  }
}
