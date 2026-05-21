import 'dart:convert';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:html/parser.dart' as html_parser;
import 'package:pointycastle/export.dart';
import '../utils/dio_exception_handler.dart';

/// ZJU CAS 统一身份认证服务
class AuthService {
  static AuthService? _instance;
  late final Dio _dio;

  static const String _casBaseUrl = 'https://zjuam.zju.edu.cn/cas';
  static const String _casLoginUrl = '$_casBaseUrl/login';
  static const String _pubkeyUrl = '$_casBaseUrl/v2/getPubKey';

  // 图书馆预约系统
  static const String _bookingBaseUrl = 'https://booking.lib.zju.edu.cn';
  static const String _libraryServiceUrl = '$_bookingBaseUrl/h5/';
  static const String _libraryCasApi = '$_bookingBaseUrl/api/cas/user';

  AuthService._() {
    _dio = Dio(BaseOptions(
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 15),
      followRedirects: false,
      validateStatus: (status) => status != null && status < 500,
    ));

    _dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) {
        options.headers['User-Agent'] =
            'Mozilla/5.0 (Linux; Android 10) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Mobile Safari/537.36';
        options.headers['Accept'] =
            'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8';
        options.headers['Accept-Language'] = 'zh-CN,zh;q=0.9,en;q=0.8';
        return handler.next(options);
      },
    ));
  }

  static AuthService get instance {
    _instance ??= AuthService._();
    return _instance!;
  }

  /// 登录 CAS 系统
  Future<LoginResult> login(String username, String password) async {
    try {
      final loginPageResponse = await _dio.get(_casLoginUrl);

      final document = html_parser.parse(loginPageResponse.data);
      final executionInput = document.querySelector('input[name="execution"]');
      final execution = executionInput?.attributes['value'] ?? '';

      if (execution.isEmpty) {
        throw AuthException('无法获取登录参数，请稍后重试');
      }

      final setCookieHeaders = loginPageResponse.headers['set-cookie'];
      String cookies = '';
      if (setCookieHeaders != null) {
        cookies = setCookieHeaders.map((c) => c.split(';')[0]).join('; ');
      }

      final pubkeyResponse = await _dio.get(
        _pubkeyUrl,
        options: Options(headers: {'Cookie': cookies}),
      );

      String encryptedPassword = password;
      if (pubkeyResponse.statusCode == 200 && pubkeyResponse.data != null) {
        try {
          final pubkeyData = pubkeyResponse.data is String
              ? json.decode(pubkeyResponse.data)
              : pubkeyResponse.data;
          final modulus = pubkeyData['modulus'] as String?;
          final exponent = pubkeyData['exponent'] as String?;
          if (modulus != null && exponent != null) {
            encryptedPassword = _rsaEncrypt(password, modulus, exponent);
          }
        } catch (_) {}
      }

      final loginResponse = await _dio.post(
        _casLoginUrl,
        data: {
          'username': username,
          'password': encryptedPassword,
          'execution': execution,
          '_eventId': 'submit',
          'geolocation': '',
        },
        options: Options(
          headers: {
            'Cookie': cookies,
            'Content-Type': 'application/x-www-form-urlencoded',
            'Origin': 'https://zjuam.zju.edu.cn',
            'Referer': _casLoginUrl,
          },
          followRedirects: false,
        ),
      );

      if (loginResponse.statusCode == 302) {
        final newCookies = loginResponse.headers['set-cookie'];
        if (newCookies != null) {
          final newCookieStr =
              newCookies.map((c) => c.split(';')[0]).join('; ');
          cookies = '$cookies; $newCookieStr';
        }

        return LoginResult(
          success: true,
          userId: username,
          userName: username,
          cookie: cookies,
        );
      }

      final errorDoc = html_parser.parse(loginResponse.data);
      final errorSpan = errorDoc.querySelector('#msg') ??
          errorDoc.querySelector('.login-error') ??
          errorDoc.querySelector('.alert-danger');
      final errorMsg = errorSpan?.text.trim() ?? '登录失败，请检查用户名和密码';

      throw AuthException(errorMsg);
    } catch (e) {
      if (e is AuthException) rethrow;
      if (e is DioException) {
        return DioExceptionHandler.handle(e,
            context: '登录失败', exceptionType: AuthException);
      }
      throw AuthException('登录失败: $e');
    }
  }

  /// 通过 CAS Cookie 获取图书馆预约系统的 JWT Token
  ///
  /// 流程：CAS TGT Cookie → Service Ticket → POST /api/cas/user → JWT
  Future<String?> getLibraryJwt(String casCookie) async {
    try {
      // Step 1: 用 TGT Cookie 向 CAS 请求针对图书馆系统的 Service Ticket
      final serviceParam = Uri.encodeComponent(_libraryServiceUrl);
      final ticketResponse = await _dio.get(
        '$_casLoginUrl?service=$serviceParam',
        options: Options(
          headers: {'Cookie': casCookie},
          followRedirects: false,
          validateStatus: (s) => s != null && s < 500,
        ),
      );

      if (ticketResponse.statusCode != 302) return null;

      final location = ticketResponse.headers['location']?.first;
      if (location == null) return null;

      // Step 2: 从重定向 URL 提取 ticket
      final uri = Uri.tryParse(location);
      if (uri == null) return null;
      final ticket = uri.queryParameters['ticket'];
      if (ticket == null || ticket.isEmpty) return null;

      // Step 3: 将 ticket POST 给图书馆后端换取 JWT
      final jwtResponse = await _dio.post(
        _libraryCasApi,
        data: {'cas': ticket},
        options: Options(
          headers: {
            'Content-Type': 'application/json',
            'Referer': '$_bookingBaseUrl/h5/',
            'Origin': _bookingBaseUrl,
          },
          validateStatus: (s) => s != null && s < 500,
        ),
      );

      if (jwtResponse.statusCode != 200 || jwtResponse.data == null) {
        return null;
      }

      final data = jwtResponse.data is String
          ? json.decode(jwtResponse.data)
          : jwtResponse.data;

      if (data is Map && data['code'] == 1) {
        return data['member']?['token']?.toString();
      }

      return null;
    } catch (_) {
      return null;
    }
  }

  String _rsaEncrypt(String password, String modulusHex, String exponentHex) {
    try {
      final modulus = BigInt.parse(modulusHex, radix: 16);
      final exponent = BigInt.parse(exponentHex, radix: 16);
      final publicKey = RSAPublicKey(modulus, exponent);

      final encryptor = PKCS1Encoding(RSAEngine())
        ..init(true, PublicKeyParameter<RSAPublicKey>(publicKey));

      final dataToEncrypt = Uint8List.fromList(utf8.encode(password));
      final encrypted = encryptor.process(dataToEncrypt);
      return base64.encode(encrypted);
    } catch (_) {
      return password;
    }
  }
}

class LoginResult {
  final bool success;
  final String userId;
  final String userName;
  final String? cookie;
  final String? ticket;

  LoginResult({
    required this.success,
    required this.userId,
    required this.userName,
    this.cookie,
    this.ticket,
  });
}

class AuthException implements Exception {
  final String message;

  AuthException(this.message);

  @override
  String toString() => message;
}
