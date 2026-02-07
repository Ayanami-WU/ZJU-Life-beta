// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:zjulife/app.dart';
import 'package:zjulife/providers/auth_provider.dart';
import 'package:zjulife/providers/theme_provider.dart';
import 'package:zjulife/providers/favorites_provider.dart';

void main() {
  testWidgets('App loads correctly', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => ThemeProvider()),
          ChangeNotifierProvider(create: (_) => AuthProvider()),
          ChangeNotifierProvider(create: (_) => FavoritesProvider()),
        ],
        child: const ZJULifeApp(),
      ),
    );

    // Verify that the app loads
    expect(find.text('浙大生活'), findsOneWidget);
  });
}
