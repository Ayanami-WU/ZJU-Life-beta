import 'dart:convert';
import 'package:intl/intl.dart';
import '../models/favorite.dart';
import '../models/bus.dart';
import '../models/canteen.dart';
import '../models/library.dart';

/// 导出格式
enum ExportFormat {
  json,
  csv,
}

/// 数据导出服务
///
/// 支持导出收藏、班车时刻表、食堂数据等为 JSON/CSV 格式
class ExportService {
  /// 导出收藏数据
  ///
  /// [favorites] 收藏列表
  /// [format] 导出格式
  /// 返回格式化的字符串
  static String exportFavorites({
    required List<FavoriteItem> favorites,
    ExportFormat format = ExportFormat.json,
  }) {
    if (format == ExportFormat.json) {
      return _exportFavoritesAsJson(favorites);
    } else {
      return _exportFavoritesAsCsv(favorites);
    }
  }

  /// 导出班车时刻表
  ///
  /// [routes] 班车路线列表
  /// [format] 导出格式
  static String exportBusSchedules({
    required List<BusRoute> routes,
    ExportFormat format = ExportFormat.json,
  }) {
    if (format == ExportFormat.json) {
      return _exportBusSchedulesAsJson(routes);
    } else {
      return _exportBusSchedulesAsCsv(routes);
    }
  }

  /// 导出食堂数据
  ///
  /// [canteens] 食堂列表
  /// [format] 导出格式
  static String exportCanteens({
    required List<CanteenData> canteens,
    ExportFormat format = ExportFormat.json,
  }) {
    if (format == ExportFormat.json) {
      return _exportCanteensAsJson(canteens);
    } else {
      return _exportCanteensAsCsv(canteens);
    }
  }

  /// 导出图书馆座位数据
  ///
  /// [seats] 座位列表
  /// [format] 导出格式
  static String exportLibrarySeats({
    required List<LibrarySeat> seats,
    ExportFormat format = ExportFormat.json,
  }) {
    if (format == ExportFormat.json) {
      return _exportLibrarySeatsAsJson(seats);
    } else {
      return _exportLibrarySeatAsCsv(seats);
    }
  }

  // ============ JSON 导出实现 ============

  static String _exportFavoritesAsJson(List<FavoriteItem> favorites) {
    final data = {
      'exportTime': DateTime.now().toIso8601String(),
      'version': '1.0',
      'type': 'favorites',
      'count': favorites.length,
      'data': favorites.map((f) => f.toJson()).toList(),
    };

    const encoder = JsonEncoder.withIndent('  ');
    return encoder.convert(data);
  }

  static String _exportBusSchedulesAsJson(List<BusRoute> routes) {
    final data = {
      'exportTime': DateTime.now().toIso8601String(),
      'version': '1.0',
      'type': 'bus_schedules',
      'count': routes.length,
      'data': routes.map((r) => r.toJson()).toList(),
    };

    const encoder = JsonEncoder.withIndent('  ');
    return encoder.convert(data);
  }

  static String _exportCanteensAsJson(List<CanteenData> canteens) {
    final data = {
      'exportTime': DateTime.now().toIso8601String(),
      'version': '1.0',
      'type': 'canteens',
      'count': canteens.length,
      'data': canteens.map((c) => c.toJson()).toList(),
    };

    const encoder = JsonEncoder.withIndent('  ');
    return encoder.convert(data);
  }

  static String _exportLibrarySeatsAsJson(List<LibrarySeat> seats) {
    final data = {
      'exportTime': DateTime.now().toIso8601String(),
      'version': '1.0',
      'type': 'library_seats',
      'count': seats.length,
      'data': seats.map((s) => s.toJson()).toList(),
    };

    const encoder = JsonEncoder.withIndent('  ');
    return encoder.convert(data);
  }

  // ============ CSV 导出实现 ============

  static String _exportFavoritesAsCsv(List<FavoriteItem> favorites) {
    final buffer = StringBuffer();

    // CSV 头部
    buffer.writeln('类型,标题,副标题,图标');

    // 数据行
    for (final item in favorites) {
      buffer.writeln(_csvRow([
        item.type.toString().split('.').last,
        item.title,
        item.subtitle ?? '',
        item.icon.codePoint.toString(),
      ]));
    }

    return buffer.toString();
  }

