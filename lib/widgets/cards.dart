import 'package:flutter/material.dart';
import '../config/theme.dart';
import '../design/design_constants.dart';
import '../design/colors.dart';

/// 现代化卡片组件
///
/// 统一使用 Celechron 设计语言的卡片样式
class ModernCard extends StatelessWidget {
  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final Color? color;
  final LinearGradient? gradient;
  final BorderRadius? borderRadius;
  final bool showShadow;

  const ModernCard({
    super.key,
    required this.child,
    this.onTap,
    this.padding,
    this.margin,
    this.color,
    this.gradient,
    this.borderRadius,
    this.showShadow = true,
  });

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final isDark = brightness == Brightness.dark;

    return Container(
      margin: margin,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: borderRadius ?? DesignConstants.cardRadius(),
          child: Ink(
            padding: padding ?? DesignConstants.cardPadding,
            decoration: BoxDecoration(
              color: gradient == null ? (color ?? context.cardColor) : null,
              gradient: gradient,
              borderRadius: borderRadius ?? DesignConstants.cardRadius(),
              boxShadow: showShadow && !isDark ? DesignConstants.cardShadow : null,
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}

/// 带渐变背景的卡片
class GradientCard extends StatelessWidget {
  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry? padding;
  final LinearGradient gradient;
  
  const GradientCard({
    super.key,
    required this.child,
    required this.gradient,
    this.onTap,
    this.padding,
  });
  
  @override
  Widget build(BuildContext context) {
    return ModernCard(
      onTap: onTap,
      gradient: gradient,
      padding: padding,
      child: child,
    );
  }
}

/// 图标卡片 - 常用于快捷入口
class IconCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String? sublabel;
  final VoidCallback? onTap;
  final Color? iconColor;
  final Color? backgroundColor;
  
  const IconCard({
    super.key,
    required this.icon,
    required this.label,
    this.sublabel,
    this.onTap,
    this.iconColor,
    this.backgroundColor,
  });
  
  @override
  Widget build(BuildContext context) {
    final bgColor = backgroundColor ?? context.primaryColor.withValues(alpha: 0.1);
    final fgColor = iconColor ?? context.primaryColor;

    return ModernCard(
      onTap: onTap,
      padding: DesignConstants.cardPadding,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: DesignConstants.iconContainerMedium,
            height: DesignConstants.iconContainerMedium,
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: BorderRadius.circular(DesignConstants.iconContainerRadius),
            ),
            child: Icon(icon, color: fgColor, size: 24),
          ),
          const SizedBox(height: DesignConstants.spacingM),
          Text(
            label,
            style: context.textTheme.labelLarge,
            textAlign: TextAlign.center,
          ),
          if (sublabel != null) ...[
            const SizedBox(height: DesignConstants.spacingXS),
            Text(
              sublabel!,
              style: context.textTheme.bodySmall,
              textAlign: TextAlign.center,
            ),
          ],
        ],
      ),
    );
  }
}

/// 信息卡片 - 用于展示统计数据
class InfoCard extends StatelessWidget {
  final String title;
  final String value;
  final String? subtitle;
  final IconData? icon;
  final Color? accentColor;
  final VoidCallback? onTap;
  
  const InfoCard({
    super.key,
    required this.title,
    required this.value,
    this.subtitle,
    this.icon,
    this.accentColor,
    this.onTap,
  });
  
  @override
  Widget build(BuildContext context) {
    final accent = accentColor ?? context.primaryColor;

    return ModernCard(
      onTap: onTap,
      child: Row(
        children: [
          if (icon != null) ...[
            Container(
              width: DesignConstants.iconContainerSmall + 4,
              height: DesignConstants.iconContainerSmall + 4,
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(DesignConstants.iconContainerRadius),
              ),
              child: Icon(icon, color: accent, size: 22),
            ),
            const SizedBox(width: DesignConstants.spacingM + 2),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: context.textTheme.bodySmall,
                ),
                const SizedBox(height: DesignConstants.spacingXS),
                Text(
                  value,
                  style: context.textTheme.headlineMedium?.copyWith(
                    color: accent,
                    fontWeight: DesignConstants.fontWeightBold,
                  ),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    subtitle!,
                    style: context.textTheme.labelSmall,
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// 列表项卡片
class ListTileCard extends StatelessWidget {
  final Widget? leading;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;
  
  const ListTileCard({
    super.key,
    this.leading,
    required this.title,
    this.subtitle,
    this.trailing,
    this.onTap,
  });
  
  @override
  Widget build(BuildContext context) {
    return ModernCard(
      onTap: onTap,
      padding: const EdgeInsets.symmetric(
        horizontal: DesignConstants.spacingL,
        vertical: DesignConstants.spacingM + 2,
      ),
      child: Row(
        children: [
          if (leading != null) ...[
            leading!,
            const SizedBox(width: DesignConstants.spacingM + 2),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: context.textTheme.bodyLarge?.copyWith(
                    fontWeight: DesignConstants.fontWeightMedium,
                  ),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: DesignConstants.spacingXS),
                  Text(
                    subtitle!,
                    style: context.textTheme.bodySmall,
                  ),
                ],
              ],
            ),
          ),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}

/// Section 标题
class SectionHeader extends StatelessWidget {
  final String title;
  final String? actionLabel;
  final VoidCallback? onAction;
  
  const SectionHeader({
    super.key,
    required this.title,
    this.actionLabel,
    this.onAction,
  });
  
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: DesignConstants.spacingS),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            title,
            style: context.textTheme.headlineSmall,
          ),
          if (actionLabel != null)
            TextButton(
              onPressed: onAction,
              child: Text(actionLabel!),
            ),
        ],
      ),
    );
  }
}

