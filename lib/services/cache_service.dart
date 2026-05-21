import 'dart:async';
import 'package:hive_flutter/hive_flutter.dart';

/// 缓存策略
enum CacheStrategy {
  /// 仅从缓存读取，不请求网络
  cacheOnly,

  /// 先读缓存，缓存未命中时请求网络
  cacheFirst,

  /// 先请求网络，失败时读取缓存
  networkFirst,

  /// 仅从网络请求，不使用缓存
  networkOnly,

  /// 总是从网络请求，但同时返回缓存（如果有）
  staleWhileRevalidate,
}

/// 缓存策略配置
class CachePolicy {
  /// 缓存键
  final String key;

  /// 缓存策略
  final CacheStrategy strategy;

  /// 缓存有效期（Time To Live）
  final Duration? ttl;

  /// 是否允许离线时使用过期缓存
  final bool allowStaleWhenOffline;

  /// 最大缓存大小（单位：字节，null 表示无限制）
  final int? maxSize;

  const CachePolicy({
    required this.key,
    this.strategy = CacheStrategy.cacheFirst,
    this.ttl,
    this.allowStaleWhenOffline = true,
    this.maxSize,
  });

  /// 默认策略：优先使用缓存，5分钟有效期
  factory CachePolicy.standard(String key) {
    return CachePolicy(
      key: key,
      strategy: CacheStrategy.cacheFirst,
      ttl: const Duration(minutes: 5),
    );
  }

  /// 实时数据策略：优先网络，30秒有效期
  factory CachePolicy.realtime(String key) {
    return CachePolicy(
      key: key,
      strategy: CacheStrategy.networkFirst,
      ttl: const Duration(seconds: 30),
    );
  }

  /// 静态数据策略：优先缓存，24小时有效期
  factory CachePolicy.static(String key) {
    return CachePolicy(
      key: key,
      strategy: CacheStrategy.cacheFirst,
      ttl: const Duration(hours: 24),
    );
  }

  /// 无缓存策略：仅网络
  factory CachePolicy.noCache(String key) {
    return CachePolicy(
      key: key,
      strategy: CacheStrategy.networkOnly,
    );
  }
}

/// 缓存项
class CacheEntry {
  /// 缓存的数据
  final String data;

  /// 缓存时间戳
  final DateTime cachedAt;

  /// 数据大小（字节）
  final int size;

  /// ETag（用于条件请求）
  final String? etag;

  CacheEntry({
    required this.data,
    required this.cachedAt,
    required this.size,
    this.etag,
  });

  /// 是否过期
  bool isExpired(Duration? ttl) {
    if (ttl == null) return false;
    return DateTime.now().difference(cachedAt) > ttl;
  }

  /// 转为 Map（用于存储）
  Map<String, dynamic> toMap() {
    return {
      'data': data,
      'cachedAt': cachedAt.millisecondsSinceEpoch,
      'size': size,
      'etag': etag,
    };
  }

  /// 从 Map 创建
  factory CacheEntry.fromMap(Map<String, dynamic> map) {
    return CacheEntry(
      data: map['data'] as String,
      cachedAt: DateTime.fromMillisecondsSinceEpoch(map['cachedAt'] as int),
      size: map['size'] as int,
      etag: map['etag'] as String?,
    );
  }
}

/// 3层缓存服务
///
/// L1: 内存缓存（最快）
/// L2: Hive 磁盘缓存（持久化）
/// L3: 网络请求（回源）
class CacheService {
  static CacheService? _instance;

  /// 内存缓存（L1）
  final Map<String, CacheEntry> _memoryCache = {};

  /// Hive 缓存盒子（L2）
  Box<Map<dynamic, dynamic>>? _cacheBox;

  /// 请求去重器：防止相同请求并发
  final Map<String, Future<String>> _pendingRequests = {};

  /// 缓存统计
  int _hits = 0;
  int _misses = 0;
  int _networkRequests = 0;

  CacheService._();

  static CacheService get instance {
    _instance ??= CacheService._();
    return _instance!;
  }

