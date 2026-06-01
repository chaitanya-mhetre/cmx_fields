import 'package:cmx_fields/src/fields/cmx_number_field.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('CmxNumberFormatter.format', () {
    test('western grouping inserts commas every three digits', () {
      expect(
        CmxNumberFormatter.format('1234567'),
        '1,234,567',
      );
      expect(CmxNumberFormatter.format('1000000'), '1,000,000');
      expect(CmxNumberFormatter.format('999'), '999');
      expect(CmxNumberFormatter.format('1000'), '1,000');
    });

    test('indian grouping inserts commas in the lakh pattern', () {
      expect(
        CmxNumberFormatter.format('1234567', grouping: NumberGrouping.indian),
        '12,34,567',
      );
      expect(
        CmxNumberFormatter.format('1000000', grouping: NumberGrouping.indian),
        '10,00,000',
      );
      expect(
        CmxNumberFormatter.format('1000', grouping: NumberGrouping.indian),
        '1,000',
      );
      expect(
        CmxNumberFormatter.format('100000', grouping: NumberGrouping.indian),
        '1,00,000',
      );
    });

    test('none grouping leaves digits ungrouped', () {
      expect(
        CmxNumberFormatter.format('1234567', grouping: NumberGrouping.none),
        '1234567',
      );
    });

    test('clamps fractional digits to decimalPlaces', () {
      expect(
        CmxNumberFormatter.format('1234.5678', decimalPlaces: 2),
        '1,234.56',
      );
      expect(
        CmxNumberFormatter.format('12.999', decimalPlaces: 1),
        '12.9',
      );
    });

    test('drops the decimal point entirely when decimalPlaces is 0', () {
      expect(CmxNumberFormatter.format('1234.99'), '1,234');
    });

    test('keeps a single leading minus only when allowNegative', () {
      expect(
        CmxNumberFormatter.format('-1234', allowNegative: true),
        '-1,234',
      );
      expect(CmxNumberFormatter.format('-1234'), '1,234');
      expect(
        CmxNumberFormatter.format('--12-34', allowNegative: true),
        '-1,234',
      );
    });

    test('strips stray non-numeric characters', () {
      expect(CmxNumberFormatter.format('a1b2c3,4d'), '1,234');
    });

    test('empty / sign-only input returns gracefully', () {
      expect(CmxNumberFormatter.format(''), '');
      expect(CmxNumberFormatter.format('-', allowNegative: true), '-');
    });
  });

  group('CmxNumberFormatter.parse', () {
    test('parses grouped western text to a num', () {
      expect(CmxNumberFormatter.parse('1,234,567'), 1234567);
    });

    test('parses grouped indian text to a num', () {
      expect(
        CmxNumberFormatter.parse('12,34,567', grouping: NumberGrouping.indian),
        1234567,
      );
    });

    test('parses decimals within the decimalPlaces budget', () {
      expect(
        CmxNumberFormatter.parse('1,234.56', decimalPlaces: 2),
        closeTo(1234.56, 1e-9),
      );
    });

    test('parses negative values when allowed', () {
      expect(
        CmxNumberFormatter.parse('-1,234', allowNegative: true),
        -1234,
      );
    });

    test('returns null for empty / sign-only input', () {
      expect(CmxNumberFormatter.parse(''), isNull);
      expect(CmxNumberFormatter.parse('-', allowNegative: true), isNull);
    });
  });

  group('CmxNumberFormatter.formatEditUpdate', () {
    test('formats and parks the cursor at the end', () {
      const formatter = CmxNumberFormatter();
      final result = formatter.formatEditUpdate(
        TextEditingValue.empty,
        const TextEditingValue(text: '1234567'),
      );
      expect(result.text, '1,234,567');
      expect(result.selection.baseOffset, result.text.length);
    });
  });

  group('CmxNumberField widget', () {
    Widget host(Widget child) => MaterialApp(
          home: Scaffold(body: child),
        );

    testWidgets('onChanged emits the parsed num as the user types',
        (tester) async {
      num? captured;
      await tester.pumpWidget(
        host(CmxNumberField(onChanged: (v) => captured = v)),
      );
      await tester.enterText(find.byType(TextField), '1234567');
      await tester.pump();
      expect(captured, 1234567);
      expect(find.text('1,234,567'), findsOneWidget);
    });

    testWidgets('steppers increment and decrement by stepValue',
        (tester) async {
      num? captured;
      await tester.pumpWidget(
        host(
          CmxNumberField(
            showSteppers: true,
            stepValue: 5,
            initialValue: 10,
            onChanged: (v) => captured = v,
          ),
        ),
      );
      await tester.tap(find.byIcon(Icons.add));
      await tester.pump();
      expect(captured, 15);

      await tester.tap(find.byIcon(Icons.remove));
      await tester.pump();
      expect(captured, 10);
    });

    testWidgets('steppers clamp at min and max and disable at bounds',
        (tester) async {
      num? captured;
      await tester.pumpWidget(
        host(
          CmxNumberField(
            showSteppers: true,
            min: 0,
            max: 3,
            initialValue: 2,
            onChanged: (v) => captured = v,
          ),
        ),
      );
      // 2 -> 3 (at max).
      await tester.tap(find.byIcon(Icons.add));
      await tester.pumpAndSettle();
      expect(captured, 3);

      // The increment button should now be disabled.
      final addButton = tester.widget<IconButton>(
        find.ancestor(
          of: find.byIcon(Icons.add),
          matching: find.byType(IconButton),
        ),
      );
      expect(addButton.onPressed, isNull);

      // Decrement all the way to the floor.
      await tester.tap(find.byIcon(Icons.remove));
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.remove));
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.remove));
      await tester.pumpAndSettle();
      expect(captured, 0);

      final removeButton = tester.widget<IconButton>(
        find.ancestor(
          of: find.byIcon(Icons.remove),
          matching: find.byType(IconButton),
        ),
      );
      expect(removeButton.onPressed, isNull);
    });

    testWidgets('Form.validate shows a min/max error', (tester) async {
      final formKey = GlobalKey<FormState>();
      await tester.pumpWidget(
        host(
          Form(
            key: formKey,
            child: const CmxNumberField(min: 100, initialValue: 5),
          ),
        ),
      );
      expect(formKey.currentState!.validate(), isFalse);
      await tester.pumpAndSettle();
      expect(find.textContaining('Must be at least'), findsOneWidget);
    });

    testWidgets('Form.validate passes for an in-range value', (tester) async {
      final formKey = GlobalKey<FormState>();
      await tester.pumpWidget(
        host(
          Form(
            key: formKey,
            child: const CmxNumberField(min: 0, max: 100, initialValue: 50),
          ),
        ),
      );
      expect(formKey.currentState!.validate(), isTrue);
      await tester.pumpAndSettle();
      expect(find.textContaining('Must be'), findsNothing);
    });

    testWidgets('custom validator runs through the FormField', (tester) async {
      final formKey = GlobalKey<FormState>();
      await tester.pumpWidget(
        host(
          Form(
            key: formKey,
            child: CmxNumberField(
              initialValue: 4,
              validator: (v) =>
                  (v != null && v % 2 != 0) ? null : 'Must be odd',
            ),
          ),
        ),
      );
      expect(formKey.currentState!.validate(), isFalse);
      await tester.pumpAndSettle();
      expect(find.text('Must be odd'), findsOneWidget);
    });
  });
}
