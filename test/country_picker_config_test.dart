import 'package:cmx_fields/cmx_fields.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('CountryPickerConfig', () {
    test('default popular matches kPopularCountryCodes order', () {
      const config = CountryPickerConfig.defaults;
      final popular = config.resolvePopular();
      expect(popular.map((c) => c.isoCode).toList(), kPopularCountryCodes);
    });

    test('popularCountryCodes preserves custom order', () {
      const config = CountryPickerConfig(
        popularCountryCodes: ['SG', 'IN', 'US'],
      );
      final popular = config.resolvePopular();
      expect(popular.map((c) => c.isoCode).toList(), ['SG', 'IN', 'US']);
    });

    test('popular excludes duplicates in full list', () {
      const config = CountryPickerConfig(
        popularCountryCodes: ['IN', 'US'],
      );
      final popular = config.resolvePopular().map((c) => c.isoCode).toSet();
      final all = config.resolveAll().map((c) => c.isoCode);
      expect(all.where(popular.contains), isEmpty);
    });

    test('allowedCountryCodes restricts pool', () {
      const config = CountryPickerConfig(
        allowedCountryCodes: ['IN', 'US', 'GB'],
        popularCountryCodes: ['US', 'IN'],
      );
      final popular = config.resolvePopular();
      final all = config.resolveAll();
      expect(popular.map((c) => c.isoCode).toList(), ['US', 'IN']);
      expect(all.map((c) => c.isoCode).toList(), ['GB']);
      expect(config.resolvePopular().length + all.length, 3);
    });

    test('excludedCountryCodes removes countries', () {
      const config = CountryPickerConfig(
        excludedCountryCodes: ['US'],
        popularCountryCodes: ['IN'],
      );
      final codes = [
        ...config.resolvePopular(),
        ...config.resolveAll(),
      ].map((c) => c.isoCode);
      expect(codes, isNot(contains('US')));
      expect(codes, contains('IN'));
    });

    test('showPopularSection false hides pinned list', () {
      const config = CountryPickerConfig(
        showPopularSection: false,
        popularCountryCodes: ['IN'],
      );
      expect(config.resolvePopular(), isEmpty);
      expect(config.resolveAll().map((c) => c.isoCode), contains('IN'));
    });
  });
}
