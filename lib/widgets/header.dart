import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../config/theme.dart';
import '../providers/theme_provider.dart';

/// 现代化头部组件
class ZJUHeader extends StatelessWidget implements PreferredSizeWidget {
  final String? title;
  final String? subtitle;
  final bool showThemeToggle;
  final List<Widget>? actions;
  final Widget? leading;
  
  const ZJUHeader({
    super.key,
    this.title,
    this.subtitle,
    this.showThemeToggle = true,
    this.actions,
    this.leading,
  });
  
  @override
  Size get preferredSize => const Size.fromHeight(60);
  
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: context.backgroundColor,
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        child: Row(
          children: [
            // Leading
            if (leading != null) ...[
              leading!,
              const SizedBox(width: 12),
            ],
            
            // Logo / Title
            Expanded(
              child: Row(
                children: [
                  // Modern ZJU Logo
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      gradient: AppTheme.primaryGradient,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: AppTheme.zjuBlue.withValues(alpha: 0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: const Center(
                      child: Text(
                        '浙',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  if (title != null)
                    Expanded(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title!,
                            style: context.textTheme.headlineMedium,
                          ),
                          if (subtitle != null)
                            Text(
                              subtitle!,
                              style: context.textTheme.bodySmall,
                            ),
                        ],
                      ),
                    )
                  else
                    Expanded(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'ZJULife',
                            style: context.textTheme.headlineMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                              color: context.primaryColor,
                            ),
                          ),
                          Text(
                            '浙大生活助手',
                            style: context.textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
            
            // Actions
            if (showThemeToggle)
              _ThemeToggleButton(),
            
            if (actions != null) ...actions!,
          ],
        ),
      ),
    );
  }
}

class _ThemeToggleButton extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        context.read<ThemeProvider>().toggleTheme();
      },
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: context.cardColor,
          borderRadius: BorderRadius.circular(12),
          boxShadow: context.cardShadow,
        ),
        child: Icon(
          context.isDark ? LucideIcons.sun : LucideIcons.moon,
          size: 20,
          color: context.onSurfaceColor,
        ),
      ),
    );
  }
}
