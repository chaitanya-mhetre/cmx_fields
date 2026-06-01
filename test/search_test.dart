import 'package:cmx_fields/src/fields/cmx_search_field.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _wrap(Widget child) {
  return MaterialApp(
    home: Scaffold(
      body: Padding(padding: const EdgeInsets.all(24), child: child),
    ),
  );
}

void main() {
  group('CmxSearchField debounce', () {
    testWidgets(
        'onDebouncedChanged fires once after the debounce, not '
        'on every keystroke', (tester) async {
      final debounced = <String>[];
      final immediate = <String>[];
      await tester.pumpWidget(
        _wrap(
          CmxSearchField(
            debounceDuration: const Duration(milliseconds: 300),
            onChanged: immediate.add,
            onDebouncedChanged: debounced.add,
          ),
        ),
      );

      await tester.enterText(find.byType(TextField), 'a');
      await tester.pump(const Duration(milliseconds: 100));
      await tester.enterText(find.byType(TextField), 'ab');
      await tester.pump(const Duration(milliseconds: 100));
      await tester.enterText(find.byType(TextField), 'abc');

      // Still inside the debounce window since the last keystroke.
      await tester.pump(const Duration(milliseconds: 100));
      expect(debounced, isEmpty);
      // onChanged fires immediately on every keystroke.
      expect(immediate, <String>['a', 'ab', 'abc']);

      // Cross the debounce threshold.
      await tester.pump(const Duration(milliseconds: 250));
      expect(debounced, <String>['abc']);
    });
  });

  group('CmxSearchField async suggestions', () {
    testWidgets(
        'shows loading spinner then results; tapping fills field and '
        'fires onSuggestionTap', (tester) async {
      String? tapped;
      await tester.pumpWidget(
        _wrap(
          CmxSearchField(
            debounceDuration: const Duration(milliseconds: 200),
            onSuggestionTap: (s) => tapped = s,
            onSearch: (q) async {
              await Future<void>.delayed(const Duration(milliseconds: 500));
              return ['$q apple', '$q banana'];
            },
          ),
        ),
      );

      await tester.tap(find.byType(TextField));
      await tester.enterText(find.byType(TextField), 'fr');
      // Advance past the debounce so onSearch starts.
      await tester.pump(const Duration(milliseconds: 250));

      // Future is pending: spinner shows, no results yet.
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text('fr apple'), findsNothing);

      // Resolve the future.
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump();

      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(find.text('fr apple'), findsOneWidget);
      expect(find.text('fr banana'), findsOneWidget);

      await tester.tap(find.text('fr banana'));
      await tester.pump();

      expect(tapped, 'fr banana');
      expect(
        tester.widget<TextField>(find.byType(TextField)).controller!.text,
        'fr banana',
      );
      // Overlay closed after tap.
      expect(find.text('fr apple'), findsNothing);
    });

    testWidgets('respects maxSuggestions', (tester) async {
      await tester.pumpWidget(
        _wrap(
          CmxSearchField(
            maxSuggestions: 2,
            debounceDuration: const Duration(milliseconds: 100),
            onSearch: (q) async => List.generate(10, (i) => 'item $i'),
          ),
        ),
      );

      await tester.tap(find.byType(TextField));
      await tester.enterText(find.byType(TextField), 'x');
      await tester.pump(const Duration(milliseconds: 150));
      await tester.pump();

      expect(find.text('item 0'), findsOneWidget);
      expect(find.text('item 1'), findsOneWidget);
      expect(find.text('item 2'), findsNothing);
    });

    testWidgets('discards stale out-of-order results', (tester) async {
      await tester.pumpWidget(
        _wrap(
          CmxSearchField(
            debounceDuration: const Duration(milliseconds: 50),
            onSearch: (q) async {
              // First query ("a") is slow; second ("ab") is fast.
              final delay = q == 'a' ? 400 : 50;
              await Future<void>.delayed(Duration(milliseconds: delay));
              return ['result for $q'];
            },
          ),
        ),
      );

      await tester.tap(find.byType(TextField));
      await tester.enterText(find.byType(TextField), 'a');
      await tester.pump(const Duration(milliseconds: 60)); // debounce -> q="a"
      await tester.enterText(find.byType(TextField), 'ab');
      await tester.pump(const Duration(milliseconds: 60)); // debounce -> q="ab"

      // Let the fast "ab" query resolve.
      await tester.pump(const Duration(milliseconds: 60));
      await tester.pump();
      expect(find.text('result for ab'), findsOneWidget);

      // Now let the slow stale "a" query resolve; it must be ignored.
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pump();
      expect(find.text('result for a'), findsNothing);
      expect(find.text('result for ab'), findsOneWidget);
    });
  });

  group('CmxSearchField recent searches', () {
    testWidgets('shows recent searches under header when focused and empty',
        (tester) async {
      String? tapped;
      await tester.pumpWidget(
        _wrap(
          CmxSearchField(
            recentSearches: const ['hello', 'world'],
            onSuggestionTap: (s) => tapped = s,
          ),
        ),
      );

      await tester.tap(find.byType(TextField));
      await tester.pump();

      expect(find.text('Recent'), findsOneWidget);
      expect(find.text('hello'), findsOneWidget);
      expect(find.text('world'), findsOneWidget);

      await tester.tap(find.text('hello'));
      await tester.pump();

      expect(tapped, 'hello');
      expect(
        tester.widget<TextField>(find.byType(TextField)).controller!.text,
        'hello',
      );
    });
  });

  group('CmxSearchField clear button', () {
    testWidgets('clear button empties the field', (tester) async {
      await tester.pumpWidget(
        _wrap(const CmxSearchField()),
      );

      await tester.enterText(find.byType(TextField), 'query');
      await tester.pumpAndSettle();

      final clearButton =
          find.byKey(const ValueKey<String>('cmx-search-clear'));
      expect(clearButton, findsOneWidget);

      await tester.tapAt(tester.getCenter(find.byIcon(Icons.close)));
      await tester.pumpAndSettle();

      expect(
        tester.widget<TextField>(find.byType(TextField)).controller!.text,
        '',
      );
    });

    testWidgets('clear button is absent when empty', (tester) async {
      await tester.pumpWidget(_wrap(const CmxSearchField()));
      await tester.pump();
      expect(
        find.byKey(const ValueKey<String>('cmx-search-clear')),
        findsNothing,
      );
    });
  });

  testWidgets('disposes cleanly with a pending debounce timer', (tester) async {
    await tester.pumpWidget(
      _wrap(
        const CmxSearchField(debounceDuration: Duration(seconds: 5)),
      ),
    );
    await tester.enterText(find.byType(TextField), 'pending');
    await tester.pump();
    // Replace the widget; pending timer must be cancelled in dispose.
    await tester.pumpWidget(_wrap(const SizedBox.shrink()));
    await tester.pump();
    expect(tester.takeException(), isNull);
  });
}
