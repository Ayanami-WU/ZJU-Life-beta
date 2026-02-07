import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../models/favorite.dart';

/// 收藏管理
class FavoritesProvider extends ChangeNotifier {
  static const String _favoritesKey = 'favorites';
  
  List<FavoriteItem> _favorites = [];
  bool _isLoaded = false;
  
  List<FavoriteItem> get favorites => List.unmodifiable(_favorites);
  bool get isLoaded => _isLoaded;
  
  List<FavoriteItem> get canteenFavorites =>
      _favorites.where((f) => f.type == FavoriteType.canteen || f.type == FavoriteType.canteenWindow).toList();
  
  List<FavoriteItem> get busFavorites =>
      _favorites.where((f) => f.type == FavoriteType.busRoute || f.type == FavoriteType.busStop).toList();
  
  List<FavoriteItem> get libraryFavorites =>
      _favorites.where((f) => f.type == FavoriteType.libraryRoom || f.type == FavoriteType.librarySeat).toList();
  
  /// 按类型分组的收藏
  Map<FavoriteType, List<FavoriteItem>> get groupedFavorites {
    final map = <FavoriteType, List<FavoriteItem>>{};
    for (final item in _favorites) {
      map.putIfAbsent(item.type, () => []).add(item);
    }
    return map;
  }
  
  FavoritesProvider() {
    _loadFavorites();
  }
  
  Future<void> _loadFavorites() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonString = prefs.getString(_favoritesKey);
      if (jsonString != null && jsonString.isNotEmpty) {
        final List<dynamic> jsonList = json.decode(jsonString);
        _favorites = jsonList.map((e) => FavoriteItem.fromJson(e)).toList();
      }
    } catch (e) {
      _favorites = [];
    }
    _isLoaded = true;
    notifyListeners();
  }
  
  Future<void> _saveFavorites() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = json.encode(_favorites.map((e) => e.toJson()).toList());
    await prefs.setString(_favoritesKey, jsonString);
  }
  
  bool isFavorite(String id) => _favorites.any((f) => f.id == id);
  
  bool isFavoriteByType(String id, FavoriteType type) => 
      _favorites.any((f) => f.id == id && f.type == type);
  
  Future<void> addFavorite(FavoriteItem item) async {
    if (!isFavorite(item.id)) {
      _favorites.insert(0, item); // 新收藏放在最前面
      await _saveFavorites();
      notifyListeners();
    }
  }
  
  Future<void> removeFavorite(String id) async {
    _favorites.removeWhere((f) => f.id == id);
    await _saveFavorites();
    notifyListeners();
  }
  
  Future<void> removeFavoriteByType(String id, FavoriteType type) async {
    _favorites.removeWhere((f) => f.id == id && f.type == type);
    await _saveFavorites();
    notifyListeners();
  }
  
  Future<bool> toggleFavorite(FavoriteItem item) async {
    if (isFavorite(item.id)) {
      await removeFavorite(item.id);
      return false;
    } else {
      await addFavorite(item);
      return true;
    }
  }
  
  /// 重新排序
  Future<void> reorder(int oldIndex, int newIndex) async {
    if (oldIndex < newIndex) {
      newIndex -= 1;
    }
    final item = _favorites.removeAt(oldIndex);
    _favorites.insert(newIndex, item);
    await _saveFavorites();
    notifyListeners();
  }
  
  /// 清空所有收藏
  Future<void> clear() async {
    _favorites.clear();
    await _saveFavorites();
    notifyListeners();
  }
  
  /// 刷新收藏列表
  Future<void> refresh() async {
    await _loadFavorites();
  }
}
