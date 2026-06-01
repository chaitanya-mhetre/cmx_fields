import 'package:cmx_fields/cmx_fields.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

PhoneResult _result({
  required bool isValid,
  String national = '9876543210',
  Country? country,
}) {
  final c = country ?? Country.fromIso('IN')!;
  return PhoneResult(
    nationalNumber: national,
    dialCode: c.dialCode,
    fullNumber: '+${c.dialCode}$national',
    country: c,
    isValid: isValid,
  );
}

void main() {
  group('CmxPhoneField.validNumber', () {
    test('rejects null and empty by default', () {
      final v = CmxPhoneField.validNumber();
      expect(v(null), 'Enter your mobile number');
      expect(v(_result(isValid: false, national: '')), 'Enter your mobile number');
    });

    test('allowEmpty lets an empty number pass', () {
      final v = CmxPhoneField.validNumber(allowEmpty: true);
      expect(v(null), isNull);
      expect(v(_result(isValid: false, national: '')), isNull);
    });

    test('passes a valid number, rejects an invalid one', () {
      final v = CmxPhoneField.validNumber();
      expect(v(_result(isValid: true)), isNull);
      expect(v(_result(isValid: false, national: '98765')), isNotNull);
    });

    test('too few digits mentions country and remaining count', () {
      final msg = CmxPhoneField.validNumber()(
        _result(isValid: false, national: '98765'),
      );
      expect(msg, contains('India'));
      expect(msg, contains('+91'));
      expect(msg, contains('10 digits'));
      expect(msg, contains('5 more'));
    });

    test('invalid format with full length uses generic country message', () {
      final msg = CmxPhoneField.validNumber()(
        _result(isValid: false, national: '0000000000'),
      );
      expect(msg, 'Enter a valid mobile number for India (+91)');
    });
  });

  group('PhoneResult.expectedLength', () {
    test('matches mask digit count', () {
      expect(_result(isValid: true).expectedLength, 10);
      final sg = Country.fromIso('SG')!;
      expect(
        _result(isValid: true, national: '81234567', country: sg).expectedLength,
        8,
      );
    });
  });

  group('country-aware validation', () {
    Future<PhoneResult?> enterFor(
      WidgetTester tester,
      String iso,
      String digits,
    ) async {
      PhoneResult? last;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CmxPhoneField(
              autoRequestHint: false,
              initialCountry: Country.fromIso(iso),
              onChanged: (r) => last = r,
            ),
          ),
        ),
      );
      await tester.enterText(find.byType(TextField), digits);
      await tester.pump(const Duration(milliseconds: 50));
      return last;
    }

    testWidgets('India expects 10 digits; 10 valid, 5 invalid', (tester) async {
      var r = await enterFor(tester, 'IN', '9876543210');
      expect(r, isNotNull);
      expect(r!.expectedLength, 10);
      expect(r.isValid, isTrue);

      r = await enterFor(tester, 'IN', '98765');
      expect(r!.isValid, isFalse);
    });

    testWidgets('US and UK report a 10-digit expected length', (tester) async {
      final us = await enterFor(tester, 'US', '2025550173');
      expect(us!.expectedLength, 10);

      final gb = await enterFor(tester, 'GB', '7400123456');
      expect(gb!.expectedLength, 10);
    });

    testWidgets('expectedLength tracks the selected country (8 for Singapore)',
        (tester) async {
      final sg = await enterFor(tester, 'SG', '81234567');
      expect(sg!.expectedLength, 8);
    });
  });
}
