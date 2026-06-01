import 'package:cmx_fields/src/fields/otp/cmx_otp_field.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Pumps [child] inside a minimal Material app for testing.
Widget _wrap(Widget child) {
  return MaterialApp(
    home: Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(8),
        child: child,
      ),
    ),
  );
}

/// All [TextField]s currently in the tree, in order.
Iterable<TextField> _boxes(WidgetTester tester) =>
    tester.widgetList<TextField>(find.byType(TextField));

void main() {
  group('CmxOtpField', () {
    testWidgets('renders one box per length', (tester) async {
      await tester.pumpWidget(
        _wrap(const CmxOtpField(length: 6, autoFocus: false)),
      );
      await tester.pump();

      expect(find.byType(TextField), findsNWidgets(6));
    });

    testWidgets(
      'entering digits advances focus and fires onChanged/onCompleted',
      (tester) async {
        final changes = <String>[];
        String? completed;

        await tester.pumpWidget(
          _wrap(
            CmxOtpField(
              length: 4,
              autoFocus: false,
              onChanged: changes.add,
              onCompleted: (v) => completed = v,
            ),
          ),
        );
        await tester.pump();

        final fields = find.byType(TextField);

        // Focus first box, then type each digit; focus should auto-advance.
        await tester.tap(fields.at(0));
        await tester.pump();

        for (final entry in const ['1', '2', '3', '4'].asMap().entries) {
          await tester.enterText(fields.at(entry.key), entry.value);
          await tester.pump();
        }

        expect(changes.last, '1234');
        expect(completed, '1234');

        // Every box holds its single digit.
        final texts = _boxes(tester).map((b) => b.controller!.text).toList();
        expect(texts, ['1', '2', '3', '4']);
      },
    );

    testWidgets(
      'pasting a full code into the first box distributes across all boxes',
      (tester) async {
        String? completed;

        await tester.pumpWidget(
          _wrap(
            CmxOtpField(
              length: 6,
              autoFocus: false,
              onCompleted: (v) => completed = v,
            ),
          ),
        );
        await tester.pump();

        final fields = find.byType(TextField);
        await tester.enterText(fields.at(0), '123456');
        await tester.pump();

        final texts = _boxes(tester).map((b) => b.controller!.text).toList();
        expect(texts, ['1', '2', '3', '4', '5', '6']);
        expect(completed, '123456');
      },
    );

    testWidgets(
      'non-digit characters are filtered out',
      (tester) async {
        await tester.pumpWidget(
          _wrap(const CmxOtpField(length: 4, autoFocus: false)),
        );
        await tester.pump();

        final fields = find.byType(TextField);
        await tester.enterText(fields.at(0), '1a2b3c4d');
        await tester.pump();

        final texts = _boxes(tester).map((b) => b.controller!.text).toList();
        expect(texts, ['1', '2', '3', '4']);
      },
    );

    testWidgets('CmxOtpController.clear() empties all boxes', (tester) async {
      final controller = CmxOtpController();
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        _wrap(
          CmxOtpField(length: 4, autoFocus: false, controller: controller),
        ),
      );
      await tester.pump();

      final fields = find.byType(TextField);
      await tester.enterText(fields.at(0), '9999');
      await tester.pump();

      expect(controller.value, '9999');

      controller.clear();
      await tester.pump();

      final texts = _boxes(tester).map((b) => b.controller!.text).toList();
      expect(texts, ['', '', '', '']);
      expect(controller.value, '');
    });

    testWidgets('CmxOtpController.value reflects entered code', (tester) async {
      final controller = CmxOtpController();
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        _wrap(
          CmxOtpField(length: 4, autoFocus: false, controller: controller),
        ),
      );
      await tester.pump();

      expect(controller.value, '');

      await tester.enterText(find.byType(TextField).at(0), '4242');
      await tester.pump();

      expect(controller.value, '4242');
    });

    testWidgets(
      'Form.validate shows an error when validator fails',
      (tester) async {
        final formKey = GlobalKey<FormState>();

        await tester.pumpWidget(
          _wrap(
            Form(
              key: formKey,
              child: CmxOtpField(
                length: 4,
                autoFocus: false,
                validator: (value) {
                  if (value == null || value.length < 4) {
                    return 'Enter all 4 digits';
                  }
                  return null;
                },
              ),
            ),
          ),
        );
        await tester.pump();

        // No error before validation.
        expect(find.text('Enter all 4 digits'), findsNothing);

        // Validate with empty value -> error.
        expect(formKey.currentState!.validate(), isFalse);
        await tester.pumpAndSettle();

        expect(find.text('Enter all 4 digits'), findsOneWidget);

        // Fill the field and re-validate -> error clears.
        await tester.enterText(find.byType(TextField).at(0), '1234');
        await tester.pump();

        expect(formKey.currentState!.validate(), isTrue);
        await tester.pumpAndSettle();

        expect(find.text('Enter all 4 digits'), findsNothing);
      },
    );

    testWidgets('obscureText hides entered digits', (tester) async {
      await tester.pumpWidget(
        _wrap(
          const CmxOtpField(length: 4, autoFocus: false, obscureText: true),
        ),
      );
      await tester.pump();

      final first = _boxes(tester).first;
      expect(first.obscureText, isTrue);
    });

    testWidgets('respects RTL directionality without throwing', (tester) async {
      await tester.pumpWidget(
        const Directionality(
          textDirection: TextDirection.rtl,
          child: MaterialApp(
            home: Scaffold(
              body: CmxOtpField(length: 4, autoFocus: false),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.byType(TextField), findsNWidgets(4));
      expect(tester.takeException(), isNull);
    });
  });
}
