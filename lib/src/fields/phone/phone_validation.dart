import 'cmx_phone_field.dart';

/// User-facing validation messages for [CmxPhoneField] / [PhoneResult].
class PhoneValidationMessages {
  const PhoneValidationMessages._();

  /// Shown when the field is empty on submit.
  static String empty({String? override}) =>
      override ?? 'Enter your mobile number';

  /// Country-aware message when digits are present but not valid.
  static String invalid(PhoneResult result, {String? override}) {
    if (override != null) return override;
    final country = result.country;
    final expected = result.expectedLength;
    final entered = result.nationalNumber.length;
    final label = '${country.name} (+${country.dialCode})';

    if (entered < expected) {
      final remaining = expected - entered;
      return 'Enter $expected digits for $label ($remaining more)';
    }
    if (entered > expected) {
      return 'Too many digits for $label (max $expected)';
    }
    return 'Enter a valid mobile number for $label';
  }
}

/// Validators for [CmxPhoneField].
extension CmxPhoneFieldValidation on CmxPhoneField {
  /// Ready-made [FormField] validator with country-specific error text.
  ///
  /// * Empty → [emptyMessage] or `'Enter your mobile number'`.
  /// * Invalid length → e.g. `'Enter 10 digits for India (+91) (3 more)'`.
  /// * Wrong format but right length → `'Enter a valid mobile number for …'`.
  static String? Function(PhoneResult?) validNumber({
    bool allowEmpty = false,
    String? emptyMessage,
    String? invalidMessage,
  }) {
    return (PhoneResult? value) {
      if (value == null || value.nationalNumber.isEmpty) {
        return allowEmpty
            ? null
            : PhoneValidationMessages.empty(override: emptyMessage);
      }
      if (value.isValid) return null;
      return PhoneValidationMessages.invalid(
        value,
        override: invalidMessage,
      );
    };
  }
}
