/// 图书馆房间节点，来自 /api/Seat/tree。
class LibraryRoomNode {
  final String id;
  final String name;
  final String libraryName;
  final String floorName;
  final String? imageUrl;

  const LibraryRoomNode({
    required this.id,
    required this.name,
    required this.libraryName,
    required this.floorName,
    this.imageUrl,
  });

  factory LibraryRoomNode.fromJson(Map<String, dynamic> json) {
    return LibraryRoomNode(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      libraryName: json['libraryName']?.toString() ?? '',
      floorName: json['floorName']?.toString() ?? '',
      imageUrl: json['imageUrl']?.toString(),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'libraryName': libraryName,
        'floorName': floorName,
        'imageUrl': imageUrl,
      };
}

/// 图书馆房间汇总数据。
///
/// 这个类型保留 LibrarySeat 命名，以兼容现有收藏、导出和列表代码。
class LibrarySeat {
  final String id;
  final String name;
  final String nameMerge;
  final String typeName;
  final String storeyName;
  final String premisesName;
  final String? firstimg;
  final List<String> images;
  final String? subtitle;
  final String? contents;
  final int totalNum;
  final int freeNum;
  final Map<String, int> statusCounts;

  const LibrarySeat({
    required this.id,
    required this.name,
    required this.nameMerge,
    required this.typeName,
    required this.storeyName,
    required this.premisesName,
    this.firstimg,
    this.images = const [],
    this.subtitle,
    this.contents,
    required this.totalNum,
    required this.freeNum,
    this.statusCounts = const {},
  });

  factory LibrarySeat.fromRoom({
    required LibraryRoomNode room,
    required List<LibrarySeatDetail> seats,
  }) {
    final counts = <String, int>{};
    for (final seat in seats) {
      final key = seat.statusLabel;
      counts[key] = (counts[key] ?? 0) + 1;
    }

    return LibrarySeat(
      id: room.id,
      name: room.name,
      nameMerge: room.name,
      typeName: '座位区',
      storeyName: room.floorName,
      premisesName: room.libraryName,
      firstimg: room.imageUrl,
      totalNum: seats.length,
      freeNum: seats.where((seat) => seat.isFree).length,
      statusCounts: counts,
    );
  }

  factory LibrarySeat.fromJson(Map<String, dynamic> json) {
    return LibrarySeat(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      nameMerge: json['nameMerge']?.toString() ?? '',
      typeName: json['type_name']?.toString() ?? '座位区',
      storeyName: json['storeyName']?.toString() ?? '',
      premisesName: json['premisesName']?.toString() ?? '',
      firstimg: json['firstimg']?.toString(),
      images:
          (json['img'] as List<dynamic>?)?.map((e) => e.toString()).toList() ??
              [],
      subtitle: json['sub_title']?.toString(),
      contents: json['contents']?.toString(),
      totalNum: _parseInt(json['total_num']),
      freeNum: _parseInt(json['free_num']),
      statusCounts: _parseStringIntMap(json['status_counts']),
    );
  }

  double get usageRate {
    if (totalNum == 0) return 0;
    return ((totalNum - freeNum) / totalNum).clamp(0.0, 1.0).toDouble();
  }

  int get usedNum => totalNum - freeNum;

  String get status {
    if (totalNum == 0) return '暂无座位';
    if (freeNum == 0) return '已满';
    if (usageRate > 0.9) return '紧张';
    if (usageRate > 0.6) return '较挤';
    return '空闲';
  }

  String get location {
    if (premisesName.isEmpty) return storeyName;
    if (storeyName.isEmpty) return premisesName;
    return '$premisesName · $storeyName';
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'nameMerge': nameMerge,
        'type_name': typeName,
        'storeyName': storeyName,
        'premisesName': premisesName,
        'firstimg': firstimg,
        'img': images,
        'sub_title': subtitle,
        'contents': contents,
        'total_num': totalNum,
        'free_num': freeNum,
        'status_counts': statusCounts,
      };

  static int _parseInt(dynamic value) {
    if (value == null) return 0;
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value) ?? 0;
    return 0;
  }

  static Map<String, int> _parseStringIntMap(dynamic value) {
    if (value is! Map) return {};
    return value.map((key, val) => MapEntry(key.toString(), _parseInt(val)));
  }
}

/// 单个座位状态，来自 /api/Seat/seat。
class LibrarySeatDetail {
  final String id;
  final String no;
  final String name;
  final String area;
  final String status;
  final String statusName;
  final String inLabel;
  final String? areaName;
  final double? pointX;
  final double? pointY;
  final double? width;
  final double? height;

  const LibrarySeatDetail({
    required this.id,
    required this.no,
    required this.name,
    required this.area,
    required this.status,
    required this.statusName,
    this.inLabel = '1',
    this.areaName,
    this.pointX,
    this.pointY,
    this.width,
    this.height,
  });

