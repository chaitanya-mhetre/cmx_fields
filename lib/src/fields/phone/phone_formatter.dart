/// An as-you-type [TextInputFormatter] that groups phone digits per a
/// country-specific mask.
library;

import 'package:flutter/services.dart';

import 'country_data.dart';

/// Formats phone input as the user types according to [country]'s mask.
///
/// All non-digit characters are stripped from the raw input, the digits are
/// capped at the mask's digit capacity, and the mask's literal separators
/// (spaces, dashes, parentheses) are re-applied. The cursor is placed at the
/// end of the formatted text, which is stable and predictable for phone entry.
///
/// The formatter is pure (no widget/state dependencies) so it is fully
/// unit-testable via [format].
class PhoneFormatter extends TextInputFormatter {
  /// Creates a formatter that applies [country]'s mask.
  const PhoneFormatter(this.country);

  /// The country whose [Country.mask] drives the grouping.
  final Country country;

  /// Returns only the ASCII digit characters contained in [input].
  static String digitsOnly(String input) {
    final buffer = StringBuffer();
    for (final unit in input.codeUnits) {
      if (unit >= 0x30 && unit <= 0x39) buffer.writeCharCode(unit);
    }
    return buffer.toString();
  }

  /// Applies [mask] to the digits in [input] and returns the formatted string.
  ///
  /// `#` characters in [mask] are filled with successive digits; any other
  /// character is emitted verbatim as a separator. Excess digits beyond the
  /// mask's capacity are appended (space-separated) so over-typing is visible
  /// rather than silently dropped, while the formatter's [formatEditUpdate]
  /// still caps at the mask capacity.
  static String format(String input, String mask) {
    final digits = digitsOnly(input);
    if (digits.isEmpty) return '';
    if (mask.isEmpty) return digits;

    final out = StringBuffer();
    var di = 0;
    for (var i = 0; i < mask.length && di < digits.length; i++) {
      final ch = mask[i];
      if (ch == '#') {
        out.write(digits[di]);
        di++;
      } else {
        out.write(ch);
      }
    }
    // Trim a trailing separator that was emitted with no following digit.
    var result = out.toString();
    while (
        result.isNotEmpty && !_isDigit(result.codeUnitAt(result.length - 1))) {
      result = result.substring(0, result.length - 1);
    }
    return result;
  }

  static bool _isDigit(int codeUnit) => codeUnit >= 0x30 && codeUnit <= 0x39;

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final capacity = country.maskDigitCount;
    var digits = digitsOnly(newValue.text);
    if (capacity > 0 && digits.length > capacity) {
      digits = digits.substring(0, capacity);
    }
    final formatted = format(digits, country.mask);
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}
