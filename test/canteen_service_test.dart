import 'package:flutter_test/flutter_test.dart';
import 'package:zjulife/services/canteen_service.dart';

void main() {
  group('CanteenService missing data message', () {
    test('uses local proxy hint for default web proxy URL', () {
      final exception = CanteenService.missingCanteenDataExceptionForTesting(
        isWeb: true,
        proxyUrl: 'http://127.0.0.1:51989/canteen/general_new.php',
      );

      expect(
        exception.toString(),
        '食堂本地代理未启动，请先运行 node tool/library_proxy.mjs',
      );
    });

    test('uses proxy config hint for custom web proxy URL', () {
      final exception = CanteenService.missingCanteenDataExceptionForTesting(
        isWeb: true,
        proxyUrl: 'https://proxy.example.com/canteen/general_new.php',
      );

      expect(exception.toString(), '食堂代理不可达，请检查 CANTEEN_PROXY_URL 配置');
    });

    test('uses campus network hint outside web', () {
      final exception = CanteenService.missingCanteenDataExceptionForTesting(
        isWeb: false,
        proxyUrl: '',
      );

      expect(exception.toString(), '网络连接失败，请连接校园网');
    });
  });
}
