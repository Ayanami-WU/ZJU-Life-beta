import 'package:flutter/cupertino.dart';
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
import '../../widgets/cupertino_grouped.dart';

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

                  CupertinoGroupSection(
                    header: '设置',
                    children: [
                      CupertinoGroupRow(
                        icon: theme.isDarkMode
                            ? LucideIcons.moon
                            : LucideIcons.sun,
                        iconColor: context.primaryColor,
                        title: '深色模式',
                        onTap: () => theme.toggleTheme(),
                        trailing: IgnorePointer(
                          child: CupertinoSwitch(
                            value: theme.isDarkMode,
                            onChanged: (_) {},
                            activeTrackColor: context.primaryColor,
                          ),
                        ),
                      ),
                      CupertinoGroupRow(
                        icon: LucideIcons.bell,
                        iconColor: AppTheme.accentOrange,
                        title: '提醒设置',
                        showChevron: true,
                        onTap: () {},
                      ),
                      CupertinoGroupRow(
                        icon: LucideIcons.messageSquare,
                        iconColor: AppTheme.accentGreen,
                        title: '意见反馈',
                        showChevron: true,
                        onTap: () {},
                      ),
                      CupertinoGroupRow(
                        icon: LucideIcons.info,
                        iconColor: AppTheme.accentPurple,
                        title: '关于',
                        showChevron: true,
                        onTap: () {},
                      ),
                    ],
                  ),

                  const SizedBox(height: 28),

                  if (auth.isAuthenticated) ...[
                    CupertinoGroupSection(
                      children: [
                        CupertinoGroupRow(
                          icon: LucideIcons.logOut,
                          iconColor: AppTheme.error,
                          title: '退出登录',
                          destructive: true,
                          onTap: () => auth.logout(),
                        ),
                      ],
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
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  auth.userId ?? '',
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.white.withValues(alpha: 0.78),
                  ),
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
        // 跳转到自习页面并定位到具体自习室
        context.go('/study?roomId=$actualId');
        break;
      case FavoriteType.librarySeat:
        // 跳转到自习页面并定位到具体座位
        context.go('/study?seatId=$actualId');
        break;
      case FavoriteType.custom:
        break;
    }
  }

  void _showClearConfirmDialog(
      BuildContext context, FavoritesProvider favorites) {
    showCupertinoDialog<void>(
      context: context,
      builder: (dialogContext) => CupertinoAlertDialog(
        title: const Text('清空收藏'),
        content: const Text('确定要清空所有收藏吗？此操作无法撤销。'),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('取消'),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () {
              favorites.clear();
              Navigator.of(dialogContext).pop();
            },
            child: const Text('清空'),
          ),
        ],
      ),
    );
  }
}
