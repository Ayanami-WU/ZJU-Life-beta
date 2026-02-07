import '../models/bus.dart';

/// 班车搜索结果
class BusSearchResult {
  final BusRoute route;
  final BusSchedule schedule;
  final double relevance; // 相关度评分 0-1

  BusSearchResult({
    required this.route,
    required this.schedule,
    required this.relevance,
  });
}

/// 班车工具类
///
/// 提供搜索、过滤、排序等实用功能
class BusUtils {
  /// 搜索班车
  ///
  /// [routes] 所有路线
  /// [keyword] 搜索关键词（支持路线名、站点名）
  /// [from] 起点站（可选）
  /// [to] 终点站（可选）
  /// [timeRange] 时间范围（可选，格式 "HH:mm-HH:mm"）
  /// [type] 班车类型（可选）
  /// [onlyToday] 仅显示今天运营的班次
  static List<BusSearchResult> search({
    required List<BusRoute> routes,
    String? keyword,
    String? from,
    String? to,
    String? timeRange,
    BusType? type,
    bool onlyToday = false,
  }) {
    final results = <BusSearchResult>[];

    for (final route in routes) {
      // 类型过滤
      if (type != null && route.type != type) continue;

      for (final schedule in route.schedules) {
        // 今日运营过滤
        if (onlyToday && !schedule.isOperatingToday) continue;

        double relevance = 1.0;

        // 关键词匹配
        if (keyword != null && keyword.isNotEmpty) {
          final kw = keyword.toLowerCase();
          final routeName = route.name.toLowerCase();
          final routeNumber = route.routeNumber.toLowerCase();
          final departure = schedule.departureLocation.toLowerCase();
          final arrival = schedule.arrivalLocation.toLowerCase();

          if (!routeName.contains(kw) &&
              !routeNumber.contains(kw) &&
              !departure.contains(kw) &&
              !arrival.contains(kw)) {
            continue;
          }

          // 计算相关度
          if (routeName == kw || routeNumber == kw) {
            relevance = 1.0;
          } else if (routeName.contains(kw) || routeNumber.contains(kw)) {
            relevance = 0.8;
          } else if (departure.contains(kw) || arrival.contains(kw)) {
            relevance = 0.6;
          }
        }

        // 起点站过滤
        if (from != null && from.isNotEmpty) {
          if (!schedule.departureLocation.contains(from)) continue;
        }

        // 终点站过滤
        if (to != null && to.isNotEmpty) {
          if (!schedule.arrivalLocation.contains(to)) continue;
        }

        // 时间范围过滤
        if (timeRange != null && timeRange.isNotEmpty) {
          final parts = timeRange.split('-');
          if (parts.length == 2) {
            final startMinutes = _parseTimeToMinutes(parts[0]);
            final endMinutes = _parseTimeToMinutes(parts[1]);
            final scheduleMinutes = schedule.departureMinutes;

            if (scheduleMinutes < startMinutes || scheduleMinutes > endMinutes) {
              continue;
            }
          }
        }

        results.add(BusSearchResult(
          route: route,
          schedule: schedule,
          relevance: relevance,
        ));
      }
    }

    // 按相关度和发车时间排序
    results.sort((a, b) {
      final relevanceCmp = b.relevance.compareTo(a.relevance);
      if (relevanceCmp != 0) return relevanceCmp;
      return a.schedule.departureMinutes.compareTo(b.schedule.departureMinutes);
    });

    return results;
  }

  /// 获取下一班车（多个）
  ///
  /// [routes] 所有路线
  /// [limit] 返回数量限制
  /// [withinMinutes] 时间范围（分钟）
  static List<BusSearchResult> getUpcomingBuses({
    required List<BusRoute> routes,
    int limit = 5,
    int withinMinutes = 120,
  }) {
    final now = DateTime.now();
    final currentMinutes = now.hour * 60 + now.minute;
    final maxMinutes = currentMinutes + withinMinutes;

    final results = <BusSearchResult>[];

    for (final route in routes) {
      for (final schedule in route.schedules) {
        // 仅今日运营
        if (!schedule.isOperatingToday) continue;

        final scheduleMinutes = schedule.departureMinutes;

        // 在时间范围内
        if (scheduleMinutes > currentMinutes && scheduleMinutes <= maxMinutes) {
          // 计算紧迫度（越近越高）
          final minutesUntil = scheduleMinutes - currentMinutes;
          final urgency = 1.0 - (minutesUntil / withinMinutes);

          results.add(BusSearchResult(
            route: route,
            schedule: schedule,
            relevance: urgency,
          ));
        }
      }
    }

    // 按发车时间排序
    results.sort((a, b) =>
        a.schedule.departureMinutes.compareTo(b.schedule.departureMinutes));

    return results.take(limit).toList();
  }

  /// 按校区分组路线
  static Map<String, List<BusRoute>> groupByCampus(List<BusRoute> routes) {
    final result = <String, List<BusRoute>>{};

    for (final route in routes) {
      final campuses = _extractCampusFromRoute(route);
      for (final campus in campuses) {
        result.putIfAbsent(campus, () => []).add(route);
      }
    }

    return result;
  }

