import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zjulife/providers/auth_provider.dart';

void main() {
  group('AuthProvider', () {
    test('loginWithCas removes stale auth cookie and library JWT', () async {
      SharedPreferences.setMockInitialValues({
        'is_authenticated': true,
        'user_id': 'old-user',
        'user_name': 'Old User',
        'auth_cookie': 'old-cookie',
        'library_jwt': 'old-library-jwt',
      });

      final provider = AuthProvider();
      await provider.ready;

      expect(provider.authCookie, 'old-cookie');
      expect(provider.libraryJwt, 'old-library-jwt');

      await provider.loginWithCas(
        userId: 'new-user',
        userName: 'New User',
        cookie: null,
      );

      final prefs = await SharedPreferences.getInstance();
      expect(provider.authCookie, isNull);
      expect(provider.libraryJwt, isNull);
      expect(prefs.getString('auth_cookie'), isNull);
      expect(prefs.getString('library_jwt'), isNull);
    });
  });
}
