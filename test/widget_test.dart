import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:culinary_coach_app/app/shell/presentation/screens/main_shell_screen.dart';

void main() {
  testWidgets('shell displays the custom bottom navigation', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: MainShellScreen()));

    expect(find.text('Home'), findsOneWidget);
    expect(find.text('Shop'), findsOneWidget);
    expect(find.text('My Recipes'), findsOneWidget);
    expect(find.text('Community'), findsOneWidget);
    expect(find.byIcon(Icons.add_rounded), findsOneWidget);
  });
}
