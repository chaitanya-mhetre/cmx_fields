/// The credit-card input field for `cmx_fields`: a grouped, brand-aware card
/// number plus expiry and CVV sub-inputs, with Luhn validation.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/cmx_field_mixin.dart';
import '../../core/cmx_field_scaffold.dart';
import '../../core/cmx_field_status.dart';
import '../../core/cmx_field_theme.dart';
import '../../core/cmx_validators.dart';
import 'card_type_detector.dart';

/// The parsed value of a [CmxCardField], emitted on every change and passed to
/// the validator.
@immutable
class CardResult {
  /// Creates a card result.
  const CardResult({
    required this.number,
    required this.formattedNumber,
    required this.expiry,
    required this.cvv,
    required this.cardType,
    required this.isValid,
  });

  /// The card number digits with no grouping separators (e.g. `4242...`).
  final String number;

  /// The card number with brand-appropriate grouping (e.g. `4242 4242 ...`).
  final String formattedNumber;

  /// The expiry in `MM/YY` form (e.g. `09/27`).
  final String expiry;

  /// The CVV/CID digits.
  final String cvv;

  /// The detected brand.
  final CardType cardType;

  /// Whether the number is Luhn-valid and of the brand's expected length, the
  /// expiry is a valid, non-expired `MM/YY`, and the CVV has the expected
  /// length for the brand.
  final bool isValid;

  @override
  bool operator ==(Object other) =>
      other is CardResult &&
      other.number == number &&
      other.formattedNumber == formattedNumber &&
      other.expiry == expiry &&
      other.cvv == cvv &&
      other.cardType == cardType &&
      other.isValid == isValid;

  @override
  int get hashCode =>
      Object.hash(number, formattedNumber, expiry, cvv, cardType, isValid);

  @override
  String toString() => 'CardResult(number: $formattedNumber, '
      'expiry: $expiry, cardType: $cardType, isValid: $isValid)';
}

/// Pure helpers for card-number formatting and validation.
///
/// Exposed statically so the grouping and Luhn logic are fully unit-testable
/// without a widget.
class CardFormatting {
  const CardFormatting._();

  /// Strips every non-digit character from [input].
  static String digitsOnly(String input) {
    final buffer = StringBuffer();
    for (final unit in input.codeUnits) {
      if (unit >= 0x30 && unit <= 0x39) buffer.writeCharCode(unit);
    }
    return buffer.toString();
  }

  /// Groups [number]'s digits with single spaces for the given [type].
  ///
  /// Amex groups as `4-6-5`; every other brand groups in fours. Excess digits
  /// beyond [CardTypeDetector.maxLength] for [type] are dropped.
  static String groupNumber(String number, CardType type) {
    final digits = digitsOnly(number);
    final max = CardTypeDetector.maxLength(type);
    final capped = digits.length > max ? digits.substring(0, max) : digits;
    final groups =
        type == CardType.amex ? const <int>[4, 6, 5] : const <int>[4, 4, 4, 4];

    final out = StringBuffer();
    var index = 0;
    for (final size in groups) {
      if (index >= capped.length) break;
      if (out.isNotEmpty) out.write(' ');
      final end =
          (index + size) <= capped.length ? index + size : capped.length;
      out.write(capped.substring(index, end));
      index = end;
    }
    return out.toString();
  }

  /// Validates [number] against the Luhn (mod-10) checksum.
  ///
  /// Returns `false` for empty input or any string with fewer than two digits.
  static bool isLuhnValid(String number) {
    final digits = digitsOnly(number);
    if (digits.length < 2) return false;
    var sum = 0;
    var alternate = false;
    for (var i = digits.length - 1; i >= 0; i--) {
      var n = digits.codeUnitAt(i) - 0x30;
      if (alternate) {
        n *= 2;
        if (n > 9) n -= 9;
      }
      sum += n;
      alternate = !alternate;
    }
    return sum % 10 == 0;
  }
}

/// A [TextInputFormatter] that groups card-number digits as the user types,
/// per the brand resolved from the current input, and caps the length.
class _CardNumberFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final type = CardTypeDetector.detect(newValue.text);
    final formatted = CardFormatting.groupNumber(newValue.text, type);
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}

/// A [TextInputFormatter] for `MM/YY` expiry input that auto-inserts the `/`
/// after the two month digits and caps the field at four digits.
class _ExpiryFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final digits = CardFormatting.digitsOnly(newValue.text);
    final capped = digits.length > 4 ? digits.substring(0, 4) : digits;
    final out = StringBuffer();
    for (var i = 0; i < capped.length; i++) {
      if (i == 2) out.write('/');
      out.write(capped[i]);
    }
    final text = out.toString();
    return TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }
}

