import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:provider/provider.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../../config/theme.dart';
import '../../providers/auth_provider.dart';

/// 图书馆座位 WebView 页面
/// 
/// 使用 WebView 直接显示图书馆预约系统
/// 因为图书馆系统是 SPA 应用，数据通过 JS 渲染
class LibraryWebViewScreen extends StatefulWidget {
  const LibraryWebViewScreen({super.key});

  @override
  State<LibraryWebViewScreen> createState() => _LibraryWebViewScreenState();
}

class _LibraryWebViewScreenState extends State<LibraryWebViewScreen> {
  late final WebViewController _controller;
  bool _isLoading = true;
  String _title = '图书馆座位';
  
  // 图书馆座位页面 URL
  static const String _libraryUrl = 'https://booking.lib.zju.edu.cn/h5/index.html#/SeatScreening/1';
  
  @override
  void initState() {
    super.initState();
    _initWebView();
  }
  
  void _initWebView() {
    final auth = context.read<AuthProvider>();
    
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
              
              // 获取页面标题
              final title = await _controller.getTitle();
              if (title != null && title.isNotEmpty && mounted) {
                setState(() => _title = title);
              }
            }
          },
          onNavigationRequest: (request) {
            // 允许所有导航
            return NavigationDecision.navigate;
          },
        ),
      )
      ..setUserAgent('Mozilla/5.0 (Linux; Android 10) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Mobile Safari/537.36');
    
    // 如果有 CAS Cookie，先设置
    if (auth.authCookie != null && auth.authCookie!.isNotEmpty) {
      // WebView 会自动处理 cookie，但我们可以尝试注入
      _controller.loadRequest(
        Uri.parse(_libraryUrl),
        headers: {
          'Cookie': auth.authCookie!,
        },
      );
    } else {
      _controller.loadRequest(Uri.parse(_libraryUrl));
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
          onPressed: () => context.pop(),
        ),
        title: Text(
          _title,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(LucideIcons.refreshCw),
            onPressed: () {
              _controller.reload();
            },
          ),
        ],
      ),
      body: Stack(
        children: [
          // WebView
          WebViewWidget(controller: _controller),
          
          // Loading indicator
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
                      '加载中...',
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
