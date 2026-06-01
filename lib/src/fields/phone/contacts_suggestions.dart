/// Device-contacts suggestion lookup for the phone field.
///
/// Everything here is guarded: on unsupported platforms (web/desktop) or any
/// plugin/permission failure it degrades to an empty result and never throws.
library;

import 'package:fast_contacts/fast_contacts.dart';
import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';

import 'phone_formatter.dart';

/// A single contact match surfaced as a suggestion under the phone field.
@immutable
class ContactSuggestion {
  /// Creates a contact suggestion.
  const ContactSuggestion({required this.name, required this.number});

  /// The contact's display name (may be empty if the device has none).
  final String name;

  /// The contact's phone number, in whatever form the device stored it.
  final String number;

  @override
  bool operator ==(Object other) =>
      other is ContactSuggestion &&
      other.name == name &&
      other.number == number;

  @override
  int get hashCode => Object.hash(name, number);

  @override
  String toString() => 'ContactSuggestion($name, $number)';
}

/// Reads device contacts (via `fast_contacts`) and filters them by typed
/// digits. Safe to use on any platform — unsupported platforms simply yield
/// no suggestions.
class ContactsSuggestionService {
  /// Creates a contacts suggestion service.
  const ContactsSuggestionService();

  /// The minimum number of typed digits before a query is attempted.
  static const int minDigits = 3;

  /// Cached contacts permission result (null = not checked yet).
  static bool? _permissionGranted;

  /// Whether contact lookup is supported on the current platform.
  ///
  /// Only Android and iOS expose contacts via the plugin; everywhere else
  /// this resolves to `false`.
  Future<bool> get isSupported async {
    if (kIsWeb) return false;
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
      case TargetPlatform.iOS:
        return true;
      case TargetPlatform.fuchsia:
      case TargetPlatform.linux:
      case TargetPlatform.macOS:
      case TargetPlatform.windows:
        return false;
    }
  }

  /// Requests runtime contacts permission when needed.
  ///
  /// Returns `false` when denied or permanently denied. Never throws.
  /// [fast_contacts] can crash the Android process if contacts are read without
  /// permission, so callers must check this before invoking the plugin.
  Future<bool> ensurePermission() async {
    if (!await isSupported) {
      _permissionGranted = false;
      return false;
    }
    if (_permissionGranted == true) return true;
    if (_permissionGranted == false) return false;

    try {
      var status = await Permission.contacts.status;
      if (status.isGranted) {
        _permissionGranted = true;
        return true;
      }
      if (status.isDenied) {
        status = await Permission.contacts.request();
      }
      _permissionGranted = status.isGranted;
      return status.isGranted;
    } catch (_) {
      _permissionGranted = false;
      return false;
    }
  }

  /// Clears the cached permission flag (for tests).
  @visibleForTesting
  static void resetPermissionCacheForTesting() {
    _permissionGranted = null;
  }

  /// Returns contacts whose normalized number contains the typed [digits].
  ///
  /// Returns an empty list when fewer than [minDigits] digits are supplied,
  /// when the platform is unsupported, or when the plugin/permission is
  /// unavailable. Never throws.
  Future<List<ContactSuggestion>> query(String digits) async {
    final needle = PhoneFormatter.digitsOnly(digits);
    if (needle.length < minDigits) return const <ContactSuggestion>[];
    if (!await isSupported) return const <ContactSuggestion>[];
    if (!await ensurePermission()) return const <ContactSuggestion>[];

    List<Contact> contacts;
    try {
      contacts = await FastContacts.getAllContacts(
        fields: const <ContactField>[
          ContactField.displayName,
          ContactField.phoneNumbers,
        ],
      );
    } catch (_) {
      // MissingPluginException / PlatformException / etc.
      return const <ContactSuggestion>[];
    }

    final results = <ContactSuggestion>[];
    final seen = <String>{};
    for (final contact in contacts) {
      for (final phone in contact.phones) {
        final normalized = PhoneFormatter.digitsOnly(phone.number);
        if (normalized.isEmpty || !normalized.contains(needle)) continue;
        if (!seen.add(normalized)) continue;
        results.add(
          ContactSuggestion(
            name: contact.displayName,
            number: phone.number,
          ),
        );
        if (results.length >= 8) return results;
      }
    }
    return results;
  }
}
