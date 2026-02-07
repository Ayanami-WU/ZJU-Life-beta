/// 班车类型
enum BusType {
  campusShuttle, // 校区班车
  campusInternal, // 校园小白车
}

extension BusTypeExtension on BusType {
  String get label {
    switch (this) {
      case BusType.campusShuttle:
        return '校区班车';
      case BusType.campusInternal:
        return '校园小白车';
    }
  }
}

/// 班车路线
class BusRoute {
  final String id;
  final String name;
  final String routeNumber;
  final BusType type;
  final String? notes;
  final List<BusSchedule> schedules;
  
  BusRoute({
    required this.id,
    required this.name,
    required this.routeNumber,
    required this.type,
    this.notes,
    this.schedules = const [],
  });
  
  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'routeNumber': routeNumber,
    'type': type.name,
    'notes': notes,
    'schedules': schedules.map((s) => s.toJson()).toList(),
  };
}

/// 班车时刻表
class BusSchedule {
  final String id;
  final String routeId;
  final String departureTime; // "HH:mm" 格式
  final String? arrivalTime;
  final String departureLocation;
  final String arrivalLocation;
  final List<int>? operatingDays; // 1-7 表示周一到周日
  
  BusSchedule({
    required this.id,
    required this.routeId,
    required this.departureTime,
    this.arrivalTime,
    required this.departureLocation,
    required this.arrivalLocation,
    this.operatingDays,
  });
  
  /// 获取发车时间的分钟数 (用于排序和计算)
  int get departureMinutes {
    final parts = departureTime.split(':');
    if (parts.length >= 2) {
      return int.parse(parts[0]) * 60 + int.parse(parts[1]);
    }
    return 0;
  }
  
  /// 判断今天是否运营
  bool get isOperatingToday {
    if (operatingDays == null) return true;
    final today = DateTime.now().weekday;
    return operatingDays!.contains(today);
  }
  
  Map<String, dynamic> toJson() => {
    'id': id,
    'routeId': routeId,
    'departureTime': departureTime,
    'arrivalTime': arrivalTime,
    'departureLocation': departureLocation,
    'arrivalLocation': arrivalLocation,
    'operatingDays': operatingDays,
  };
}

/// 班车站点
class BusStation {
  final String id;
  final String name;
  final String? campus;
  
  BusStation({
    required this.id,
    required this.name,
    this.campus,
  });
  
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is BusStation && runtimeType == other.runtimeType && id == other.id;
  
  @override
  int get hashCode => id.hashCode;
}

/// 常用班车站点
class BusStations {
  static final List<BusStation> zijingangStations = [
    BusStation(id: 'zjg_east', name: '紫金港东', campus: 'zijingang'),
    BusStation(id: 'zjg_west', name: '紫金港西', campus: 'zijingang'),
    BusStation(id: 'zjg_north', name: '紫金港北', campus: 'zijingang'),
  ];
  
  static final List<BusStation> yuquanStations = [
    BusStation(id: 'yq_main', name: '玉泉校区', campus: 'yuquan'),
    BusStation(id: 'yq_gate', name: '玉泉正门', campus: 'yuquan'),
  ];
  
  static final List<BusStation> xixiStations = [
    BusStation(id: 'xx_main', name: '西溪校区', campus: 'xixi'),
  ];
  
  static final List<BusStation> huajiachiStations = [
    BusStation(id: 'hjc_main', name: '华家池校区', campus: 'huajiachi'),
  ];
  
  static List<BusStation> get allStations => [
    ...zijingangStations,
    ...yuquanStations,
    ...xixiStations,
    ...huajiachiStations,
  ];
}

/// 校内环线站点
class InternalBusStop {
  final String id;
  final String name;
  final String? description;
  final List<int> arrivalTimes; // 以分钟表示的到站时间列表
  final double? latitude;
  final double? longitude;
  
  InternalBusStop({
    required this.id,
    required this.name,
    this.description,
    this.arrivalTimes = const [],
    this.latitude,
    this.longitude,
  });
  
  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'description': description,
    'arrivalTimes': arrivalTimes,
    'latitude': latitude,
    'longitude': longitude,
  };
}

/// 附近站点（带距离信息）
class NearbyStation {
  final String id;
  final String name;
  final String stationName;
  final double latitude;
  final double longitude;
  final double distance; // 米
  
  NearbyStation({
    required this.id,
    required this.name,
    required this.stationName,
    required this.latitude,
    required this.longitude,
    required this.distance,
  });
  
  /// 格式化距离显示
  String get formattedDistance {
    if (distance < 1000) {
      return '${distance.round()}米';
    } else {
      return '${(distance / 1000).toStringAsFixed(1)}公里';
    }
  }
  
  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'stationName': stationName,
    'latitude': latitude,
    'longitude': longitude,
    'distance': distance,
  };
}
