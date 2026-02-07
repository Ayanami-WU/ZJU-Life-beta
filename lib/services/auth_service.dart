import 'dart:convert';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:html/parser.dart' as html_parser;
import 'package:pointycastle/export.dart';
import '../utils/dio_exception_handler.dart';

/// ZJU CAS 统一身份认证服务
/// 
/// 使用 HTTP 请求模拟浏览器登录 CAS 系统
class AuthService {
  static AuthService? _instance;
  late final Dio _dio;
  
  // CAS 服务器配置
  static const String _casBaseUrl = 'https://zjuam.zju.edu.cn/cas';
  static const String _casLoginUrl = '$_casBaseUrl/login';
  
  // 公钥获取 URL (用于密码加密)
  static const String _pubkeyUrl = '$_casBaseUrl/v2/getPubKey';
  
  AuthService._() {
    _dio = Dio(BaseOptions(
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 15),
      followRedirects: false,
      validateStatus: (status) => status != null && status < 500,
    ));
    
    // 添加 Cookie 管理
    _dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) {
        options.headers['User-Agent'] = 
          'Mozilla/5.0 (Linux; Android 10) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Mobile Safari/537.36';
        options.headers['Accept'] = 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8';
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
  /// 
  /// [username] 学号
  /// [password] 密码
  /// 
  /// 返回包含用户信息和 Cookie 的结果
  Future<LoginResult> login(String username, String password) async {
    try {
      // 1. 获取登录页面，获取 execution 参数和 Cookie
      final loginPageResponse = await _dio.get(_casLoginUrl);
      
      // 解析登录页面获取必要参数
      final document = html_parser.parse(loginPageResponse.data);
      final executionInput = document.querySelector('input[name="execution"]');
      final execution = executionInput?.attributes['value'] ?? '';
      
      if (execution.isEmpty) {
        throw AuthException('无法获取登录参数，请稍后重试');
      }
      
      // 获取 Cookie
      final setCookieHeaders = loginPageResponse.headers['set-cookie'];
      String cookies = '';
      if (setCookieHeaders != null) {
        cookies = setCookieHeaders.map((c) => c.split(';')[0]).join('; ');
      }
      
      // 2. 获取 RSA 公钥 (用于密码加密)
      final pubkeyResponse = await _dio.get(
        _pubkeyUrl,
        options: Options(
          headers: {'Cookie': cookies},
        ),
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
            // RSA 加密密码
            encryptedPassword = _rsaEncrypt(password, modulus, exponent);
          }
        } catch (e) {
          // 如果加密失败，使用原始密码尝试
          encryptedPassword = password;
        }
      }
      
      // 3. 提交登录请求
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
      
      // 4. 检查登录结果
      // 登录成功会重定向 (302)
      if (loginResponse.statusCode == 302) {
        // 更新 Cookie
        final newCookies = loginResponse.headers['set-cookie'];
        if (newCookies != null) {
          final newCookieStr = newCookies.map((c) => c.split(';')[0]).join('; ');
          cookies = '$cookies; $newCookieStr';
        }
        
        return LoginResult(
          success: true,
          userId: username,
          userName: username, // CAS 不直接返回用户名，使用学号
          cookie: cookies,
        );
      }
      
      // 登录失败，解析错误信息
      final errorDoc = html_parser.parse(loginResponse.data);
      final errorSpan = errorDoc.querySelector('#msg') ?? 
                        errorDoc.querySelector('.login-error') ??
                        errorDoc.querySelector('.alert-danger');
      final errorMsg = errorSpan?.text.trim() ?? '登录失败，请检查用户名和密码';
      
      throw AuthException(errorMsg);

    } catch (e) {
      if (e is AuthException) rethrow;
      if (e is DioException) {
        return DioExceptionHandler.handle(e, context: '登录失败', exceptionType: AuthException);
      }
      throw AuthException('登录失败: $e');
    }
  }
  
  /// RSA 加密密码
  ///
  /// 浙大 CAS 使用 RSA 加密密码
  String _rsaEncrypt(String password, String modulusHex, String exponentHex) {
    try {
      // 解析公钥参数
      final modulus = BigInt.parse(modulusHex, radix: 16);
      final exponent = BigInt.parse(exponentHex, radix: 16);
      final publicKey = RSAPublicKey(modulus, exponent);

      // 使用 OAEP 填充方式进行 RSA 加密
      final encryptor = OAEPEncoding(RSAEngine())
        ..init(true, PublicKeyParameter<RSAPublicKey>(publicKey));

      // 加密密码
      final dataToEncrypt = Uint8List.fromList(utf8.encode(password));
      final encrypted = encryptor.process(dataToEncrypt);

      // 返回 Base64 编码的加密结果
      return base64.encode(encrypted);
    } catch (e) {
      // 如果加密失败，返回原密码作为降级方案
      return password;
    }
  }
}

/// 登录结果
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

/// 认证异常
class AuthException implements Exception {
  final String message;
  
  AuthException(this.message);
  
  @override
  String toString() => message;
}