/// Validates an `MM/YY` [expiry] against the [now] reference date.
///
/// Returns `true` only for a complete `MM/YY` whose month is `01`-`12` and
/// whose month/year is not in the past. Exposed for testing.
bool isExpiryValid(String expiry, {DateTime? now}) {
  final digits = CardFormatting.digitsOnly(expiry);
  if (digits.length != 4) return false;
  final month = int.parse(digits.substring(0, 2));
  final year = 2000 + int.parse(digits.substring(2, 4));
  if (month < 1 || month > 12) return false;
  final reference = now ?? DateTime.now();
  // Valid through the last day of the expiry month.
  final lastValidMoment = DateTime(year, month + 1, 0, 23, 59, 59);
  return !lastValidMoment.isBefore(reference);
}

/// A polished credit-card input.
///
/// Layout:
/// * A full-width **number** field that groups digits with spaces
///   (`4242 4242 4242 4242`; Amex groups `4-6-5`), auto-detects the brand and
///   animates the matching badge into the suffix slot via [AnimatedSwitcher].
/// * Below it, a row of an **expiry** (`MM/YY`) field and an obscured **CVV**
///   field whose length tracks the detected brand.
///
/// Validation: the number must be Luhn-valid and of the brand's expected
/// length, the expiry a valid non-expired `MM/YY`, and the CVV of the expected
/// length. The combined [CardResult] is emitted via [onChanged] and validated
/// through [validator].
///
/// Works standalone and inside a [Form]; it builds an internal
/// [FormField] so `Form.validate()` triggers [validator], shows the error and
/// shakes. Reduced-motion and RTL safe.
class CmxCardField extends StatefulWidget {
  /// Creates a card field.
  const CmxCardField({
    super.key,
    this.label = 'Card number',
    this.enabled = true,
    this.showCardTypeIcon = true,
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

  /// Floating label for the number field.
  final String? label;

  /// Whether the field is interactive.
  final bool enabled;

  /// Whether to show the animated brand badge in the number field's suffix.
  final bool showCardTypeIcon;

  /// Called whenever any sub-input changes, with the combined [CardResult].
  final ValueChanged<CardResult>? onChanged;

  /// Validates the combined [CardResult]; return an error string or `null`.
  final CmxValidator<CardResult>? validator;

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

  /// Validates a complete, Luhn-valid card with expiry and CVV.
  static CmxValidator<CardResult> validCard([
    String message = 'Enter valid card details',
  ]) {
    return (CardResult? value) =>
        (value != null && value.isValid) ? null : message;
  }

  @override
  State<CmxCardField> createState() => _CmxCardFieldState();
}

class _CmxCardFieldState extends State<CmxCardField>
    with TickerProviderStateMixin, CmxFieldStateMixin<CmxCardField> {
  final TextEditingController _numberController = TextEditingController();
  final TextEditingController _expiryController = TextEditingController();
  final TextEditingController _cvvController = TextEditingController();

  final FocusNode _expiryFocus = FocusNode();
  final FocusNode _cvvFocus = FocusNode();

  CardType _cardType = CardType.unknown;
  CardResult? _result;
  String? _errorText;

  @override
  void initState() {
    super.initState();
    // The mixin owns the number field's focus node.
    initCmxField(enabled: widget.enabled);
    _expiryFocus.addListener(_handleSubFocusChange);
    _cvvFocus.addListener(_handleSubFocusChange);
    _result = _computeResult();
  }

  void _handleSubFocusChange() {
    if (mounted) setState(() {});
  }

  @override
  void didUpdateWidget(CmxCardField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.enabled != oldWidget.enabled) {
      setEnabled(widget.enabled);
    }
  }

  @override
  void dispose() {
    _numberController.dispose();
    _expiryController.dispose();
    _cvvController.dispose();
    _expiryFocus.removeListener(_handleSubFocusChange);
    _cvvFocus.removeListener(_handleSubFocusChange);
    _expiryFocus.dispose();
    _cvvFocus.dispose();
    disposeCmxField();
    super.dispose();
  }

  CardResult _computeResult() {
    final digits = CardFormatting.digitsOnly(_numberController.text);
    final type = CardTypeDetector.detect(digits);
    final formatted = CardFormatting.groupNumber(digits, type);
    final expiry = _expiryController.text;
    final cvv = CardFormatting.digitsOnly(_cvvController.text);

    final numberValid = digits.length == CardTypeDetector.maxLength(type) &&
        type != CardType.unknown &&
        CardFormatting.isLuhnValid(digits);
    final expiryValid = isExpiryValid(expiry);
    final cvvValid = cvv.length == CardTypeDetector.cvvLength(type);

    return CardResult(
      number: digits,
      formattedNumber: formatted,
      expiry: expiry,
      cvv: cvv,
      cardType: type,
      isValid: numberValid && expiryValid && cvvValid,
    );
  }

  void _onChanged(FormFieldState<CardResult> field) {
    final result = _computeResult();
    setState(() {
      // Re-cap CVV if the brand changed and the entered value is now too long.
      final maxCvv = CardTypeDetector.cvvLength(result.cardType);
      if (result.cvv.length > maxCvv) {
        _cvvController.text = result.cvv.substring(0, maxCvv);
        _cvvController.selection = TextSelection.collapsed(offset: maxCvv);
      }
      _cardType = result.cardType;
      _result = result;
      if (_errorText != null) {
        _errorText = null;
        resetStatus();
      }
    });
    field.didChange(result);
    widget.onChanged?.call(result);
  }

  String? _runValidator(CardResult? value) {
    if (widget.validator == null) return null;
    return widget.validator!(value);
  }

  void _syncFieldError(FormFieldState<CardResult> field) {
    final error = field.errorText;
    if (error == _errorText) return;
    setState(() => _errorText = error);
    if (error != null) {
      triggerShake();
    } else {
      resetStatus();
    }
  }

  Widget _buildBrandSuffix() {
    if (!widget.showCardTypeIcon) return const SizedBox.shrink();
    final reduce = MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    return Padding(
      padding: const EdgeInsetsDirectional.only(end: 12),
      child: AnimatedSwitcher(
        duration: reduce ? Duration.zero : const Duration(milliseconds: 240),
        transitionBuilder: (child, animation) => ScaleTransition(
          scale: animation,
          child: FadeTransition(opacity: animation, child: child),
        ),
        child: _cardType == CardType.unknown
            ? const SizedBox.shrink(key: ValueKey<CardType>(CardType.unknown))
            : brandIcon(_cardType),
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

    final cvvLength = CardTypeDetector.cvvLength(_cardType);

    return FormField<CardResult>(
      initialValue: _result,
      enabled: widget.enabled,
      autovalidateMode: widget.autovalidateMode,
      validator: _runValidator,
      builder: (FormFieldState<CardResult> field) {
        if (field.errorText != _errorText) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) _syncFieldError(field);
          });
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            CmxFieldScaffold(
              theme: theme,
              status: status,
              isEmpty: _numberController.text.isEmpty,
              enabled: widget.enabled,
              label: widget.label,
              hint: '1234 5678 9012 3456',
              errorText: _errorText,
              showCheckmark: false,
              suffix: _buildBrandSuffix(),
              shakeAnimation: shakeAnimation,
              child: TextField(
                controller: _numberController,
                focusNode: focusNode,
                enabled: widget.enabled,
                decoration: null,
                keyboardType: TextInputType.number,
                textInputAction: TextInputAction.next,
                style: theme.inputStyle,
                autofillHints: const [AutofillHints.creditCardNumber],
                inputFormatters: [_CardNumberFormatter()],
                onChanged: (_) => _onChanged(field),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: CmxFieldScaffold(
                    theme: theme,
                    status: status.isError
                        ? CmxFieldStatus.idle
                        : (_expiryFocus.hasFocus
                            ? CmxFieldStatus.focused
                            : CmxFieldStatus.idle),
                    isEmpty: _expiryController.text.isEmpty,
                    enabled: widget.enabled,
                    label: 'MM/YY',
                    hint: 'MM/YY',
                    showCheckmark: false,
                    child: TextField(
                      controller: _expiryController,
                      focusNode: _expiryFocus,
                      enabled: widget.enabled,
                      decoration: null,
                      keyboardType: TextInputType.number,
                      textInputAction: TextInputAction.next,
                      style: theme.inputStyle,
                      autofillHints: const [
                        AutofillHints.creditCardExpirationDate,
                      ],
                      inputFormatters: [_ExpiryFormatter()],
                      onChanged: (_) => _onChanged(field),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: CmxFieldScaffold(
                    theme: theme,
                    status: status.isError
                        ? CmxFieldStatus.idle
                        : (_cvvFocus.hasFocus
                            ? CmxFieldStatus.focused
                            : CmxFieldStatus.idle),
                    isEmpty: _cvvController.text.isEmpty,
                    enabled: widget.enabled,
                    label: 'CVV',
                    hint: '0' * cvvLength,
                    showCheckmark: false,
                    child: TextField(
                      controller: _cvvController,
                      focusNode: _cvvFocus,
                      enabled: widget.enabled,
                      decoration: null,
                      obscureText: true,
                      keyboardType: TextInputType.number,
                      textInputAction: TextInputAction.done,
                      style: theme.inputStyle,
                      autofillHints: const [
                        AutofillHints.creditCardSecurityCode,
                      ],
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                        LengthLimitingTextInputFormatter(cvvLength),
                      ],
                      onChanged: (_) => _onChanged(field),
                    ),
                  ),
                ),
              ],
            ),
          ],
        );
      },
    );
  }
}
