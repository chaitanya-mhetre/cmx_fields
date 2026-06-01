import 'package:cmx_fields/src/fields/cmx_date_field.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('CmxDateFormat.format', () {
    final date = DateTime(2026, 6, 1); // a Monday

    test('dd/MM/yyyy', () {
      expect(CmxDateFormat.format(date, 'dd/MM/yyyy'), '01/06/2026');
    });

    test('MMM d, yyyy', () {
      expect(CmxDateFormat.format(date, 'MMM d, yyyy'), 'Jun 1, 2026');
    });

    test('d MMMM yyyy', () {
      expect(CmxDateFormat.format(date, 'd MMMM yyyy'), '1 June 2026');
    });

    test('yy and M tokens', () {
      expect(CmxDateFormat.format(date, 'yy'), '26');
      expect(CmxDateFormat.format(date, 'M/d/yy'), '6/1/26');
    });

    test('EEE abbreviated weekday', () {
      expect(CmxDateFormat.format(date, 'EEE'), 'Mon');
      // 2026-06-07 is a Sunday.
      expect(CmxDateFormat.format(DateTime(2026, 6, 7), 'EEE'), 'Sun');
    });

    test('zero-padding for dd and MM', () {
      final padded = DateTime(2007, 3, 5);
      expect(CmxDateFormat.format(padded, 'dd/MM/yyyy'), '05/03/2007');
      expect(CmxDateFormat.format(padded, 'd/M/yy'), '5/3/07');
    });

    test('literals pass through verbatim', () {
      expect(
        CmxDateFormat.format(date, 'EEE, MMM dd'),
        'Mon, Jun 01',
      );
    });
  });

  group('CmxDateField widget', () {
    Widget wrap(Widget child) => MaterialApp(
          home: Scaffold(body: child),
        );

    testWidgets('shows the formatted initialDate', (tester) async {
      await tester.pumpWidget(
        wrap(
          CmxDateField(
            label: 'Birthday',
            initialDate: DateTime(2026, 6, 1),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('01/06/2026'), findsOneWidget);
    });

    testWidgets('respects custom dateFormat', (tester) async {
      await tester.pumpWidget(
        wrap(
          CmxDateField(
            dateFormat: 'MMM d, yyyy',
            initialDate: DateTime(2026, 6, 1),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Jun 1, 2026'), findsOneWidget);
    });

    testWidgets(
        'tapping opens the material picker and selecting fires '
        'onChanged + updates display', (tester) async {
      DateTime? changed;
      await tester.pumpWidget(
        wrap(
          CmxDateField(
            label: 'Date',
            pickerStyle: DatePickerStyle.material,
            initialDate: DateTime(2026, 6, 15),
            firstDate: DateTime(2026),
            lastDate: DateTime(2026, 12, 31),
            onChanged: (value) => changed = value,
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byType(TextField));
      await tester.pumpAndSettle();

      // The dialog is open.
      expect(find.byType(Dialog), findsOneWidget);

      // Pick the 20th in the visible (June 2026) month grid.
      await tester.tap(find.text('20'));
      await tester.pumpAndSettle();

      // Confirm.
      await tester.tap(
        find.byWidgetPredicate(
          (w) => w is Text && (w.data?.toUpperCase() == 'OK'),
        ),
      );
      await tester.pumpAndSettle();

      expect(changed, DateTime(2026, 6, 20));
      expect(find.text('20/06/2026'), findsOneWidget);
    });

    testWidgets('cancelling the picker leaves the value unchanged',
        (tester) async {
      DateTime? changed;
      var changeCount = 0;
      await tester.pumpWidget(
        wrap(
          CmxDateField(
            pickerStyle: DatePickerStyle.material,
            initialDate: DateTime(2026, 6, 15),
            firstDate: DateTime(2026),
            lastDate: DateTime(2026, 12, 31),
            onChanged: (value) {
              changed = value;
              changeCount++;
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byType(TextField));
      await tester.pumpAndSettle();
      await tester.tap(
        find.byWidgetPredicate(
          (w) => w is Text && (w.data?.toUpperCase() == 'CANCEL'),
        ),
      );
      await tester.pumpAndSettle();

      expect(changeCount, 0);
      expect(changed, isNull);
      expect(find.text('15/06/2026'), findsOneWidget);
    });

    testWidgets('Form validation shows an error when no date is chosen',
        (tester) async {
      final formKey = GlobalKey<FormState>();
      await tester.pumpWidget(
        wrap(
          Form(
            key: formKey,
            child: CmxDateField(
              label: 'Required date',
              validator: (value) => value == null ? 'Pick a date' : null,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Pick a date'), findsNothing);

      expect(formKey.currentState!.validate(), isFalse);
      await tester.pumpAndSettle();

      expect(find.text('Pick a date'), findsOneWidget);
    });

    testWidgets('Form validation passes once a date is present',
        (tester) async {
      final formKey = GlobalKey<FormState>();
      await tester.pumpWidget(
        wrap(
          Form(
            key: formKey,
            child: CmxDateField(
              initialDate: DateTime(2026, 6, 1),
              validator: (value) => value == null ? 'Pick a date' : null,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(formKey.currentState!.validate(), isTrue);
      await tester.pumpAndSettle();

      expect(find.text('Pick a date'), findsNothing);
    });

    testWidgets('disabled field does not open the picker', (tester) async {
      await tester.pumpWidget(
        wrap(
          CmxDateField(
            enabled: false,
            pickerStyle: DatePickerStyle.material,
            initialDate: DateTime(2026, 6, 1),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byType(TextField), warnIfMissed: false);
      await tester.pumpAndSettle();

      expect(find.byType(Dialog), findsNothing);
    });
  });
}
