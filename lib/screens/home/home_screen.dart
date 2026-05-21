import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';

import '../../design/colors.dart';
import '../../design/design_constants.dart';
import '../../widgets/cards.dart';
import '../../providers/auth_provider.dart';
import '../../providers/favorites_provider.dart';
import '../../providers/campus_provider.dart';
import '../../services/canteen_service.dart';
import '../../services/bus_service.dart';
import '../../models/canteen.dart';
import '../../models/bus.dart';
import '../../models/favorite.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  // 实时数据
  final CanteenService _canteenService = CanteenService();
  final BusService _busService = BusService();
  
  List<CanteenData>? _canteenData;
  List<BusRoute>? _busRoutes;
  bool _isLoadingLiveData = false;
  
  @override
  void initState() {
    super.initState();
    _loadLiveData();
  }
  
  Future<void> _loadLiveData() async {
    if (_isLoadingLiveData) return;
    setState(() => _isLoadingLiveData = true);
    
    try {
      // 并行加载食堂和班车数据
      final results = await Future.wait([
        _canteenService.fetchCanteenData().then((r) => r.canteens).catchError((_) => <CanteenData>[]),
        _busService.fetchBusRoutes(BusType.campusShuttle).catchError((_) => <BusRoute>[]),
      ]);
      
      if (mounted) {
        setState(() {
          _canteenData = results[0] as List<CanteenData>;
          _busRoutes = results[1] as List<BusRoute>;
        });
      }
    } catch (_) {
      // 静默失败
    } finally {
      if (mounted) {
        setState(() => _isLoadingLiveData = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final favorites = context.watch<FavoritesProvider>();
    final campus = context.watch<CampusProvider>();
    final brightness = Theme.of(context).brightness;

    return Scaffold(
      backgroundColor: brightness == Brightness.dark 
          ? const Color(0xFF0F172A) 
          : const Color(0xFFF8FAFC),
      body: CustomScrollView(
        slivers: [
          // 顶部安全区域
          SliverToBoxAdapter(
            child: SizedBox(height: MediaQuery.of(context).padding.top + 8),
          ),
          
          // 顶部欢迎区域
          SliverToBoxAdapter(
            child: Padding(
              padding: DesignConstants.pagePadding,
              child: _buildHeader(auth, campus),
            ),
          ),

          const SliverToBoxAdapter(child: SizedBox(height: DesignConstants.spacingXL)),

          // 快捷入口卡片组
          SliverToBoxAdapter(
            child: Padding(
              padding: DesignConstants.pagePadding,
              child: _buildQuickEntries(),
            ),
          ),

          const SliverToBoxAdapter(child: SizedBox(height: DesignConstants.spacingL)),

          // 收藏区域 - 始终显示
          SliverToBoxAdapter(
            child: Padding(
              padding: DesignConstants.pagePadding,
              child: _buildFavoritesSection(favorites),
            ),
          ),
          
          // 登录提示
          if (!auth.isAuthenticated)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                child: _buildLoginPrompt(),
              ),
            ),
          
          // 底部间距
          SliverToBoxAdapter(
            child: SizedBox(height: MediaQuery.of(context).padding.bottom + 100),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(AuthProvider auth, CampusProvider campus) {
    final now = DateTime.now();
    final greeting = _getGreeting(now.hour);
    final dateStr = DateFormat('M月d日 EEEE', 'zh_CN').format(now);
    final brightness = Theme.of(context).brightness;
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    greeting,
                    style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w700,
                      color: brightness == Brightness.dark 
                          ? Colors.white 
                          : const Color(0xFF0F172A),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Container(
                        width: 6,
                        height: 6,
                        decoration: BoxDecoration(
                          color: AppColors.okGreen.dark,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: DesignConstants.spacingS),
                      Text(
                        dateStr,
                        style: TextStyle(
                          fontSize: 14,
                          color: brightness == Brightness.dark
                              ? Colors.white60
                              : const Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            // 头像/设置按钮
            GestureDetector(
              onTap: () => context.go('/profile'),
              child: Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: brightness == Brightness.dark 
                      ? const Color(0xFF1E293B) 
                      : Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: brightness == Brightness.dark ? null : [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.06),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Icon(
                  auth.isAuthenticated ? LucideIcons.user : LucideIcons.settings,
                  size: 20,
                  color: brightness == Brightness.dark
                      ? Colors.white60
                      : const Color(0xFF64748B),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: DesignConstants.spacingL),
        // 校区选择器
        _buildCampusSelector(campus),
      ],
    );
  }
  
  Widget _buildCampusSelector(CampusProvider campus) {
    final brightness = Theme.of(context).brightness;
    
    return GestureDetector(
      onTap: () => _showCampusPicker(campus),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: brightness == Brightness.dark
              ? AppColors.winter.dark.withValues(alpha: 0.15)
              : AppColors.winter.light,
          borderRadius: DesignConstants.cardRadius(),
          border: Border.all(
            color: AppColors.winter.dark.withValues(alpha: 0.2),
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              LucideIcons.mapPin,
              size: 16,
              color: AppColors.winter.dark,
            ),
            const SizedBox(width: DesignConstants.spacingS),
            Text(
              campus.selectedCampus.label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppColors.winter.dark,
              ),
            ),
            const SizedBox(width: 6),
            Icon(
              LucideIcons.chevronDown,
              size: 14,
              color: AppColors.winter.dark,
            ),
          ],
        ),
      ),
    );
  }
  
  void _showCampusPicker(CampusProvider campus) {
    final brightness = Theme.of(context).brightness;
    
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: brightness == Brightness.dark
              ? const Color(0xFF1E293B)
              : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: DesignConstants.spacingM),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: brightness == Brightness.dark
                      ? Colors.white24
                      : Colors.black12,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: DesignConstants.spacingXL),
              Text(
                '选择校区',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: brightness == Brightness.dark
                      ? Colors.white
                      : const Color(0xFF0F172A),
                ),
              ),
              const SizedBox(height: DesignConstants.spacingXL),
              Padding(
                padding: DesignConstants.pagePadding,
                child: Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: Campus.values.map((c) {
                    final isSelected = c == campus.selectedCampus;
                    return GestureDetector(
                      onTap: () {
                        HapticFeedback.selectionClick();
                        campus.selectCampus(c);
                        Navigator.pop(context);
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 12,
                        ),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? AppColors.winter.dark.withValues(alpha: 0.15)
                              : (brightness == Brightness.dark
                                  ? Colors.white10
                                  : const Color(0xFFF1F5F9)),
                          borderRadius: DesignConstants.cardRadius(),
                          border: isSelected
                              ? Border.all(
                                  color: AppColors.winter.dark,
                                  width: 2,
                                )
                              : null,
                        ),
                        child: Text(
                          c.label,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: isSelected
                                ? FontWeight.w600
                                : FontWeight.w500,
                            color: isSelected
                                ? AppColors.winter.dark
                                : (brightness == Brightness.dark
                                    ? Colors.white70
                                    : const Color(0xFF64748B)),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(height: DesignConstants.spacingXXL),
            ],
          ),
        ),
      ),
    );
  }

  String _getGreeting(int hour) {
    if (hour < 6) return '夜深了 🌙';
    if (hour < 9) return '早上好 ☀️';
    if (hour < 12) return '上午好 🌤';
    if (hour < 14) return '中午好 🍜';
    if (hour < 18) return '下午好 ☕';
    if (hour < 22) return '晚上好 🌆';
    return '夜深了 🌙';
  }

  Widget _buildQuickEntries() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 主要入口卡片
        ForeheadCard(
          foreheadColor: AppColors.cyan,
          forehead: _buildForeheadRow(
            icon: LucideIcons.layoutGrid,
            title: '快捷入口',
          ),
          child: Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Row(
              children: [
                Expanded(
                  child: TwoLineCard(
                    title: '食堂',
                    content: '就餐',
                    backgroundColor: AppColors.peach,
                    animate: true,
                    onTap: () => context.go('/canteen'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TwoLineCard(
                    title: '自习',
                    content: '学习',
                    backgroundColor: AppColors.okGreen,
                    animate: true,
                    onTap: () => context.go('/study'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TwoLineCard(
                    title: '班车',
                    content: '出行',
                    backgroundColor: AppColors.violet,
                    animate: true,
                    onTap: () => context.go('/bus'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFavoritesSection(FavoritesProvider favorites) {
    final brightness = Theme.of(context).brightness;
    final isEmpty = favorites.favorites.isEmpty;
    
    return ForeheadCard(
      foreheadColor: AppColors.sakura,
      forehead: _buildForeheadRow(
        icon: LucideIcons.heart,
        title: '我的收藏',
        trailing: isEmpty 
            ? null 
            : GestureDetector(
                onTap: () => context.go('/profile'),
                child: Text(
                  '管理',
                  style: TextStyle(
                    fontSize: 13,
                    color: brightness == Brightness.dark
                        ? Colors.white60
                        : const Color(0xFF64748B),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
      ),
      child: Padding(
        padding: const EdgeInsets.only(top: 8),
        child: isEmpty 
            ? _buildEmptyFavorites()
            : Column(
                children: favorites.favorites.take(5).map((item) => 
                  _LiveFavoriteCard(
                    item: item,
                    canteenData: _canteenData,
                    busRoutes: _busRoutes,
                    onTap: () => _navigateToFavorite(item),
                  ),
                ).toList(),
              ),
      ),
    );
  }
  
  Widget _buildEmptyFavorites() {
    final brightness = Theme.of(context).brightness;
    
    return Container(
      height: 82,
      decoration: BoxDecoration(
        color: brightness == Brightness.dark
            ? Colors.white.withValues(alpha: 0.05)
            : Colors.black.withValues(alpha: 0.02),
        borderRadius: DesignConstants.cardRadius(),
        border: Border.all(
          color: brightness == Brightness.dark
              ? Colors.white.withValues(alpha: 0.08)
              : Colors.black.withValues(alpha: 0.05),
          width: 1,
          strokeAlign: BorderSide.strokeAlignInside,
        ),
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              LucideIcons.heartOff,
              size: 24,
              color: brightness == Brightness.dark
                  ? Colors.white30
                  : const Color(0xFFCBD5E1),
            ),
            const SizedBox(height: 6),
            Text(
              '在食堂、班车页面点击 ♥ 添加收藏',
              style: TextStyle(
                fontSize: 12,
                color: brightness == Brightness.dark
                    ? Colors.white38
                    : const Color(0xFF94A3B8),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _navigateToFavorite(FavoriteItem item) {
    switch (item.type) {
      case FavoriteType.canteen:
      case FavoriteType.canteenWindow:
        context.go('/canteen');
        break;
      case FavoriteType.busRoute:
      case FavoriteType.busStop:
        context.go('/bus');
        break;
      case FavoriteType.libraryRoom:
      case FavoriteType.librarySeat:
        context.go('/study');
        break;
      case FavoriteType.custom:
        break;
    }
  }

  Widget _buildLoginPrompt() {
    return RoundCard(
      onTap: () => context.go('/login'),
      padding: EdgeInsets.zero,
      backgroundColor: AppColors.zjuBlue.dark,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              AppColors.zjuBlue.dark,
              AppColors.zjuBlue.dark.withValues(alpha: 0.85),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '解锁完整体验',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '登录统一身份认证，使用收藏、座位预约等功能',
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.white.withValues(alpha: 0.8),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: DesignConstants.smallRadius(),
                    ),
                    child: Text(
                      '立即登录',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.zjuBlue.dark,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              LucideIcons.logIn,
              size: 44,
              color: Colors.white.withValues(alpha: 0.25),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildForeheadRow({
    required IconData icon,
    required String title,
    Widget? trailing,
  }) {
    final brightness = Theme.of(context).brightness;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Row(
        children: [
          Icon(
            icon,
            size: 18,
            color: brightness == Brightness.dark
                ? Colors.white
                : const Color(0xFF0F172A),
          ),
          const SizedBox(width: DesignConstants.spacingS),
          Text(
            title,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary.resolve(context),
            ),
          ),
          if (trailing != null) ...[
            const Spacer(),
            trailing,
          ],
        ],
      ),
    );
  }
}

/// 带实时数据的收藏卡片
class _LiveFavoriteCard extends StatelessWidget {
  final FavoriteItem item;
  final List<CanteenData>? canteenData;
  final List<BusRoute>? busRoutes;
  final VoidCallback? onTap;

  const _LiveFavoriteCard({
    required this.item,
    this.canteenData,
    this.busRoutes,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final liveInfo = _getLiveInfo();
    
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            HapticFeedback.lightImpact();
            onTap?.call();
          },
          borderRadius: DesignConstants.cardRadius(),
          child: Ink(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: brightness == Brightness.dark
                  ? const Color(0xFF1E293B)
                  : Colors.white,
              borderRadius: DesignConstants.cardRadius(),
              boxShadow: brightness == Brightness.dark 
                  ? null
                  : [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.05),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
            ),
            child: Row(
              children: [
                // 图标
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: _getTypeColor(item.type).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(DesignConstants.iconContainerRadius),
                  ),
                  child: Icon(
                    item.icon,
                    color: _getTypeColor(item.type),
                    size: 22,
                  ),
                ),
                const SizedBox(width: DesignConstants.spacingM),
                // 内容
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.title,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        item.subtitle ?? '',
                        style: TextStyle(
                          fontSize: 12,
                          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                // 实时数据
                if (liveInfo != null) ...[
                  const SizedBox(width: DesignConstants.spacingS),
                  liveInfo.isProgressBar 
                      ? _buildProgressWidget(context, liveInfo)
                      : _buildLiveInfoWidget(context, liveInfo),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLiveInfoWidget(BuildContext context, _LiveInfo info) {
    final brightness = Theme.of(context).brightness;
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: info.color.withValues(alpha: 0.12),
        borderRadius: DesignConstants.smallRadius(),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            info.mainText,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: info.color,
            ),
          ),
          if (info.subText != null)
            Text(
              info.subText!,
              style: TextStyle(
                fontSize: 10,
                color: brightness == Brightness.dark
                    ? Colors.white60
                    : const Color(0xFF64748B),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildProgressWidget(BuildContext context, _LiveInfo info) {
    final brightness = Theme.of(context).brightness;
    
    return SizedBox(
      width: 80,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                info.mainText,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: info.color,
                ),
              ),
            ],
          ),
          const SizedBox(height: DesignConstants.spacingXS),
          ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: LinearProgressIndicator(
              value: info.progress ?? 0,
              backgroundColor: brightness == Brightness.dark
                  ? Colors.white.withValues(alpha: 0.1)
                  : Colors.black.withValues(alpha: 0.08),
              valueColor: AlwaysStoppedAnimation<Color>(info.color),
              minHeight: 6,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            info.subText ?? '',
            style: TextStyle(
              fontSize: 9,
              color: brightness == Brightness.dark
                  ? Colors.white60
                  : const Color(0xFF64748B),
            ),
          ),
        ],
      ),
    );
  }

  _LiveInfo? _getLiveInfo() {
    switch (item.type) {
      case FavoriteType.canteen:
      case FavoriteType.canteenWindow:
        return _getCanteenLiveInfo();
      case FavoriteType.busRoute:
        return _getBusLiveInfo();
      default:
        return null;
    }
  }

  _LiveInfo? _getCanteenLiveInfo() {
    if (canteenData == null) return null;
    
    // 通过名称匹配食堂
    final canteen = canteenData!.where((c) =>
      c.name.contains(item.title) || item.title.contains(c.name)
    ).firstOrNull;
    
    if (canteen == null || canteen.currentCount == null) return null;
    
    final crowdLevel = canteen.crowdLevel;
    final Color color;
    if (crowdLevel < 0.3) {
      color = AppColors.okGreen.dark;
    } else if (crowdLevel < 0.6) {
      color = AppColors.cyan.dark;
    } else if (crowdLevel < 0.85) {
      color = AppColors.peach.dark;
    } else {
      color = const Color(0xFFDC2626);
    }
    
    return _LiveInfo(
      mainText: canteen.crowdStatus,
      subText: '${canteen.currentCount}/${canteen.capacity}人',
      color: color,
      progress: crowdLevel,
      isProgressBar: true,
    );
  }

  _LiveInfo? _getBusLiveInfo() {
    if (busRoutes == null) return null;

    // 从 data 获取路线ID
    final routeId = item.data?['routeId'] as String?;
    if (routeId == null) return null;
    
    final route = busRoutes!.where((r) => r.id == routeId).firstOrNull;
    if (route == null) return null;
    
    // 获取下一班车
    final now = DateTime.now();
    final currentMinutes = now.hour * 60 + now.minute;
    
    BusSchedule? nextBus;
    for (final schedule in route.schedules) {
      if (schedule.departureMinutes > currentMinutes && schedule.isOperatingToday) {
        nextBus = schedule;
        break;
      }
    }
    
    if (nextBus == null) {
      return _LiveInfo(
        mainText: '今日无',
        subText: '明日首班',
        color: const Color(0xFF64748B),
      );
    }
    
    final waitMinutes = nextBus.departureMinutes - currentMinutes;
    final Color color;
    if (waitMinutes <= 10) {
      color = AppColors.okGreen.dark;
    } else if (waitMinutes <= 30) {
      color = AppColors.violet.dark;
    } else {
      color = const Color(0xFF64748B);
    }
    
    return _LiveInfo(
      mainText: nextBus.departureTime,
      subText: waitMinutes <= 60 ? '$waitMinutes分钟后' : '下一班',
      color: color,
    );
  }

  Color _getTypeColor(FavoriteType type) {
    switch (type) {
      case FavoriteType.busRoute:
      case FavoriteType.busStop:
        return AppColors.violet.dark;
      case FavoriteType.canteen:
      case FavoriteType.canteenWindow:
        return AppColors.peach.dark;
      case FavoriteType.libraryRoom:
      case FavoriteType.librarySeat:
        return AppColors.okGreen.dark;
      case FavoriteType.custom:
        return AppColors.cyan.dark;
    }
  }
}

class _LiveInfo {
  final String mainText;
  final String? subText;
  final Color color;
  final double? progress;
  final bool isProgressBar;

  _LiveInfo({
    required this.mainText,
    this.subText,
    required this.color,
    this.progress,
    this.isProgressBar = false,
  });
}
