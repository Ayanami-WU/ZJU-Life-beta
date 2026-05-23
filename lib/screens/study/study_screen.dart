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
  final LibraryService? libraryService;

  const StudyScreen({
    super.key,
    this.highlightRoomId,
    this.highlightSeatId,
    this.libraryService,
  });

  @override
  State<StudyScreen> createState() => _StudyScreenState();
}

class _StudyScreenState extends State<StudyScreen> {
  late final LibraryService _libraryService;

  List<LibrarySeat> _seats = [];
  bool _isLoading = false;
  bool _isAuthorizing = false;
  bool _needsLogin = false;
  String? _error;
  String? _highlightedId;

  @override
  void initState() {
    super.initState();
    _libraryService = widget.libraryService ?? LibraryService();
    _highlightedId = widget.highlightRoomId ?? widget.highlightSeatId;
    WidgetsBinding.instance.addPostFrameCallback((_) => _init());
  }

  Future<void> _init() async {
    await _loadSeats();
  }

  Future<void> _loadSeats({bool forceRefresh = false}) async {
    if (_isLoading) return;

    setState(() {
      _isLoading = true;
      _needsLogin = false;
      _error = null;
    });

    try {
      final canLoadLibrary = await _ensureLibraryAccess();
      if (!canLoadLibrary) {
        if (!mounted) return;
        setState(() => _isLoading = false);
        return;
      }

      final seats = await _libraryService.fetchAllSeats(
        useCache: !forceRefresh,
      );
      if (!mounted) return;
      setState(() {
        _seats = seats;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      final message = e.toString();
      if (message.contains('图书馆登录已过期') || message.contains('图书馆授权失败')) {
        await context.read<AuthProvider>().clearLibraryJwt();
        _libraryService.updateAuthToken(null);
        if (!mounted) return;
        setState(() {
          _needsLogin = true;
          _error = null;
          _isLoading = false;
        });
        return;
      }
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<bool> _ensureLibraryAccess() async {
    if (widget.libraryService != null) return true;

    final authProvider = context.read<AuthProvider>();
    await authProvider.ready;
    if (!mounted) return false;

    final existingToken = authProvider.libraryJwt;
    if (existingToken != null && existingToken.isNotEmpty) {
      _libraryService.updateAuthToken(existingToken);
      return true;
    }

    final casCookie = authProvider.authCookie;
    if (!authProvider.isAuthenticated ||
        casCookie == null ||
        casCookie.isEmpty) {
      setState(() {
        _needsLogin = true;
        _isAuthorizing = false;
      });
      return false;
    }

    setState(() => _isAuthorizing = true);

    final libraryJwt = await AuthService.instance.getLibraryJwt(casCookie);
    if (!mounted) return false;

    setState(() => _isAuthorizing = false);

    if (libraryJwt == null || libraryJwt.isEmpty) {
      throw AuthException('图书馆授权失败，请重新登录');
    }

    await authProvider.updateLibraryJwt(libraryJwt);
    if (!mounted) return false;

    _libraryService.updateAuthToken(libraryJwt);
    return true;
  }

  @override
  Widget build(BuildContext context) {
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

              if (_isLoading)
                SliverFillRemaining(
                  child: LoadingIndicator(
                    message: _isAuthorizing ? '正在获取图书馆权限...' : '加载座位数据...',
                  ),
                )
              else if (_needsLogin)
                SliverFillRemaining(
                  child: _StatusView(
                    icon: LucideIcons.keyRound,
                    iconColor: AppColors.winter,
                    title: '登录后查看座位',
                    subtitle: '图书馆座位需要使用统一身份认证获取访问凭证',
                    action: FilledButton.icon(
                      onPressed: () => context.go('/login'),
                      icon: const Icon(LucideIcons.logIn, size: 18),
                      label: const Text('去登录'),
                    ),
                  ),
                )
              else if (_error != null)
                SliverFillRemaining(
                  child: _StatusView(
                    icon: LucideIcons.wifiOff,
                    iconColor: AppColors.autumn,
                    title: '加载失败',
                    subtitle: _error ?? '请检查网络连接后重试',
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

  const _StatusView({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
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
                color: Theme.of(context).brightness == Brightness.dark
                    ? iconColor.dark.withValues(alpha: 0.2)
                    : iconColor.light,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Icon(icon, size: 36, color: iconColor.dark),
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
            onTap: () =>
                context.go('/study/room/${Uri.encodeComponent(seat.id)}'),
            showChevron: true,
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
