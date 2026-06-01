import 'package:cmx_fields/src/fields/card/card_type_detector.dart';
import 'package:cmx_fields/src/fields/card/cmx_card_field.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('CardTypeDetector.detect', () {
    test('detects Visa from a leading 4', () {
      expect(CardTypeDetector.detect('4111111111111111'), CardType.visa);
      expect(CardTypeDetector.detect('4242424242424242'), CardType.visa);
      expect(CardTypeDetector.detect('4'), CardType.visa);
    });

    test('detects Mastercard in the 51-55 range', () {
      expect(CardTypeDetector.detect('5500005555555559'), CardType.mastercard);
      expect(CardTypeDetector.detect('5105105105105100'), CardType.mastercard);
    });

    test('detects Mastercard in the 2221-2720 range', () {
      expect(CardTypeDetector.detect('2221000000000009'), CardType.mastercard);
      expect(CardTypeDetector.detect('2720999999999996'), CardType.mastercard);
      // Just outside the range falls back to other brands / unknown.
      expect(CardTypeDetector.detect('2220000000000000'), CardType.unknown);
    });

    test('detects Amex from 34 / 37 with 15-digit length and 4-digit CVV', () {
      expect(CardTypeDetector.detect('378282246310005'), CardType.amex);
      expect(CardTypeDetector.detect('340000000000009'), CardType.amex);
      expect(CardTypeDetector.maxLength(CardType.amex), 15);
      expect(CardTypeDetector.cvvLength(CardType.amex), 4);
    });

    test('detects Discover from its prefixes', () {
      expect(CardTypeDetector.detect('6011111111111117'), CardType.discover);
      expect(CardTypeDetector.detect('6440000000000000'), CardType.discover);
      expect(CardTypeDetector.detect('6490000000000000'), CardType.discover);
      expect(CardTypeDetector.detect('6500000000000000'), CardType.discover);
      expect(CardTypeDetector.detect('6221260000000000'), CardType.discover);
      expect(CardTypeDetector.detect('6229250000000000'), CardType.discover);
    });

    test('detects RuPay from its prefixes', () {
      expect(CardTypeDetector.detect('6000000000000000'), CardType.rupay);
      expect(CardTypeDetector.detect('6521000000000000'), CardType.rupay);
      expect(CardTypeDetector.detect('6522000000000000'), CardType.rupay);
      expect(CardTypeDetector.detect('5080000000000000'), CardType.rupay);
    });

    test('detects Maestro from its prefixes', () {
      expect(CardTypeDetector.detect('5000000000000000'), CardType.maestro);
      expect(CardTypeDetector.detect('5600000000000000'), CardType.maestro);
      expect(CardTypeDetector.detect('5800000000000000'), CardType.maestro);
      expect(CardTypeDetector.detect('6304000000000000'), CardType.maestro);
      expect(CardTypeDetector.detect('6759000000000000'), CardType.maestro);
      expect(CardTypeDetector.detect('6767700000000000'), CardType.maestro);
      expect(CardTypeDetector.detect('6767740000000000'), CardType.maestro);
    });

    test('returns unknown for junk and empty input', () {
      expect(CardTypeDetector.detect(''), CardType.unknown);
      expect(CardTypeDetector.detect('abc'), CardType.unknown);
      expect(CardTypeDetector.detect('9999999999999999'), CardType.unknown);
    });

    test('ignores grouping spaces in the input', () {
      expect(CardTypeDetector.detect('4242 4242 4242 4242'), CardType.visa);
    });

    test('non-amex brands report length 16 and CVV length 3', () {
      expect(CardTypeDetector.maxLength(CardType.visa), 16);
      expect(CardTypeDetector.cvvLength(CardType.visa), 3);
      expect(CardTypeDetector.maxLength(CardType.unknown), 16);
      expect(CardTypeDetector.cvvLength(CardType.unknown), 3);
    });

    test('exposes display names', () {
      expect(CardTypeDetector.displayName(CardType.visa), 'Visa');
      expect(CardTypeDetector.displayName(CardType.mastercard), 'Mastercard');
      expect(CardTypeDetector.displayName(CardType.amex), 'Amex');
      expect(CardTypeDetector.displayName(CardType.unknown), 'Card');
    });
  });

  group('CardFormatting.isLuhnValid', () {
    test('a known-valid number passes', () {
      expect(CardFormatting.isLuhnValid('4242424242424242'), isTrue);
      expect(CardFormatting.isLuhnValid('5500005555555559'), isTrue);
      expect(CardFormatting.isLuhnValid('378282246310005'), isTrue);
    });

    test('a near-miss fails', () {
      expect(CardFormatting.isLuhnValid('4242424242424241'), isFalse);
      expect(CardFormatting.isLuhnValid('1234567812345678'), isFalse);
    });

    test('handles grouped input and rejects empty/short input', () {
      expect(CardFormatting.isLuhnValid('4242 4242 4242 4242'), isTrue);
      expect(CardFormatting.isLuhnValid(''), isFalse);
      expect(CardFormatting.isLuhnValid('4'), isFalse);
    });
  });

  group('CardFormatting.groupNumber', () {
    test('groups standard cards in fours', () {
      expect(
        CardFormatting.groupNumber('4242424242424242', CardType.visa),
        '4242 4242 4242 4242',
      );
      expect(
        CardFormatting.groupNumber('424242', CardType.visa),
        '4242 42',
      );
    });

    test('groups Amex as 4-6-5', () {
      expect(
        CardFormatting.groupNumber('378282246310005', CardType.amex),
        '3782 822463 10005',
      );
    });

    test('caps digits at the brand maximum length', () {
      expect(
        CardFormatting.groupNumber('42424242424242429999', CardType.visa),
        '4242 4242 4242 4242',
      );
      expect(
        CardFormatting.groupNumber('3782822463100059999', CardType.amex),
        '3782 822463 10005',
      );
    });
  });

  group('isExpiryValid', () {
    final now = DateTime(2026, 6, 1);

    test('accepts a future MM/YY', () {
      expect(isExpiryValid('09/27', now: now), isTrue);
      expect(isExpiryValid('06/26', now: now), isTrue); // current month
    });

    test('rejects past, incomplete, or out-of-range months', () {
      expect(isExpiryValid('05/26', now: now), isFalse); // last month
      expect(isExpiryValid('13/30', now: now), isFalse); // bad month
      expect(isExpiryValid('00/30', now: now), isFalse);
      expect(isExpiryValid('09/2', now: now), isFalse); // incomplete
      expect(isExpiryValid('', now: now), isFalse);
    });
  });

  group('CmxCardField widget', () {
    Widget host(Widget child) => MaterialApp(home: Scaffold(body: child));

    Finder numberField() => find.byType(TextField).first;

    testWidgets(
      'a full valid card emits isValid: true with the right cardType',
      (tester) async {
        CardResult? captured;
        await tester.pumpWidget(
          host(CmxCardField(onChanged: (r) => captured = r)),
        );

        final fields = find.byType(TextField);
        await tester.enterText(fields.at(0), '4242424242424242');
        await tester.pump();
        // Expiry comfortably in the future relative to any test run.
        await tester.enterText(fields.at(1), '1299');
        await tester.pump();
        await tester.enterText(fields.at(2), '123');
        await tester.pump();

        expect(captured, isNotNull);
        expect(captured!.cardType, CardType.visa);
        expect(captured!.number, '4242424242424242');
        expect(captured!.formattedNumber, '4242 4242 4242 4242');
        expect(captured!.expiry, '12/99');
        expect(captured!.cvv, '123');
        expect(captured!.isValid, isTrue);
      },
    );

    testWidgets('an invalid number is not valid', (tester) async {
      CardResult? captured;
      await tester.pumpWidget(
        host(CmxCardField(onChanged: (r) => captured = r)),
      );

      final fields = find.byType(TextField);
      await tester.enterText(fields.at(0), '4242424242424241'); // Luhn fail
      await tester.pump();
      await tester.enterText(fields.at(1), '1299');
      await tester.pump();
      await tester.enterText(fields.at(2), '123');
      await tester.pump();

      expect(captured, isNotNull);
      expect(captured!.cardType, CardType.visa);
      expect(captured!.isValid, isFalse);
    });

    testWidgets('groups digits with spaces as typed', (tester) async {
      await tester.pumpWidget(host(const CmxCardField()));
      await tester.enterText(numberField(), '4242424242424242');
      await tester.pump();
      expect(find.text('4242 4242 4242 4242'), findsOneWidget);
    });

    testWidgets('detects Amex and limits CVV to four digits', (tester) async {
      CardResult? captured;
      await tester.pumpWidget(
        host(CmxCardField(onChanged: (r) => captured = r)),
      );
      final fields = find.byType(TextField);
      await tester.enterText(fields.at(0), '378282246310005');
      await tester.pump();
      await tester.enterText(fields.at(2), '12345'); // one too many
      await tester.pump();

      expect(captured!.cardType, CardType.amex);
      expect(captured!.cvv, '1234');
    });

    testWidgets('Form.validate shows the validator error', (tester) async {
      final formKey = GlobalKey<FormState>();
      await tester.pumpWidget(
        host(
          Form(
            key: formKey,
            child: CmxCardField(
              validator: (r) =>
                  (r != null && r.isValid) ? null : 'Enter a valid card',
            ),
          ),
        ),
      );

      expect(formKey.currentState!.validate(), isFalse);
      await tester.pumpAndSettle();
      expect(find.text('Enter a valid card'), findsOneWidget);
    });

    testWidgets('Form.validate passes for a fully valid card', (tester) async {
      final formKey = GlobalKey<FormState>();
      await tester.pumpWidget(
        host(
          Form(
            key: formKey,
            child: CmxCardField(
              validator: (r) =>
                  (r != null && r.isValid) ? null : 'Enter a valid card',
            ),
          ),
        ),
      );

      final fields = find.byType(TextField);
      await tester.enterText(fields.at(0), '4242424242424242');
      await tester.pump();
      await tester.enterText(fields.at(1), '1299');
      await tester.pump();
      await tester.enterText(fields.at(2), '123');
      await tester.pump();

      expect(formKey.currentState!.validate(), isTrue);
      await tester.pumpAndSettle();
      expect(find.text('Enter a valid card'), findsNothing);
    });
  });

  group('CardResult value semantics', () {
    test('equality and hashCode', () {
      const a = CardResult(
        number: '4242424242424242',
        formattedNumber: '4242 4242 4242 4242',
        expiry: '12/99',
        cvv: '123',
        cardType: CardType.visa,
        isValid: true,
      );
      const b = CardResult(
        number: '4242424242424242',
        formattedNumber: '4242 4242 4242 4242',
        expiry: '12/99',
        cvv: '123',
        cardType: CardType.visa,
        isValid: true,
      );
      const c = CardResult(
        number: '4242424242424242',
        formattedNumber: '4242 4242 4242 4242',
        expiry: '12/99',
        cvv: '123',
        cardType: CardType.visa,
        isValid: false,
      );
      expect(a, b);
      expect(a.hashCode, b.hashCode);
      expect(a == c, isFalse);
      expect(a.toString(), contains('isValid: true'));
    });
  });
}
