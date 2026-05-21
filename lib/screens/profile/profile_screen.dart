import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';

import '../../config/theme.dart';
import '../../models/favorite.dart';
import '../../providers/auth_provider.dart';
import '../../providers/theme_provider.dart';
import '../../providers/favorites_provider.dart';
import '../../widgets/header.dart';
import '../../widgets/cards.dart';
import '../../widgets/favorite_button.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final theme = context.watch<ThemeProvider>();
    final favorites = context.watch<FavoritesProvider>();

    return Scaffold(
      backgroundColor: context.backgroundColor,
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            // Header
            const SliverToBoxAdapter(
              child: PageHeader(title: '我的'),
            ),

            SliverPadding(
              padding: const EdgeInsets.all(20),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  // Profile Card
                  _buildProfileCard(context, auth),
                  const SizedBox(height: 28),

                  // Favorites Section
                  if (favorites.favorites.isNotEmpty) ...[
                    _buildFavoritesSection(context, favorites),
                    const SizedBox(height: 28),
                  ],

                  // Settings
                  const SectionHeader(title: '设置'),
                  const SizedBox(height: 12),

                  // Theme Toggle
                  ModernCard(
                    onTap: () => theme.toggleTheme(),
                    child: Row(
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: context.primaryColor.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(
                            theme.isDarkMode
                                ? LucideIcons.moon
                                : LucideIcons.sun,
                            size: 20,
                            color: context.primaryColor,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Text(
                            '深色模式',
                            style: context.textTheme.bodyLarge?.copyWith(
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                        Switch(
                          value: theme.isDarkMode,
                          onChanged: (_) => theme.toggleTheme(),
                          activeTrackColor: context.primaryColor,
                          thumbColor: WidgetStateProperty.all(Colors.white),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),

                  // Other Settings
                  _SettingsItem(
                    icon: LucideIcons.bell,
                    label: '提醒设置',
                    color: AppTheme.accentOrange,
                    onTap: () {},
                  ),
                  const SizedBox(height: 10),
                  _SettingsItem(
                    icon: LucideIcons.messageSquare,
                    label: '意见反馈',
                    color: AppTheme.accentGreen,
                    onTap: () {},
                  ),
                  const SizedBox(height: 10),
                  _SettingsItem(
                    icon: LucideIcons.info,
                    label: '关于',
                    color: AppTheme.accentPurple,
                    onTap: () {},
                  ),

                  const SizedBox(height: 28),

                  // Logout
                  if (auth.isAuthenticated) ...[
                    OutlinedButton(
                      onPressed: () => auth.logout(),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        foregroundColor: AppTheme.error,
                        side: const BorderSide(color: AppTheme.error),
                      ),
                      child: const Text('退出登录'),
                    ),
                  ],

                  const SizedBox(height: 100),
                ]),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileCard(BuildContext context, AuthProvider auth) {
    if (!auth.isAuthenticated) {
      return ModernCard(
        onTap: () => context.go('/login'),
        gradient: AppTheme.primaryGradient,
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Icon(
                LucideIcons.user,
                size: 24,
                color: Colors.white,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '点击登录',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '使用浙大统一身份认证',
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.white.withValues(alpha: 0.8),
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              LucideIcons.chevronRight,
              size: 20,
              color: Colors.white,
            ),
          ],
        ),
      );
    }

    return ModernCard(
      padding: const EdgeInsets.all(20),
      child: Row(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              gradient: AppTheme.primaryGradient,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Center(
              child: Text(
                auth.userName?.isNotEmpty == true
                    ? auth.userName![0].toUpperCase()
                    : 'U',
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  auth.userName ?? '用户',
                  style: context.textTheme.headlineSmall,
                ),
                const SizedBox(height: 4),
                Text(
                  auth.userId ?? '',
                  style: context.textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFavoritesSection(
      BuildContext context, FavoritesProvider favorites) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisSize: MainAxisSize.max,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child:
                  SectionHeader(title: '我的收藏 (${favorites.favorites.length})'),
            ),
            if (favorites.favorites.isNotEmpty)
              TextButton(
                onPressed: () {
                  _showClearConfirmDialog(context, favorites);
                },
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: const Text(
                  '清空',
                  style: TextStyle(
                    fontSize: 13,
                    color: AppTheme.error,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 12),
        ...favorites.favorites.map((item) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: FavoriteItemCard(
                item: item,
                onTap: () => _navigateToFavorite(context, item),
                onRemove: () {
                  HapticFeedback.lightImpact();
                  favorites.removeFavorite(item.id);
                },
              ),
            )),
      ],
    );
  }

  void _navigateToFavorite(BuildContext context, FavoriteItem item) {
    // 从 item.id 中提取实际的业务ID
    // 格式: "canteen_123", "bus_456", "library_789"
    final parts = item.id.split('_');
    final actualId = parts.length > 1 ? parts.sublist(1).join('_') : item.id;

    switch (item.type) {
      case FavoriteType.canteen:
        // 跳转到食堂页面并定位到具体食堂
        context.go('/canteen?canteenId=$actualId');
        break;
      case FavoriteType.canteenWindow:
        // 跳转到食堂页面并定位到具体窗口
        context.go('/canteen?windowId=$actualId');
        break;
      case FavoriteType.busRoute:
        // 跳转到班车页面并定位到具体路线
        context.go('/bus?routeId=$actualId');
        break;
      case FavoriteType.busStop:
        // 跳转到班车页面并定位到具体站点
        context.go('/bus?stopId=$actualId');
        break;
      case FavoriteType.libraryRoom:
        // 跳转到自习室房间地图
        context.go('/study/room/${Uri.encodeComponent(actualId)}');
        break;
      case FavoriteType.librarySeat:
        // 当前版本不做单座位详情，回到自习页
        context.go('/study');
        break;
      case FavoriteType.custom:
        break;
    }
  }

  void _showClearConfirmDialog(
      BuildContext context, FavoritesProvider favorites) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('清空收藏'),
        content: const Text('确定要清空所有收藏吗？此操作无法撤销。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () {
              favorites.clear();
              Navigator.pop(context);
            },
            style: TextButton.styleFrom(foregroundColor: AppTheme.error),
            child: const Text('清空'),
          ),
        ],
      ),
    );
  }
}

class _SettingsItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _SettingsItem({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ModernCard(
      onTap: onTap,
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 20, color: color),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              label,
              style: context.textTheme.bodyLarge?.copyWith(
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Icon(
            LucideIcons.chevronRight,
            size: 18,
            color: context.secondaryColor,
          ),
        ],
      ),
    );
  }
}
