import 'package:dio/dio.dart';
import '../config/constants.dart';

/// HTTP 客户端单例
class HttpService {
  static HttpService? _instance;
  late final Dio _dio;
  
  HttpService._() {
    _dio = Dio(BaseOptions(
      connectTimeout: ApiConfig.connectTimeout,
      receiveTimeout: ApiConfig.receiveTimeout,
      headers: {
        'Accept': 'application/json',
        'Content-Type': 'application/json',
      },
    ));
    
    // 添加日志拦截器 (仅开发模式)
    _dio.interceptors.add(LogInterceptor(
      requestBody: true,
      responseBody: true,
    ));
  }
  
  static HttpService get instance {
    _instance ??= HttpService._();
    return _instance!;
  }
  
  Dio get dio => _dio;
  
  /// 设置认证 Cookie
  void setAuthCookie(String cookie) {
    _dio.options.headers['Cookie'] = cookie;
  }
  
  /// 清除认证
  void clearAuth() {
    _dio.options.headers.remove('Cookie');
  }
  
  /// GET 请求
  Future<Response<T>> get<T>(
    String url, {
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) async {
    return _dio.get<T>(
      url,
      queryParameters: queryParameters,
      options: options,
    );
  }
  
  /// POST 请求
  Future<Response<T>> post<T>(
    String url, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) async {
    return _dio.post<T>(
      url,
      data: data,
      queryParameters: queryParameters,
      options: options,
    );
  }
}
