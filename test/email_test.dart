import 'package:cmx_fields/src/core/cmx_animations.dart';
import 'package:cmx_fields/src/core/cmx_validators.dart';
import 'package:cmx_fields/src/fields/cmx_email_field.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _wrap(Widget child) {
  return MaterialApp(
    home: Scaffold(body: child),
  );
}

void main() {
  group('CmxEmailField widget', () {
    testWidgets('valid email shows the success checkmark', (tester) async {
      String? last;
      await tester.pumpWidget(
        _wrap(
          CmxEmailField(
            showSuggestions: false,
            onChanged: (v) => last = v,
          ),
        ),
      );

      await tester.enterText(find.byType(TextField), 'jane@example.com');
      await tester.pumpAndSettle();

      expect(last, 'jane@example.com');
      expect(find.byType(CmxCheckmark), findsOneWidget);
    });

    testWidgets('invalid email shows no checkmark', (tester) async {
      await tester.pumpWidget(
        _wrap(const CmxEmailField(showSuggestions: false)),
      );

      await tester.enterText(find.byType(TextField), 'not-an-email');
      await tester.pumpAndSettle();

      expect(find.byType(CmxCheckmark), findsNothing);
    });

    testWidgets('empty text shows no checkmark', (tester) async {
      await tester.pumpWidget(
        _wrap(const CmxEmailField(showSuggestions: false)),
      );

      await tester.enterText(find.byType(TextField), 'a@b.com');
      await tester.pumpAndSettle();
      expect(find.byType(CmxCheckmark), findsOneWidget);

      await tester.enterText(find.byType(TextField), '');
      await tester.pumpAndSettle();
      expect(find.byType(CmxCheckmark), findsNothing);
    });

    testWidgets('offers gmail completion and tapping completes the field',
        (tester) async {
      final controller = TextEditingController();
      await tester.pumpWidget(
        _wrap(CmxEmailField(controller: controller)),
      );

      await tester.tap(find.byType(TextField));
      await tester.pump();
      await tester.enterText(find.byType(TextField), 'john@gm');
      await tester.pumpAndSettle();

      final suggestion = find.text('john@gmail.com');
      expect(suggestion, findsOneWidget);

      await tester.tap(suggestion);
      await tester.pumpAndSettle();

      expect(controller.text, 'john@gmail.com');
      // Overlay closed after selection: no suggestion ListTile remains. The
      // completed text now lives in the TextField, so only check the overlay.
      expect(find.byType(ListTile), findsNothing);
    });

    testWidgets('custom domains appear in suggestions', (tester) async {
      await tester.pumpWidget(
        _wrap(
          const CmxEmailField(customDomains: <String>['agribid.ai']),
        ),
      );

      await tester.tap(find.byType(TextField));
      await tester.pump();
      await tester.enterText(find.byType(TextField), 'dev@agri');
      await tester.pumpAndSettle();

      expect(find.text('dev@agribid.ai'), findsOneWidget);
    });

    testWidgets('no suggestions when showSuggestions is false', (tester) async {
      await tester.pumpWidget(
        _wrap(const CmxEmailField(showSuggestions: false)),
      );

      await tester.tap(find.byType(TextField));
      await tester.pump();
      await tester.enterText(find.byType(TextField), 'john@gm');
      await tester.pumpAndSettle();

      expect(find.text('john@gmail.com'), findsNothing);
    });

    testWidgets('Form.validate invalidates empty/garbage, passes real address',
        (tester) async {
      final formKey = GlobalKey<FormState>();
      await tester.pumpWidget(
        _wrap(
          Form(
            key: formKey,
            child: CmxEmailField(
              showSuggestions: false,
              validator: CmxValidators.compose<String>([
                CmxValidators.required(),
                CmxValidators.email(),
              ]),
            ),
          ),
        ),
      );

      // Empty -> required fails.
      expect(formKey.currentState!.validate(), isFalse);
      await tester.pumpAndSettle();
      expect(find.text('Required'), findsOneWidget);

      // Garbage -> email fails.
      await tester.enterText(find.byType(TextField), 'garbage');
      await tester.pumpAndSettle();
      expect(formKey.currentState!.validate(), isFalse);
      await tester.pumpAndSettle();
      expect(find.text('Enter a valid email'), findsOneWidget);

      // Real address -> passes, error clears.
      await tester.enterText(find.byType(TextField), 'real@address.com');
      await tester.pumpAndSettle();
      expect(formKey.currentState!.validate(), isTrue);
      await tester.pumpAndSettle();
      expect(find.text('Enter a valid email'), findsNothing);
      expect(find.text('Required'), findsNothing);
    });
  });
}
