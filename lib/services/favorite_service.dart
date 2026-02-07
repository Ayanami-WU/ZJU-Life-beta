import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/favorite.dart';

/// 收藏服务 - 管理用户收藏
class FavoriteService {
  static const String _storageKey = 'zjulife_favorites';
  
  SharedPreferences? _prefs;
  
  /// 初始化
  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
  }
  
  /// 获取所有收藏
  Future<List<FavoriteItem>> getAll() async {
    await _ensureInitialized();
    
    final jsonStr = _prefs!.getString(_storageKey);
    if (jsonStr == null || jsonStr.isEmpty) {
      return [];
    }
    
    try {
      final List<dynamic> jsonList = json.decode(jsonStr);
      return jsonList
          .map((e) => FavoriteItem.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (e) {
      return [];
    }
  }
  
  /// 添加收藏
  Future<bool> add(FavoriteItem item) async {
    await _ensureInitialized();
    
    final items = await getAll();
    
    // 检查是否已存在
    if (items.any((e) => e.id == item.id && e.type == item.type)) {
      return false;
    }
    
    items.insert(0, item);
    await _save(items);
    return true;
  }
  
  /// 移除收藏
  Future<bool> remove(String id, FavoriteType type) async {
    await _ensureInitialized();
    
    final items = await getAll();
    final index = items.indexWhere((e) => e.id == id && e.type == type);
    
    if (index == -1) {
      return false;
    }
    
    items.removeAt(index);
    await _save(items);
    return true;
  }
  
  /// 切换收藏状态
  Future<bool> toggle(FavoriteItem item) async {
    if (await isFavorite(item.id, item.type)) {
      await remove(item.id, item.type);
      return false;
    } else {
      await add(item);
      return true;
    }
  }
  
  /// 检查是否已收藏
  Future<bool> isFavorite(String id, FavoriteType type) async {
    final items = await getAll();
    return items.any((e) => e.id == id && e.type == type);
  }
  
  /// 按类型获取收藏
  Future<List<FavoriteItem>> getByType(FavoriteType type) async {
    final items = await getAll();
    return items.where((e) => e.type == type).toList();
  }
  
  /// 清空所有收藏
  Future<void> clear() async {
    await _ensureInitialized();
    await _prefs!.remove(_storageKey);
  }
  
  /// 更新收藏项
  Future<bool> update(FavoriteItem item) async {
    await _ensureInitialized();
    
    final items = await getAll();
    final index = items.indexWhere((e) => e.id == item.id && e.type == item.type);
    
    if (index == -1) {
      return false;
    }
    
    items[index] = item;
    await _save(items);
    return true;
  }
  
  /// 重新排序
  Future<void> reorder(int oldIndex, int newIndex) async {
    final items = await getAll();
    
    if (oldIndex < 0 || oldIndex >= items.length) return;
    if (newIndex < 0 || newIndex > items.length) return;
    
    if (oldIndex < newIndex) {
      newIndex -= 1;
    }
    
    final item = items.removeAt(oldIndex);
    items.insert(newIndex, item);
    await _save(items);
  }
  
  // ============ Private Methods ============
  
  Future<void> _ensureInitialized() async {
    _prefs ??= await SharedPreferences.getInstance();
  }
  
  Future<void> _save(List<FavoriteItem> items) async {
    final jsonList = items.map((e) => e.toJson()).toList();
    await _prefs!.setString(_storageKey, json.encode(jsonList));
  }
}
