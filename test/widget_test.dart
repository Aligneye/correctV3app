// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:correctv1/main.dart';

void main() {
  testWidgets('shows configuration screen when Supabase is not configured', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const MyApp(isSupabaseConfigured: false));

    expect(find.text('Supabase is not configured'), findsOneWidget);
    expect(find.byIcon(Icons.lock_outline_rounded), findsOneWidget);
  });
}
