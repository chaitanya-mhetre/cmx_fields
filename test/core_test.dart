import 'package:cmx_fields/cmx_fields.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('CmxValidators', () {
    test('required rejects null/empty/whitespace, accepts content', () {
      final v = CmxValidators.required();
      expect(v(null), isNotNull);
      expect(v(''), isNotNull);
      expect(v('   '), isNotNull);
      expect(v('x'), isNull);
    });

    test('email validates format and lets empty pass', () {
      final v = CmxValidators.email();
      expect(v(''), isNull);
      expect(v('not-an-email'), isNotNull);
      expect(v('a@b'), isNotNull);
      expect(v('user@example.com'), isNull);
    });

    test('minLength / maxLength', () {
      expect(CmxValidators.minLength(3)('ab'), isNotNull);
      expect(CmxValidators.minLength(3)('abc'), isNull);
      expect(CmxValidators.maxLength(3)('abcd'), isNotNull);
      expect(CmxValidators.maxLength(3)('abc'), isNull);
    });

    test('match compares against a live getter', () {
      var other = 'secret';
      final v = CmxValidators.match(() => other);
      expect(v('secret'), isNull);
      other = 'changed';
      expect(v('secret'), isNotNull);
    });

    test('compose returns the first error in order', () {
      final v = CmxValidators.compose<String>([
        CmxValidators.required('need it'),
        CmxValidators.minLength(5, 'too short'),
      ]);
      expect(v(''), 'need it');
      expect(v('ab'), 'too short');
      expect(v('abcdef'), isNull);
    });
  });

  group('CmxFieldTheme', () {
    test('copyWith overrides only provided fields', () {
      const base = CmxFieldTheme();
      final next =
          base.copyWith(borderRadius: 99, borderStyle: CmxBorderStyle.rounded);
      expect(next.borderRadius, 99);
      expect(next.borderStyle, CmxBorderStyle.rounded);
      expect(next.focusedColor, base.focusedColor);
    });

    test('equality and hashCode are value-based', () {
      const a = CmxFieldTheme(borderRadius: 10);
      const b = CmxFieldTheme(borderRadius: 10);
      const c = CmxFieldTheme(borderRadius: 12);
      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
      expect(a, isNot(equals(c)));
    });
  });

  group('CmxFieldThemeProvider', () {
    testWidgets('of returns inherited theme or default', (tester) async {
      late CmxFieldTheme inherited;
      late CmxFieldTheme fallback;

      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              fallback = CmxFieldThemeProvider.of(context);
              return CmxFieldThemeProvider(
                theme: const CmxFieldTheme(borderRadius: 42),
                child: Builder(
                  builder: (inner) {
                    inherited = CmxFieldThemeProvider.of(inner);
                    return const SizedBox();
                  },
                ),
              );
            },
          ),
        ),
      );

      expect(fallback.borderRadius, const CmxFieldTheme().borderRadius);
      expect(inherited.borderRadius, 42);
    });
  });

  group('CmxFieldStatus', () {
    test('getters reflect the variant', () {
      expect(CmxFieldStatus.error.isError, isTrue);
      expect(CmxFieldStatus.focused.isFocused, isTrue);
      expect(CmxFieldStatus.valid.isValid, isTrue);
      expect(CmxFieldStatus.disabled.isDisabled, isTrue);
      expect(CmxFieldStatus.loading.isLoading, isTrue);
      expect(CmxFieldStatus.idle.isError, isFalse);
    });
  });

  group('CmxCheckmark', () {
    testWidgets('builds without error in both visibility states',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                CmxCheckmark(visible: true, color: Colors.green),
                CmxCheckmark(visible: false, color: Colors.green),
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(CmxCheckmark), findsNWidgets(2));
    });
  });
}
