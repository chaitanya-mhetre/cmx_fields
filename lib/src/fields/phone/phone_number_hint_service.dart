import 'package:flutter/foundation.dart';
import 'package:phone_number_hint/phone_number_hint.dart';

/// Whether Google's Phone Number Hint picker is available on this platform.
///
/// It is an Android-only Google Play Services feature. Returns `false` on web,
/// iOS, and desktop — callers should fall back to manual entry there.
bool get isPhoneNumberHintSupported =>
    !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

/// Wraps the `phone_number_hint` plugin to suggest a phone number already on
/// the device (SIM / Google account) via the system picker.
///
/// This is **not** the keyboard's saved-autofill and **not** SMS OTP reading —
/// it shows Google's number-hint UI and the user explicitly picks a number, so
/// no app-specific phone-read permission is required.
///
/// All methods degrade gracefully: on unsupported platforms, when the user
/// dismisses the picker, or on any plugin error, [requestHint] returns `null`
/// instead of throwing.
class PhoneNumberHintService {
  /// Creates a service. Optionally inject a [plugin] for testing.
  PhoneNumberHintService({PhoneNumberHint? plugin})
      : _plugin = plugin ?? PhoneNumberHint();

  final PhoneNumberHint _plugin;

  /// Whether the hint picker can be shown on this platform.
  bool get isSupported => isPhoneNumberHintSupported;

  /// Shows the system number-hint picker and returns the chosen national number
  /// (digits only), or `null` if unsupported / dismissed / on error.
  ///
  /// [dialCode] is the country's dial code without `+` (e.g. `91`) and
  /// [nationalLength] is the expected national digit count (e.g. `10`); both are
  /// used to strip a leading country code and trim to the national portion.
  Future<String?> requestHint({
    String dialCode = '91',
    int nationalLength = 10,
  }) async {
    if (!isSupported) return null;
    try {
      final raw = await _plugin.requestHint();
      if (raw == null || raw.isEmpty) return null;
      return normalize(
        raw,
        dialCode: dialCode,
        nationalLength: nationalLength,
      );
    } catch (_) {
      // Picker dismissed, Play Services unavailable, etc. — fall back silently.
      return null;
    }
  }

  /// Pure normalization of a raw hint string into national digits.
  ///
  /// Strips spaces/dashes and a leading `+[dialCode]` or bare `[dialCode]`,
  /// removes any remaining non-digits, and trims to the last [nationalLength]
  /// digits when longer. Exposed as a static so it is unit-testable without the
  /// platform plugin.
  static String? normalize(
    String input, {
    required String dialCode,
    required int nationalLength,
  }) {
    var n = input.replaceAll(RegExp(r'[\s\-]'), '');
    final withPlus = '+$dialCode';
    if (n.startsWith(withPlus)) {
      n = n.substring(withPlus.length);
    } else if (n.startsWith(dialCode) &&
        n.length == nationalLength + dialCode.length) {
      n = n.substring(dialCode.length);
    }
    n = n.replaceAll(RegExp(r'\D'), '');
    if (nationalLength > 0 && n.length > nationalLength) {
      n = n.substring(n.length - nationalLength);
    }
    return n.isEmpty ? null : n;
  }
}
