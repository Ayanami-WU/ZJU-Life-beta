import 'dart:convert';

/// 食堂数据模型
class CanteenData {
  final String id;
  final String name;
  final int? currentCount;
  final int capacity;
  final String? campus;

  CanteenData({
    required this.id,
    required this.name,
    this.currentCount,
    required this.capacity,
    this.campus,
  });

  /// 拥挤程度 (0.0 - 1.0)
  double get crowdLevel {
    if (currentCount == null || capacity == 0) return 0;
    return (currentCount! / capacity).clamp(0.0, 1.0);
  }

  /// 拥挤状态描述
  String get crowdStatus {
    if (currentCount == null) return '暂无数据';
    if (crowdLevel < 0.3) return '空闲';
    if (crowdLevel < 0.6) return '适中';
    if (crowdLevel < 0.85) return '较挤';
    return '拥挤';
  }

  /// 从 API 响应解析
  factory CanteenData.fromApiResponse({
    required String id,
    required String name,
    String? countStr,
    required int capacity,
  }) {
    int? count;
    if (countStr != null && countStr.isNotEmpty) {
      count = int.tryParse(countStr);
    }

    return CanteenData(
      id: id,
      name: name,
      currentCount: count,
      capacity: capacity,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'currentCount': currentCount,
        'capacity': capacity,
        'campus': campus,
      };
}

/// 食堂 API 响应解析
class CanteenApiResponse {
  final List<CanteenData> canteens;
  final DateTime fetchedAt;

  CanteenApiResponse({
    required this.canteens,
    DateTime? fetchedAt,
  }) : fetchedAt = fetchedAt ?? DateTime.now();

  /// 解析 general_new.php 返回的数据
  /// {
  ///   "data": {
  ///     "canteen_name": [...],
  ///     "canteen_no": [...],
  ///     "canteen_num": [...],
  ///     "canteen_allowance": [...]
  ///   }
  /// }
  factory CanteenApiResponse.fromRawJson(String rawJson) {
    var normalized = rawJson;
    if (normalized.isNotEmpty && normalized.codeUnitAt(0) == 0xFEFF) {
      normalized = normalized.substring(1);
    }
    if (normalized.startsWith('ï»¿')) {
      normalized = normalized.substring(3);
    }

    final decoded = json.decode(normalized);
    if (decoded is! Map) {
      throw const FormatException('食堂数据格式错误');
    }

    return CanteenApiResponse.fromJson(Map<String, dynamic>.from(decoded));
  }

  factory CanteenApiResponse.fromJson(Map<String, dynamic> json) {
    final rawData = json['data'];
    if (rawData is! Map) {
      throw const FormatException('食堂数据格式错误');
    }

    final data = Map<String, dynamic>.from(rawData);
    final names = _asStringList(data['canteen_name']);
    final ids = _asStringList(data['canteen_no']);
    final counts = _asList(data['canteen_num']);
    final capacities = _asList(data['canteen_allowance']);

    final canteens = <CanteenData>[];
    for (int i = 0; i < names.length && i < ids.length; i++) {
      canteens.add(CanteenData.fromApiResponse(
        id: ids[i],
        name: names[i],
        countStr: counts.length > i ? counts[i]?.toString() : null,
        capacity: capacities.length > i ? _parseInt(capacities[i]) ?? 0 : 0,
      ));
    }

    return CanteenApiResponse(canteens: canteens);
  }

  static List<dynamic> _asList(dynamic value) {
    return value is List ? value : const [];
  }

  static List<String> _asStringList(dynamic value) {
    return _asList(value).map((item) => item.toString()).toList();
  }

  static int? _parseInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '');
  }
}