  /// 初始化缓存服务
  Future<void> init() async {
    if (_cacheBox != null) return;

    try {
      _cacheBox = await Hive.openBox<Map>('zjulife_cache');
    } catch (e) {
      // 如果打开失败，尝试删除损坏的缓存
      try {
        await Hive.deleteBoxFromDisk('zjulife_cache');
        _cacheBox = await Hive.openBox<Map>('zjulife_cache');
      } catch (e) {
        // 缓存初始化失败，继续运行但不使用磁盘缓存
        _cacheBox = null;
      }
    }
  }

  /// 获取缓存数据
  ///
  /// [policy] 缓存策略
  /// [fetcher] 网络请求函数（当需要从网络获取时调用）
  Future<String?> get({
    required CachePolicy policy,
    required Future<String> Function() fetcher,
  }) async {
    await init();

    switch (policy.strategy) {
      case CacheStrategy.cacheOnly:
        return _getCached(policy);

      case CacheStrategy.cacheFirst:
        return _getCacheFirst(policy, fetcher);

      case CacheStrategy.networkFirst:
        return _getNetworkFirst(policy, fetcher);

      case CacheStrategy.networkOnly:
        return _getNetworkOnly(policy, fetcher);

      case CacheStrategy.staleWhileRevalidate:
        return _getStaleWhileRevalidate(policy, fetcher);
    }
  }

  /// 仅从缓存获取
  Future<String?> _getCached(CachePolicy policy) async {
    // 1. 尝试从内存缓存获取
    final memEntry = _memoryCache[policy.key];
    if (memEntry != null && !memEntry.isExpired(policy.ttl)) {
      _hits++;
      return memEntry.data;
    }

    // 2. 尝试从磁盘缓存获取
    if (_cacheBox != null) {
      final diskMap = _cacheBox!.get(policy.key);
      if (diskMap != null) {
        final entry = CacheEntry.fromMap(Map<String, dynamic>.from(diskMap));
        if (!entry.isExpired(policy.ttl)) {
          // 写入内存缓存
          _memoryCache[policy.key] = entry;
          _hits++;
          return entry.data;
        }
      }
    }

    _misses++;
    return null;
  }

  /// 优先缓存策略
  Future<String?> _getCacheFirst(
      CachePolicy policy, Future<String> Function() fetcher) async {
    // 1. 先尝试从缓存获取
    final cached = await _getCached(policy);
    if (cached != null) {
      return cached;
    }

    // 2. 缓存未命中，从网络获取
    try {
      return await _fetchAndCache(policy, fetcher);
    } catch (e) {
      // 3. 网络失败，如果允许则返回过期缓存
      if (policy.allowStaleWhenOffline) {
        return await _getStaleCache(policy);
      }
      rethrow;
    }
  }

  /// 优先网络策略
  Future<String?> _getNetworkFirst(
      CachePolicy policy, Future<String> Function() fetcher) async {
    try {
      // 1. 先尝试从网络获取
      return await _fetchAndCache(policy, fetcher);
    } catch (e) {
      // 2. 网络失败，如果允许则回退到缓存
      if (!policy.allowStaleWhenOffline) {
        rethrow;
      }
      return await _getCached(policy) ?? await _getStaleCache(policy);
    }
  }

  /// 仅网络策略
  Future<String?> _getNetworkOnly(
      CachePolicy policy, Future<String> Function() fetcher) async {
    return await _fetchAndCache(policy, fetcher);
  }

  /// Stale-While-Revalidate 策略
  /// 立即返回缓存（即使过期），同时在后台刷新
  Future<String?> _getStaleWhileRevalidate(
      CachePolicy policy, Future<String> Function() fetcher) async {
    // 1. 立即返回缓存（包括过期的）
    final cached = await _getStaleCache(policy);

    // 2. 后台刷新缓存
    unawaited(_fetchAndCache(policy, fetcher).catchError((_) {
      // 忽略后台刷新失败，返回空字符串
      return '';
    }));

    return cached;
  }

