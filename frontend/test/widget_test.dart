import 'package:academy_erp_frontend/main.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('Academy ERP login screen is displayed', (WidgetTester tester) async {
    await tester.pumpWidget(const AcademyErpApp());

    expect(find.text('Welcome to Academy ERP'), findsOneWidget);
    expect(find.text('Email address'), findsOneWidget);
    expect(find.text('Password'), findsOneWidget);
    expect(find.text('Sign in'), findsOneWidget);
  });

  testWidgets('Login validation messages appear for empty fields',
          (WidgetTester tester) async {
        await tester.pumpWidget(const AcademyErpApp());

        await tester.tap(find.text('Sign in'));
        await tester.pump();

        expect(find.text('Please enter your email address.'), findsOneWidget);
        expect(find.text('Please enter your password.'), findsOneWidget);
      });
}