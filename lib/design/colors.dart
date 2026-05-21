import 'package:flutter/material.dart';

/// 自定义颜色系统
/// 精确匹配 Celechron 设计风格，支持亮色/暗色模式动态颜色
class AppColors {
  // 季节色彩 - 与 Celechron CustomCupertinoDynamicColors 完全匹配
  static const spring = DynamicColor(
    light: Color.fromRGBO(230, 255, 226, 1.0),
    dark: Color.fromRGBO(147, 251, 56, 1.0),
  );

  static const summer = DynamicColor(
    light: Color.fromRGBO(255, 218, 238, 1.0),
    dark: Color.fromRGBO(255, 25, 69, 1.0),
  );

  static const autumn = DynamicColor(
    light: Color.fromRGBO(255, 234, 230, 1.0),
    dark: Color.fromRGBO(255, 101, 56, 1.0),
  );

  static const winter = DynamicColor(
    light: Color.fromRGBO(226, 239, 255, 1.0),
    dark: Color.fromRGBO(0, 183, 251, 1.0),
  );

  // 功能色彩
  static const cyan = DynamicColor(
    light: Color.fromRGBO(218, 234, 255, 1.0),
    dark: Color.fromRGBO(0, 140, 255, 1.0),
  );

  static const magenta = DynamicColor(
    light: Color.fromRGBO(230, 229, 255, 1.0),
    dark: Color.fromRGBO(238, 55, 161, 1.0),
  );

  static const peach = DynamicColor(
    light: Color.fromRGBO(255, 235, 226, 1.0),
    dark: Color.fromRGBO(233, 114, 70, 1.0),
  );

  static const violet = DynamicColor(
    light: Color.fromRGBO(230, 229, 255, 1.0),
    dark: Color.fromRGBO(151, 131, 216, 1.0),
  );

  static const sakura = DynamicColor(
    light: Color.fromRGBO(255, 226, 255, 1.0),
    dark: Color.fromRGBO(218, 130, 217, 1.0),
  );

  static const okGreen = DynamicColor(
    light: Color.fromRGBO(230, 255, 226, 1.0),
    dark: Color.fromRGBO(63, 222, 23, 1.0),
  );

  static const sand = DynamicColor(
    light: Color.fromRGBO(255, 246, 211, 1.0),
    dark: Color.fromRGBO(252, 222, 59, 1.0),
  );

  // 主题色
  static const zjuBlue = DynamicColor(
    light: Color(0xFF003D87),
    dark: Color(0xFF4D8FD9),
  );

  // 表面颜色
  static const surface = DynamicColor(
    light: Color(0xFFFFFFFF),
    dark: Color(0xFF1E293B),
  );

  static const background = DynamicColor(
    light: Color(0xFFF8FAFC),
    dark: Color(0xFF0F172A),
  );

  static const secondaryBackground = DynamicColor(
    light: Color(0xFFF1F5F9),
    dark: Color(0xFF1E293B),
  );

  // 文字颜色
  static const textPrimary = DynamicColor(
    light: Color(0xFF0F172A),
    dark: Color(0xFFF1F5F9),
  );

  static const textSecondary = DynamicColor(
    light: Color(0xFF64748B),
    dark: Color(0xFF94A3B8),
  );

  static const textTertiary = DynamicColor(
    light: Color(0xFF94A3B8),
    dark: Color(0xFF64748B),
  );

  // 分割线
  static const divider = DynamicColor(
    light: Color(0xFFE2E8F0),
    dark: Color(0xFF334155),
  );

  // 卡片颜色列表（用于随机分配）
  static const List<DynamicColor> cardColors = [
    spring,
    summer,
    autumn,
    winter,
    cyan,
    magenta,
    peach,
    violet,
    sakura,
  ];

  /// 根据字符串生成稳定的颜色
  static DynamicColor colorFromString(String str) {
    final index = str.hashCode.abs() % cardColors.length;
    return cardColors[index];
  }
}

/// 动态颜色类，支持亮色/暗色模式
class DynamicColor {
  final Color light;
  final Color dark;

  const DynamicColor({
    required this.light,
    required this.dark,
  });

  /// 根据当前主题解析颜色
  Color resolve(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    return brightness == Brightness.dark ? dark : light;
  }

  /// 获取带透明度的颜色
  Color withAlpha(BuildContext context, double alpha) {
    return resolve(context).withValues(alpha: alpha);
  }
}

/// 扩展方法
extension DynamicColorExtension on BuildContext {
  Color resolveDynamic(DynamicColor color) => color.resolve(this);
}
