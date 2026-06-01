import 'package:cmx_fields/src/fields/phone/cmx_phone_field.dart';
import 'package:cmx_fields/src/fields/phone/country_data.dart';
import 'package:cmx_fields/src/fields/phone/phone_formatter.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('PhoneFormatter', () {
    test('formats Indian numbers as ##### #####', () {
      const india = Country('India', 'IN', '91', '🇮🇳', '##### #####', 10);
      expect(PhoneFormatter.format('9876543210', india.mask), '98765 43210');
      expect(PhoneFormatter.format('98765', india.mask), '98765');
      expect(PhoneFormatter.format('987654', india.mask), '98765 4');
    });

    test('formats US numbers as (###) ###-####', () {
      const us = Country.fallback;
      expect(PhoneFormatter.format('4155552671', us.mask), '(415) 555-2671');
      expect(PhoneFormatter.format('415', us.mask), '(415');
      expect(PhoneFormatter.format('4155', us.mask), '(415) 5');
    });

    test('strips non-digits and caps at mask capacity via edit update', () {
      const us = Country.fallback;
      const formatter = PhoneFormatter(us);
      final result = formatter.formatEditUpdate(
        TextEditingValue.empty,
        const TextEditingValue(text: 'abc4155552671999'),
      );
      expect(result.text, '(415) 555-2671');
      expect(result.selection.baseOffset, result.text.length);
    });

    test('digitsOnly keeps only ASCII digits', () {
      expect(PhoneFormatter.digitsOnly('+91 (98) 765-43210'), '919876543210');
      expect(PhoneFormatter.digitsOnly(''), '');
    });
  });

  group('country_data integrity', () {
    test('no duplicate ISO codes', () {
      final seen = <String>{};
      for (final c in kAllCountries) {
        expect(seen.add(c.isoCode), isTrue, reason: 'duplicate ${c.isoCode}');
      }
    });

    test('every entry has non-empty dialCode, flag, name and a valid mask', () {
      for (final c in kAllCountries) {
        expect(c.dialCode, isNotEmpty, reason: c.isoCode);
        expect(c.flag, isNotEmpty, reason: c.isoCode);
        expect(c.name, isNotEmpty, reason: c.isoCode);
        expect(c.isoCode.length, 2, reason: c.isoCode);
        expect(c.maskDigitCount, greaterThan(0), reason: c.isoCode);
        expect(c.maxLength, greaterThan(0), reason: c.isoCode);
      }
    });

    test('all popular country codes resolve via fromIso', () {
      for (final iso in kPopularCountryCodes) {
        expect(Country.fromIso(iso), isNotNull, reason: iso);
      }
    });

    test('fromIso is case-insensitive and fromDial works', () {
      expect(Country.fromIso('in')?.isoCode, 'IN');
      expect(Country.fromDial('+91')?.isoCode, 'IN');
      expect(Country.fromDial('91')?.isoCode, 'IN');
      expect(Country.fromIso('ZZ'), isNull);
    });
  });

  group('PhoneResult', () {
    test('equality and hashCode', () {
      const india = Country('India', 'IN', '91', '🇮🇳', '##### #####', 10);
      const a = PhoneResult(
        nationalNumber: '9876543210',
        dialCode: '91',
        fullNumber: '+919876543210',
        country: india,
        isValid: true,
      );
      const b = PhoneResult(
        nationalNumber: '9876543210',
        dialCode: '91',
        fullNumber: '+919876543210',
        country: india,
        isValid: true,
      );
      const c = PhoneResult(
        nationalNumber: '1234',
        dialCode: '91',
        fullNumber: '+911234',
        country: india,
        isValid: false,
      );
      expect(a, equals(b));
      expect(a.hashCode, b.hashCode);
      expect(a, isNot(equals(c)));
      expect(a.toString(), contains('+919876543210'));
    });
  });

  group('CmxPhoneField widget', () {
    testWidgets('emits onChanged with formatted result and validity',
        (tester) async {
      PhoneResult? last;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CmxPhoneField(
              initialCountry:
                  const Country('India', 'IN', '91', '🇮🇳', '##### #####', 10),
              showContactSuggestions: false,
              autoDetectCountry: false,
              onChanged: (r) => last = r,
            ),
          ),
        ),
      );

      await tester.enterText(find.byType(TextField), '9876543210');
      await tester.pumpAndSettle();

      expect(last, isNotNull);
      expect(last!.nationalNumber, '9876543210');
      expect(last!.dialCode, '91');
      expect(last!.fullNumber, '+919876543210');
      expect(last!.isValid, isTrue);
      expect(find.text('98765 43210'), findsOneWidget);
    });

    testWidgets('reports invalid for too-short numbers', (tester) async {
      PhoneResult? last;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CmxPhoneField(
              initialCountry:
                  const Country('India', 'IN', '91', '🇮🇳', '##### #####', 10),
              showContactSuggestions: false,
              autoDetectCountry: false,
              onChanged: (r) => last = r,
            ),
          ),
        ),
      );

      await tester.enterText(find.byType(TextField), '12');
      await tester.pumpAndSettle();

      expect(last, isNotNull);
      expect(last!.isValid, isFalse);
    });

    testWidgets('validator integrates with Form.validate()', (tester) async {
      final formKey = GlobalKey<FormState>();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Form(
              key: formKey,
              child: CmxPhoneField(
                showContactSuggestions: false,
                autoDetectCountry: false,
                initialCountry: Country.fallback,
                validator: CmxPhoneField.validNumber(),
              ),
            ),
          ),
        ),
      );

      expect(formKey.currentState!.validate(), isFalse);
      await tester.pumpAndSettle();
      expect(find.text('Enter your mobile number'), findsOneWidget);
    });
  });
}
