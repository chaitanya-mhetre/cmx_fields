/// The flagship phone input field for `cmx_fields`.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:phone_numbers_parser/phone_numbers_parser.dart';

import '../../core/cmx_animations.dart';
import '../../core/cmx_field_scaffold.dart';
import '../../core/cmx_field_theme.dart';
import '../../core/cmx_field_mixin.dart';
import 'contacts_suggestions.dart';
import 'country_data.dart';
import 'country_picker_config.dart';
import 'country_picker_sheet.dart';
import '../../core/cmx_fill_progress.dart';
import 'phone_formatter.dart';
import 'phone_number_hint_service.dart';
import 'phone_validation.dart';

/// The parsed result of a phone field, emitted on change/submit and passed to
/// the validator.
@immutable
class PhoneResult {
  /// Creates a phone result.
  const PhoneResult({
    required this.nationalNumber,
    required this.dialCode,
    required this.fullNumber,
    required this.country,
    required this.isValid,
  });

  /// The national significant digits the user entered (no separators).
  final String nationalNumber;

  /// The selected country's dial code, without the leading `+` (e.g. `91`).
  final String dialCode;

  /// The full E.164-style number including the `+` and dial code
  /// (e.g. `+919876543210`).
  final String fullNumber;

  /// The country currently selected for this number.
  final Country country;

  /// Whether the number parses and validates for [country].
  final bool isValid;

  /// Expected national digit count for [country] (from mask or [Country.maxLength]).
  int get expectedLength => country.maskDigitCount > 0
      ? country.maskDigitCount
      : country.maxLength;

  @override
  bool operator ==(Object other) =>
      other is PhoneResult &&
      other.nationalNumber == nationalNumber &&
      other.dialCode == dialCode &&
      other.fullNumber == fullNumber &&
      other.country == country &&
      other.isValid == isValid;

  @override
  int get hashCode =>
      Object.hash(nationalNumber, dialCode, fullNumber, country, isValid);

  @override
  String toString() =>
      'PhoneResult(fullNumber: $fullNumber, isValid: $isValid)';
}