  /// 从网络获取并缓存
  Future<String> _fetchAndCache(
      CachePolicy policy, Future<String> Function() fetcher) async {
    // 请求去重：如果已有相同请求在进行中，直接返回
    if (_pendingRequests.containsKey(policy.key)) {
      return await _pendingRequests[policy.key]!;
    }

    // 创建新请求
    final request = _executeFetch(policy, fetcher);
    _pendingRequests[policy.key] = request;

    try {
      final result = await request;
      return result;
    } finally {
      _pendingRequests.remove(policy.key);
    }
  }

  /// 执行网络请求
  Future<String> _executeFetch(
      CachePolicy policy, Future<String> Function() fetcher) async {
    _networkRequests++;

    try {
      final data = await fetcher();

      // 保存到缓存
      await _saveCache(policy.key, data);

      return data;
    } catch (e) {
      rethrow;
    }
  }

  /// 获取过期缓存（用于离线场景）
  Future<String?> _getStaleCache(CachePolicy policy) async {
    // 从内存获取
    final memEntry = _memoryCache[policy.key];
    if (memEntry != null) {
      return memEntry.data;
    }

    // 从磁盘获取
    if (_cacheBox != null) {
      final diskMap = _cacheBox!.get(policy.key);
      if (diskMap != null) {
        final entry = CacheEntry.fromMap(Map<String, dynamic>.from(diskMap));
        return entry.data;
      }
    }

    return null;
  }

  /// 保存到缓存
  Future<void> _saveCache(String key, String data) async {
    final entry = CacheEntry(
      data: data,
      cachedAt: DateTime.now(),
      size: data.length,
    );

    // 1. 保存到内存缓存
    _memoryCache[key] = entry;

    // 2. 保存到磁盘缓存
    if (_cacheBox != null) {
      try {
        await _cacheBox!.put(key, entry.toMap());
      } catch (e) {
        // 磁盘写入失败，仅记录但不影响功能
      }
    }
  }

  /// 手动设置缓存
  Future<void> set(String key, String data) async {
    await _saveCache(key, data);
  }

  /// 删除缓存
  Future<void> delete(String key) async {
    _memoryCache.remove(key);
    if (_cacheBox != null) {
      await _cacheBox!.delete(key);
    }
  }

  /// 清空所有缓存
  Future<void> clear() async {
    _memoryCache.clear();
    if (_cacheBox != null) {
      await _cacheBox!.clear();
    }
  }

  /// 清理过期缓存
  Future<void> cleanExpired() async {
    if (_cacheBox == null) return;

    final now = DateTime.now();
    final keysToDelete = <String>[];

    // 遍历所有缓存项
    for (final key in _cacheBox!.keys) {
      final diskMap = _cacheBox!.get(key);
      if (diskMap != null) {
        final entry = CacheEntry.fromMap(Map<String, dynamic>.from(diskMap));
        // 删除超过7天的缓存
        if (now.difference(entry.cachedAt) > const Duration(days: 7)) {
          keysToDelete.add(key as String);
        }
      }
    }

    // 批量删除
    for (final key in keysToDelete) {
      await delete(key);
    }
  }

  /// 获取缓存大小（字节）
  Future<int> getCacheSize() async {
    if (_cacheBox == null) return 0;

    int totalSize = 0;
    for (final key in _cacheBox!.keys) {
      final diskMap = _cacheBox!.get(key);
      if (diskMap != null) {
        final entry = CacheEntry.fromMap(Map<String, dynamic>.from(diskMap));
        totalSize += entry.size;
      }
    }

    return totalSize;
  }

  /// 获取缓存统计信息
  Map<String, dynamic> getStats() {
    final total = _hits + _misses;
    final hitRate =
        total > 0 ? (_hits / total * 100).toStringAsFixed(2) : '0.00';

    return {
      'hits': _hits,
      'misses': _misses,
      'hitRate': '$hitRate%',
      'networkRequests': _networkRequests,
      'memoryEntries': _memoryCache.length,
      'diskEntries': _cacheBox?.length ?? 0,
    };
  }

  /// 重置统计信息
  void resetStats() {
    _hits = 0;
    _misses = 0;
    _networkRequests = 0;
  }
}
