// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

// Package imports:
import 'package:flutter_test/flutter_test.dart';

// Project imports:
import 'package:lpulive_unofficial/pages/login_page.dart';

void main() {
  testWidgets('Login screen loads correctly', (
    WidgetTester tester,
  ) async {
    // Build the login app
    await tester.pumpWidget(const LoginApp());

    // Wait for the app to settle (including async checks)
    await tester.pumpAndSettle(const Duration(seconds: 1));

    // Verify that the login screen appears
    expect(find.text('Welcome back'), findsOneWidget);
    expect(find.text('Sign in with your university credentials'), findsOneWidget);
    expect(find.text('Sign in'), findsOneWidget);
  });
}
