import 'package:cmx_fields/src/core/cmx_field_theme.dart';
import 'package:cmx_fields/src/core/cmx_validators.dart';
import 'package:cmx_fields/src/fields/cmx_textarea_field.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

const CmxFieldTheme _theme = CmxFieldTheme();

Widget _wrap(Widget child) {
  return MaterialApp(
    home: Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: child,
      ),
    ),
  );
}

void main() {
  group('CmxTextAreaField counter', () {
    testWidgets('shows running count without maxLength', (tester) async {
      await tester.pumpWidget(
        _wrap(const CmxTextAreaField(label: 'Notes')),
      );

      // Empty starts at 0.
      expect(find.text('0'), findsOneWidget);

      await tester.enterText(find.byType(TextField), 'hello');
      await tester.pump();
      expect(find.text('5'), findsOneWidget);
    });

    testWidgets('formats as "n / max" when maxLength is set', (tester) async {
      await tester.pumpWidget(
        _wrap(const CmxTextAreaField(label: 'Bio', maxLength: 200)),
      );

      expect(find.text('0 / 200'), findsOneWidget);

      await tester.enterText(find.byType(TextField), 'multi\nline\ntext');
      await tester.pump();
      // 'multi\nline\ntext' = 15 chars including the two newlines.
      expect(find.text('15 / 200'), findsOneWidget);
    });

    testWidgets('counter turns error color at >= 90% of maxLength',
        (tester) async {
      await tester.pumpWidget(
        _wrap(const CmxTextAreaField(label: 'Bio', maxLength: 10)),
      );

      // 8 chars -> below 90%, label color.
      await tester.enterText(find.byType(TextField), '12345678');
      await tester.pump();
      Text counter() => tester.widget<Text>(find.text('8 / 10'));
      expect(counter().style!.color, _theme.labelColor);

      // 9 chars -> 90%, error color.
      await tester.enterText(find.byType(TextField), '123456789');
      await tester.pump();
      Text counter2() => tester.widget<Text>(find.text('9 / 10'));
      expect(counter2().style!.color, _theme.errorColor);
    });

    testWidgets('hides counter when showCounter is false', (tester) async {
      await tester.pumpWidget(
        _wrap(const CmxTextAreaField(label: 'Notes', showCounter: false)),
      );
      await tester.enterText(find.byType(TextField), 'abc');
      await tester.pump();
      expect(find.text('3'), findsNothing);
    });
  });

  group('CmxTextAreaField maxLength enforcement', () {
    testWidgets('hard-caps input at maxLength', (tester) async {
      await tester.pumpWidget(
        _wrap(const CmxTextAreaField(label: 'Bio', maxLength: 5)),
      );

      await tester.enterText(find.byType(TextField), 'abcdefghij');
      await tester.pump();

      final field = tester.widget<TextField>(find.byType(TextField));
      expect(field.controller!.text, 'abcde');
      expect(find.text('5 / 5'), findsOneWidget);
    });

    testWidgets('wires maxLengthEnforcement to enforced', (tester) async {
      await tester.pumpWidget(
        _wrap(const CmxTextAreaField(label: 'Bio', maxLength: 5)),
      );
      final field = tester.widget<TextField>(find.byType(TextField));
      expect(field.maxLength, 5);
      expect(field.maxLengthEnforcement, MaxLengthEnforcement.enforced);
    });
  });

  group('CmxTextAreaField sizing', () {
    testWidgets('auto-expand wires minLines/maxLines and grows',
        (tester) async {
      await tester.pumpWidget(
        _wrap(const CmxTextAreaField(label: 'Notes', minLines: 2, maxLines: 5)),
      );

      final field = tester.widget<TextField>(find.byType(TextField));
      expect(field.minLines, 2);
      expect(field.maxLines, 5);

      final startHeight = tester.getSize(find.byType(TextField)).height;

      await tester.enterText(
        find.byType(TextField),
        'line1\nline2\nline3\nline4',
      );
      await tester.pumpAndSettle();

      final grownHeight = tester.getSize(find.byType(TextField)).height;
      expect(grownHeight, greaterThan(startHeight));
    });

    testWidgets('autoExpand false pins to a fixed maxLines box',
        (tester) async {
      await tester.pumpWidget(
        _wrap(
          const CmxTextAreaField(
            label: 'Notes',
            minLines: 2,
            maxLines: 4,
            autoExpand: false,
          ),
        ),
      );

      final field = tester.widget<TextField>(find.byType(TextField));
      expect(field.minLines, 4);
      expect(field.maxLines, 4);

      final startHeight = tester.getSize(find.byType(TextField)).height;
      await tester.enterText(
        find.byType(TextField),
        'a\nb\nc\nd\ne\nf\ng',
      );
      await tester.pumpAndSettle();
      final afterHeight = tester.getSize(find.byType(TextField)).height;
      expect(afterHeight, startHeight);
    });

    testWidgets('renders without overflow when content grows', (tester) async {
      await tester.pumpWidget(
        _wrap(const CmxTextAreaField(label: 'Notes')),
      );
      await tester.enterText(
        find.byType(TextField),
        List<String>.generate(12, (i) => 'line $i').join('\n'),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  });

  group('CmxTextAreaField in a Form', () {
    testWidgets('minLength validator shows error and clears on edit',
        (tester) async {
      final formKey = GlobalKey<FormState>();
      await tester.pumpWidget(
        _wrap(
          Form(
            key: formKey,
            child: CmxTextAreaField(
              label: 'Bio',
              validator: CmxValidators.minLength(10, 'Too short'),
            ),
          ),
        ),
      );

      await tester.enterText(find.byType(TextField), 'short');
      await tester.pump();

      expect(formKey.currentState!.validate(), isFalse);
      await tester.pumpAndSettle();
      expect(find.text('Too short'), findsOneWidget);

      await tester.enterText(find.byType(TextField), 'long enough text');
      await tester.pump();
      expect(formKey.currentState!.validate(), isTrue);
      await tester.pumpAndSettle();
      expect(find.text('Too short'), findsNothing);
    });

    testWidgets('onChanged fires with the latest text', (tester) async {
      final values = <String>[];
      await tester.pumpWidget(
        _wrap(
          CmxTextAreaField(label: 'Notes', onChanged: values.add),
        ),
      );
      await tester.enterText(find.byType(TextField), 'abc');
      await tester.pump();
      expect(values.last, 'abc');
    });
  });
}