/// Editorial 风格标签（兼容旧代码）
class EditorialLabel extends StatelessWidget {
  final String text;
  
  const EditorialLabel(this.text, {super.key});
  
  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: context.textTheme.labelMedium?.copyWith(
        fontWeight: FontWeight.w600,
        letterSpacing: 0.5,
      ),
    );
  }
}

/// Editorial 风格卡片（兼容旧代码）
class EditorialCard extends StatelessWidget {
  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry? padding;
  final bool showBorder;

  const EditorialCard({
    super.key,
    required this.child,
    this.onTap,
    this.padding,
    this.showBorder = true,
  });

  @override
  Widget build(BuildContext context) {
    return ModernCard(
      onTap: onTap,
      padding: padding ?? DesignConstants.cardPadding,
      child: child,
    );
  }
}

// ============================================================================
// Components migrated from design/cards.dart for consolidation
// ============================================================================

/// 圆角矩形卡片 - 参考 Celechron RoundRectangleCard
/// 支持点击动画效果
class RoundCard extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final EdgeInsetsGeometry padding;
  final bool animate;
  final List<BoxShadow>? boxShadow;
  final BorderRadius? borderRadius;
  final Color? backgroundColor;

  const RoundCard({
    super.key,
    required this.child,
    this.onTap,
    this.onLongPress,
    this.padding = const EdgeInsets.all(16),
    this.animate = true,
    this.boxShadow,
    this.borderRadius,
    this.backgroundColor,
  });

  @override
  State<RoundCard> createState() => _RoundCardState();
}

class _RoundCardState extends State<RoundCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  bool isDown = false;
  bool isCancel = false;

  @override
  void initState() {
    super.initState();
    if (widget.animate && widget.onTap != null) {
      _animationController = AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 100),
      );
      _scaleAnimation = Tween<double>(begin: 1.0, end: 0.97).animate(
        CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
      );
    } else {
      _animationController = AnimationController(vsync: this);
      _scaleAnimation = const AlwaysStoppedAnimation(1.0);
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final defaultShadow = brightness == Brightness.dark
        ? null
        : [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              spreadRadius: 0,
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ];

    final bgColor = widget.backgroundColor ?? (
      brightness == Brightness.dark
          ? AppColors.surface.dark
          : AppColors.surface.light
    );

    final core = Container(
      padding: widget.padding,
      decoration: BoxDecoration(
        borderRadius: widget.borderRadius ?? BorderRadius.circular(14),
        boxShadow: widget.boxShadow ?? defaultShadow,
        color: bgColor,
      ),
      child: widget.child,
    );

    if (!widget.animate || widget.onTap == null) {
      return widget.onTap != null
          ? GestureDetector(onTap: widget.onTap, onLongPress: widget.onLongPress, child: core)
          : core;
    }

    return GestureDetector(
      onTapDown: (_) async {
        isDown = true;
        isCancel = false;
        _animationController.forward();
        await Future.delayed(const Duration(milliseconds: 100));
        isDown = false;
        if (isCancel) {
          _animationController.reverse();
          isCancel = false;
        }
      },
      onTapUp: (_) async {
        isCancel = true;
        if (!isDown) _animationController.reverse();
      },
      onTapCancel: () => _animationController.reverse(),
      onTap: widget.onTap,
      onLongPress: widget.onLongPress,
      child: ScaleTransition(
        scale: _scaleAnimation,
        child: core,
      ),
    );
  }
}

/// 带彩色标题栏的卡片 - 参考 Celechron RoundRectangleCardWithForehead
class ForeheadCard extends StatelessWidget {
  final Widget forehead;
  final Widget child;
  final DynamicColor foreheadColor;
  final VoidCallback? onTap;
  final bool animate;

