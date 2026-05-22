import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';

import '../config/constants.dart';
import '../models/library.dart';
import '../utils/dio_exception_handler.dart';
import 'cache_service.dart';

/// 图书馆座位服务。
///
/// 使用 booking.lib.zju.edu.cn 的座位查询接口，通过用户自己的 CAS 登录态换取
/// 图书馆系统 Token 后读取实时座位和地图数据。
class LibraryService {
  LibraryService({String? authToken}) : _authToken = authToken {
    _dio = Dio(
      BaseOptions(
        baseUrl: _apiBaseUrl,
        connectTimeout: const Duration(seconds: 15),
        receiveTimeout: const Duration(seconds: 20),
        headers: {
          'Accept': 'application/json, text/plain, */*',
          'Content-Type': 'application/json',
          'X-Requested-With': 'XMLHttpRequest',
          'User-Agent':
              'Mozilla/5.0 (Linux; Android 10) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Mobile Safari/537.36',
          'Referer': 'https://booking.lib.zju.edu.cn/h5/',
          'Origin': _bookingBaseUrl,
        },
      ),
    );
  }

  late final Dio _dio;
  String? _authToken;
  final CacheService _cache = CacheService.instance;

  static const String _bookingBaseUrl = 'https://booking.lib.zju.edu.cn';
  static const String defaultSegment = '1';
  static const String defaultStartTime = '08:00';
  static const String defaultEndTime = '22:00';

  static String get _apiBaseUrl =>
      kIsWeb ? ApiConfig.localLibraryProxyUrl : _bookingBaseUrl;

  void updateAuthToken(String? token) {
    _authToken = token;
  }

  String? get _authorizationHeader {
    final token = _authToken?.trim();
    if (token == null || token.isEmpty) return null;
    return normalizeAuthorizationHeader(token);
  }

  static String normalizeAuthorizationHeader(String token) {
    var rawToken = token.trim();
    if (rawToken.toLowerCase().startsWith('bearer')) {
      rawToken = rawToken.substring(6).trim();
    }
    return 'bearer$rawToken';
  }

  static String formatChinaDate(DateTime instant) {
    final chinaTime = instant.toUtc().add(const Duration(hours: 8));
    return DateFormat('yyyy-MM-dd').format(chinaTime);
  }

  String get _cacheScope {
    final token = _authToken?.trim();
    if (token == null || token.isEmpty) return 'anonymous';
    return token.hashCode.toUnsigned(32).toRadixString(16);
  }

  /// 获取房间汇总数据。
  Future<List<LibrarySeat>> fetchAllSeats({bool useCache = true}) async {
    final query = LibrarySeatQuery.today();
    final policy = CachePolicy(
      key: 'library_rooms_auth_v3_${query.cacheKey}_$_cacheScope',
      strategy:
          useCache ? CacheStrategy.networkFirst : CacheStrategy.networkOnly,
      ttl: const Duration(minutes: 2),
      allowStaleWhenOffline: false,
    );

    return DioExceptionHandler.wrap(
      operation: () async {
        final cachedJson = await _cache.get(
          policy: policy,
          fetcher: () async {
            final rooms = await _fetchRoomSummaries(query, useCache: useCache);
            return json.encode(rooms.map((room) => room.toJson()).toList());
          },
        );

        if (cachedJson == null) {
          throw NetworkException('获取图书馆座位失败');
        }

        final data = json.decode(cachedJson) as List<dynamic>;
        return data
            .map((e) => LibrarySeat.fromJson(e as Map<String, dynamic>))
            .toList();
      },
      context: '获取图书馆座位失败',
    );
  }

