import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import '../config/constants.dart';
import '../models/canteen.dart';
import 'http_service.dart';
import 'cache_service.dart';
import '../utils/dio_exception_handler.dart';

/// 食堂数据服务
class CanteenService {
  final HttpService _http = HttpService.instance;
  final CacheService _cache = CacheService.instance;

  /// 获取食堂实时数据
  ///
  /// 注意：这个接口需要在校园网内访问
  /// URL: http://canteen.zju.edu.cn/general_new.php?t=xxx
  ///
  /// [useCache] 是否使用缓存（默认 true）
  /// 抛出 [NetworkException] 如果网络请求失败
  Future<CanteenApiResponse> fetchCanteenData({bool useCache = true}) async {
    // 缓存策略：实时数据，30秒有效期，网络优先但支持离线
    final policy = CachePolicy(
      key: 'canteen_data',
      strategy:
          useCache ? CacheStrategy.networkFirst : CacheStrategy.networkOnly,
      ttl: const Duration(seconds: 30),
      allowStaleWhenOffline: true,
    );

    return await DioExceptionHandler.wrap(
      operation: () async {
        final cachedJson = await _cache.get(
          policy: policy,
          fetcher: () => _fetchCanteenDataFromNetwork(),
        );

        if (cachedJson != null) {
          return CanteenApiResponse.fromRawJson(cachedJson);
        }

        throw missingCanteenDataExceptionForTesting(
          isWeb: kIsWeb,
          proxyUrl: ApiConfig.localCanteenProxyUrl,
        );
      },
      context: '获取食堂数据失败',
    );
  }

  /// 从网络获取食堂数据
  Future<String> _fetchCanteenDataFromNetwork() async {
    // 添加时间戳防止服务器缓存
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    const baseUrl =
        kIsWeb ? ApiConfig.localCanteenProxyUrl : ApiConfig.canteenDataUrl;
    final url = '$baseUrl?t=$timestamp';

    final response = await _http.dio.get<dynamic>(
      url,
      options: Options(
        headers: {
          'Accept': '*/*',
          'User-Agent': 'Mozilla/5.0 (Linux; Android 10) AppleWebKit/537.36',
        },
        responseType: ResponseType.plain,
      ),
    );

    if (response.data != null) {
      // 返回原始 JSON 字符串用于缓存
      if (response.data is String) {
        return response.data as String;
      } else {
        return json.encode(response.data);
      }
    }

    throw NetworkException('数据格式错误');
  }

  @visibleForTesting
  static NetworkException missingCanteenDataExceptionForTesting({
    required bool isWeb,
    required String proxyUrl,
  }) {
    if (!isWeb) {
      return NetworkException('网络连接失败，请连接校园网');
    }

    final normalized = proxyUrl.toLowerCase();
    final isDefaultLocalProxy = normalized.contains('127.0.0.1:51989') ||
        normalized.contains('localhost:51989');

    if (isDefaultLocalProxy) {
      return NetworkException(
        '食堂本地代理未启动，请先运行 node tool/library_proxy.mjs',
      );
    }

    return NetworkException('食堂代理不可达，请检查 CANTEEN_PROXY_URL 配置');
  }

  /// 按校区筛选食堂
  List<CanteenData> filterByCampus(List<CanteenData> canteens, String campus) {
    final campusKeywords = {
      'zijingang': ['紫金港', '银泉', '玉湖', '澄月', '麦香', '临湖', '风味', '休闲'],
      'yuquan': ['玉泉'],
      'xixi': ['西溪'],
      'huajiachi': ['华家池'],
      'haining': ['海宁'],
      'zhoushan': ['舟山', '之江'],
    };

    final keywords = campusKeywords[campus] ?? [];
    return canteens.where((c) {
      return keywords.any((keyword) => c.name.contains(keyword));
    }).toList();
  }
}
