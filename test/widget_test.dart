import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zjulife/app.dart';
import 'package:zjulife/providers/auth_provider.dart';
import 'package:zjulife/providers/campus_provider.dart';
import 'package:zjulife/providers/theme_provider.dart';
import 'package:zjulife/providers/favorites_provider.dart';

void main() {
  late Directory hiveDir;

  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
    await initializeDateFormatting('zh_CN', null);
    hiveDir = await Directory.systemTemp.createTemp('zjulife_widget_test_');
    Hive.init(hiveDir.path);
  });

  tearDownAll(() async {
    await Hive.close();
    if (await hiveDir.exists()) {
      await hiveDir.delete(recursive: true);
    }
  });

  testWidgets('App loads correctly', (WidgetTester tester) async {
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
    expect(find.text('首页'), findsOneWidget);
  });
}
