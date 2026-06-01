import 'package:cmx_fields/src/fields/password/cmx_password_field.dart';
import 'package:cmx_fields/src/fields/password/strength_indicator.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('PasswordStrengthChecker.check', () {
    test('empty -> none', () {
      expect(PasswordStrengthChecker.check(''), PasswordStrength.none);
    });

    test('short (< 6) -> weak', () {
      expect(PasswordStrengthChecker.check('abc'), PasswordStrength.weak);
      expect(PasswordStrengthChecker.check('aB1!'), PasswordStrength.weak);
    });

    test('length >= 6 but not strong -> medium', () {
      expect(PasswordStrengthChecker.check('abcdef'), PasswordStrength.medium);
      // 7 letters + number but length < 8 -> still medium.
      expect(PasswordStrengthChecker.check('abcdef1'), PasswordStrength.medium);
    });

    test('length >= 8 with letter + number -> strong', () {
      expect(
        PasswordStrengthChecker.check('abcdefg1'),
        PasswordStrength.strong,
      );
      // Has symbol but missing case variety for veryStrong stays strong.
      expect(
        PasswordStrengthChecker.check('abcdef1!'),
        PasswordStrength.strong,
      );
    });

    test('length >= 8 with upper+lower+number+symbol -> veryStrong', () {
      expect(
        PasswordStrengthChecker.check('Abcdef1!'),
        PasswordStrength.veryStrong,
      );
      expect(
        PasswordStrengthChecker.check('P@ssw0rdXY'),
        PasswordStrength.veryStrong,
      );
    });

    test('strength labels and ordering', () {
      expect(PasswordStrength.none.label, '');
      expect(PasswordStrength.weak.label, 'Weak');
      expect(PasswordStrength.medium.label, 'Medium');
      expect(PasswordStrength.strong.label, 'Strong');
      expect(PasswordStrength.veryStrong.label, 'Very Strong');
      expect(
        PasswordStrength.weak.index < PasswordStrength.veryStrong.index,
        isTrue,
      );
    });
  });

  group('kDefaultPasswordRules', () {
    PasswordRule ruleFor(String label) =>
        kDefaultPasswordRules.firstWhere((r) => r.label == label);

    test('covers five expected rules', () {
      expect(kDefaultPasswordRules.length, 5);
    });

    test('min length rule', () {
      final rule = ruleFor('At least 8 characters');
      expect(rule.test('1234567'), isFalse);
      expect(rule.test('12345678'), isTrue);
    });

    test('uppercase rule', () {
      final rule = ruleFor('An uppercase letter');
      expect(rule.test('abc'), isFalse);
      expect(rule.test('aBc'), isTrue);
    });

    test('lowercase rule', () {
      final rule = ruleFor('A lowercase letter');
      expect(rule.test('ABC'), isFalse);
      expect(rule.test('ABc'), isTrue);
    });

    test('number rule', () {
      final rule = ruleFor('A number');
      expect(rule.test('abc'), isFalse);
      expect(rule.test('abc9'), isTrue);
    });

    test('special character rule', () {
      final rule = ruleFor('A special character');
      expect(rule.test('abc123'), isFalse);
      expect(rule.test('abc!'), isTrue);
      expect(rule.test('a-b'), isTrue);
    });
  });

  group('CmxPasswordField widget', () {
    testWidgets('toggles obscureText via the eye button', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: CmxPasswordField(label: 'Password'),
          ),
        ),
      );

      await tester.enterText(find.byType(TextField), 'secret');
      await tester.pump();

      TextField field() => tester.widget<TextField>(find.byType(TextField));
      expect(field().obscureText, isTrue);

      // Eye-off icon visible initially (obscured).
      expect(find.byIcon(Icons.visibility_off_outlined), findsOneWidget);

      await tester.tap(find.byType(IconButton));
      await tester.pumpAndSettle();

      expect(field().obscureText, isFalse);
      expect(find.byIcon(Icons.visibility_outlined), findsOneWidget);
    });

    testWidgets('strength bar/label updates as text is entered',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: CmxPasswordField(label: 'Password'),
          ),
        ),
      );

      StrengthIndicator indicator() =>
          tester.widget<StrengthIndicator>(find.byType(StrengthIndicator));

      expect(indicator().strength, PasswordStrength.none);

      await tester.enterText(find.byType(TextField), 'abc');
      await tester.pump();
      expect(indicator().strength, PasswordStrength.weak);
      expect(find.text('Weak'), findsOneWidget);

      await tester.enterText(find.byType(TextField), 'Abcdef1!');
      await tester.pump();
      expect(indicator().strength, PasswordStrength.veryStrong);
      expect(find.text('Very Strong'), findsOneWidget);
    });

    testWidgets('shows rules checklist when showRules is true', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: CmxPasswordField(label: 'Password', showRules: true),
          ),
        ),
      );

      expect(find.byType(PasswordRulesChecklist), findsOneWidget);
      expect(find.text('At least 8 characters'), findsOneWidget);
    });
  });

  group('CmxPasswordField in a Form', () {
    testWidgets('minStrength produces a validation error', (tester) async {
      final formKey = GlobalKey<FormState>();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Form(
              key: formKey,
              child: const CmxPasswordField(
                label: 'Password',
                minStrength: PasswordStrength.strong,
              ),
            ),
          ),
        ),
      );

      // Weak password fails minStrength.
      await tester.enterText(find.byType(TextField), 'abc');
      await tester.pump();

      expect(formKey.currentState!.validate(), isFalse);
      await tester.pumpAndSettle();
      expect(find.textContaining('too weak'), findsOneWidget);

      // A strong password passes.
      await tester.enterText(find.byType(TextField), 'abcdefg1');
      await tester.pump();
      expect(formKey.currentState!.validate(), isTrue);
      await tester.pumpAndSettle();
      expect(find.textContaining('too weak'), findsNothing);
    });
  });
}