/// A polished, animated international phone input.
///
/// Features:
/// * A tappable flag + dial-code prefix that opens a searchable country picker.
/// * A small flag scale-bounce when the country changes (reduced-motion safe).
/// * Live as-you-type formatting via [PhoneFormatter].
/// * Validation through `phone_numbers_parser`, surfaced via [onChanged],
///   [onSubmitted] and [validator].
/// * Optional contact suggestions overlay once at least three digits are typed.
/// * Optional auto-detection of the initial country from the ambient locale.
///
/// Works standalone and inside a [Form]; it builds an internal [FormField] so
/// `Form.validate()` triggers [validator], shows the error and shakes.
class CmxPhoneField extends StatefulWidget {
  /// Creates a phone field.
  const CmxPhoneField({
    super.key,
    this.label,
    this.hint,
    this.initialCountry,
    this.initialValue,
    this.countryPicker = CountryPickerConfig.defaults,
    this.showContactSuggestions = true,
    this.autoDetectCountry = true,
    this.enablePhoneNumberHint = true,
    this.autoRequestHint = true,
    this.hintRequestDelay = const Duration(milliseconds: 500),
    this.showHintButton = true,
    this.showFillProgress = true,
    this.enabled = true,
    this.controller,
    this.focusNode,
    this.onChanged,
    this.onSubmitted,
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

  /// Floating label text.
  final String? label;

  /// Placeholder shown when empty and focused.
  final String? hint;

  /// The country selected initially. Wins over [autoDetectCountry].
  final Country? initialCountry;

  /// The initial national number (digits; separators are ignored).
  final String? initialValue;

  /// Country picker layout: popular countries (order preserved), allow/exclude
  /// lists, and section title. See [CountryPickerConfig].
  final CountryPickerConfig countryPicker;

  /// Whether to show the device-contacts suggestion overlay.
  final bool showContactSuggestions;

  /// Whether to auto-detect the initial country from the ambient locale when
  /// no [initialCountry] is provided.
  final bool autoDetectCountry;

  /// Whether to enable Google's Phone Number Hint (Android only) — both the
  /// auto-request on open and the manual suffix button. No effect on other
  /// platforms.
  final bool enablePhoneNumberHint;

  /// Whether to automatically show the device number-hint picker shortly after
  /// the field appears (Android only, when the field is empty).
  final bool autoRequestHint;

  /// Delay before the automatic hint request fires, letting the UI settle.
  final Duration hintRequestDelay;

  /// Whether to show the manual "use a device number" button in the suffix
  /// while the field is empty (Android only).
  final bool showHintButton;

  /// Whether to show the green fill-progress ring (and success checkmark) in
  /// the suffix as the number is typed.
  final bool showFillProgress;

  /// Whether the field is interactive.
  final bool enabled;

  /// Optional external controller for the editable text.
  final TextEditingController? controller;

  /// Optional external focus node.
  final FocusNode? focusNode;

  /// Called whenever the value or country changes.
  final ValueChanged<PhoneResult>? onChanged;

  /// Called when the user submits from the keyboard.
  final ValueChanged<PhoneResult>? onSubmitted;

  /// Validates the current [PhoneResult]; return an error string or `null`.
  final String? Function(PhoneResult? value)? validator;

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

  /// Ready-made validator with country-specific messages.
  ///
  /// See [CmxPhoneFieldValidation.validNumber].
  static String? Function(PhoneResult?) validNumber({
    bool allowEmpty = false,
    String? emptyMessage,
    String? invalidMessage,
  }) =>
      CmxPhoneFieldValidation.validNumber(
        allowEmpty: allowEmpty,
        emptyMessage: emptyMessage,
        invalidMessage: invalidMessage,
      );

  @override
  State<CmxPhoneField> createState() => _CmxPhoneFieldState();
}

class _CmxPhoneFieldState extends State<CmxPhoneField>
    with TickerProviderStateMixin, CmxFieldStateMixin<CmxPhoneField> {
  late TextEditingController _controller;
  bool _ownsController = false;

  final LayerLink _layerLink = LayerLink();
  final ContactsSuggestionService _contactsService =
      const ContactsSuggestionService();
  OverlayEntry? _overlayEntry;
  List<ContactSuggestion> _suggestions = const <ContactSuggestion>[];

  late AnimationController _flagBounceController;
  bool _localeResolved = false;

  final PhoneNumberHintService _hintService = PhoneNumberHintService();
  Timer? _hintTimer;

  Country _country = Country.fallback;
  PhoneResult? _result;
  String? _errorText;

  /// Expected national digit count for the current country.
  int get _expectedDigits => _country.maskDigitCount > 0
      ? _country.maskDigitCount
      : _country.maxLength;

  @override
  void initState() {
    super.initState();
    initCmxField(focusNode: widget.focusNode, enabled: widget.enabled);

    _controller = widget.controller ?? TextEditingController();
    _ownsController = widget.controller == null;

    _flagBounceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 280),
    );

    if (widget.initialCountry != null) {
      _country = widget.initialCountry!;
    }

    if (widget.initialValue != null && widget.initialValue!.isNotEmpty) {
      final digits = PhoneFormatter.digitsOnly(widget.initialValue!);
      _controller.text = PhoneFormatter.format(digits, _country.mask);
    }

    focusNode.addListener(_handleFocusToggleOverlay);
    _recompute(emit: false);

    if (widget.enabled &&
        widget.enablePhoneNumberHint &&
        widget.autoRequestHint &&
        _hintService.isSupported) {
      _hintTimer = Timer(widget.hintRequestDelay, () {
        if (mounted && _controller.text.isEmpty) _requestHint();
      });
    }
  }

