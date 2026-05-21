import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:html/parser.dart' as html_parser;
import '../config/constants.dart';

/// ZJU CAS 统一身份认证服务
class AuthService {
  static AuthService? _instance;
  late final Dio _dio;

  static const String _casBaseUrl = 'https://zjuam.zju.edu.cn/cas';
  static const String _casLoginUrl = '$_casBaseUrl/login';
  static const String _pubkeyUrl = '$_casBaseUrl/v2/getPubKey';
  static const String _bookingBaseUrl = 'https://booking.lib.zju.edu.cn';
  static const String _libraryServiceUrl = '$_bookingBaseUrl/h5/';
  static const String _libraryCasApi = '$_bookingBaseUrl/api/cas/user';

  static String casLoginUrlForService(String service) {
    return '$_casLoginUrl?service=${Uri.encodeComponent(service)}';
  }

  AuthService._() {
    _dio = Dio(BaseOptions(
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 15),
      followRedirects: false,
      validateStatus: (status) => status != null && status < 500,
    ));

    _dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) {
        options.headers.putIfAbsent(
          'User-Agent',
          () =>
              'Mozilla/5.0 (Linux; Android 10) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Mobile Safari/537.36',
        );
        options.headers.putIfAbsent(
          'Accept',
          () =>
              'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
        );
        options.headers.putIfAbsent(
          'Accept-Language',
          () => 'zh-CN,zh;q=0.9,en;q=0.8',
        );
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
    if (kIsWeb) {
      return _loginWithLocalProxy(username, password);
    }

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
          'authcode': '',
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
      if (e is DioException) throw AuthException(_dioErrorMessage(e));
      throw AuthException('登录失败: $e');
    }
  }

  Future<LoginResult> _loginWithLocalProxy(
    String username,
    String password,
  ) async {
    try {
      final response = await _dio.post(
        '${ApiConfig.localLibraryProxyUrl}/auth/login',
        data: {
          'username': username,
          'password': password,
        },
        options: Options(
          headers: {
            'Accept': 'application/json',
            'Content-Type': 'application/json',
          },
          validateStatus: (status) => status != null && status < 500,
        ),
      );

      final data =
          response.data is String ? json.decode(response.data) : response.data;
      if (data is! Map) {
        throw AuthException('登录响应格式异常');
      }

      if (response.statusCode != 200 || data['success'] != true) {
        throw AuthException(data['message']?.toString() ?? '登录失败');
      }

      return LoginResult(
        success: true,
        userId: data['userId']?.toString() ?? username,
        userName: data['userName']?.toString() ?? username,
        cookie: data['cookie']?.toString(),
        ticket: data['ticket']?.toString(),
        libraryJwt: data['libraryJwt']?.toString(),
      );
    } catch (e) {
      if (e is AuthException) rethrow;
      if (e is DioException) throw AuthException(_dioErrorMessage(e));
      throw AuthException('登录失败: $e');
    }
  }

  String _dioErrorMessage(DioException e) {
    switch (e.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.receiveTimeout:
      case DioExceptionType.sendTimeout:
        return '连接超时，请检查本地代理和网络';
      case DioExceptionType.connectionError:
        return '无法连接本地登录代理，请确认 51989 代理已启动';
      case DioExceptionType.badResponse:
        return '登录服务响应错误 (${e.response?.statusCode ?? "未知"})';
      case DioExceptionType.cancel:
        return '请求已取消';
      case DioExceptionType.badCertificate:
        return '证书验证失败';
      case DioExceptionType.unknown:
        return '网络错误: ${e.message ?? "未知错误"}';
    }
  }

  /// 使用已有 CAS Cookie 为图书馆预约系统换取访问 Token。
  Future<String?> getLibraryJwt(String casCookie) async {
    try {
      final serviceParam = Uri.encodeComponent(_libraryServiceUrl);
      final ticketResponse = await _dio.get(
        '$_casLoginUrl?service=$serviceParam',
        options: Options(
          headers: {'Cookie': casCookie},
          followRedirects: false,
          validateStatus: (status) => status != null && status < 500,
        ),
      );

      if (ticketResponse.statusCode != 302) return null;

      final location = ticketResponse.headers['location']?.first;
      final uri = Uri.tryParse(location ?? '');
      final ticket =
          uri?.queryParameters['cas'] ?? uri?.queryParameters['ticket'];
      if (ticket == null || ticket.isEmpty) return null;

      return exchangeLibraryTicket(ticket);
    } catch (_) {
      return null;
    }
  }

  /// 将 CAS ticket 兑换为图书馆预约系统 Token。
  Future<String?> exchangeLibraryTicket(String ticket) async {
    try {
      const endpoint = kIsWeb
          ? '${ApiConfig.localLibraryProxyUrl}/api/cas/user'
          : _libraryCasApi;
      final jwtResponse = await _dio.post(
        endpoint,
        data: {'cas': ticket},
        options: Options(
          headers: {
            'Accept': 'application/json, text/plain, */*',
            'Content-Type': 'application/json',
            'Referer': _libraryServiceUrl,
            'Origin': _bookingBaseUrl,
          },
          validateStatus: (status) => status != null && status < 500,
        ),
      );

      final data = jwtResponse.data is String
          ? json.decode(jwtResponse.data)
          : jwtResponse.data;
      if (data is! Map) return null;

      if (jwtResponse.statusCode != 200) return null;

      final code = data['code']?.toString();
      if (code != null && code.isNotEmpty && code != '0' && code != '1') {
        return null;
      }

      return _extractLibraryToken(data);
    } catch (_) {
      return null;
    }
  }

  String? _extractLibraryToken(dynamic value, {bool allowPlainString = false}) {
    if (allowPlainString) {
      final token = _tokenString(value);
      if (token != null) return token;
    }

    if (value is Iterable) {
      for (final item in value) {
        final nested = _extractLibraryToken(item);
        if (nested != null) return nested;
      }
      return null;
    }

    if (value is! Map) return null;

    const tokenKeys = {
      'token',
      'access_token',
      'accesstoken',
      'jwt',
      'authorization',
    };
    const trustedStringKeys = {'member', 'data'};

    for (final entry in value.entries) {
      final key = entry.key.toString();
      final normalized = key.toLowerCase();
      if (tokenKeys.contains(normalized)) {
        final direct = _extractLibraryToken(
          entry.value,
          allowPlainString: true,
        );
        if (direct != null) return direct;
      }
    }

    for (final key in trustedStringKeys) {
      if (!value.containsKey(key)) continue;
      final direct = _extractLibraryToken(
        value[key],
        allowPlainString: true,
      );
      if (direct != null) return direct;
    }

    for (final item in value.values) {
      final nested = _extractLibraryToken(item);
      if (nested != null) return nested;
    }

    return null;
  }

  String? _tokenString(dynamic value) {
    if (value is! String) return null;
    final token = value.trim();
    return token.length < 16 ? null : token;
  }

  String _rsaEncrypt(String password, String modulusHex, String exponentHex) {
    try {
      final modulus = BigInt.parse(modulusHex, radix: 16);
      final exponent = BigInt.parse(exponentHex, radix: 16);
      final modulusWords = (modulusHex.length / 4).ceil();
      final rawChunkSize = 2 * (modulusWords - 1);
      final chunkSize = rawChunkSize < 2 ? 2 : rawChunkSize;
      final codeUnits = password.split('').reversed.join().codeUnits.toList();

      while (codeUnits.length % chunkSize != 0) {
        codeUnits.add(0);
      }

      final blocks = <String>[];
      for (var start = 0; start < codeUnits.length; start += chunkSize) {
        var block = BigInt.zero;
        var digit = 0;
        for (var offset = 0; offset < chunkSize; offset += 2) {
          final low = codeUnits[start + offset];
          final high = start + offset + 1 < codeUnits.length
              ? codeUnits[start + offset + 1]
              : 0;
          block += BigInt.from(low + (high << 8)) << (16 * digit);
          digit++;
        }

        var encrypted = block.modPow(exponent, modulus).toRadixString(16);
        encrypted = encrypted.padLeft(((encrypted.length + 3) ~/ 4) * 4, '0');
        blocks.add(encrypted);
      }

      return blocks.join(' ');
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
  final String? libraryJwt;

  LoginResult({
    required this.success,
    required this.userId,
    required this.userName,
    this.cookie,
    this.ticket,
    this.libraryJwt,
  });
}

class AuthException implements Exception {
  final String message;

  AuthException(this.message);

  @override
  String toString() => message;
}
