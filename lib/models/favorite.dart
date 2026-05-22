import 'package:flutter/material.dart';

/// 收藏项目类型
enum FavoriteType {
  busRoute, // 班车线路
  busStop, // 班车站点
  canteen, // 食堂
  canteenWindow, // 食堂窗口
  libraryRoom, // 图书馆房间
  librarySeat, // 图书馆座位
  custom, // 自定义
}

/// 收藏项目
class FavoriteItem {
  final String id;
  final FavoriteType type;
  final String title;
  final String? subtitle;
  final String? iconName;
  final Map<String, dynamic>? data;
  final DateTime createdAt;

  FavoriteItem({
    required this.id,
    required this.type,
    required this.title,
    this.subtitle,
    this.iconName,
    this.data,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  /// 从 JSON 创建
  factory FavoriteItem.fromJson(Map<String, dynamic> json) {
    return FavoriteItem(
      id: json['id'] as String,
      type: FavoriteType.values.firstWhere(
        (e) => e.name == json['type'],
        orElse: () => FavoriteType.custom,
      ),
      title: json['title'] as String,
      subtitle: json['subtitle'] as String?,
      iconName: json['iconName'] as String?,
      data: json['data'] as Map<String, dynamic>?,
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'] as String)
          : null,
    );
  }

  /// 转换为 JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'type': type.name,
      'title': title,
      'subtitle': subtitle,
      'iconName': iconName,
      'data': data,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  /// 获取图标
  IconData get icon {
    switch (type) {
      case FavoriteType.busRoute:
      case FavoriteType.busStop:
        return Icons.directions_bus_rounded;
      case FavoriteType.canteen:
      case FavoriteType.canteenWindow:
        return Icons.restaurant_rounded;
      case FavoriteType.libraryRoom:
      case FavoriteType.librarySeat:
        return Icons.menu_book_rounded;
      case FavoriteType.custom:
        return Icons.star_rounded;
    }
  }

  /// 获取类型名称
  String get typeName {
    switch (type) {
      case FavoriteType.busRoute:
        return '班车线路';
      case FavoriteType.busStop:
        return '班车站点';
      case FavoriteType.canteen:
        return '食堂';
      case FavoriteType.canteenWindow:
        return '食堂窗口';
      case FavoriteType.libraryRoom:
        return '图书馆';
      case FavoriteType.librarySeat:
        return '座位';
      case FavoriteType.custom:
        return '其他';
    }
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is FavoriteItem && other.id == id && other.type == type;
  }

  @override
  int get hashCode => Object.hash(id, type);

  FavoriteItem copyWith({
    String? id,
    FavoriteType? type,
    String? title,
    String? subtitle,
    String? iconName,
    Map<String, dynamic>? data,
    DateTime? createdAt,
  }) {
    return FavoriteItem(
      id: id ?? this.id,
      type: type ?? this.type,
      title: title ?? this.title,
      subtitle: subtitle ?? this.subtitle,
      iconName: iconName ?? this.iconName,
      data: data ?? this.data,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
