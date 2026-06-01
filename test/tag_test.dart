import 'package:cmx_fields/src/fields/cmx_tag_field.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _wrap(Widget child) {
  return MaterialApp(
    home: Scaffold(body: child),
  );
}

void main() {
  group('CmxTagField widget', () {
    testWidgets('typing then submitting commits a tag and fires onTagsChanged',
        (tester) async {
      List<String>? last;
      await tester.pumpWidget(
        _wrap(CmxTagField(onTagsChanged: (t) => last = t)),
      );

      await tester.tap(find.byType(TextField));
      await tester.pump();
      await tester.enterText(find.byType(TextField), 'flutter');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();

      expect(find.text('flutter'), findsOneWidget);
      expect(last, <String>['flutter']);
    });

    testWidgets('typing a comma separator commits the tag', (tester) async {
      List<String>? last;
      await tester.pumpWidget(
        _wrap(CmxTagField(onTagsChanged: (t) => last = t)),
      );

      await tester.tap(find.byType(TextField));
      await tester.pump();
      await tester.enterText(find.byType(TextField), 'dart,');
      await tester.pumpAndSettle();

      expect(find.text('dart'), findsOneWidget);
      expect(last, <String>['dart']);
    });

    testWidgets('tapping a chip close icon removes the tag', (tester) async {
      List<String>? last;
      await tester.pumpWidget(
        _wrap(
          CmxTagField(
            initialTags: const <String>['alpha', 'beta'],
            onTagsChanged: (t) => last = t,
          ),
        ),
      );

      expect(find.text('alpha'), findsOneWidget);
      expect(find.byIcon(Icons.close), findsNWidgets(2));

      await tester.tap(find.byIcon(Icons.close).first);
      await tester.pumpAndSettle();

      expect(find.text('alpha'), findsNothing);
      expect(find.text('beta'), findsOneWidget);
      expect(last, <String>['beta']);
    });

    testWidgets('backspace on empty input removes the last tag',
        (tester) async {
      List<String>? last;
      await tester.pumpWidget(
        _wrap(
          CmxTagField(
            initialTags: const <String>['one', 'two'],
            onTagsChanged: (t) => last = t,
          ),
        ),
      );

      await tester.tap(find.byType(TextField));
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.backspace);
      await tester.pumpAndSettle();

      expect(find.text('two'), findsNothing);
      expect(find.text('one'), findsOneWidget);
      expect(last, <String>['one']);
    });

    testWidgets('maxTags prevents adding beyond the cap', (tester) async {
      List<String>? last;
      await tester.pumpWidget(
        _wrap(
          CmxTagField(
            maxTags: 2,
            initialTags: const <String>['a', 'b'],
            onTagsChanged: (t) => last = t,
          ),
        ),
      );

      await tester.tap(find.byType(TextField));
      await tester.pump();
      await tester.enterText(find.byType(TextField), 'c');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();

      // No new chip was committed (onTagsChanged never fired) and the rejected
      // text remains in the inline input.
      expect(last, isNull);
      final controller =
          tester.widget<TextField>(find.byType(TextField)).controller;
      expect(controller!.text, 'c');
    });

    testWidgets('duplicate is prevented when allowDuplicates is false',
        (tester) async {
      List<String>? last;
      await tester.pumpWidget(
        _wrap(
          CmxTagField(
            initialTags: const <String>['x'],
            onTagsChanged: (t) => last = t,
          ),
        ),
      );

      await tester.tap(find.byType(TextField));
      await tester.pump();
      await tester.enterText(find.byType(TextField), 'x');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();

      // The duplicate was rejected: still exactly one chip and the typed text
      // remains in the input (so 'x' appears as chip + input = 2 matches).
      expect(find.text('x'), findsNWidgets(2));
      expect(last, isNull);
    });

    testWidgets('duplicate allowed when allowDuplicates is true',
        (tester) async {
      List<String>? last;
      await tester.pumpWidget(
        _wrap(
          CmxTagField(
            allowDuplicates: true,
            initialTags: const <String>['x'],
            onTagsChanged: (t) => last = t,
          ),
        ),
      );

      await tester.tap(find.byType(TextField));
      await tester.pump();
      await tester.enterText(find.byType(TextField), 'x');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();

      expect(find.text('x'), findsNWidgets(2));
      expect(last, <String>['x', 'x']);
    });

    testWidgets('Form.validate shows error when empty, clears with a tag',
        (tester) async {
      final formKey = GlobalKey<FormState>();
      await tester.pumpWidget(
        _wrap(
          Form(
            key: formKey,
            child: CmxTagField(
              validator: (tags) => (tags == null || tags.isEmpty)
                  ? 'Add at least one tag'
                  : null,
            ),
          ),
        ),
      );

      expect(formKey.currentState!.validate(), isFalse);
      await tester.pumpAndSettle();
      expect(find.text('Add at least one tag'), findsOneWidget);

      await tester.tap(find.byType(TextField));
      await tester.pump();
      await tester.enterText(find.byType(TextField), 'flutter');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();

      expect(formKey.currentState!.validate(), isTrue);
      await tester.pumpAndSettle();
      expect(find.text('Add at least one tag'), findsNothing);
    });

    testWidgets('tapping a suggestion adds it as a tag', (tester) async {
      List<String>? last;
      await tester.pumpWidget(
        _wrap(
          CmxTagField(
            suggestions: const <String>['flutter', 'flask', 'django'],
            onTagsChanged: (t) => last = t,
          ),
        ),
      );

      await tester.tap(find.byType(TextField));
      await tester.pump();
      await tester.enterText(find.byType(TextField), 'fl');
      await tester.pumpAndSettle();

      expect(find.text('flask'), findsOneWidget);
      await tester.tap(find.text('flask'));
      await tester.pumpAndSettle();

      expect(last, <String>['flask']);
    });
  });
}