  @override
  void didUpdateWidget(CmxPhoneField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.enabled != oldWidget.enabled) {
      setEnabled(widget.enabled);
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_localeResolved) {
      _localeResolved = true;
      if (widget.initialCountry == null && widget.autoDetectCountry) {
        final locale = Localizations.maybeLocaleOf(context);
        final code = locale?.countryCode;
        if (code != null) {
          final detected = Country.fromIso(code);
          if (detected != null) {
            _country = detected;
            if (_controller.text.isNotEmpty) {
              final digits = PhoneFormatter.digitsOnly(_controller.text);
              _controller.text = PhoneFormatter.format(digits, _country.mask);
            }
            _recompute(emit: false);
          }
        }
      }
    }
  }

  @override
  void dispose() {
    _hintTimer?.cancel();
    _removeOverlay();
    focusNode.removeListener(_handleFocusToggleOverlay);
    _flagBounceController.dispose();
    if (_ownsController) _controller.dispose();
    disposeCmxField();
    super.dispose();
  }

  // --- Result computation ----------------------------------------------------

  PhoneResult _computeResult() {
    final digits = PhoneFormatter.digitsOnly(_controller.text);
    var valid = false;
    var full = '+${_country.dialCode}$digits';
    if (digits.isNotEmpty) {
      try {
        final iso = IsoCode.values.byName(_country.isoCode);
        final parsed = PhoneNumber.parse(digits, callerCountry: iso);
        valid = parsed.isValid();
        full = parsed.international;
      } catch (_) {
        valid = false;
      }
    }
    return PhoneResult(
      nationalNumber: digits,
      dialCode: _country.dialCode,
      fullNumber: full,
      country: _country,
      isValid: valid,
    );
  }

  void _recompute({required bool emit}) {
    _result = _computeResult();
    if (emit) widget.onChanged?.call(_result!);
  }

  // --- Text / country changes -------------------------------------------------

  void _onTextChanged() {
    setState(_syncOnText);
  }

  void _syncOnText() {
    _recompute(emit: true);
    if (_errorText != null) {
      _errorText = null;
      resetStatus();
    }
    _updateContactSuggestions();
  }

  Future<void> _openCountryPicker() async {
    if (!widget.enabled) return;
    final picked = await showCountryPickerSheet(
      context,
      selected: _country,
      config: widget.countryPicker,
    );
    if (picked == null || !mounted) return;
    if (picked == _country) return;
    setState(() {
      _country = picked;
      // Re-format existing digits under the new mask.
      final digits = PhoneFormatter.digitsOnly(_controller.text);
      _controller.text = PhoneFormatter.format(digits, _country.mask);
      _recompute(emit: true);
    });
    if (!CmxAnimations.reduceMotion(context)) {
      _flagBounceController
        ..reset()
        ..forward();
    }
  }

  void _handleSubmitted(String _) {
    _recompute(emit: false);
    if (_result != null) widget.onSubmitted?.call(_result!);
  }

  // --- Phone Number Hint ------------------------------------------------------

  /// Shows Google's device number-hint picker and fills the field with the
  /// chosen national number. No-op on unsupported platforms / on dismissal.
  Future<void> _requestHint() async {
    if (!widget.enabled || !widget.enablePhoneNumberHint) return;
    final number = await _hintService.requestHint(
      dialCode: _country.dialCode,
      nationalLength: _expectedDigits,
    );
    if (number == null || number.isEmpty || !mounted) return;
    setState(() {
      _controller.text = PhoneFormatter.format(number, _country.mask);
      _recompute(emit: true);
      if (_errorText != null) {
        _errorText = null;
        resetStatus();
      }
    });
  }

  // --- Suffix (hint button / fill progress) -----------------------------------

  Widget? _buildSuffix(CmxFieldTheme theme) {
    final digits = PhoneFormatter.digitsOnly(_controller.text);
    final isValid = _result?.isValid ?? false;

    if (digits.isEmpty) {
      final canHint = widget.enabled &&
          widget.enablePhoneNumberHint &&
          widget.showHintButton &&
          _hintService.isSupported;
      if (canHint) {
        return Padding(
          padding: const EdgeInsetsDirectional.only(end: 12),
          child: IconButton(
            icon: Icon(Icons.contact_phone_outlined, color: theme.focusedColor),
            iconSize: 20,
            visualDensity: VisualDensity.compact,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
            tooltip: 'Use a number from this device',
            onPressed: _requestHint,
          ),
        );
      }
      return null;
    }

    if (!widget.showFillProgress) {
      if (!isValid) return null;
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

    final expected = _expectedDigits;
    final progress = expected > 0 ? digits.length / expected : 0.0;
    return CmxFillProgress(
      progress: progress,
      valid: isValid,
      color: theme.successColor,
    );
  }

  // --- Contact suggestions overlay -------------------------------------------

  Future<void> _updateContactSuggestions() async {
    if (!widget.showContactSuggestions || !isFocused) {
      _removeOverlay();
      return;
    }
    final digits = PhoneFormatter.digitsOnly(_controller.text);
    if (digits.length < ContactsSuggestionService.minDigits) {
      _removeOverlay();
      return;
    }
    final matches = await _contactsService.query(digits);
    if (!mounted) return;
    final stillRelevant = isFocused &&
        PhoneFormatter.digitsOnly(_controller.text).length >=
            ContactsSuggestionService.minDigits;
    if (matches.isEmpty || !stillRelevant) {
      _removeOverlay();
      return;
    }
    _suggestions = matches;
    _showOverlay();
  }

  void _handleFocusToggleOverlay() {
    if (!isFocused) {
      _removeOverlay();
    } else {
      _updateContactSuggestions();
    }
  }

  void _showOverlay() {
    _removeOverlay();
    final overlay = Overlay.maybeOf(context);
    if (overlay == null) return;
    _overlayEntry = OverlayEntry(builder: _buildOverlay);
    overlay.insert(_overlayEntry!);
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
                final s = _suggestions[index];
                return ListTile(
                  dense: true,
                  title: Text(s.name.isEmpty ? s.number : s.name),
                  subtitle: s.name.isEmpty ? null : Text(s.number),
                  onTap: () => _applySuggestion(s),
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  void _applySuggestion(ContactSuggestion suggestion) {
    final digits = PhoneFormatter.digitsOnly(suggestion.number);
    // Drop a leading country dial code if present so we keep national digits.
    var national = digits;
    if (national.startsWith(_country.dialCode) &&
        national.length > _country.maskDigitCount) {
      national = national.substring(_country.dialCode.length);
    }
    if (_country.maskDigitCount > 0 &&
        national.length > _country.maskDigitCount) {
      national = national.substring(national.length - _country.maskDigitCount);
    }
    setState(() {
      _controller.text = PhoneFormatter.format(national, _country.mask);
      _recompute(emit: true);
    });
    _removeOverlay();
  }

  // --- Prefix -----------------------------------------------------------------

  Widget _buildFlagPrefix(CmxFieldTheme theme) {
    // A 1.0 -> 1.18 -> 1.0 scale bounce driven by the bounce controller (0..1).
    final flagScale = _flagBounceController.drive(
      TweenSequence<double>(<TweenSequenceItem<double>>[
        TweenSequenceItem(
          tween: Tween(begin: 1.0, end: 1.18)
              .chain(CurveTween(curve: Curves.easeOut)),
          weight: 1,
        ),
        TweenSequenceItem(
          tween: Tween(begin: 1.18, end: 1.0)
              .chain(CurveTween(curve: Curves.easeIn)),
          weight: 1,
        ),
      ]),
    );
    return InkWell(
      onTap: widget.enabled ? _openCountryPicker : null,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsetsDirectional.fromSTEB(12, 0, 8, 0),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            ScaleTransition(
              scale: flagScale,
              child: Text(
                _country.flag,
                style: const TextStyle(fontSize: 22),
              ),
            ),
            const SizedBox(width: 6),
            Text(
              '+${_country.dialCode}',
              style: (theme.inputStyle ?? const TextStyle())
                  .copyWith(fontWeight: FontWeight.w600),
            ),
            const Icon(Icons.arrow_drop_down, size: 20),
          ],
        ),
      ),
    );
  }

  // --- FormField glue ---------------------------------------------------------

  String? _runValidator(PhoneResult? value) {
    if (widget.validator == null) return null;
    return widget.validator!(value);
  }

  void _handleFieldStateChanged(FormFieldState<PhoneResult> field) {
    final error = field.errorText;
    if (error == _errorText) return;
    setState(() => _errorText = error);
    if (error != null) {
      triggerShake();
    } else {
      resetStatus();
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

    return FormField<PhoneResult>(
      initialValue: _result,
      enabled: widget.enabled,
      autovalidateMode: widget.autovalidateMode,
      validator: _runValidator,
      builder: (FormFieldState<PhoneResult> field) {
        // Mirror the FormField's error into our scaffold/shake after the frame
        // (e.g. when Form.validate() runs externally).
        if (field.errorText != _errorText) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) _handleFieldStateChanged(field);
          });
        }

        return AnimatedBuilder(
          animation: _flagBounceController,
          builder: (context, _) {
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
                prefix: _buildFlagPrefix(theme),
                suffix: _buildSuffix(theme),
                suffixIconConstraints: const BoxConstraints(
                  minWidth: 48,
                  minHeight: 36,
                  maxWidth: 48,
                  maxHeight: 36,
                ),
                showCheckmark: false,
                shakeAnimation: shakeAnimation,
                child: TextField(
                  controller: _controller,
                  focusNode: focusNode,
                  enabled: widget.enabled,
                  decoration: null,
                  keyboardType: TextInputType.phone,
                  textInputAction: TextInputAction.done,
                  style: theme.inputStyle,
                  inputFormatters: [PhoneFormatter(_country)],
                  onChanged: (_) {
                    _onTextChanged();
                    field.didChange(_result);
                  },
                  onSubmitted: _handleSubmitted,
                ),
              ),
            );
          },
        );
      },
    );
  }
}
