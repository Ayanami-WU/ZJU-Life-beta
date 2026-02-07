import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 用户认证状态
class AuthProvider extends ChangeNotifier {
  bool _isAuthenticated = false;
  String? _userId;
  String? _userName;
  String? _casTicket;
  String? _authCookie;
  
  bool get isAuthenticated => _isAuthenticated;
  String? get userId => _userId;
  String? get userName => _userName;
  String? get casTicket => _casTicket;
  String? get authCookie => _authCookie;
  
  AuthProvider() {
    _loadAuthState();
  }
  
  Future<void> _loadAuthState() async {
    final prefs = await SharedPreferences.getInstance();
    _isAuthenticated = prefs.getBool('is_authenticated') ?? false;
    _userId = prefs.getString('user_id');
    _userName = prefs.getString('user_name');
    _authCookie = prefs.getString('auth_cookie');
    notifyListeners();
  }
  
  /// CAS 认证成功后调用
  Future<void> loginWithCas({
    required String userId,
    required String userName,
    String? ticket,
    String? cookie,
  }) async {
    _isAuthenticated = true;
    _userId = userId;
    _userName = userName;
    _casTicket = ticket;
    _authCookie = cookie;
    
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('is_authenticated', true);
    await prefs.setString('user_id', userId);
    await prefs.setString('user_name', userName);
    if (cookie != null) {
      await prefs.setString('auth_cookie', cookie);
    }
    
    notifyListeners();
  }
  
  /// 更新 Cookie
  Future<void> updateCookie(String cookie) async {
    _authCookie = cookie;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('auth_cookie', cookie);
    notifyListeners();
  }
  
  Future<void> logout() async {
    _isAuthenticated = false;
    _userId = null;
    _userName = null;
    _casTicket = null;
    _authCookie = null;
    
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('is_authenticated');
    await prefs.remove('user_id');
    await prefs.remove('user_name');
    await prefs.remove('auth_cookie');
    
    notifyListeners();
  }
}
