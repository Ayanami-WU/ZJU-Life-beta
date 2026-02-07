import 'package:flutter/material.dart';

/// Celechron 设计语言常量
///
/// 统一定义应用中所有UI组件的设计参数，确保视觉一致性
class DesignConstants {
  DesignConstants._();

  // ============ 圆角 ============

  /// 标准卡片圆角 (Celechron统一使用12px)
  static const double cardBorderRadius = 12.0;

  /// 小圆角 (用于按钮、标签等小组件)
  static const double smallBorderRadius = 8.0;

  /// 大圆角 (用于底部弹窗等大型容器)
  static const double largeBorderRadius = 20.0;

  /// 图标容器圆角
  static const double iconContainerRadius = 10.0;

  // ============ 阴影 ============

  /// 标准卡片阴影 (浅色模式)
  /// Celechron使用: blur 12, offset (0, 6), opacity 0.06
  static List<BoxShadow> get cardShadow => [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.06),
          blurRadius: 12,
          offset: const Offset(0, 6),
        ),
      ];

  /// 轻微阴影 (用于悬浮按钮等)
  static List<BoxShadow> get lightShadow => [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.04),
          blurRadius: 8,
          offset: const Offset(0, 2),
        ),
      ];

  /// 强调阴影 (用于需要突出的元素)
  static List<BoxShadow> get emphasizedShadow => [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.1),
          blurRadius: 16,
          offset: const Offset(0, 8),
        ),
      ];

  // ============ 动画 ============

  /// 快速动画时长 (按压反馈)
  /// Celechron: 200ms
  static const Duration fastAnimation = Duration(milliseconds: 200);

  /// 标准动画时长 (页面切换、展开收起)
  /// Celechron: 400ms
  static const Duration normalAnimation = Duration(milliseconds: 400);

  /// 慢速动画时长 (复杂过渡)
  static const Duration slowAnimation = Duration(milliseconds: 600);

  /// 标准缓动曲线 (进出)
  static const Curve standardCurve = Curves.easeInOut;

  /// 缓出曲线 (推荐用于大多数动画)
  static const Curve easeOutCurve = Curves.easeOutCubic;

  /// 缓入曲线
  static const Curve easeInCurve = Curves.easeInCubic;

  /// 弹性曲线 (用于引起注意的动画)
  static const Curve elasticCurve = Curves.elasticOut;

  // ============ 缩放 ============

  /// 按压时的缩放比例
  /// Celechron: 0.95
  static const double pressedScale = 0.95;

  /// 悬停时的缩放比例
  static const double hoverScale = 1.02;

  // ============ 间距 ============

  /// 极小间距
  static const double spacingXS = 4.0;

  /// 小间距
  static const double spacingS = 8.0;

  /// 标准间距
  static const double spacingM = 12.0;

  /// 大间距
  static const double spacingL = 16.0;

  /// 超大间距
  static const double spacingXL = 20.0;

  /// 区块间距
  static const double spacingXXL = 24.0;

  /// 卡片内边距 (标准)
  static const EdgeInsets cardPadding = EdgeInsets.all(16.0);

  /// 卡片内边距 (紧凑)
  static const EdgeInsets cardPaddingCompact = EdgeInsets.all(12.0);

  /// 页面水平边距
  static const EdgeInsets pagePadding = EdgeInsets.symmetric(horizontal: 20.0);

  /// 卡片间距
  static const EdgeInsets cardMargin = EdgeInsets.only(bottom: 12.0);

  // ============ 尺寸 ============

  /// 图标容器尺寸 (小)
  static const double iconContainerSmall = 40.0;

  /// 图标容器尺寸 (中)
  static const double iconContainerMedium = 48.0;

  /// 图标容器尺寸 (大)
  static const double iconContainerLarge = 56.0;

  /// 底部导航栏高度
  static const double bottomNavBarHeight = 60.0;

  /// 标准按钮高度
  static const double buttonHeight = 48.0;

  /// 紧凑按钮高度
  static const double buttonHeightCompact = 40.0;

  // ============ 高亮效果 ============

  /// 高亮边框宽度
  static const double highlightBorderWidth = 2.0;

  /// 高亮显示时长
  static const Duration highlightDuration = Duration(seconds: 3);

  /// 高亮动画时长
  static const Duration highlightAnimationDuration = Duration(milliseconds: 300);

  // ============ 不透明度 ============

  /// 禁用状态不透明度
  static const double disabledOpacity = 0.4;

  /// 次要文本不透明度
  static const double secondaryTextOpacity = 0.6;

  /// 提示文本不透明度
  static const double hintTextOpacity = 0.5;

  /// 分割线不透明度
  static const double dividerOpacity = 0.1;

  // ============ 字体大小 ============

  /// 超大标题
  static const double fontSizeXXL = 28.0;

  /// 大标题
  static const double fontSizeXL = 24.0;

  /// 标题
  static const double fontSizeL = 20.0;

  /// 副标题
  static const double fontSizeM = 16.0;

  /// 正文
  static const double fontSizeS = 14.0;

  /// 辅助文字
  static const double fontSizeXS = 12.0;

  /// 微小文字
  static const double fontSizeXXS = 10.0;

  // ============ 字重 ============

  /// 常规
  static const FontWeight fontWeightRegular = FontWeight.w400;

  /// 中等
  static const FontWeight fontWeightMedium = FontWeight.w500;

  /// 半粗
  static const FontWeight fontWeightSemiBold = FontWeight.w600;

  /// 粗体
  static const FontWeight fontWeightBold = FontWeight.w700;

  // ============ 工具方法 ============

  /// 创建带圆角的BoxDecoration
  static BoxDecoration cardDecoration({
    required Color backgroundColor,
    required bool isDark,
    Color? borderColor,
    double? borderWidth,
  }) {
    return BoxDecoration(
      color: backgroundColor,
      borderRadius: BorderRadius.circular(cardBorderRadius),
      border: borderColor != null
          ? Border.all(color: borderColor, width: borderWidth ?? 1)
          : null,
      boxShadow: isDark ? null : cardShadow,
    );
  }

  /// 创建圆角
  static BorderRadius cardRadius() => BorderRadius.circular(cardBorderRadius);

  /// 创建小圆角
  static BorderRadius smallRadius() => BorderRadius.circular(smallBorderRadius);

  /// 创建大圆角
  static BorderRadius largeRadius() => BorderRadius.circular(largeBorderRadius);
}