  const ForeheadCard({
    super.key,
    required this.forehead,
    required this.child,
    required this.foreheadColor,
    this.onTap,
    this.animate = true,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: Stack(
        children: [
          // 背景色条
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Container(
              height: 44,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                color: foreheadColor.resolve(context).withValues(alpha: 0.25),
              ),
            ),
          ),
          // 内容
          Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              forehead,
              RoundCard(
                onTap: onTap,
                animate: animate,
                boxShadow: const [],
                child: child,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// 双行信息卡片 - 参考 Celechron TwoLineCard
class TwoLineCard extends StatefulWidget {
  final String title;
  final String content;
  final String? extraContent;
  final DynamicColor backgroundColor;
  final bool withColoredFont;
  final bool animate;
  final VoidCallback? onTap;
  final double? height;
  final double? width;

  const TwoLineCard({
    super.key,
    required this.title,
    required this.content,
    this.extraContent,
    this.backgroundColor = AppColors.cyan,
    this.withColoredFont = false,
    this.animate = false,
    this.onTap,
    this.height,
    this.width,
  });

  @override
  State<TwoLineCard> createState() => _TwoLineCardState();
}

class _TwoLineCardState extends State<TwoLineCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  bool isDown = false;
  bool isCancel = false;

  @override
  void initState() {
    super.initState();
    if (widget.animate && widget.onTap != null) {
      _animationController = AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 100),
      );
      _scaleAnimation = Tween<double>(begin: 1.0, end: 0.97).animate(
        CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
      );
    } else {
      _animationController = AnimationController(vsync: this);
      _scaleAnimation = const AlwaysStoppedAnimation(1.0);
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final bgColor = brightness == Brightness.dark
        ? const Color(0xFF2A2A2E)
        : widget.backgroundColor.light;

    final textColor = (widget.withColoredFont && brightness == Brightness.dark)
        ? widget.backgroundColor.dark
        : Theme.of(context).textTheme.bodyLarge?.color;

    final core = Container(
      height: widget.height,
      width: widget.width,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: bgColor,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            offset: const Offset(0, 2),
            blurRadius: 4,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              widget.title,
              style: TextStyle(
                color: textColor?.withValues(alpha: 0.6),
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          const SizedBox(height: 2),
          // 彩色条
          if (!widget.withColoredFont)
            Container(
              height: 4,
              width: 28,
              decoration: BoxDecoration(
                color: widget.backgroundColor.resolve(context),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          const SizedBox(height: 6),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  widget.content,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: textColor,
                  ),
                ),
                if (widget.extraContent != null)
                  Text(
                    ' / ${widget.extraContent}',
                    style: TextStyle(
                      fontSize: 12,
                      color: textColor?.withValues(alpha: 0.7),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );

    if (!widget.animate || widget.onTap == null) {
      return widget.onTap != null
          ? GestureDetector(onTap: widget.onTap, child: core)
          : core;
    }

    return GestureDetector(
      onTapDown: (_) async {
        isDown = true;
        isCancel = false;
        _animationController.forward();
        await Future.delayed(const Duration(milliseconds: 100));
        isDown = false;
        if (isCancel) {
          _animationController.reverse();
          isCancel = false;
        }
      },
      onTapUp: (_) async {
        isCancel = true;
        if (!isDown) _animationController.reverse();
      },
      onTapCancel: () => _animationController.reverse(),
      onTap: widget.onTap,
      child: ScaleTransition(
        scale: _scaleAnimation,
        child: core,
      ),
    );
  }
}

/// 子标题行
class SubtitleRow extends StatelessWidget {
  final String subtitle;
  final Widget? trailing;

  const SubtitleRow({
    super.key,
    required this.subtitle,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10, top: 4),
      child: Row(
        children: [
          Text(
            subtitle,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary.resolve(context),
            ),
          ),
          if (trailing != null) ...[
            const Spacer(),
            trailing!,
          ],
        ],
      ),
    );
  }
}

/// 列表项卡片（来自 design/cards.dart）
class ListItemCard extends StatelessWidget {
  final Widget leading;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry? padding;

  const ListItemCard({
    super.key,
    required this.leading,
    required this.title,
    this.subtitle,
    this.trailing,
    this.onTap,
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    return RoundCard(
      onTap: onTap,
      padding: padding ?? const EdgeInsets.all(14),
      child: Row(
        children: [
          leading,
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 3),
                  Text(
                    subtitle!,
                    style: TextStyle(
                      fontSize: 13,
                      color: AppColors.textSecondary.resolve(context),
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}

/// 图标框
class IconBox extends StatelessWidget {
  final IconData icon;
  final DynamicColor color;
  final double size;

  const IconBox({
    super.key,
    required this.icon,
    required this.color,
    this.size = 44,
  });

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final bgColor = brightness == Brightness.dark
        ? color.dark.withValues(alpha: 0.2)
        : color.light;
    final iconColor = color.dark;

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(size * 0.26),
      ),
      child: Icon(icon, color: iconColor, size: size * 0.5),
    );
  }
}
