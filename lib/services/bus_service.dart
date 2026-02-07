import 'dart:convert';
import 'package:dio/dio.dart';
import '../models/bus.dart';
import 'http_service.dart';
import 'cache_service.dart';
import '../utils/dio_exception_handler.dart';

/// 班车服务
///
/// 班车数据来源: https://bccx.zju.edu.cn/schoolbus_wx/
/// 注意：需要在校园网内访问
class BusService {
  final HttpService _http = HttpService.instance;
  final CacheService _cache = CacheService.instance;

  // API 基础地址
  static const String _baseUrl = 'https://bccx.zju.edu.cn/schoolbus_wx';
  
  /// 获取所有站点列表
  ///
  /// [useCache] 是否使用缓存（默认 true）
  Future<List<BusStation>> fetchStations({bool useCache = true}) async {
    // 缓存策略：站点数据相对静态，24小时有效期
    final policy = CachePolicy(
      key: 'bus_stations',
      strategy: useCache ? CacheStrategy.cacheFirst : CacheStrategy.networkOnly,
      ttl: const Duration(hours: 24),
      allowStaleWhenOffline: true,
    );

    return await DioExceptionHandler.wrap(
      operation: () async {
        final cachedJson = await _cache.get(
          policy: policy,
          fetcher: () => _fetchStationsFromNetwork(),
        );

        if (cachedJson != null) {
          final data = json.decode(cachedJson);
          if (data['success'] == true && data['data'] is List) {
            return (data['data'] as List).map((item) {
              return BusStation(
                id: item['station_alias'] ?? '',
                name: item['station_alias'] ?? '',
                campus: _getCampusFromSort(item['station_sort']),
              );
            }).toList();
          }
        }

        throw NetworkException('获取站点数据失败');
      },
      context: '获取站点数据失败',
    );
  }

  /// 从网络获取站点数据
  Future<String> _fetchStationsFromNetwork() async {
    final response = await _http.dio.get(
      '$_baseUrl/stationlist',
      options: Options(
        headers: {
          'Accept': 'application/json',
          'User-Agent': 'Mozilla/5.0 (Linux; Android 10) AppleWebKit/537.36',
        },
      ),
    );

    if (response.statusCode == 200 && response.data != null) {
      return json.encode(response.data);
    }

    throw NetworkException('获取站点数据失败');
  }
  
  /// 根据 station_sort 获取校区名
  String _getCampusFromSort(dynamic sort) {
    switch (sort) {
      case 1: return 'zijingang';
      case 2: return 'yuquan';
      case 3: return 'xixi';
      case 4: return 'huajiachi';
      case 5: return 'zhijiang';
      case 6: return 'hubin';
      default: return 'other';
    }
  }
  
  /// 获取附近站点（需要位置信息）
  Future<List<NearbyStation>> fetchNearbyStations(double lat, double lng) async {
    return await DioExceptionHandler.wrap(
      operation: () async {
        final response = await _http.dio.get(
          '$_baseUrl/getnearstation',
          queryParameters: {
            'lat': lat,
            'lng': lng,
          },
          options: Options(
            headers: {
              'Accept': 'application/json',
              'User-Agent': 'Mozilla/5.0 (Linux; Android 10) AppleWebKit/537.36',
            },
          ),
        );

        if (response.statusCode == 200 && response.data != null) {
          final data = response.data;
          if (data['success'] == true && data['data'] is List) {
            return (data['data'] as List).map((item) {
              return NearbyStation(
                id: item['station_alias_no'] ?? '',
                name: item['station_alias'] ?? '',
                stationName: item['station_name'] ?? '',
                latitude: (item['station_lat'] as num?)?.toDouble() ?? 0,
                longitude: (item['station_long'] as num?)?.toDouble() ?? 0,
                distance: (item['distance'] as num?)?.toDouble() ?? 0,
              );
            }).toList();
          }
        }
        throw NetworkException('获取附近站点失败');
      },
      context: '获取附近站点失败',
    );
  }
  
  /// 获取所有班车路线和时刻表
  ///
  /// 由于 API 可能需要具体查询，暂时使用静态数据
  /// 抛出 [NetworkException] 如果网络请求失败
  Future<List<BusRoute>> fetchBusRoutes(BusType type) async {
    return await DioExceptionHandler.wrap(
      operation: () async {
        // 尝试从服务器获取数据，如果失败则使用静态数据
        // TODO: 当找到时刻表 API 时替换
        if (type == BusType.campusShuttle) {
          return _getStaticShuttleRoutes();
        } else {
          return _getStaticInternalRoutes();
        }
      },
      context: '获取班车数据失败',
    );
  }
  
