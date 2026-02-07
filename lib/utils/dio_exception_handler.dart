import 'package:dio/dio.dart';

/// DioException 统一处理工具类
///
/// 消除服务层中重复的异常处理代码
class DioExceptionHandler {
  /// 处理 DioException 并转换为统一的异常类型
  ///
  /// [e] - Dio 异常
  /// [context] - 上下文信息（如"获取数据失败"）
  /// [exceptionType] - 要抛出的异常类型（默认为 NetworkException）
  static Never handle(
    DioException e, {
    required String context,
    Type exceptionType = NetworkException,
  }) {
    final message = _getErrorMessage(e);

    // 根据异常类型抛出相应的异常
    if (exceptionType == AuthException) {
      throw AuthException(message);
    } else {
      throw NetworkException(message);
    }
  }

  /// 获取用户友好的错误信息
  static String _getErrorMessage(DioException e) {
    switch (e.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.receiveTimeout:
      case DioExceptionType.sendTimeout:
        return '连接超时，请检查网络';

      case DioExceptionType.connectionError:
        return '网络连接失败，请连接校园网';

      case DioExceptionType.badResponse:
        return '服务器响应错误 (${e.response?.statusCode ?? "未知"})';

      case DioExceptionType.cancel:
        return '请求已取消';

      case DioExceptionType.badCertificate:
        return '证书验证失败';

      case DioExceptionType.unknown:
        return '网络错误: ${e.message ?? "未知错误"}';
    }
  }

  /// 包装异步操作，自动处理 DioException
  ///
  /// 用法:
  /// ```dart
  /// return await DioExceptionHandler.wrap(
  ///   operation: () => dio.get('/api/data'),
  ///   context: '获取数据失败',
  /// );
  /// ```
  static Future<T> wrap<T>({
    required Future<T> Function() operation,
    required String context,
    Type exceptionType = NetworkException,
  }) async {
    try {
      return await operation();
    } on DioException catch (e) {
      handle(e, context: context, exceptionType: exceptionType);
    } catch (e) {
      // 重新抛出已知异常
      if (e is NetworkException || e is AuthException || e is Exception) {
        rethrow;
      }
      // 未知异常包装
      if (exceptionType == AuthException) {
        throw AuthException('$context: $e');
      } else {
        throw NetworkException('$context: $e');
      }
    }
  }
}

/// 网络异常
class NetworkException implements Exception {
  final String message;

  NetworkException(this.message);

  @override
  String toString() => message;
}

/// 认证异常
class AuthException implements Exception {
  final String message;

  AuthException(this.message);

  @override
  String toString() => message;
}
