import 'package:flutter/foundation.dart';

import 'country_data.dart';

/// Controls which countries appear in the picker and how they are ordered.
///
/// Pass to [CmxPhoneField.countryPicker] to pin your own countries at the top
/// (in the order you list them) and optionally restrict the full list.
///
/// ```dart
/// CmxPhoneField(
///   countryPicker: CountryPickerConfig(
///     popularCountryCodes: ['IN', 'US', 'AE', 'GB', 'SG'],
///     popularSectionTitle: 'Frequent',
///   ),
/// )
/// ```
@immutable
class CountryPickerConfig {
  /// Creates country-picker settings.
  const CountryPickerConfig({
    this.popularCountryCodes,
    this.allowedCountryCodes,
    this.excludedCountryCodes,
    this.showPopularSection = true,
    this.popularSectionTitle = 'Popular',
  });

  /// ISO 3166-1 alpha-2 codes shown first, **in this order**.
  ///
  /// When `null`, uses [kPopularCountryCodes]. Unknown codes are skipped.
  final List<String>? popularCountryCodes;

  /// When set, only these ISO codes are selectable (still sorted A–Z below
  /// the popular section, minus duplicates).
  final List<String>? allowedCountryCodes;

  /// ISO codes removed from both popular and the full list.
  final List<String>? excludedCountryCodes;

  /// Whether to show the pinned section when [resolvePopular] is non-empty.
  final bool showPopularSection;

  /// Heading above the pinned countries (e.g. `'Popular'`, `'Frequent'`).
  final String popularSectionTitle;

  /// Package defaults (popular list from [kPopularCountryCodes]).
  static const CountryPickerConfig defaults = CountryPickerConfig();

  static Set<String> _normalizeCodes(Iterable<String>? codes) {
    if (codes == null) return <String>{};
    return codes.map((c) => c.trim().toUpperCase()).where((c) => c.isNotEmpty).toSet();
  }

  /// Countries available after [allowedCountryCodes] / [excludedCountryCodes].
  List<Country> _basePool() {
    final allowed = _normalizeCodes(allowedCountryCodes);
    final excluded = _normalizeCodes(excludedCountryCodes);
    return kAllCountries.where((c) {
      if (excluded.contains(c.isoCode)) return false;
      if (allowed.isNotEmpty && !allowed.contains(c.isoCode)) return false;
      return true;
    }).toList(growable: false);
  }

  /// Pinned countries in [popularCountryCodes] order (or package default).
  List<Country> resolvePopular() {
    if (!showPopularSection) return const <Country>[];
    final pool = {for (final c in _basePool()) c.isoCode: c};
    final codes = popularCountryCodes ?? kPopularCountryCodes;
    final popular = <Country>[];
    final seen = <String>{};
    for (final raw in codes) {
      final iso = raw.trim().toUpperCase();
      if (iso.isEmpty || !seen.add(iso)) continue;
      final country = pool[iso];
      if (country != null) popular.add(country);
    }
    return popular;
  }

  /// Remaining countries, alphabetical, excluding [resolvePopular] entries.
  List<Country> resolveAll() {
    final popularIsos = resolvePopular().map((c) => c.isoCode).toSet();
    final rest = _basePool().where((c) => !popularIsos.contains(c.isoCode)).toList()
      ..sort((a, b) => a.name.compareTo(b.name));
    return rest;
  }
}
