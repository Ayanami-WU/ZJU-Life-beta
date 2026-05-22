import 'dart:ui';

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

    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: context.cardColor.withValues(
              alpha: context.isDark ? 0.78 : 0.88,
            ),
            border: Border(
              top: BorderSide(
                color: context.dividerColor.withValues(alpha: 0.65),
                width: 0.5,
              ),
            ),
          ),
          child: SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(4, 5, 4, 6),
              child: Row(
                children: List.generate(_navItems.length, (index) {
                  final item = _navItems[index];
                  final isSelected = index == currentIndex;

                  return Expanded(
                    child: _NavButton(
                      item: item,
                      isSelected: isSelected,
                      onTap: () => context.go(item.path),
                    ),
                  );
                }),
              ),
            ),
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
    final color = isSelected ? context.primaryColor : context.secondaryColor;

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedScale(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOutCubic,
        scale: isSelected ? 1.03 : 1.0,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 3),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                isSelected ? item.activeIcon : item.icon,
                size: 23,
                color: color,
              ),
              const SizedBox(height: 3),
              Text(
                item.label,
                style: TextStyle(
                  fontSize: 11,
                  height: 1.1,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                  color: color,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