  /// 静态校区班车时刻表 (紫金港-玉泉)
  List<BusRoute> _getStaticShuttleRoutes() {
    return [
      BusRoute(
        id: 'zjg_yq_morning',
        name: '紫金港→玉泉',
        routeNumber: 'A线',
        type: BusType.campusShuttle,
        notes: '工作日运行',
        schedules: [
          for (final time in [
            '07:00', '07:15', '07:30', '07:45', '08:00', '08:15', '08:30',
            '09:00', '09:30', '10:00', '10:30', '11:00', '11:30',
            '12:00', '12:30', '13:00', '13:30', '14:00', '14:30', '15:00',
            '15:30', '16:00', '16:30', '17:00', '17:30', '18:00', '18:30',
            '19:00', '19:30', '20:00', '20:30', '21:00', '21:30', '22:00',
          ])
            BusSchedule(
              id: 'zjg_yq_$time',
              routeId: 'zjg_yq_morning',
              departureTime: time,
              departureLocation: '紫金港校区(蓝田南门)',
              arrivalLocation: '玉泉校区',
              operatingDays: [1, 2, 3, 4, 5], // 周一到周五
            ),
        ],
      ),
      BusRoute(
        id: 'yq_zjg_morning',
        name: '玉泉→紫金港',
        routeNumber: 'A线',
        type: BusType.campusShuttle,
        notes: '工作日运行',
        schedules: [
          for (final time in [
            '07:00', '07:15', '07:30', '07:45', '08:00', '08:15', '08:30',
            '09:00', '09:30', '10:00', '10:30', '11:00', '11:30',
            '12:00', '12:30', '13:00', '13:30', '14:00', '14:30', '15:00',
            '15:30', '16:00', '16:30', '17:00', '17:30', '18:00', '18:30',
            '19:00', '19:30', '20:00', '20:30', '21:00', '21:30', '22:00',
          ])
            BusSchedule(
              id: 'yq_zjg_$time',
              routeId: 'yq_zjg_morning',
              departureTime: time,
              departureLocation: '玉泉校区(正门)',
              arrivalLocation: '紫金港校区',
              operatingDays: [1, 2, 3, 4, 5], // 周一到周五
            ),
        ],
      ),
      BusRoute(
        id: 'zjg_xx',
        name: '紫金港→西溪',
        routeNumber: 'B线',
        type: BusType.campusShuttle,
        notes: '工作日运行',
        schedules: [
          for (final time in [
            '07:30', '08:00', '08:30', '09:30', '10:30', '11:30',
            '13:30', '14:30', '15:30', '16:30', '17:30', '18:30',
            '20:00', '21:30',
          ])
            BusSchedule(
              id: 'zjg_xx_$time',
              routeId: 'zjg_xx',
              departureTime: time,
              departureLocation: '紫金港校区',
              arrivalLocation: '西溪校区',
              operatingDays: [1, 2, 3, 4, 5],
            ),
        ],
      ),
      BusRoute(
        id: 'xx_zjg',
        name: '西溪→紫金港',
        routeNumber: 'B线',
        type: BusType.campusShuttle,
        notes: '工作日运行',
        schedules: [
          for (final time in [
            '07:30', '08:00', '08:30', '09:30', '10:30', '11:30',
            '13:30', '14:30', '15:30', '16:30', '17:30', '18:30',
            '20:00', '21:30',
          ])
            BusSchedule(
              id: 'xx_zjg_$time',
              routeId: 'xx_zjg',
              departureTime: time,
              departureLocation: '西溪校区',
              arrivalLocation: '紫金港校区',
              operatingDays: [1, 2, 3, 4, 5],
            ),
        ],
      ),
      BusRoute(
        id: 'zjg_hjc',
        name: '紫金港→华家池',
        routeNumber: 'C线',
        type: BusType.campusShuttle,
        notes: '工作日运行',
        schedules: [
          for (final time in [
            '07:30', '08:30', '10:30', '13:30', '15:30', '17:30', '21:00',
          ])
            BusSchedule(
              id: 'zjg_hjc_$time',
              routeId: 'zjg_hjc',
              departureTime: time,
              departureLocation: '紫金港校区',
              arrivalLocation: '华家池校区',
              operatingDays: [1, 2, 3, 4, 5],
            ),
        ],
      ),
      BusRoute(
        id: 'hjc_zjg',
        name: '华家池→紫金港',
        routeNumber: 'C线',
        type: BusType.campusShuttle,
        notes: '工作日运行',
        schedules: [
          for (final time in [
            '07:30', '08:30', '10:30', '13:30', '15:30', '17:30', '21:00',
          ])
            BusSchedule(
              id: 'hjc_zjg_$time',
              routeId: 'hjc_zjg',
              departureTime: time,
              departureLocation: '华家池校区',
              arrivalLocation: '紫金港校区',
              operatingDays: [1, 2, 3, 4, 5],
            ),
        ],
      ),
    ];
  }
  
