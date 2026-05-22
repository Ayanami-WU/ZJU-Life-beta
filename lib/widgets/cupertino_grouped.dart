import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../config/theme.dart';

class CupertinoGroupSection extends StatelessWidget {
  final String? header;
  final Widget? headerTrailing;
  final String? footer;
  final List<Widget> children;
  final EdgeInsetsGeometry margin;
  final EdgeInsetsGeometry? headerPadding;

  const CupertinoGroupSection({
    super.key,
    this.header,
    this.headerTrailing,
    this.footer,
    required this.children,
    this.margin = EdgeInsets.zero,
    this.headerPadding,
  });

  @override
  Widget build(BuildContext context) {
    final divider = context.dividerColor.withValues(alpha: 0.62);
    final radius = BorderRadius.circular(12);

    return Padding(
      padding: margin,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (header != null) ...[
            Padding(
              padding: headerPadding ??
                  const EdgeInsets.only(left: 16, right: 16, bottom: 7),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      header!.toUpperCase(),
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: context.secondaryColor,
                        letterSpacing: 0,
                      ),
                    ),
                  ),
                  if (headerTrailing != null) headerTrailing!,
                ],
              ),
            ),
          ],
          ClipRRect(
            borderRadius: radius,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: context.cardColor,
                borderRadius: radius,
                border: context.isDark
                    ? Border.all(
                        color: context.dividerColor.withValues(alpha: 0.32),
                        width: 0.5,
                      )
                    : null,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (var i = 0; i < children.length; i++) ...[
                    children[i],
                    if (i != children.length - 1)
                      Padding(
                        padding: const EdgeInsets.only(left: 62),
                        child: Divider(
                          height: 1,
                          thickness: 0.5,
                          color: divider,
                        ),
                      ),
                  ],
                ],
              ),
            ),
          ),
          if (footer != null) ...[
            const SizedBox(height: 7),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                footer!,
                style: TextStyle(
                  fontSize: 12,
                  height: 1.28,
                  color: context.secondaryColor,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class CupertinoGroupRow extends StatelessWidget {
  final IconData? icon;
  final Color? iconColor;
  final Widget? leading;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;
  final bool showChevron;
  final bool destructive;
  final EdgeInsetsGeometry padding;

  const CupertinoGroupRow({
    super.key,
    this.icon,
    this.iconColor,
    this.leading,
    required this.title,
    this.subtitle,
    this.trailing,
    this.onTap,
    this.showChevron = false,
    this.destructive = false,
    this.padding = const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
  });

  @override
  Widget build(BuildContext context) {
    final resolvedIconColor = iconColor ?? context.primaryColor;
    final titleColor = destructive ? AppTheme.error : context.textColor;
    final content = Padding(
      padding: padding,
      child: Row(
        children: [
          leading ??
              (icon == null
                  ? const SizedBox.shrink()
                  : _GroupedIcon(
                      icon: icon!,
                      color: resolvedIconColor,
                    )),
          if (leading != null || icon != null) const SizedBox(width: 12),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w400,
                    color: titleColor,
                    height: 1.2,
                  ),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 3),
                  Text(
                    subtitle!,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13,
                      height: 1.22,
                      color: context.secondaryColor,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (trailing != null) ...[
            const SizedBox(width: 10),
            trailing!,
          ],
          if (showChevron) ...[
            const SizedBox(width: 6),
            Icon(
              LucideIcons.chevronRight,
              size: 18,
              color: context.secondaryColor.withValues(alpha: 0.62),
            ),
          ],
        ],
      ),
    );

    if (onTap == null) {
      return content;
    }

    return CupertinoButton(
      padding: EdgeInsets.zero,
      minimumSize: Size.zero,
      pressedOpacity: 0.72,
      alignment: Alignment.centerLeft,
      onPressed: onTap,
      child: content,
    );
  }
}

class CupertinoMetricPill extends StatelessWidget {
  final String text;
  final Color color;
  final String? subtext;

  const CupertinoMetricPill({
    super.key,
    required this.text,
    required this.color,
    this.subtext,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: context.isDark ? 0.18 : 0.11),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            text,
            style: TextStyle(
              color: color,
              fontSize: 13,
              fontWeight: FontWeight.w700,
              height: 1.1,
            ),
          ),
          if (subtext != null)
            Text(
              subtext!,
              style: TextStyle(
                color: context.secondaryColor,
                fontSize: 10,
                height: 1.1,
              ),
            ),
        ],
      ),
    );
  }
}

class _GroupedIcon extends StatelessWidget {
  final IconData icon;
  final Color color;

  const _GroupedIcon({
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 34,
      height: 34,
      decoration: BoxDecoration(
        color: color.withValues(alpha: context.isDark ? 0.2 : 0.12),
        borderRadius: BorderRadius.circular(9),
      ),
      child: Icon(icon, size: 18, color: color),
    );
  }
}
