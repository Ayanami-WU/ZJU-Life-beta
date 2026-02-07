import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 校区枚举
enum Campus {
  zijingang('紫金港', 'zjg'),
  yuquan('玉泉', 'yq'),
  xixi('西溪', 'xx'),
  huajiachi('华家池', 'hjc'),
  haining('海宁', 'hn'),
  zhoushan('舟山', 'zs');

  final String label;
  final String code;
  
  const Campus(this.label, this.code);
  
  static Campus fromCode(String code) {
    return Campus.values.firstWhere(
      (c) => c.code == code,
      orElse: () => Campus.zijingang,
    );
  }
}

/// 校区选择 Provider
class CampusProvider extends ChangeNotifier {
  static const String _cacheKey = 'selected_campus';
  
  Campus _selectedCampus = Campus.zijingang;
  
  Campus get selectedCampus => _selectedCampus;
  
  CampusProvider() {
    _loadFromCache();
  }
  
  Future<void> _loadFromCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final code = prefs.getString(_cacheKey);
      if (code != null) {
        _selectedCampus = Campus.fromCode(code);
        notifyListeners();
      }
    } catch (e) {
      debugPrint('CampusProvider: Failed to load campus: $e');
    }
  }
  
  Future<void> selectCampus(Campus campus) async {
    if (_selectedCampus == campus) return;
    
    _selectedCampus = campus;
    notifyListeners();
    
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_cacheKey, campus.code);
    } catch (e) {
      debugPrint('CampusProvider: Failed to save campus: $e');
    }
  }
  
  /// 获取校区对应的食堂关键词
  List<String> get canteenKeywords {
    switch (_selectedCampus) {
      case Campus.zijingang:
        return ['银泉', '玉湖', '澄月', '麦香', '临湖'];
      case Campus.yuquan:
        return ['玉泉一', '玉泉二', '玉泉四'];
      case Campus.xixi:
        return ['西溪一', '西溪二'];
      case Campus.huajiachi:
        return ['华家池一', '华家池五'];
      case Campus.haining:
        return ['海宁'];
      case Campus.zhoushan:
        return ['舟山'];
    }
  }
  
  /// 获取校区对应的班车关键词
  List<String> get busKeywords {
    switch (_selectedCampus) {
      case Campus.zijingang:
        return ['紫金港'];
      case Campus.yuquan:
        return ['玉泉'];
      case Campus.xixi:
        return ['西溪'];
      case Campus.huajiachi:
        return ['华家池'];
      case Campus.haining:
        return ['海宁'];
      case Campus.zhoushan:
        return ['舟山'];
    }
  }
  
  /// 获取校区对应的自习室/图书馆关键词
  List<String> get libraryKeywords {
    switch (_selectedCampus) {
      case Campus.zijingang:
        return ['紫金港'];
      case Campus.yuquan:
        return ['玉泉'];
      case Campus.xixi:
        return ['西溪'];
      case Campus.huajiachi:
        return ['华家池'];
      case Campus.haining:
        return ['海宁'];
      case Campus.zhoushan:
        return ['舟山'];
    }
  }
}
