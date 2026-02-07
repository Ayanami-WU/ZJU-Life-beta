/// 图书馆/自习室座位数据
class LibrarySeat {
  final String id;
  final String roomName;
  final String buildingName;
  final int totalSeats;
  final int availableSeats;
  final String? floor;
  
  LibrarySeat({
    required this.id,
    required this.roomName,
    required this.buildingName,
    required this.totalSeats,
    required this.availableSeats,
    this.floor,
  });
  
  /// 使用率 (0.0 - 1.0)
  double get usageRate {
    if (totalSeats == 0) return 0;
    return ((totalSeats - availableSeats) / totalSeats).clamp(0.0, 1.0);
  }
  
  /// 状态描述
  String get status {
    if (availableSeats == 0) return '已满';
    if (usageRate > 0.9) return '紧张';
    if (usageRate > 0.6) return '较挤';
    return '空闲';
  }
  
  Map<String, dynamic> toJson() => {
    'id': id,
    'roomName': roomName,
    'buildingName': buildingName,
    'totalSeats': totalSeats,
    'availableSeats': availableSeats,
    'floor': floor,
  };
  
  /// 从图书馆预约系统的 HTML 解析
  /// 格式: "座位 48\n空闲 12"
  factory LibrarySeat.fromHtmlText({
    required String id,
    required String roomName,
    required String buildingName,
    required String text,
    String? floor,
  }) {
    final lines = text.split('\n');
    int total = 0;
    int available = 0;
    
    for (final line in lines) {
      if (line.contains('座位')) {
        final match = RegExp(r'(\d+)').firstMatch(line);
        if (match != null) {
          total = int.parse(match.group(1)!);
        }
      } else if (line.contains('空闲')) {
        final match = RegExp(r'(\d+)').firstMatch(line);
        if (match != null) {
          available = int.parse(match.group(1)!);
        }
      }
    }
    
    return LibrarySeat(
      id: id,
      roomName: roomName,
      buildingName: buildingName,
      totalSeats: total,
      availableSeats: available,
      floor: floor,
    );
  }
}

/// 自习室区域
class StudyArea {
  final String id;
  final String name;
  final String campus;
  final List<LibrarySeat> seats;
  
  StudyArea({
    required this.id,
    required this.name,
    required this.campus,
    this.seats = const [],
  });
  
  int get totalSeats => seats.fold(0, (sum, s) => sum + s.totalSeats);
  int get availableSeats => seats.fold(0, (sum, s) => sum + s.availableSeats);
  
  double get usageRate {
    if (totalSeats == 0) return 0;
    return ((totalSeats - availableSeats) / totalSeats).clamp(0.0, 1.0);
  }
}
