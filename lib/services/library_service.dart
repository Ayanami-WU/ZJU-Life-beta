import 'dart:convert';
import 'package:dio/dio.dart';
import '../models/library.dart';
import '../utils/dio_exception_handler.dart';
import 'cache_service.dart';

/// 图书馆座位服务
///
/// 需要通过 CAS 认证后才能访问
/// 数据来源: https://booking.lib.zju.edu.cn/
class LibraryService {
  late final Dio _dio;
  final CacheService _cache = CacheService.instance;

  String? _casCookie;
  String? _libraryCookie;
  
  LibraryService() {
    _dio = Dio(BaseOptions(
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 15),
      followRedirects: false,
      validateStatus: (status) => status != null && status < 500,
    ));
  }
  
  /// 设置 CAS 认证 Cookie
  void setAuthCookie(String cookie) {
    _casCookie = cookie;
    // 重置图书馆 cookie，下次请求时重新获取
    _libraryCookie = null;
  }
  
  /// 是否已认证
  bool get isAuthenticated => _casCookie != null && _casCookie!.isNotEmpty;
  
  /// 获取座位数据
  ///
  /// 使用 HTTP 爬虫方式获取数据
  /// [useCache] 是否使用缓存（默认 true）
  /// 抛出 [NetworkException] 如果网络请求失败
  /// 抛出 [Exception] 如果未登录
  Future<List<LibrarySeat>> fetchSeats({bool useCache = true}) async {
    if (!isAuthenticated) {
      throw Exception('需要先登录统一身份认证');
    }

    // 缓存策略：座位数据实时性要求高，1分钟有效期
    final policy = CachePolicy(
      key: 'library_seats_${_casCookie?.hashCode ?? 0}',
      strategy: useCache ? CacheStrategy.networkFirst : CacheStrategy.networkOnly,
      ttl: const Duration(minutes: 1),
      allowStaleWhenOffline: true,
    );

    return await DioExceptionHandler.wrap(
      operation: () async {
        final cachedJson = await _cache.get(
          policy: policy,
          fetcher: () => _fetchSeatsFromNetwork(),
        );

        if (cachedJson != null) {
          final data = json.decode(cachedJson);
          return _parseSeatsFromJson(data);
        }

        throw NetworkException('获取座位数据失败');
      },
      context: '获取座位数据失败',
    );
  }

  /// 从网络获取座位数据
  Future<String> _fetchSeatsFromNetwork() async {
    if (!isAuthenticated) {
      throw Exception('需要先登录统一身份认证');
    }
    
    try {
      // 1. 如果没有图书馆 cookie，需要通过 CAS 认证获取
      if (_libraryCookie == null) {
        await _authenticateWithLibrary();
      }
      
      // 2. 请求座位数据 API
      final response = await _dio.get(
        'https://booking.lib.zju.edu.cn/api/ic2/spaceLib',
        options: Options(
          headers: {
            'Cookie': _libraryCookie,
            'Accept': 'application/json, text/plain, */*',
            'Referer': 'https://booking.lib.zju.edu.cn/h5/',
            'User-Agent': 'Mozilla/5.0 (Linux; Android 10) AppleWebKit/537.36',
          },
        ),
      );
      
      if (response.statusCode == 200 && response.data != null) {
        return json.encode(response.data);
      }

      // 如果返回 401 或其他认证错误，尝试重新认证
      if (response.statusCode == 401 || response.statusCode == 403) {
        _libraryCookie = null;
        await _authenticateWithLibrary();
        // 重试请求
        final retryResponse = await _dio.get(
          'https://booking.lib.zju.edu.cn/api/ic2/spaceLib',
          options: Options(
            headers: {
              'Cookie': _libraryCookie,
              'Accept': 'application/json, text/plain, */*',
              'Referer': 'https://booking.lib.zju.edu.cn/h5/',
              'User-Agent': 'Mozilla/5.0 (Linux; Android 10) AppleWebKit/537.36',
            },
          ),
        );
        if (retryResponse.statusCode == 200 && retryResponse.data != null) {
          return json.encode(retryResponse.data);
        }
      }
      
      throw NetworkException('获取座位数据失败: HTTP ${response.statusCode}');
    } catch (e) {
      if (e is NetworkException) rethrow;
      if (e is Exception) rethrow;
      throw NetworkException('获取数据失败: $e');
    }
  }
  
  /// 通过 CAS 认证获取图书馆 session
  Future<void> _authenticateWithLibrary() async {
    // 图书馆 CAS 认证入口
    const libraryCasUrl = 'https://booking.lib.zju.edu.cn/ic2/casLogin';
    
    String cookies = _casCookie ?? '';
    
    // 1. 访问图书馆 CAS 登录入口，会重定向到 CAS
    var response = await _dio.get(
      libraryCasUrl,
      options: Options(
        headers: {
          'Cookie': cookies,
          'User-Agent': 'Mozilla/5.0 (Linux; Android 10) AppleWebKit/537.36',
        },
      ),
    );
    
    // 收集 cookies
    cookies = _mergeCookies(cookies, response.headers['set-cookie']);
    
    // 2. 跟随重定向，最多 10 次
    int redirectCount = 0;
    while (response.statusCode == 302 && redirectCount < 10) {
      redirectCount++;
      
      final location = response.headers['location']?.first;
      if (location == null) break;
      
      // 解析重定向 URL
      final redirectUrl = location.startsWith('http') 
          ? location 
          : Uri.parse(libraryCasUrl).resolve(location).toString();
      
      response = await _dio.get(
        redirectUrl,
        options: Options(
          headers: {
            'Cookie': cookies,
            'User-Agent': 'Mozilla/5.0 (Linux; Android 10) AppleWebKit/537.36',
          },
        ),
      );
      
      // 收集 cookies
      cookies = _mergeCookies(cookies, response.headers['set-cookie']);
    }
    
    // 保存获取到的 cookies
    _libraryCookie = cookies;
  }
  
  /// 合并 cookies
  String _mergeCookies(String existing, List<String>? newCookies) {
    if (newCookies == null || newCookies.isEmpty) return existing;
    
    final cookieMap = <String, String>{};
    
    // 解析现有 cookies
    for (final cookie in existing.split('; ')) {
      final parts = cookie.split('=');
      if (parts.length >= 2) {
        cookieMap[parts[0]] = parts.sublist(1).join('=');
      }
    }
    
    // 添加新 cookies
    for (final cookie in newCookies) {
      final mainPart = cookie.split(';')[0];
      final parts = mainPart.split('=');
      if (parts.length >= 2) {
        cookieMap[parts[0]] = parts.sublist(1).join('=');
      }
    }
    
    return cookieMap.entries.map((e) => '${e.key}=${e.value}').join('; ');
  }
  
  /// 解析 JSON 数据为座位列表
  List<LibrarySeat> _parseSeatsFromJson(dynamic data) {
    try {
      final List<LibrarySeat> seats = [];
      
      // API 返回格式可能是:
      // { "data": { "list": [...] } }
      // 或者 { "data": [...] }
      // 需要根据实际响应调整
      
      dynamic list;
      if (data is Map<String, dynamic>) {
        final dataField = data['data'];
        if (dataField is Map<String, dynamic>) {
          list = dataField['list'] ?? dataField['spaceLib'];
        } else if (dataField is List) {
          list = dataField;
        }
      } else if (data is List) {
        list = data;
      }
      
      if (list != null && list is List) {
        for (final item in list) {
          if (item is Map<String, dynamic>) {
            seats.add(LibrarySeat(
              id: item['id']?.toString() ?? '',
              roomName: item['name']?.toString() ?? 
                        item['roomName']?.toString() ?? 
                        '未知区域',
              buildingName: item['libName']?.toString() ?? 
                            item['buildingName']?.toString() ?? 
                            '未知建筑',
              totalSeats: _parseInt(item['totalCount'] ?? item['totalSeats']),
              availableSeats: _parseInt(item['freeCount'] ?? item['availableSeats']),
              floor: item['floor']?.toString() ?? '',
            ));
          }
        }
      }
      
      if (seats.isEmpty) {
        throw NetworkException('未找到座位数据');
      }
      
      return seats;
    } catch (e) {
      if (e is NetworkException) rethrow;
      throw NetworkException('解析数据失败: $e');
    }
  }
  
  int _parseInt(dynamic value) {
    if (value == null) return 0;
    if (value is int) return value;
    if (value is String) return int.tryParse(value) ?? 0;
    return 0;
  }
  
  /// 按建筑分组
  Map<String, List<LibrarySeat>> groupByBuilding(List<LibrarySeat> seats) {
    final result = <String, List<LibrarySeat>>{};
    for (final seat in seats) {
      result.putIfAbsent(seat.buildingName, () => []).add(seat);
    }
    return result;
  }
}
