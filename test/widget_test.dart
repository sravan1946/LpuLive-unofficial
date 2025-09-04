// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

  import 'package:flutter_test/flutter_test.dart';
  import 'package:lpulive_unofficial/pages/token_input_page.dart';
  import 'package:lpulive_unofficial/pages/chat_home_page.dart';

 void main() {
   testWidgets('Token input screen loads correctly', (WidgetTester tester) async {
     // Build the token input app
     await tester.pumpWidget(const TokenInputApp());

     // Wait for the app to settle (including async token check)
     await tester.pumpAndSettle(const Duration(seconds: 2));

     // Verify that the token input screen appears
     expect(find.text('Welcome to LPU Live Chat'), findsOneWidget);
     expect(find.text('Please enter your authentication token to continue'), findsOneWidget);
     expect(find.text('Continue to Chat'), findsOneWidget);
   });

    testWidgets('Chat app loads correctly', (WidgetTester tester) async {
      // Build our chat app
      await tester.pumpWidget(const MyApp());

      // Wait for the app to settle
      await tester.pumpAndSettle();

      // Verify that the chat home page appears
      expect(find.text('University Groups'), findsOneWidget);
      expect(find.text('No University Courses'), findsOneWidget);
    });
 }
