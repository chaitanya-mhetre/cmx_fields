// Smoke test for the cmx_fields showcase app.

import 'package:cmx_fields_example/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('gallery launches and switches tabs', (tester) async {
    await tester.pumpWidget(const CmxFieldsDemoApp());
    await tester.pump();

    // The first tab (Phone) is shown.
    expect(find.text('cmx_fields'), findsOneWidget);
    expect(find.byType(TabBar), findsOneWidget);

    // Switch to the Password tab and confirm its page renders.
    await tester.tap(find.text('Password').first);
    await tester.pumpAndSettle();
    expect(find.text('Confirm password'), findsOneWidget);
  });
}