  /// 按类型分组
  static Map<BusType, List<BusRoute>> groupByType(List<BusRoute> routes) {
    final result = <BusType, List<BusRoute>>{};

    for (final route in routes) {
      result.putIfAbsent(route.type, () => []).add(route);
    }

    return result;
  }

  /// 获取某个站点的所有班次
  static List<BusSearchResult> getSchedulesForStation({
    required List<BusRoute> routes,
    required String stationName,
    bool departureOnly = false,
    bool arrivalOnly = false,
  }) {
    final results = <BusSearchResult>[];

    for (final route in routes) {
      for (final schedule in route.schedules) {
        final isDeparture = schedule.departureLocation.contains(stationName);
        final isArrival = schedule.arrivalLocation.contains(stationName);

        if (departureOnly && !isDeparture) continue;
        if (arrivalOnly && !isArrival) continue;
        if (!isDeparture && !isArrival) continue;

        results.add(BusSearchResult(
          route: route,
          schedule: schedule,
          relevance: isDeparture ? 1.0 : 0.8,
        ));
      }
    }

    // 按发车时间排序
    results.sort((a, b) =>
        a.schedule.departureMinutes.compareTo(b.schedule.departureMinutes));

    return results;
  }

  /// 计算两个时间的间隔（分钟）
  static int getMinutesUntil(String time) {
    final now = DateTime.now();
    final currentMinutes = now.hour * 60 + now.minute;
    final targetMinutes = _parseTimeToMinutes(time);

    if (targetMinutes > currentMinutes) {
      return targetMinutes - currentMinutes;
    } else {
      // 第二天的班次
      return 24 * 60 - currentMinutes + targetMinutes;
    }
  }

  /// 格式化时间差
  static String formatTimeUntil(int minutes) {
    if (minutes < 0) return '已发车';
    if (minutes == 0) return '即将发车';
    if (minutes < 60) return '$minutes分钟后';

    final hours = minutes ~/ 60;
    final mins = minutes % 60;
    if (mins == 0) return '$hours小时后';
    return '$hours小时$mins分钟后';
  }

  /// 判断是否是工作日
  static bool isWeekday() {
    final today = DateTime.now().weekday;
    return today >= 1 && today <= 5; // 周一到周五
  }

  /// 判断是否是周末
  static bool isWeekend() {
    final today = DateTime.now().weekday;
    return today == 6 || today == 7; // 周六、周日
  }

  /// 获取时段描述
  static String getTimeOfDay() {
    final hour = DateTime.now().hour;
    if (hour < 6) return '凌晨';
    if (hour < 9) return '早晨';
    if (hour < 12) return '上午';
    if (hour < 14) return '中午';
    if (hour < 18) return '下午';
    if (hour < 22) return '晚上';
    return '深夜';
  }

  /// 智能推荐班次
  ///
  /// 根据当前时间、工作日等因素推荐合适的班次
  static List<BusSearchResult> getRecommendations({
    required List<BusRoute> routes,
    int limit = 3,
  }) {
    final now = DateTime.now();
    final currentMinutes = now.hour * 60 + now.minute;
    final results = <BusSearchResult>[];

    for (final route in routes) {
      for (final schedule in route.schedules) {
        if (!schedule.isOperatingToday) continue;

        final scheduleMinutes = schedule.departureMinutes;
        if (scheduleMinutes <= currentMinutes) continue;

        final minutesUntil = scheduleMinutes - currentMinutes;

        // 推荐15-60分钟内的班次
        if (minutesUntil >= 15 && minutesUntil <= 60) {
          // 评分：时间越近评分越高
          final score = 1.0 - (minutesUntil - 15) / 45;

          results.add(BusSearchResult(
            route: route,
            schedule: schedule,
            relevance: score,
          ));
        }
      }
    }

    // 按评分排序
    results.sort((a, b) => b.relevance.compareTo(a.relevance));

    return results.take(limit).toList();
  }

  // ============ 私有工具方法 ============

  /// 解析时间字符串为分钟数
  static int _parseTimeToMinutes(String time) {
    final parts = time.trim().split(':');
    if (parts.length >= 2) {
      final hour = int.tryParse(parts[0]) ?? 0;
      final minute = int.tryParse(parts[1]) ?? 0;
      return hour * 60 + minute;
    }
    return 0;
  }

  /// 从路线名提取校区信息
  static Set<String> _extractCampusFromRoute(BusRoute route) {
    final campuses = <String>{};
    final name = route.name.toLowerCase();

    if (name.contains('紫金港') || name.contains('zjg')) campuses.add('紫金港');
    if (name.contains('玉泉') || name.contains('yq')) campuses.add('玉泉');
    if (name.contains('西溪') || name.contains('xx')) campuses.add('西溪');
    if (name.contains('华家池') || name.contains('hjc')) campuses.add('华家池');
    if (name.contains('之江') || name.contains('zj')) campuses.add('之江');
    if (name.contains('海宁') || name.contains('hn')) campuses.add('海宁');

    if (campuses.isEmpty) campuses.add('其他');

    return campuses;
  }
}
