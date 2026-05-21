/// 图书馆座位区域数据
///
/// 对应 API: https://booking.lib.zju.edu.cn/reserve/index/list
/// 认证方式: JWT Bearer Token
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
  final List<BoutiqueSeat> boutique;

  LibrarySeat({
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
    this.boutique = const [],
  });

  /// 使用率 (0.0 - 1.0)
  double get usageRate {
    if (totalNum == 0) return 0;
    return ((totalNum - freeNum) / totalNum).clamp(0.0, 1.0);
  }

  /// 已用座位数
  int get usedNum => totalNum - freeNum;

  /// 状态描述
  String get status {
    if (freeNum == 0) return '已满';
    if (usageRate > 0.9) return '紧张';
    if (usageRate > 0.6) return '较挤';
    return '空闲';
  }

  /// 完整楼层位置 (如: "主馆 · 三层")
  String get location => '$premisesName · $storeyName';

  /// 从 API JSON 解析
  factory LibrarySeat.fromJson(Map<String, dynamic> json) {
    return LibrarySeat(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      nameMerge: json['nameMerge']?.toString() ?? '',
      typeName: json['type_name']?.toString() ?? '普通座位',
      storeyName: json['storeyName']?.toString() ?? '',
      premisesName: json['premisesName']?.toString() ?? '',
      firstimg: json['firstimg']?.toString(),
      images: (json['img'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      subtitle: json['sub_title']?.toString(),
      contents: json['contents']?.toString(),
      totalNum: _parseInt(json['total_num']),
      freeNum: _parseInt(json['free_num']),
      boutique: (json['boutique'] as List<dynamic>?)
              ?.map((e) => BoutiqueSeat.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
    );
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
        'boutique': boutique.map((b) => b.toJson()).toList(),
      };

  static int _parseInt(dynamic value) {
    if (value == null) return 0;
    if (value is int) return value;
    if (value is String) return int.tryParse(value) ?? 0;
    return 0;
  }
}

/// 精品座位类型
class BoutiqueSeat {
  final String id;
  final String name;
  final String? enname;

  BoutiqueSeat({
    required this.id,
    required this.name,
    this.enname,
  });

  factory BoutiqueSeat.fromJson(Map<String, dynamic> json) {
    return BoutiqueSeat(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      enname: json['enname']?.toString(),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'enname': enname,
      };
}

/// 座位列表分页响应
class LibrarySeatListResponse {
  final int page;
  final int size;
  final int totalPage;
  final int count;
  final List<LibrarySeat> list;

  LibrarySeatListResponse({
    required this.page,
    required this.size,
    required this.totalPage,
    required this.count,
    required this.list,
  });

  bool get hasMore => page < totalPage;

  factory LibrarySeatListResponse.fromJson(Map<String, dynamic> json) {
    final data = json['data'] as Map<String, dynamic>? ?? {};
    return LibrarySeatListResponse(
      page: data['page'] as int? ?? 1,
      size: data['size'] as int? ?? 10,
      totalPage: data['totalPage'] as int? ?? 1,
      count: data['count'] as int? ?? 0,
      list: (data['list'] as List<dynamic>?)
              ?.map(
                  (e) => LibrarySeat.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }
}
