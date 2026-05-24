import 'package:flutter_test/flutter_test.dart';
import 'package:zjulife/services/auth_service.dart';

void main() {
  group('AuthService library auth helpers', () {
    test('extracts CAS ticket from query string', () {
      expect(
        AuthService.extractTicketFromLocation(
          'https://booking.lib.zju.edu.cn/h5/?ticket=ST-QUERY-123',
        ),
        'ST-QUERY-123',
      );
    });

    test('extracts CAS ticket from hash query string', () {
      expect(
        AuthService.extractTicketFromLocation(
          'https://booking.lib.zju.edu.cn/h5/#/cas/?cas=ST-HASH-456',
        ),
        'ST-HASH-456',
      );
    });

    test('returns null when location has no ticket', () {
      expect(
        AuthService.extractTicketFromLocation(
          'https://booking.lib.zju.edu.cn/h5/#/study',
        ),
        isNull,
      );
    });

    test('keeps CAS login path for official auth redirects', () {
      expect(
        AuthService.casLoginPathFromLocation(
          'https://zjuam.zju.edu.cn/cas/login?service=https%3A%2F%2Fbooking.lib.zju.edu.cn%2Fh5%2F',
        ),
        '/cas/login?service=https%3A%2F%2Fbooking.lib.zju.edu.cn%2Fh5%2F',
      );
    });

    test('rejects non CAS hosts when deriving login path', () {
      expect(
        AuthService.casLoginPathFromLocation(
          'https://booking.lib.zju.edu.cn/h5/#/cas',
        ),
        isEmpty,
      );
    });
  });
}