  /// 获取房间地图与座位明细。
  Future<LibraryRoomDetail> fetchRoomDetail(
    String roomId, {
    bool useCache = true,
  }) async {
    final query = LibrarySeatQuery.today();

    return DioExceptionHandler.wrap(
      operation: () async {
        final rooms = await fetchRoomNodes(useCache: useCache);
        final room = rooms.firstWhere(
          (item) => item.id == roomId,
          orElse: () => LibraryRoomNode(
            id: roomId,
            name: roomId,
            libraryName: '图书馆',
            floorName: '',
          ),
        );

        final seatsFuture = fetchRoomSeats(
          roomId,
          query: query,
          useCache: useCache,
        );
        final mapFuture = fetchRoomMap(room, useCache: useCache);

        return LibraryRoomDetail(
          room: room,
          seats: await seatsFuture,
          map: await mapFuture,
        );
      },
      context: '获取房间座位失败',
    );
  }

  /// 获取可预约房间节点。
  Future<List<LibraryRoomNode>> fetchRoomNodes({bool useCache = true}) async {
    final policy = CachePolicy(
      key: 'library_room_nodes_auth_v3_$_cacheScope',
      strategy:
          useCache ? CacheStrategy.networkFirst : CacheStrategy.networkOnly,
      ttl: const Duration(hours: 24),
      allowStaleWhenOffline: false,
    );

    final cachedJson = await _cache.get(
      policy: policy,
      fetcher: () async {
        final summaries = await _fetchReserveRoomSummaries(
          LibrarySeatQuery.today(),
          useCache: useCache,
        );
        final rooms = summaries.map(roomNodeFromSummary).toList();
        return json.encode(rooms.map((room) => room.toJson()).toList());
      },
    );

    if (cachedJson == null) {
      throw NetworkException('获取图书馆区域失败');
    }

    final data = json.decode(cachedJson) as List<dynamic>;
    return data
        .map((e) => LibraryRoomNode.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// 获取某个房间的座位明细。
  Future<List<LibrarySeatDetail>> fetchRoomSeats(
    String roomId, {
    LibrarySeatQuery? query,
    bool useCache = true,
  }) async {
    final effectiveQuery = query ?? LibrarySeatQuery.today();
    final policy = CachePolicy(
      key:
          'library_room_seats_auth_v2_${roomId}_${effectiveQuery.cacheKey}_$_cacheScope',
      strategy:
          useCache ? CacheStrategy.networkFirst : CacheStrategy.networkOnly,
      ttl: const Duration(minutes: 2),
      allowStaleWhenOffline: false,
    );

    final cachedJson = await _cache.get(
      policy: policy,
      fetcher: () async {
        final response = await _postJson(
          '/api/Seat/seat',
          effectiveQuery.toSeatPayload(roomId),
        );
        final data = response['data'];
        if (data is! List) {
          throw NetworkException('座位数据格式异常');
        }
        final seats = data
            .whereType<Map>()
            .map(
              (e) => LibrarySeatDetail.fromJson(Map<String, dynamic>.from(e)),
            )
            .toList();
        return json.encode(seats.map((seat) => seat.toJson()).toList());
      },
    );

    if (cachedJson == null) return [];

    final data = json.decode(cachedJson) as List<dynamic>;
    return data
        .map((e) => LibrarySeatDetail.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// 获取房间地图资源。
  Future<LibraryRoomMap> fetchRoomMap(
    LibraryRoomNode room, {
    bool useCache = true,
  }) async {
    final policy = CachePolicy(
      key: 'library_room_map_auth_v2_${room.id}_$_cacheScope',
      strategy:
          useCache ? CacheStrategy.networkFirst : CacheStrategy.networkOnly,
      ttl: const Duration(hours: 24),
      allowStaleWhenOffline: false,
    );

    String? cachedJson;
    try {
      cachedJson = await _cache.get(
        policy: policy,
        fetcher: () async {
          final response = await _postJson('/api/seat/map', {'id': room.id});
          final data = response['data'];
          if (data is! Map) {
            throw NetworkException('地图数据格式异常');
          }
          final map = LibraryRoomMap.fromJson(Map<String, dynamic>.from(data));
          return json.encode(map.toJson());
        },
      );
    } catch (_) {
      cachedJson = null;
    }

    final mapData = cachedJson == null
        ? const LibraryRoomMap()
        : LibraryRoomMap.fromJson(
            json.decode(cachedJson) as Map<String, dynamic>,
          );

    return LibraryRoomMap(
      config: _libraryImageUrl(mapData.config),
      free: _libraryImageUrl(mapData.free),
      leave: _libraryImageUrl(mapData.leave),
      book: _libraryImageUrl(mapData.book),
      use: _libraryImageUrl(mapData.use),
      close: _libraryImageUrl(mapData.close),
      notAvailable: _libraryImageUrl(mapData.notAvailable),
      imageUrl: _libraryImageUrl(mapData.imageUrl ?? room.imageUrl),
      width: mapData.width,
      height: mapData.height,
    );
  }

  Future<List<LibrarySeat>> _fetchRoomSummaries(
    LibrarySeatQuery query, {
    required bool useCache,
  }) async {
    return _fetchReserveRoomSummaries(query, useCache: useCache);
  }

  Future<List<LibrarySeat>> _fetchReserveRoomSummaries(
    LibrarySeatQuery query, {
    required bool useCache,
  }) async {
    final summaries = <LibrarySeat>[];
    const pageSize = 200;
    var page = 1;
    var total = 0;

    do {
      final response = await _postJson(
        '/reserve/index/list',
        query.toReserveListPayload(page: page, size: pageSize),
      );
      final pageRooms = parseReserveRoomList(response);
      summaries.addAll(pageRooms);

      final data = response['data'];
      total = data is Map ? _parseInt(data['count']) : summaries.length;
      page += 1;
    } while (summaries.length < total);

    summaries.sort(
      (a, b) => '${a.premisesName}${a.storeyName}${a.name}'.compareTo(
        '${b.premisesName}${b.storeyName}${b.name}',
      ),
    );
    return summaries;
  }

  Future<Map<String, dynamic>> _postJson(
    String path,
    Map<String, dynamic> data,
  ) async {
    final requestData = Map<String, dynamic>.from(data);
    final authHeader = _authorizationHeader;
    final headers = <String, dynamic>{};
    if (authHeader != null) {
      headers['Authorization'] = authHeader;
      headers['lang'] = 'zh';
    }

    final response = await _dio.post(
      path,
      data: requestData,
      options: headers.isEmpty ? null : Options(headers: headers),
    );

    if (response.statusCode != 200 || response.data == null) {
      throw NetworkException('请求失败: HTTP ${response.statusCode}');
    }

    final decoded =
        response.data is String ? json.decode(response.data) : response.data;
    if (decoded is! Map) {
      throw NetworkException('响应格式异常');
    }
    final responseMap = Map<String, dynamic>.from(decoded);

    final code = responseMap['code'];
    if (code?.toString() == '10001') {
      throw NetworkException('图书馆登录已过期，请重新登录');
    }

    final codeText = code?.toString();
    if (codeText != '0' && codeText != '1') {
      throw NetworkException(
        responseMap['msg']?.toString() ??
            responseMap['message']?.toString() ??
            '请求失败',
      );
    }

    return responseMap;
  }

  /// 将图书馆树压平为房间节点。
  static List<LibraryRoomNode> flattenRoomTree(List<dynamic> nodes) {
    final rooms = <LibraryRoomNode>[];

    void walk(
      List<dynamic> currentNodes, {
      String? libraryName,
      String? floorName,
    }) {
      for (final rawNode in currentNodes) {
        if (rawNode is! Map) continue;
        final node = Map<String, dynamic>.from(rawNode);
        final levels = node['levels']?.toString() ?? '';
        final type = node['type']?.toString() ?? '';
        final name = node['name']?.toString() ?? '';

        final nextLibrary =
            levels == '1' && name.isNotEmpty ? name : libraryName;
        final nextFloor = levels == '2' && name.isNotEmpty ? name : floorName;

        if (levels == '3' && type == '1') {
          final id = node['id']?.toString() ?? '';
          if (id.isNotEmpty) {
            rooms.add(
              LibraryRoomNode(
                id: id,
                name: name.isNotEmpty ? name : id,
                libraryName: nextLibrary ?? '图书馆',
                floorName: nextFloor ?? '',
                imageUrl: _absoluteUrl(node['image_url']?.toString()),
              ),
            );
          }
        }

        final children = node['children'];
        if (children is List) {
          walk(children, libraryName: nextLibrary, floorName: nextFloor);
        }
      }
    }

    walk(nodes);
    rooms.sort(
      (a, b) => '${a.libraryName}${a.floorName}${a.name}'.compareTo(
        '${b.libraryName}${b.floorName}${b.name}',
      ),
    );
    return rooms;
  }

  static LibrarySeat summarizeRoom(
    LibraryRoomNode room,
    List<LibrarySeatDetail> seats,
  ) {
    return LibrarySeat.fromRoom(room: room, seats: seats);
  }

  static List<LibrarySeat> parseReserveRoomList(Map<String, dynamic> response) {
    final data = response['data'];
    final list = data is Map ? data['list'] : data;
    if (list is! List) return [];

    return list
        .whereType<Map>()
        .map((item) => LibrarySeat.fromJson(Map<String, dynamic>.from(item)))
        .toList();
  }

  static LibraryRoomNode roomNodeFromSummary(LibrarySeat seat) {
    return LibraryRoomNode(
      id: seat.id,
      name: seat.name.isNotEmpty ? seat.name : seat.id,
      libraryName: seat.premisesName.isNotEmpty ? seat.premisesName : '图书馆',
      floorName: seat.storeyName,
      imageUrl: _absoluteUrl(seat.firstimg),
    );
  }

  static int _parseInt(dynamic value) {
    if (value == null) return 0;
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value) ?? 0;
    return 0;
  }

  /// 按建筑分组。
  Map<String, List<LibrarySeat>> groupByBuilding(List<LibrarySeat> seats) {
    final result = <String, List<LibrarySeat>>{};
    for (final seat in seats) {
      final key = seat.premisesName.isEmpty ? '图书馆' : seat.premisesName;
      result.putIfAbsent(key, () => []).add(seat);
    }
    return result;
  }

  /// 按楼层分组。
  Map<String, List<LibrarySeat>> groupByStorey(List<LibrarySeat> seats) {
    final result = <String, List<LibrarySeat>>{};
    for (final seat in seats) {
      final key = seat.storeyName.isEmpty ? '其他' : seat.storeyName;
      result.putIfAbsent(key, () => []).add(seat);
    }
    return result;
  }

  static String? _absoluteUrl(String? value) {
    if (value == null || value.isEmpty) return null;
    final uri = Uri.tryParse(value);
    if (uri == null) return null;
    if (uri.hasScheme) return value;
    if (value.startsWith('/')) return '$_bookingBaseUrl$value';
    return '$_bookingBaseUrl/$value';
  }

  static String? _libraryImageUrl(String? value) {
    final absoluteUrl = _absoluteUrl(value);
    if (absoluteUrl == null || !kIsWeb) return absoluteUrl;
    final encodedUrl = Uri.encodeQueryComponent(absoluteUrl);
    return '$_apiBaseUrl/library-image?url=$encodedUrl';
  }
}

class LibrarySeatQuery {
  final String day;
  final String segment;
  final String startTime;
  final String endTime;

  const LibrarySeatQuery({
    required this.day,
    this.segment = LibraryService.defaultSegment,
    this.startTime = LibraryService.defaultStartTime,
    this.endTime = LibraryService.defaultEndTime,
  });

  factory LibrarySeatQuery.today() {
    return LibrarySeatQuery(
      day: LibraryService.formatChinaDate(DateTime.now()),
    );
  }

  String get cacheKey => '${day}_${segment}_${startTime}_$endTime';

  Map<String, dynamic> toSeatPayload(String roomId) => {
        'area': roomId,
        'segment': segment,
        'day': day,
        'startTime': startTime,
        'endTime': endTime,
      };

  Map<String, dynamic> toReserveListPayload({
    required int page,
    required int size,
  }) =>
      {
        'id': '1',
        'date': day,
        'categoryIds': ['1'],
        'members': 0,
        'page': page,
        'size': size,
      };
}
