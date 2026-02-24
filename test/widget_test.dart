// This is a basic Flutter widget test for Chatly app.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:chatly/main.dart';

void main() {
  testWidgets('Chatly app starts without errors', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const ChatlyApp());

    // Verify that the app starts without throwing any exceptions
    expect(find.byType(MaterialApp), findsOneWidget);
  });
}