  static String _exportBusSchedulesAsCsv(List<BusRoute> routes) {
    final buffer = StringBuffer();

    // CSV 头部
    buffer.writeln('路线名称,线路编号,类型,发车时间,起点,终点,运营日,备注');

    // 数据行
    for (final route in routes) {
      for (final schedule in route.schedules) {
        buffer.writeln(_csvRow([
          route.name,
          route.routeNumber,
          route.type.label,
          schedule.departureTime,
          schedule.departureLocation,
          schedule.arrivalLocation,
          _formatOperatingDays(schedule.operatingDays),
          route.notes ?? '',
        ]));
      }
    }

    return buffer.toString();
  }

  static String _exportCanteensAsCsv(List<CanteenData> canteens) {
    final buffer = StringBuffer();

    // CSV 头部
    buffer.writeln('食堂ID,食堂名称,当前人数,容量,校区,拥挤程度,状态');

    // 数据行
    for (final canteen in canteens) {
      buffer.writeln(_csvRow([
        canteen.id,
        canteen.name,
        canteen.currentCount?.toString() ?? '0',
        canteen.capacity.toString(),
        canteen.campus ?? '',
        '${(canteen.crowdLevel * 100).toStringAsFixed(1)}%',
        canteen.crowdStatus,
      ]));
    }

    return buffer.toString();
  }

  static String _exportLibrarySeatAsCsv(List<LibrarySeat> seats) {
    final buffer = StringBuffer();

    // CSV 头部
    buffer.writeln('建筑,房间,楼层,总座位数,空闲座位数,占用率');

    // 数据行
    for (final seat in seats) {
      final occupancyRate = seat.totalNum > 0
          ? ((seat.totalNum - seat.freeNum) / seat.totalNum * 100)
              .toStringAsFixed(1)
          : '0.0';

      buffer.writeln(_csvRow([
        seat.premisesName,
        seat.name,
        seat.storeyName,
        seat.totalNum.toString(),
        seat.freeNum.toString(),
        '$occupancyRate%',
      ]));
    }

    return buffer.toString();
  }

  // ============ 工具方法 ============

  /// 生成 CSV 行（处理转义）
  static String _csvRow(List<String> fields) {
    return fields.map(_escapeCsvField).join(',');
  }

  /// 转义 CSV 字段
  static String _escapeCsvField(String field) {
    // 如果包含逗号、引号或换行，需要用引号包裹并转义
    if (field.contains(',') ||
        field.contains('"') ||
        field.contains('\n') ||
        field.contains('\r')) {
      // 引号加倍转义
      final escaped = field.replaceAll('"', '""');
      return '"$escaped"';
    }
    return field;
  }

  /// 格式化运营日
  static String _formatOperatingDays(List<int>? days) {
    if (days == null || days.isEmpty) return '每天';

    const dayNames = ['周一', '周二', '周三', '周四', '周五', '周六', '周日'];
    final names = days
        .where((d) => d >= 1 && d <= 7)
        .map((d) => dayNames[d - 1])
        .toList();

    // 判断是否是工作日
    if (days.length == 5 &&
        days.contains(1) &&
        days.contains(2) &&
        days.contains(3) &&
        days.contains(4) &&
        days.contains(5)) {
      return '工作日';
    }

    // 判断是否是周末
    if (days.length == 2 && days.contains(6) && days.contains(7)) {
      return '周末';
    }

    return names.join('、');
  }

  /// 获取导出文件名
  ///
  /// [type] 数据类型（favorites, bus, canteen, library）
  /// [format] 导出格式
  static String getExportFileName({
    required String type,
    required ExportFormat format,
  }) {
    final timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
    final ext = format == ExportFormat.json ? 'json' : 'csv';
    return 'zjulife_${type}_$timestamp.$ext';
  }

  /// 获取导出 MIME 类型
  static String getMimeType(ExportFormat format) {
    return format == ExportFormat.json
        ? 'application/json'
        : 'text/csv';
  }
}
