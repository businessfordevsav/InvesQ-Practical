import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:invesq_practical/main.dart';

void main() {
  testWidgets('App initialization test', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const MyApp());

    // Verify that app initializes with splash screen
    expect(find.text('InvesQ Practical'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });
}
