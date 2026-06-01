/// A validator that returns `null` when [value] is acceptable, or an error
/// message when it is not — matching Flutter's `FormFieldValidator` contract.
typedef CmxValidator<T> = String? Function(T? value);

/// A library of composable, pure validators usable on any field.
///
/// All validators return `null` for valid input and a message otherwise, so
/// they drop straight into `TextFormField.validator` and the `cmx_fields`
/// widgets.
///
/// ```dart
/// validator: CmxValidators.compose([
///   CmxValidators.required(),
///   CmxValidators.email(),
/// ]),
/// ```
class CmxValidators {
  const CmxValidators._();

  static final RegExp _emailRegExp = RegExp(
    r"^[a-zA-Z0-9.!#$%&'*+/=?^_`{|}~-]+@[a-zA-Z0-9](?:[a-zA-Z0-9-]{0,61}"
    r'[a-zA-Z0-9])?(?:\.[a-zA-Z0-9](?:[a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?)+$',
  );

  /// Fails when the value is null, empty, or whitespace-only.
  static CmxValidator<String> required([String message = 'Required']) {
    return (value) => (value == null || value.trim().isEmpty) ? message : null;
  }

  /// Fails when a non-empty value is not a syntactically valid email.
  ///
  /// Empty values pass — combine with [required] to forbid them.
  static CmxValidator<String> email([
    String message = 'Enter a valid email',
  ]) {
    return (value) {
      if (value == null || value.isEmpty) return null;
      return _emailRegExp.hasMatch(value.trim()) ? null : message;
    };
  }

  /// Fails when a non-empty value is shorter than [length] characters.
  static CmxValidator<String> minLength(int length, [String? message]) {
    return (value) {
      if (value == null || value.isEmpty) return null;
      return value.length < length
          ? (message ?? 'Must be at least $length characters')
          : null;
    };
  }

  /// Fails when the value is longer than [length] characters.
  static CmxValidator<String> maxLength(int length, [String? message]) {
    return (value) {
      if (value == null) return null;
      return value.length > length
          ? (message ?? 'Must be at most $length characters')
          : null;
    };
  }

  /// Fails when a non-empty value does not match [pattern].
  static CmxValidator<String> pattern(
    RegExp pattern, [
    String message = 'Invalid format',
  ]) {
    return (value) {
      if (value == null || value.isEmpty) return null;
      return pattern.hasMatch(value) ? null : message;
    };
  }

  /// Fails when the value does not equal [other] (e.g. confirm-password).
  static CmxValidator<String> match(
    String Function() other, [
    String message = 'Does not match',
  ]) {
    return (value) => value == other() ? null : message;
  }

  /// Runs [validators] in order and returns the first error, or `null`.
  static CmxValidator<T> compose<T>(List<CmxValidator<T>> validators) {
    return (value) {
      for (final validator in validators) {
        final result = validator(value);
        if (result != null) return result;
      }
      return null;
    };
  }
}