  factory LibrarySeatDetail.fromJson(Map<String, dynamic> json) {
    return LibrarySeatDetail(
      id: json['id']?.toString() ?? '',
      no: json['no']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      area: json['area']?.toString() ?? '',
      status: json['status']?.toString() ?? '',
      statusName: json['status_name']?.toString() ?? '',
      inLabel: json['in_label']?.toString() ?? '1',
      areaName: json['area_name']?.toString(),
      pointX: _parseDouble(json['point_x']),
      pointY: _parseDouble(json['point_y']),
      width: _parseDouble(json['width']),
      height: _parseDouble(json['height']),
    );
  }

  bool get hasPoint => pointX != null && pointY != null;

  bool get hasMapRect =>
      hasPoint && width != null && height != null && width! > 0 && height! > 0;

  bool get isFree => status == '1' || statusName == '空闲';

  bool get isInLabel => inLabel == '1';

  String get displayName {
    if (no.isNotEmpty) return no;
    if (name.isNotEmpty) return name;
    if (id.isNotEmpty) return id;
    return '未知座位';
  }

  String get statusLabel => statusName.isNotEmpty ? statusName : '状态 $status';

  Map<String, dynamic> toJson() => {
        'id': id,
        'no': no,
        'name': name,
        'area': area,
        'status': status,
        'status_name': statusName,
        'in_label': inLabel,
        'area_name': areaName,
        'point_x': pointX,
        'point_y': pointY,
        'width': width,
        'height': height,
      };

  static double? _parseDouble(dynamic value) {
    if (value == null) return null;
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value);
    return null;
  }
}

/// 房间地图资源，来自 /api/seat/map。
class LibraryRoomMap {
  final String? config;
  final String? free;
  final String? leave;
  final String? book;
  final String? use;
  final String? close;
  final String? notAvailable;
  final String? imageUrl;
  final double? width;
  final double? height;

  const LibraryRoomMap({
    this.config,
    this.free,
    this.leave,
    this.book,
    this.use,
    this.close,
    this.notAvailable,
    this.imageUrl,
    this.width,
    this.height,
  });

  factory LibraryRoomMap.fromJson(Map<String, dynamic> json) {
    return LibraryRoomMap(
      config: json['config']?.toString(),
      free: json['free']?.toString(),
      leave: json['leave']?.toString(),
      book: json['book']?.toString(),
      use: json['use']?.toString(),
      close: json['close']?.toString(),
      notAvailable: json['not']?.toString(),
      imageUrl: json['image_url']?.toString(),
      width: _parseDouble(json['width']),
      height: _parseDouble(json['height']),
    );
  }

  String? get preferredImageUrl =>
      _nonEmpty(config) ?? _nonEmpty(free) ?? _nonEmpty(imageUrl);

  /// 官方 H5 的地图模式以 free 图作为整张平面底图。
  String? get floorPlanImageUrl =>
      _nonEmpty(free) ?? _nonEmpty(config) ?? _nonEmpty(imageUrl);

  bool get hasNaturalSize =>
      width != null && height != null && width! > 0 && height! > 0;

  String? imageForSeat(LibrarySeatDetail seat) {
    final normalizedStatus = int.tryParse(seat.status);
    if (!seat.isInLabel) return _nonEmpty(notAvailable);
    if (normalizedStatus == 1) return _nonEmpty(free);
    if (normalizedStatus == 7) return _nonEmpty(leave);
    if ({2, 10, 11}.contains(normalizedStatus)) return _nonEmpty(book);
    if ({6, 8, 9}.contains(normalizedStatus)) return _nonEmpty(use);
    if ({3, 4, 5}.contains(normalizedStatus)) return _nonEmpty(close);
    return null;
  }

  Map<String, dynamic> toJson() => {
        'config': config,
        'free': free,
        'leave': leave,
        'book': book,
        'use': use,
        'close': close,
        'not': notAvailable,
        'image_url': imageUrl,
        'width': width,
        'height': height,
      };

  static String? _nonEmpty(String? value) {
    if (value == null || value.isEmpty) return null;
    return value;
  }

  static double? _parseDouble(dynamic value) {
    if (value == null) return null;
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value);
    return null;
  }
}

/// 房间详情页所需数据。
class LibraryRoomDetail {
  final LibraryRoomNode room;
  final List<LibrarySeatDetail> seats;
  final LibraryRoomMap map;

  const LibraryRoomDetail({
    required this.room,
    required this.seats,
    required this.map,
  });

  int get totalNum => seats.length;

  int get freeNum => seats.where((seat) => seat.isFree).length;

  bool get hasMap =>
      map.floorPlanImageUrl != null && seats.any((seat) => seat.hasPoint);

  Map<String, int> get statusCounts {
    final counts = <String, int>{};
    for (final seat in seats) {
      final key = seat.statusLabel;
      counts[key] = (counts[key] ?? 0) + 1;
    }
    return counts;
  }
}
