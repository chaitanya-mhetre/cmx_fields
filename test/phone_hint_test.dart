import 'package:cmx_fields/cmx_fields.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('PhoneNumberHintService.normalize', () {
    test('strips a leading +dialCode', () {
      expect(
        PhoneNumberHintService.normalize(
          '+91 98765 43210',
          dialCode: '91',
          nationalLength: 10,
        ),
        '9876543210',
      );
    });

    test('strips a bare dialCode when total length matches', () {
      expect(
        PhoneNumberHintService.normalize(
          '919876543210',
          dialCode: '91',
          nationalLength: 10,
        ),
        '9876543210',
      );
    });

    test('keeps a plain national number, dropping separators', () {
      expect(
        PhoneNumberHintService.normalize(
          '98765-43210',
          dialCode: '91',
          nationalLength: 10,
        ),
        '9876543210',
      );
    });

    test('trims to the last nationalLength digits when longer', () {
      expect(
        PhoneNumberHintService.normalize(
          '+1 (555) 123-4567',
          dialCode: '1',
          nationalLength: 10,
        ),
        '5551234567',
      );
    });

    test('returns null for empty / digitless input', () {
      expect(
        PhoneNumberHintService.normalize(
          '  --  ',
          dialCode: '91',
          nationalLength: 10,
        ),
        isNull,
      );
    });
  });

  group('isPhoneNumberHintSupported', () {
    test('is a bool that does not throw off-Android', () {
      expect(isPhoneNumberHintSupported, isA<bool>());
    });
  });

  group('PhoneFillProgress', () {
    testWidgets('renders a ring while filling (not valid)', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: PhoneFillProgress(
              progress: 0.5,
              valid: false,
              color: Colors.green,
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      final indicator = tester.widget<CircularProgressIndicator>(
        find.byType(CircularProgressIndicator),
      );
      expect(indicator.value, greaterThan(0.0));
    });

    testWidgets('shows the checkmark when valid', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: PhoneFillProgress(
              progress: 1.0,
              valid: true,
              color: Colors.green,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(CmxCheckmark), findsOneWidget);
      final check = tester.widget<CmxCheckmark>(find.byType(CmxCheckmark));
      expect(check.visible, isTrue);
    });
  });

  group('CmxPhoneField fill progress', () {
    testWidgets('shows fill progress that becomes valid for a real number',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CmxPhoneField(
              label: 'Phone',
              autoRequestHint: false,
              initialCountry: Country.fromIso('IN'),
            ),
          ),
        ),
      );

      await tester.enterText(find.byType(TextField), '98765');
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.byType(PhoneFillProgress), findsOneWidget);
      var progress = tester.widget<PhoneFillProgress>(
        find.byType(PhoneFillProgress),
      );
      expect(progress.valid, isFalse);

      await tester.enterText(find.byType(TextField), '9876543210');
      await tester.pump(const Duration(milliseconds: 300));
      progress = tester.widget<PhoneFillProgress>(
        find.byType(PhoneFillProgress),
      );
      expect(progress.valid, isTrue);
      expect(progress.progress, closeTo(1.0, 0.001));
    });
  });
}
