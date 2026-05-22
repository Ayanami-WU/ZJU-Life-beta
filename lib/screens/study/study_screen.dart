import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';

import '../../config/theme.dart';
import '../../design/colors.dart';
import '../../design/design_constants.dart';
import '../../models/library.dart';
import '../../models/favorite.dart';
import '../../providers/auth_provider.dart';
import '../../services/auth_service.dart';
import '../../services/library_service.dart';
import '../../widgets/cards.dart';
import '../../widgets/cupertino_grouped.dart';
import '../../widgets/header.dart';
import '../../widgets/indicators.dart';
import '../../widgets/favorite_button.dart';

class StudyScreen extends StatefulWidget {
  final String? highlightRoomId;
  final String? highlightSeatId;

  const StudyScreen({
    super.key,
    this.highlightRoomId,
    this.highlightSeatId,
  });

  @override
  State<StudyScreen> createState() => _StudyScreenState();
}

class _StudyScreenState extends State<StudyScreen> {
  final LibraryService _libraryService = LibraryService();

  List<LibrarySeat> _seats = [];
  bool _isLoading = false;
  bool _isAcquiringJwt = false;
  String? _error;
  String? _highlightedId;

  @override
  void initState() {
    super.initState();
    _highlightedId = widget.highlightRoomId ?? widget.highlightSeatId;
    WidgetsBinding.instance.addPostFrameCallback((_) => _init());
  }

  Future<void> _init() async {
    final auth = context.read<AuthProvider>();

    if (auth.hasLibraryJwt) {
      _libraryService.setJwtToken(auth.libraryJwt!);
      _loadSeats();
    } else if (auth.isAuthenticated && auth.authCookie != null) {
      // CAS 已登录但无图书馆 JWT → 自动获取
      await _acquireJwt();
    } else {
      // 未登录 CAS
      setState(() {
        _error = 'not_logged_in';
      });
    }
  }

