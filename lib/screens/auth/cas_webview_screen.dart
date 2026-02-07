import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:provider/provider.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../../config/theme.dart';
import '../../config/constants.dart';
import '../../providers/auth_provider.dart';

/// CAS 统一身份认证 WebView
/// 
/// 使用 WebView 加载浙大 CAS 登录页面，
/// 登录成功后从 Cookie 或 URL 获取认证信息
class CasWebViewScreen extends StatefulWidget {
  const CasWebViewScreen({super.key});

  @override
  State<CasWebViewScreen> createState() => _CasWebViewScreenState();
}

class _CasWebViewScreenState extends State<CasWebViewScreen> {
  late final WebViewController _controller;
  bool _isLoading = true;
  String _currentUrl = '';

  // CAS 登录页面 URL
  // 登录成功后会重定向到 service 参数指定的地址
  static const String _casLoginUrl = 
      '${ApiConfig.zjuCasUrl}?service=https://booking.lib.zju.edu.cn';

  @override
  void initState() {
    super.initState();
    _initWebView();
  }

  void _initWebView() {
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (url) {
            setState(() {
              _isLoading = true;
              _currentUrl = url;
            });
          },
          onPageFinished: (url) {
            setState(() => _isLoading = false);
            _checkLoginSuccess(url);
          },
          onNavigationRequest: (request) {
            // 可以在这里拦截特定的 URL
            return NavigationDecision.navigate;
          },
        ),
      )
      ..loadRequest(Uri.parse(_casLoginUrl));
  }

  /// 检查是否登录成功
  /// 
  /// 登录成功后，CAS 会重定向到 service URL，
  /// 并在 URL 中附带 ticket 参数
  void _checkLoginSuccess(String url) async {
    // 检查是否已经离开 CAS 登录页面
    if (!url.contains('zjuam.zju.edu.cn') && 
        url.contains('booking.lib.zju.edu.cn')) {
      // 尝试获取用户信息
      // 在实际应用中，可以通过执行 JavaScript 获取页面中的用户信息
      try {
        // 尝试从页面获取用户名
        final userName = await _controller.runJavaScriptReturningResult(
          'document.querySelector(".user-name")?.innerText || ""'
        );
        
        // 获取 Cookie (用于后续 API 调用)
        final _ = await _controller.runJavaScriptReturningResult(
          'document.cookie'
        );

        if (mounted) {
          // 登录成功，更新认证状态
          await context.read<AuthProvider>().loginWithCas(
            userId: 'user_id', // 实际应该从页面获取
            userName: userName.toString().replaceAll('"', ''),
          );

          // 显示成功提示
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('登录成功'),
                backgroundColor: Color(0xFF16A34A),
              ),
            );

            // 返回首页
            context.go('/');
          }
        }
      } catch (e) {
        debugPrint('Error getting user info: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.backgroundColor,
      appBar: AppBar(
        backgroundColor: context.backgroundColor,
        elevation: 0,
        leading: GestureDetector(
          onTap: () => context.go('/login'),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Container(
              decoration: BoxDecoration(
                color: context.cardColor,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                LucideIcons.x,
                size: 20,
                color: context.primaryColor,
              ),
            ),
          ),
        ),
        title: Column(
          children: [
            Text(
              '统一身份认证',
              style: context.textTheme.headlineSmall,
            ),
            if (_currentUrl.isNotEmpty)
              Text(
                Uri.parse(_currentUrl).host,
                style: context.textTheme.bodySmall,
              ),
          ],
        ),
        centerTitle: true,
        actions: [
          if (_isLoading)
            Padding(
              padding: const EdgeInsets.all(16),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: context.primaryColor,
                ),
              ),
            ),
        ],
      ),
      body: Column(
        children: [
          // Loading Progress
          if (_isLoading)
            LinearProgressIndicator(
              color: context.primaryColor,
              backgroundColor: context.dividerColor,
            ),

          // WebView
          Expanded(
            child: WebViewWidget(controller: _controller),
          ),

          // Safety Notice
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: context.surfaceColor,
              border: Border(
                top: BorderSide(color: context.dividerColor),
              ),
            ),
            child: Row(
              children: [
                const Icon(
                  LucideIcons.shield,
                  size: 16,
                  color: AppTheme.success,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '您正在浙江大学统一身份认证系统登录，密码不会被第三方获取',
                    style: context.textTheme.bodySmall,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
