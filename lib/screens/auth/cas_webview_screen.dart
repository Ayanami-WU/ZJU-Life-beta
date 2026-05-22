import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../../config/theme.dart';
import '../../config/constants.dart';
import '../../providers/auth_provider.dart';
import '../../services/auth_service.dart';
import '../../utils/web_location_stub.dart'
    if (dart.library.html) '../../utils/web_location_web.dart' as web_location;

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
  WebViewController? _controller;
  bool _isLoading = true;
  bool _isCompleted = false;
  String _currentUrl = '';
  String? _errorMessage;

  // CAS 登录页面 URL
  // 登录成功后会重定向到 service 参数指定的地址
  static const String _libraryServiceUrl = '${ApiConfig.libraryBookingUrl}/h5/';
  static final String _casLoginUrl =
      AuthService.casLoginUrlForService(_libraryServiceUrl);

  @override
  void initState() {
    super.initState();
    if (kIsWeb) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _handleWebCas());
    } else {
      _initWebView();
    }
  }

  void _initWebView() {
    final controller = WebViewController()
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
    _controller = controller;
  }

  Future<void> _handleWebCas() async {
    final currentUrl = web_location.currentHref();
    final ticket = _extractCasTicket(currentUrl);
    setState(() {
      _currentUrl = currentUrl;
      _errorMessage = null;
      _isLoading = true;
    });

    if (ticket == null || ticket.isEmpty) {
      setState(() {
        _errorMessage = 'Web 预览无法嵌入学校 CAS 页面，请返回登录页使用本机代理登录。';
        _isLoading = false;
      });
      return;
    }

    try {
      await _completeLogin(ticket, userName: '统一身份认证用户');
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }

  /// 检查是否登录成功
  ///
  /// 登录成功后，CAS 会重定向到 service URL，
  /// 并在 URL 中附带 ticket 参数
  void _checkLoginSuccess(String url) async {
    if (_isCompleted) return;

    // 检查是否已经离开 CAS 登录页面
    if (!url.contains('zjuam.zju.edu.cn') &&
        url.contains('booking.lib.zju.edu.cn')) {
      // 尝试获取用户信息
      // 在实际应用中，可以通过执行 JavaScript 获取页面中的用户信息
      try {
        final uri = Uri.tryParse(url);
        final ticket =
            uri?.queryParameters['cas'] ?? uri?.queryParameters['ticket'];
        if (ticket == null || ticket.isEmpty) return;

        // 尝试从页面获取用户名
        final userName = await _controller!.runJavaScriptReturningResult(
            'document.querySelector(".user-name")?.innerText || ""');

        // 获取 Cookie (用于后续 API 调用)
        final _ =
            await _controller!.runJavaScriptReturningResult('document.cookie');

        await _completeLogin(
          ticket,
          userName: userName.toString().replaceAll('"', ''),
        );
        _isCompleted = true;
      } catch (e) {
        _isCompleted = false;
        debugPrint('Error getting user info: $e');
      }
    }
  }

  Future<void> _completeLogin(String ticket, {required String userName}) async {
    final libraryJwt = await AuthService.instance.exchangeLibraryTicket(ticket);
    if (libraryJwt == null || libraryJwt.isEmpty) {
      throw AuthException('图书馆授权失败，请确认本地登录代理已启动后重试');
    }

    if (!mounted) return;
    final authProvider = context.read<AuthProvider>();

    // 登录成功，更新认证状态
    await authProvider.loginWithCas(
      userId: 'cas_user',
      userName: userName.isEmpty ? '统一身份认证用户' : userName,
      ticket: ticket,
    );
    await authProvider.updateLibraryJwt(libraryJwt);

    if (!mounted) return;
    // 显示成功提示
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('登录成功'),
        backgroundColor: Color(0xFF16A34A),
      ),
    );

    // 返回自习页
    context.go('/study');
  }

  static String? _extractCasTicket(String url) {
    final uri = Uri.tryParse(url);
    if (uri == null) return null;

    String? fromParams(Map<String, String> params) {
      return params['cas'] ?? params['ticket'];
    }

    final direct = fromParams(uri.queryParameters);
    if (direct != null && direct.isNotEmpty) return direct;

    final fragment = uri.fragment;
    final queryStart = fragment.indexOf('?');
    if (queryStart >= 0 && queryStart < fragment.length - 1) {
      final fragmentParams = Uri.splitQueryString(
        fragment.substring(queryStart + 1),
      );
      final fromFragment = fromParams(fragmentParams);
      if (fromFragment != null && fromFragment.isNotEmpty) {
        return fromFragment;
      }
    }

    for (final key in const ['cas', 'ticket']) {
      final match = RegExp('[?&]$key=([^&#]+)').firstMatch(url);
      if (match != null) return Uri.decodeComponent(match.group(1)!);
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    if (kIsWeb) return _buildWebCasView(context);

    final controller = _controller;
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
            child: controller == null
                ? const Center(child: CircularProgressIndicator())
                : WebViewWidget(controller: controller),
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

  Widget _buildWebCasView(BuildContext context) {
    return Scaffold(
      backgroundColor: context.backgroundColor,
      appBar: AppBar(
        backgroundColor: context.backgroundColor,
        elevation: 0,
        leading: IconButton(
          onPressed: () => context.go('/login'),
          icon: const Icon(LucideIcons.x, size: 20),
          color: context.primaryColor,
          tooltip: '关闭',
        ),
        title: Text('统一身份认证', style: context.textTheme.headlineSmall),
        centerTitle: true,
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: context.primaryColor.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Icon(
                  _errorMessage == null
                      ? LucideIcons.shieldCheck
                      : LucideIcons.alertCircle,
                  size: 36,
                  color: context.primaryColor,
                ),
              ),
              const SizedBox(height: 20),
              Text(
                _errorMessage == null ? '正在完成登录' : '网页登录不可用',
                style:
                    const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              Text(
                _errorMessage ??
                    (_isLoading ? '正在用 CAS ticket 换取图书馆访问凭证' : '请返回登录页继续'),
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14, color: context.secondaryColor),
              ),
              if (_errorMessage != null) ...[
                const SizedBox(height: 24),
                FilledButton.icon(
                  onPressed: () => context.go('/login'),
                  icon: const Icon(LucideIcons.arrowLeft, size: 18),
                  label: const Text('返回登录'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
