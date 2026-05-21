import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../../config/theme.dart';
import '../../providers/auth_provider.dart';

/// 图书馆 WebView 登录页面
///
/// 通过 WebView 让用户登录图书馆预约系统 (CAS → JWT)
/// 登录成功后从 localStorage 中提取 JWT token
class LibraryWebViewScreen extends StatefulWidget {
  /// 是否为登录模式（登录成功自动返回）
  final bool loginMode;

  const LibraryWebViewScreen({
    super.key,
    this.loginMode = false,
  });

  @override
  State<LibraryWebViewScreen> createState() => _LibraryWebViewScreenState();
}

class _LibraryWebViewScreenState extends State<LibraryWebViewScreen> {
  late final WebViewController _controller;
  bool _isLoading = true;
  String _title = '图书馆登录';
  Timer? _tokenCheckTimer;
  bool _tokenExtracted = false;

  // 图书馆 H5 入口
  static const String _libraryUrl =
      'https://booking.lib.zju.edu.cn/h5/index.html#/SeatScreening/1';

  @override
  void initState() {
    super.initState();
    _initWebView();
  }

  @override
  void dispose() {
    _tokenCheckTimer?.cancel();
    super.dispose();
  }

  void _initWebView() {
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.white)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (url) {
            if (mounted) {
              setState(() => _isLoading = true);
            }
          },
          onPageFinished: (url) async {
            if (mounted) {
              setState(() => _isLoading = false);

              final title = await _controller.getTitle();
              if (title != null && title.isNotEmpty && mounted) {
                setState(() => _title = title);
              }

              // 页面加载完成后开始检测 JWT token
              _startTokenExtraction();
            }
          },
          onNavigationRequest: (request) {
            return NavigationDecision.navigate;
          },
        ),
      )
      ..setUserAgent(
          'Mozilla/5.0 (Linux; Android 10) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Mobile Safari/537.36');

    _controller.loadRequest(Uri.parse(_libraryUrl));
  }

  /// 定期尝试从 localStorage 提取 JWT token
  void _startTokenExtraction() {
    _tokenCheckTimer?.cancel();
    _tokenCheckTimer = Timer.periodic(
      const Duration(seconds: 2),
      (_) => _tryExtractToken(),
    );
    // 立即尝试一次
    _tryExtractToken();
  }

  /// 尝试从 WebView 的 localStorage 中提取 JWT
  Future<void> _tryExtractToken() async {
    if (_tokenExtracted) return;

    try {
      // 尝试常见的 localStorage key
      // 图书馆系统可能使用 token / access_token / jwt / Authorization 等
      final result = await _controller.runJavaScriptReturningResult('''
        (function() {
          // 尝试各种可能的 token key
          var keys = ['token', 'access_token', 'jwt', 'Authorization', 'auth_token', 'userToken', 'user_token'];
          for (var i = 0; i < keys.length; i++) {
            var val = localStorage.getItem(keys[i]);
            if (val && val.length > 20) {
              return val;
            }
          }
          // 遍历所有 localStorage 找类似 JWT 的值
          for (var j = 0; j < localStorage.length; j++) {
            var key = localStorage.key(j);
            var val = localStorage.getItem(key);
            if (val && val.length > 50 && (val.indexOf('eyJ') === 0 || val.indexOf('"eyJ') === 0)) {
              return val;
            }
          }
          return '';
        })()
      ''');

      String token = result.toString();
      // 去除引号
      if (token.startsWith('"') && token.endsWith('"')) {
        token = token.substring(1, token.length - 1);
      }

      if (token.isNotEmpty && token.length > 20 && mounted) {
        _tokenExtracted = true;
        _tokenCheckTimer?.cancel();

        final auth = context.read<AuthProvider>();
        await auth.updateLibraryJwt(token);

        if (widget.loginMode && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('图书馆登录成功！'),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 2),
            ),
          );
          // 延迟返回，让用户看到提示
          await Future.delayed(const Duration(milliseconds: 500));
          if (mounted) {
            Navigator.of(context).pop(true); // 返回 true 表示登录成功
          }
        }
      }
    } catch (e) {
      // JS 执行失败，静默忽略
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.backgroundColor,
      appBar: AppBar(
        backgroundColor: context.primaryColor,
        foregroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(LucideIcons.arrowLeft),
          onPressed: () => Navigator.of(context).pop(false),
        ),
        title: Text(
          widget.loginMode ? '图书馆登录' : _title,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(LucideIcons.refreshCw),
            onPressed: () {
              _tokenExtracted = false;
              _controller.reload();
            },
          ),
        ],
      ),
      body: Stack(
        children: [
          WebViewWidget(controller: _controller),
          if (_isLoading)
            Container(
              color: Colors.white.withValues(alpha: 0.8),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(
                      color: context.primaryColor,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      widget.loginMode ? '请在网页中完成登录...' : '加载中...',
                      style: TextStyle(
                        color: context.secondaryColor,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