  /// 通过 CAS Cookie 自动获取图书馆 JWT
  Future<void> _acquireJwt() async {
    final auth = context.read<AuthProvider>();
    if (auth.authCookie == null) return;

    setState(() {
      _isAcquiringJwt = true;
      _error = null;
    });

    try {
      final jwt = await AuthService.instance.getLibraryJwt(auth.authCookie!);
      if (!mounted) return;

      if (jwt != null && jwt.isNotEmpty) {
        await auth.updateLibraryJwt(jwt);
        _libraryService.setJwtToken(jwt);
        await _loadSeats();
      } else {
        setState(() {
          _error = 'jwt_failed';
          _isAcquiringJwt = false;
        });
      }
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'jwt_failed';
        _isAcquiringJwt = false;
      });
    }
  }

  Future<void> _loadSeats({bool forceRefresh = false}) async {
    if (_isLoading) return;

    setState(() {
      _isLoading = true;
      _error = null;
      _isAcquiringJwt = false;
    });

    try {
      final seats =
          await _libraryService.fetchAllSeats(useCache: !forceRefresh);
      if (!mounted) return;
      setState(() {
        _seats = seats;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      final msg = e.toString();
      if (msg.contains('need_login')) {
        // JWT 过期，重新获取
        final auth = context.read<AuthProvider>();
        await auth.clearLibraryJwt();
        setState(() => _isLoading = false);
        if (auth.authCookie != null) {
          _acquireJwt();
        } else {
          setState(() => _error = 'jwt_expired');
        }
      } else {
        setState(() {
          _error = msg;
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();

    return Scaffold(
      backgroundColor: context.backgroundColor,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () => _loadSeats(forceRefresh: true),
          color: context.primaryColor,
          child: CustomScrollView(
            slivers: [
              // 页面标题区
              SliverToBoxAdapter(child: _buildPageHeader()),

              if (_isAcquiringJwt)
                const SliverFillRemaining(
                  child: _StatusView(
                    icon: LucideIcons.keyRound,
                    iconColor: AppColors.winter,
                    title: '正在获取权限',
                    subtitle: '通过统一身份认证自动登录图书馆系统...',
                    showSpinner: true,
                  ),
                )
              else if (_isLoading)
                const SliverFillRemaining(
                  child: LoadingIndicator(message: '加载座位数据...'),
                )
              else if (_error == 'not_logged_in')
                SliverFillRemaining(
                  child: _StatusView(
                    icon: LucideIcons.logIn,
                    iconColor: AppColors.winter,
                    title: '请先登录',
                    subtitle: '登录浙大统一身份认证后可查看图书馆座位',
                    action: FilledButton.icon(
                      onPressed: () => context.go('/login'),
                      icon: const Icon(LucideIcons.logIn, size: 18),
                      label: const Text('前往登录'),
                    ),
                  ),
                )
              else if (_error == 'jwt_failed' || _error == 'jwt_expired')
                SliverFillRemaining(
                  child: _StatusView(
                    icon: LucideIcons.alertCircle,
                    iconColor: AppColors.autumn,
                    title: _error == 'jwt_expired' ? '登录已过期' : '图书馆授权失败',
                    subtitle: auth.isAuthenticated
                        ? '点击重试，或尝试重新登录统一身份认证'
                        : '请先登录统一身份认证',
                    action: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (auth.isAuthenticated)
                          FilledButton.icon(
                            onPressed: _acquireJwt,
                            icon: const Icon(LucideIcons.refreshCw, size: 18),
                            label: const Text('重试'),
                          ),
                      ],
                    ),
                  ),
                )
              else if (_error != null)
                SliverFillRemaining(
                  child: _StatusView(
                    icon: LucideIcons.wifiOff,
                    iconColor: AppColors.autumn,
                    title: '加载失败',
                    subtitle: '请检查网络连接后重试',
                    action: FilledButton.icon(
                      onPressed: () => _loadSeats(forceRefresh: true),
                      icon: const Icon(LucideIcons.refreshCw, size: 18),
                      label: const Text('重试'),
                    ),
                  ),
                )
              else if (_seats.isEmpty)
                const SliverFillRemaining(
                  child: _StatusView(
                    icon: LucideIcons.bookOpen,
                    iconColor: AppColors.okGreen,
                    title: '暂无座位数据',
                    subtitle: '下拉刷新试试',
                  ),
                )
              else
                _buildSeatList(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPageHeader() {
    return PageHeader(
      title: '自习',
      subtitle: '图书馆座位',
      actions: _seats.isEmpty
          ? null
          : [
              CupertinoButton(
                minimumSize: const Size(36, 36),
                padding: EdgeInsets.zero,
                onPressed: () => _loadSeats(forceRefresh: true),
                child: Icon(
                  LucideIcons.refreshCw,
                  size: 20,
                  color: AppColors.textSecondary.resolve(context),
                ),
              ),
            ],
    );
  }

  Widget _buildSeatList() {
    final grouped = _libraryService.groupByBuilding(_seats);
    int totalSeats = 0;
    int freeSeats = 0;
    for (final s in _seats) {
      totalSeats += s.totalNum;
      freeSeats += s.freeNum;
    }

    return SliverPadding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 100),
      sliver: SliverList(
        delegate: SliverChildListDelegate([
          // 总览卡片
          _buildOverviewCard(totalSeats, freeSeats),
          const SizedBox(height: 20),
          // 按建筑分组
          ...grouped.entries.map((entry) => _buildBuildingSection(
                entry.key,
                entry.value,
              )),
        ]),
      ),
    );
  }

  Widget _buildOverviewCard(int totalSeats, int freeSeats) {
    final occupancy =
        totalSeats > 0 ? (totalSeats - freeSeats) / totalSeats : 0.0;

    final occupancyColor = occupancy < 0.6
        ? AppColors.okGreen.dark
        : occupancy < 0.85
            ? AppColors.autumn.dark
            : AppColors.summer.dark;

    return CupertinoGroupSection(
      header: '座位概览',
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Expanded(
                child: _OverviewMetric(
                  label: '空闲座位',
                  value: '$freeSeats',
                  color: AppColors.okGreen.dark,
                ),
              ),
              Expanded(
                child: _OverviewMetric(
                  label: '总座位',
                  value: '$totalSeats',
                  color: AppColors.winter.dark,
                ),
              ),
              Expanded(
                child: _OverviewMetric(
                  label: '使用率',
                  value: '${(occupancy * 100).round()}%',
                  color: occupancyColor,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildBuildingSection(String building, List<LibrarySeat> seats) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SubtitleRow(subtitle: building),
        ...seats.map((seat) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _SeatCard(
                seat: seat,
                isHighlighted: _highlightedId == seat.id,
              ),
            )),
        const SizedBox(height: 8),
      ],
    );
  }
}

// ─── 状态占位视图 ──────────────────────────────────────────────────────────────

class _StatusView extends StatelessWidget {
  final IconData icon;
  final DynamicColor iconColor;
  final String title;
  final String subtitle;
  final Widget? action;
  final bool showSpinner;

  const _StatusView({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    this.action,
    this.showSpinner = false,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Stack(
              alignment: Alignment.center,
              children: [
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: Theme.of(context).brightness == Brightness.dark
                        ? iconColor.dark.withValues(alpha: 0.2)
                        : iconColor.light,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Icon(icon, size: 36, color: iconColor.dark),
                ),
                if (showSpinner)
                  SizedBox(
                    width: 94,
                    height: 94,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      color: iconColor.dark,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 20),
            Text(
              title,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: AppColors.textSecondary.resolve(context),
              ),
            ),
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

class _OverviewMetric extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _OverviewMetric({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: AppColors.textSecondary.resolve(context),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w700,
            color: color,
          ),
        ),
      ],
    );
  }
}

// ─── 座位卡片 ──────────────────────────────────────────────────────────────────

class _SeatCard extends StatelessWidget {
  final LibrarySeat seat;
  final bool isHighlighted;

  const _SeatCard({required this.seat, this.isHighlighted = false});

  @override
  Widget build(BuildContext context) {
    final occupancy = seat.usageRate;
    final statusColor = occupancy < 0.6
        ? AppColors.okGreen.dark
        : occupancy < 0.85
            ? AppColors.autumn.dark
            : AppColors.summer.dark;

    return AnimatedContainer(
      duration: DesignConstants.highlightAnimationDuration,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: isHighlighted
            ? Border.all(
                color: context.primaryColor,
                width: DesignConstants.highlightBorderWidth,
              )
            : null,
      ),
      child: CupertinoGroupSection(
        children: [
          CupertinoGroupRow(
            icon: LucideIcons.bookOpen,
            iconColor: statusColor,
            title: seat.name,
            subtitle: '${seat.typeName}  ·  ${seat.storeyName}',
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                CupertinoMetricPill(
                  text: '${seat.freeNum}/${seat.totalNum}',
                  subtext: seat.status,
                  color: statusColor,
                ),
                const SizedBox(width: 8),
                FavoriteButton(
                  itemId: 'library_${seat.id}',
                  type: FavoriteType.libraryRoom,
                  title: seat.name,
                  subtitle: seat.location,
                  data: {
                    'building': seat.premisesName,
                    'floor': seat.storeyName,
                    'totalSeats': seat.totalNum,
                  },
                  size: 20,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
