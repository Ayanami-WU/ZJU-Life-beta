import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../config/theme.dart';

/// 主布局 Shell - 包含底部导航栏
class MainShell extends StatelessWidget {
  final Widget child;

  const MainShell({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: child,
      bottomNavigationBar: const ZJUBottomNav(),
    );
  }
}

/// 现代化底部导航栏
class ZJUBottomNav extends StatelessWidget {
  const ZJUBottomNav({super.key});

  static const _navItems = [
    _NavItem(
        icon: LucideIcons.home,
        activeIcon: LucideIcons.home,
        label: '首页',
        path: '/'),
    _NavItem(
        icon: LucideIcons.utensils,
        activeIcon: LucideIcons.utensils,
        label: '食堂',
        path: '/canteen'),
    _NavItem(
        icon: LucideIcons.bus,
        activeIcon: LucideIcons.bus,
        label: '班车',
        path: '/bus'),
    _NavItem(
        icon: LucideIcons.bookOpen,
        activeIcon: LucideIcons.bookOpen,
        label: '自习',
        path: '/study'),
    _NavItem(
        icon: LucideIcons.user,
        activeIcon: LucideIcons.user,
        label: '我的',
        path: '/profile'),
  ];

  int _getCurrentIndex(BuildContext context) {
    final location = GoRouterState.of(context).uri.path;
    for (int i = 0; i < _navItems.length; i++) {
      if (_navItems[i].path == location) return i;
      if (_navItems[i].path != '/' &&
          location.startsWith('${_navItems[i].path}/')) {
        return i;
      }
    }
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    final currentIndex = _getCurrentIndex(context);

    return Container(
      decoration: BoxDecoration(
        color: context.cardColor,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 20,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: List.generate(_navItems.length, (index) {
              final item = _navItems[index];
              final isSelected = index == currentIndex;

              return _NavButton(
                item: item,
                isSelected: isSelected,
                onTap: () => context.go(item.path),
              );
            }),
          ),
        ),
      ),
    );
  }
}

class _NavItem {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  final String path;

  const _NavItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.path,
  });
}

class _NavButton extends StatelessWidget {
  final _NavItem item;
  final bool isSelected;
  final VoidCallback onTap;

  const _NavButton({
    required this.item,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: EdgeInsets.symmetric(
          horizontal: isSelected ? 16 : 12,
          vertical: 8,
        ),
        decoration: BoxDecoration(
          color: isSelected
              ? context.primaryColor.withValues(alpha: 0.1)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isSelected ? item.activeIcon : item.icon,
              size: 22,
              color: isSelected ? context.primaryColor : context.secondaryColor,
            ),
            if (isSelected) ...[
              const SizedBox(width: 6),
              Text(
                item.label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: context.primaryColor,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