  /// 静态校内环线时刻表 (小白车)
  /// 数据来源：紫金港校区小白车运行时刻表
  List<BusRoute> _getStaticInternalRoutes() {
    // 线路1（顺时针）站点：东大门→风雨操场→东教学区→生科院→医药组团→人文社科组团→管理学院→理工组团→材化高组团→北教学区→生活区
    // 线路2（逆时针）站点：生活区→北教学区→材化高组团→理工组团→管理学院→人文社科组团→医药组团→生科院→东教学区→风雨操场→东大门→生活区
    
    // 线路1发车时间
    final route1Times = ['07:40', '08:10', '08:30'];
    
    // 线路2发车时间
    final route2Times = [
      '08:50', '09:10', '09:35', '10:00', '10:25', '10:50',
      '11:15', '11:40', '12:05', '12:30', '12:55', '13:20',
      '13:45', '14:10', '14:35', '15:00', '15:25', '15:50',
      '16:15', '16:40', '17:05', '17:25', '18:00',
    ];
    
    return [
      // 线路1 顺时针
      BusRoute(
        id: 'internal_route1',
        name: '线路1（顺时针）',
        routeNumber: '小白车',
        type: BusType.campusInternal,
        notes: '东大门→风雨操场→东教学区→生科院→医药组团→人文社科组团→管理学院→理工组团→材化高组团→北教学区→生活区',
        schedules: [
          for (final time in route1Times)
            BusSchedule(
              id: 'internal_r1_$time',
              routeId: 'internal_route1',
              departureTime: time,
              departureLocation: '东大门',
              arrivalLocation: '生活区',
              operatingDays: [1, 2, 3, 4, 5],
            ),
        ],
      ),
      // 线路2 逆时针
      BusRoute(
        id: 'internal_route2',
        name: '线路2（逆时针）',
        routeNumber: '小白车',
        type: BusType.campusInternal,
        notes: '生活区→北教学区→材化高组团→理工组团→管理学院→人文社科组团→医药组团→生科院→东教学区→风雨操场→东大门→生活区',
        schedules: [
          for (final time in route2Times)
            BusSchedule(
              id: 'internal_r2_$time',
              routeId: 'internal_route2',
              departureTime: time,
              departureLocation: '生活区',
              arrivalLocation: '生活区（环线）',
              operatingDays: [1, 2, 3, 4, 5],
            ),
        ],
      ),
    ];
  }
  
  /// 获取校内环线站点数据
  /// 小白车站点顺序（线路1顺时针方向）
  List<InternalBusStop> fetchInternalBusStops() {
    // 站点列表（按顺时针顺序）
    final stops = [
      '东大门',
      '风雨操场',
      '东教学区',
      '生科院',
      '医药组团',
      '人文社科组团',
      '管理学院',
      '理工组团',
      '材化高组团',
      '北教学区',
      '生活区',
    ];
    
    // 线路1发车时间（分钟）
    final route1StartTimes = [7 * 60 + 40, 8 * 60 + 10, 8 * 60 + 30];
    
    // 线路2发车时间（分钟）
    final route2StartTimes = [
      8 * 60 + 50, 9 * 60 + 10, 9 * 60 + 35, 10 * 60, 10 * 60 + 25, 10 * 60 + 50,
      11 * 60 + 15, 11 * 60 + 40, 12 * 60 + 5, 12 * 60 + 30, 12 * 60 + 55, 13 * 60 + 20,
      13 * 60 + 45, 14 * 60 + 10, 14 * 60 + 35, 15 * 60, 15 * 60 + 25, 15 * 60 + 50,
      16 * 60 + 15, 16 * 60 + 40, 17 * 60 + 5, 17 * 60 + 25, 18 * 60,
    ];
    
    // 估计每站间隔约2分钟
    const intervalPerStop = 2;
    
    return [
      for (var i = 0; i < stops.length; i++)
        InternalBusStop(
          id: 'stop_$i',
          name: stops[i],
          description: '第${i + 1}站',
          arrivalTimes: [
            // 线路1到达时间
            for (final start in route1StartTimes) start + i * intervalPerStop,
            // 线路2到达时间（逆时针，从生活区开始）
            for (final start in route2StartTimes) start + (stops.length - 1 - i) * intervalPerStop,
          ],
        ),
    ];
  }
  
  /// 搜索班车
  /// 
  /// [from] 起点站
  /// [to] 终点站
  /// [date] 日期
  /// [time] 时间
  List<BusSchedule> searchSchedules({
    required List<BusRoute> routes,
    String? from,
    String? to,
    DateTime? date,
    DateTime? time,
  }) {
    final results = <BusSchedule>[];
    
    for (final route in routes) {
      for (final schedule in route.schedules) {
        // 检查站点匹配
        final matchFrom = from == null || 
            from.isEmpty || 
            schedule.departureLocation.contains(from);
        final matchTo = to == null || 
            to.isEmpty || 
            schedule.arrivalLocation.contains(to);
        
        // 检查日期
        final matchDate = date == null || schedule.isOperatingToday;
        
        if (matchFrom && matchTo && matchDate) {
          results.add(schedule);
        }
      }
    }
    
    // 按发车时间排序
    results.sort((a, b) => a.departureMinutes.compareTo(b.departureMinutes));
    
    return results;
  }
  
  /// 获取下一班车
  BusSchedule? getNextBus(List<BusSchedule> schedules) {
    final now = DateTime.now();
    final currentMinutes = now.hour * 60 + now.minute;
    
    for (final schedule in schedules) {
      if (schedule.departureMinutes > currentMinutes) {
        return schedule;
      }
    }
    return null;
  }
}
