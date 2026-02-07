import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../config/theme.dart';

/// 现代进度条指示器
class ProgressIndicatorBar extends StatelessWidget {
  final double progress; // 0.0 - 1.0
  final String? label;
  final bool showPercentage;
  final Color? activeColor;
  final double height;
  
  const ProgressIndicatorBar({
    super.key,
    required this.progress,
    this.label,
    this.showPercentage = true,
    this.activeColor,
    this.height = 6,
  });
  
  Color _getAutoColor() {
    if (progress < 0.3) return AppTheme.success;
    if (progress < 0.6) return AppTheme.warning;
    if (progress < 0.85) return AppTheme.accentOrange;
    return AppTheme.error;
  }
  
  @override
  Widget build(BuildContext context) {
    final color = activeColor ?? _getAutoColor();
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (label != null || showPercentage) ...[
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              if (label != null)
                Text(
                  label!,
                  style: context.textTheme.bodySmall,
                ),
              if (showPercentage)
                Text(
                  '${(progress * 100).round()}%',
                  style: context.textTheme.labelMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: color,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 6),
        ],
        Container(
          height: height,
          decoration: BoxDecoration(
            color: context.dividerColor,
            borderRadius: BorderRadius.circular(height / 2),
          ),
          child: FractionallySizedBox(
            alignment: Alignment.centerLeft,
            widthFactor: progress.clamp(0.0, 1.0),
            child: Container(
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(height / 2),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// 兼容旧代码的别名
typedef CrowdIndicator = ProgressIndicatorBar;

/// 状态标签
class StatusChip extends StatelessWidget {
  final String text;
  final Color? color;
  final IconData? icon;
  final bool filled;
  
  const StatusChip({
    super.key,
    required this.text,
    this.color,
    this.icon,
    this.filled = false,
  });
  
  @override
  Widget build(BuildContext context) {
    final chipColor = color ?? context.primaryColor;
    
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: icon != null ? 10 : 12,
        vertical: 6,
      ),
      decoration: BoxDecoration(
        color: filled ? chipColor : chipColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: filled ? null : Border.all(color: chipColor.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(
              icon,
              size: 14,
              color: filled ? Colors.white : chipColor,
            ),
            const SizedBox(width: 4),
          ],
          Text(
            text,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: filled ? Colors.white : chipColor,
            ),
          ),
        ],
      ),
    );
  }
}

/// 兼容旧代码的别名
typedef StatusBadge = StatusChip;

/// 加载指示器
class LoadingIndicator extends StatelessWidget {
  final String? message;
  final Color? color;
  
  const LoadingIndicator({
    super.key,
    this.message,
    this.color,
  });
  
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 40,
            height: 40,
            child: CircularProgressIndicator(
              strokeWidth: 3,
              valueColor: AlwaysStoppedAnimation(
                color ?? context.primaryColor,
              ),
            ),
          ),
          if (message != null) ...[
            const SizedBox(height: 16),
            Text(
              message!,
              style: context.textTheme.bodyMedium,
            ),
          ],
        ],
      ),
    );
  }
}

/// 空状态展示
class EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final Widget? action;
  
  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.action,
  });
  
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: context.primaryColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(24),
              ),
              child: Icon(
                icon,
                size: 36,
                color: context.primaryColor.withValues(alpha: 0.5),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              title,
              style: context.textTheme.headlineSmall,
              textAlign: TextAlign.center,
            ),
            if (subtitle != null) ...[
              const SizedBox(height: 8),
              Text(
                subtitle!,
                style: context.textTheme.bodyMedium?.copyWith(
                  color: context.secondaryColor,
                ),
                textAlign: TextAlign.center,
              ),
            ],
            if (action != null) ...[
              const SizedBox(height: 24),
              action!,
            ],
          ],
        ),
      ),
    );
  }
}

/// 错误状态展示
class ErrorState extends StatelessWidget {
  final String message;
  final VoidCallback? onRetry;
  
  const ErrorState({
    super.key,
    required this.message,
    this.onRetry,
  });
  
  @override
  Widget build(BuildContext context) {
    return EmptyState(
      icon: LucideIcons.wifiOff,
      title: '加载失败',
      subtitle: message,
      action: onRetry != null
          ? ElevatedButton.icon(
              onPressed: onRetry,
              icon: const Icon(LucideIcons.refreshCw, size: 18),
              label: const Text('重试'),
            )
          : null,
    );
  }
}

/// 拥挤度指示器（专为食堂设计）
class CrowdLevel extends StatelessWidget {
  final double level; // 0.0 - 1.0
  final bool compact;
  
  const CrowdLevel({
    super.key,
    required this.level,
    this.compact = false,
  });
  
  String _getLevelText() {
    if (level < 0.3) return '空闲';
    if (level < 0.6) return '适中';
    if (level < 0.85) return '较挤';
    return '拥挤';
  }
  
  Color _getLevelColor() {
    if (level < 0.3) return AppTheme.success;
    if (level < 0.6) return AppTheme.warning;
    if (level < 0.85) return AppTheme.accentOrange;
    return AppTheme.error;
  }
  
  @override
  Widget build(BuildContext context) {
    final color = _getLevelColor();
    
    if (compact) {
      return StatusChip(
        text: _getLevelText(),
        color: color,
      );
    }
    
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 6),
        Text(
          _getLevelText(),
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: color,
          ),
        ),
        const SizedBox(width: 6),
        Text(
          '${(level * 100).round()}%',
          style: context.textTheme.bodySmall,
        ),
      ],
    );
  }
}
