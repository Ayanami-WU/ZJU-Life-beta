import 'dart:convert';
import 'package:dio/dio.dart';
import '../models/library.dart';
import '../utils/dio_exception_handler.dart';
import 'cache_service.dart';

/// 图书馆座位服务
///
/// 使用 JWT Bearer Token 认证
/// 数据来源: https://booking.lib.zju.edu.cn/reserve/index/list
class LibraryService {
  late final Dio _dio;
  final CacheService _cache = CacheService.instance;

  /// JWT Token (通过 WebView 登录获取)
  String? _jwtToken;

  static const String _baseUrl = 'https://booking.lib.zju.edu.cn';
  static const String _listApi = '$_baseUrl/reserve/index/list';

  LibraryService() {
    _dio = Dio(BaseOptions(
      baseUrl: _baseUrl,
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 15),
      headers: {
        'Accept': 'application/json, text/plain, */*',
        'Content-Type': 'application/json',
        'User-Agent':
            'Mozilla/5.0 (Linux; Android 10) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Mobile Safari/537.36',
        'Referer': '$_baseUrl/h5/',
        'Origin': _baseUrl,
      },
    ));

    _dio.interceptors.add(LogInterceptor(
      requestBody: true,
      responseBody: true,
    ));
  }

  /// 设置 JWT Token
  void setJwtToken(String token) {
    _jwtToken = token;
  }

  /// 清除 JWT Token
  void clearJwtToken() {
    _jwtToken = null;
  }

  /// 是否已认证 (有 JWT token)
  bool get isAuthenticated => _jwtToken != null && _jwtToken!.isNotEmpty;

  /// 获取所有座位数据 (自动分页加载全部)
  ///
  /// [useCache] 是否使用缓存（默认 true）
  Future<List<LibrarySeat>> fetchAllSeats({bool useCache = true}) async {
    if (!isAuthenticated) {
      throw Exception('need_login');
    }

    final policy = CachePolicy(
      key: 'library_seats_jwt_${_jwtToken.hashCode}',
      strategy:
          useCache ? CacheStrategy.networkFirst : CacheStrategy.networkOnly,
      ttl: const Duration(minutes: 1),
      allowStaleWhenOffline: true,
    );

    return await DioExceptionHandler.wrap(
      operation: () async {
        final cachedJson = await _cache.get(
          policy: policy,
          fetcher: () => _fetchAllSeatsFromNetwork(),
        );

        if (cachedJson != null) {
          final data = json.decode(cachedJson) as List<dynamic>;
          return data
              .map((e) => LibrarySeat.fromJson(e as Map<String, dynamic>))
              .toList();
        }

        throw NetworkException('获取座位数据失败');
      },
      context: '获取座位数据失败',
    );
  }

  /// 从网络获取全部座位（自动翻页）
  Future<String> _fetchAllSeatsFromNetwork() async {
    final allSeats = <LibrarySeat>[];
    int page = 1;
    int totalPage = 1;

    do {
      final response = await _fetchPage(page: page, limit: 20);
      allSeats.addAll(response.list);
      totalPage = response.totalPage;
      page++;
    } while (page <= totalPage);

    return json.encode(allSeats.map((s) => s.toJson()).toList());
  }

  /// 获取单页座位数据
  Future<LibrarySeatListResponse> _fetchPage({
    int page = 1,
    int limit = 10,
    List<String>? premisesIds,
    List<String>? categoryIds,
  }) async {
    final response = await _dio.post(
      _listApi,
      data: {
        'premisesIds': premisesIds ?? [],
        'categoryIds': categoryIds ?? [],
        'page': page,
        'limit': limit,
      },
      options: Options(
        headers: {
          'Authorization': 'Bearer $_jwtToken',
        },
      ),
    );

    if (response.statusCode == 200 && response.data != null) {
      final data =
          response.data is String ? json.decode(response.data) : response.data;

      if (data is Map<String, dynamic>) {
        final code = data['code'];
        if (code == 10001) {
          // JWT 过期或无效
          _jwtToken = null;
          throw Exception('need_login');
        }
        if (code != 0) {
          throw NetworkException(data['msg']?.toString() ?? '请求失败');
        }
        return LibrarySeatListResponse.fromJson(data);
      }
    }

    throw NetworkException('获取座位数据失败: HTTP ${response.statusCode}');
  }

  /// 按建筑分组
  Map<String, List<LibrarySeat>> groupByBuilding(List<LibrarySeat> seats) {
    final result = <String, List<LibrarySeat>>{};
    for (final seat in seats) {
      result.putIfAbsent(seat.premisesName, () => []).add(seat);
    }
    return result;
  }

  /// 按楼层分组 (在同一建筑内)
  Map<String, List<LibrarySeat>> groupByStorey(List<LibrarySeat> seats) {
    final result = <String, List<LibrarySeat>>{};
    for (final seat in seats) {
      result.putIfAbsent(seat.storeyName, () => []).add(seat);
    }
    return result;
  }
}
