// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zjulife/app.dart';
import 'package:zjulife/config/routes.dart';
import 'package:zjulife/providers/auth_provider.dart';
import 'package:zjulife/providers/campus_provider.dart';
import 'package:zjulife/providers/theme_provider.dart';
import 'package:zjulife/providers/favorites_provider.dart';

void main() {
  testWidgets('App loads correctly', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    appRouter.go('/login');
    addTearDown(() => appRouter.go('/'));

    // Build our app and trigger a frame.
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => ThemeProvider()),
          ChangeNotifierProvider(create: (_) => AuthProvider()),
          ChangeNotifierProvider(create: (_) => FavoritesProvider()),
          ChangeNotifierProvider(create: (_) => CampusProvider()),
        ],
        child: const ZJULifeApp(),
      ),
    );

    // Verify that the app loads
    expect(find.text('统一身份认证'), findsOneWidget);
  });
}
