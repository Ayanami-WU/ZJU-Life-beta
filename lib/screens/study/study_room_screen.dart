import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';

import '../../config/theme.dart';
import '../../design/colors.dart';
import '../../design/design_constants.dart';
import '../../models/library.dart';
import '../../providers/auth_provider.dart';
import '../../services/auth_service.dart';
import '../../services/library_service.dart';
import '../../widgets/cards.dart';
import '../../widgets/indicators.dart';

class StudyRoomScreen extends StatefulWidget {
  final String roomId;
  final LibraryService? libraryService;

  const StudyRoomScreen({super.key, required this.roomId, this.libraryService});

  @override
  State<StudyRoomScreen> createState() => _StudyRoomScreenState();
}

class _StudyRoomScreenState extends State<StudyRoomScreen> {
  late final LibraryService _libraryService;

  LibraryRoomDetail? _detail;
  bool _isLoading = false;
  bool _isAuthorizing = false;
  bool _needsLogin = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _libraryService = widget.libraryService ?? LibraryService();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadDetail());
  }

  Future<void> _loadDetail({bool forceRefresh = false}) async {
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

      final detail = await _libraryService.fetchRoomDetail(
        widget.roomId,
        useCache: !forceRefresh,
      );
      if (!mounted) return;
      setState(() {
        _detail = detail;
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
          onRefresh: () => _loadDetail(forceRefresh: true),
          color: context.primaryColor,
          child: CustomScrollView(
            slivers: [
              SliverToBoxAdapter(child: _buildHeader()),
              if (_isLoading)
                SliverFillRemaining(
                  child: LoadingIndicator(
                    message: _isAuthorizing ? '正在获取图书馆权限...' : '加载座位地图...',
                  ),
                )
              else if (_needsLogin)
                SliverFillRemaining(
                  child: _RoomStatusView(
                    icon: LucideIcons.keyRound,
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
                  child: _RoomStatusView(
                    icon: LucideIcons.wifiOff,
                    title: '加载失败',
                    subtitle: _error ?? '请检查网络连接后重试',
                    action: FilledButton.icon(
                      onPressed: () => _loadDetail(forceRefresh: true),
                      icon: const Icon(LucideIcons.refreshCw, size: 18),
                      label: const Text('重试'),
                    ),
                  ),
                )
              else if (_detail == null)
                const SliverFillRemaining(
                  child: _RoomStatusView(
                    icon: LucideIcons.map,
                    title: '暂无座位数据',
                    subtitle: '下拉刷新试试',
                  ),
                )
              else
                _buildBody(_detail!),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    final room = _detail?.room;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 20, 8),
      child: Row(
        children: [
          IconButton(
            onPressed: () {
              if (context.canPop()) {
                context.pop();
              } else {
                context.go('/study');
              }
            },
            icon: const Icon(LucideIcons.arrowLeft, size: 22),
            tooltip: '返回',
          ),
          const SizedBox(width: 4),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  room?.name ?? '房间座位',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary.resolve(context),
                  ),
                ),
                Text(
                  room == null
                      ? '图书馆座位地图'
                      : '${room.libraryName} · ${room.floorName}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13,
                    color: AppColors.textSecondary.resolve(context),
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: () => _loadDetail(forceRefresh: true),
            icon: const Icon(LucideIcons.refreshCw, size: 20),
            color: AppColors.textSecondary.resolve(context),
            tooltip: '刷新',
          ),
        ],
      ),
    );
  }

  Widget _buildBody(LibraryRoomDetail detail) {
    return SliverPadding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 100),
      sliver: SliverList(
        delegate: SliverChildListDelegate([
          _buildOverview(detail),
          const SizedBox(height: 16),
          _buildStatusLegend(detail),
          const SizedBox(height: 16),
          if (detail.hasMap) _buildMap(detail) else _buildSeatList(detail),
        ]),
      ),
    );
  }

  Widget _buildOverview(LibraryRoomDetail detail) {
    final total = detail.totalNum;
    final free = detail.freeNum;
    final usage = total > 0 ? (total - free) / total : 0.0;

    return ForeheadCard(
      foreheadColor: AppColors.winter,
      forehead: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Row(
          children: [
            Icon(
              LucideIcons.map,
              size: 18,
              color: AppColors.textPrimary.resolve(context),
            ),
            const SizedBox(width: 8),
            Text(
              '房间概览',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary.resolve(context),
              ),
            ),
          ],
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.only(top: 8),
        child: Row(
          children: [
            Expanded(
              child: TwoLineCard(
                title: '空闲',
                content: '$free',
                backgroundColor: AppColors.okGreen,
                withColoredFont: true,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: TwoLineCard(
                title: '总数',
                content: '$total',
                backgroundColor: AppColors.winter,
                withColoredFont: true,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: TwoLineCard(
                title: '使用率',
                content: '${(usage * 100).round()}%',
                backgroundColor: usage < 0.6
                    ? AppColors.okGreen
                    : usage < 0.85
                        ? AppColors.autumn
                        : AppColors.summer,
                withColoredFont: true,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusLegend(LibraryRoomDetail detail) {
    final counts = detail.statusCounts.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: counts.map((entry) {
        final color = _statusColorByLabel(entry.key);
        return StatusChip(text: '${entry.key} ${entry.value}', color: color);
      }).toList(),
    );
  }

  Widget _buildMap(LibraryRoomDetail detail) {
    final imageUrl = detail.map.preferredImageUrl!;
    final seatsWithPoint = detail.seats.where((seat) => seat.hasPoint).toList();

    return ModernCard(
      padding: EdgeInsets.zero,
      showShadow: false,
      child: ClipRRect(
        borderRadius: DesignConstants.cardRadius(),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final size = constraints.maxWidth;
            return SizedBox(
              height: size,
              child: InteractiveViewer(
                minScale: 1,
                maxScale: 5,
                boundaryMargin: const EdgeInsets.all(80),
                child: SizedBox(
                  width: size,
                  height: size,
                  child: Stack(
                    children: [
                      Positioned.fill(
                        child: Image.network(
                          imageUrl,
                          fit: BoxFit.fill,
                          errorBuilder: (context, error, stackTrace) {
                            return _MapFallback(
                              message: '地图加载失败，显示座位列表',
                              seats: detail.seats,
                              colorForSeat: _statusColorForSeat,
                              framed: false,
                            );
                          },
                        ),
                      ),
                      ...seatsWithPoint.map(
                        (seat) => _SeatPoint(
                          seat: seat,
                          size: size,
                          color: _statusColorForSeat(seat),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildSeatList(LibraryRoomDetail detail) {
    return _MapFallback(
      message: '暂无可用地图，已切换为座位列表',
      seats: detail.seats,
      colorForSeat: _statusColorForSeat,
    );
  }

  Color _statusColorForSeat(LibrarySeatDetail seat) {
    return _statusColorByLabel(seat.statusLabel, status: seat.status);
  }

  Color _statusColorByLabel(String label, {String? status}) {
    if (status == '1' || label == '空闲') return AppColors.okGreen.dark;
    if (label.contains('预约') || label.contains('即将')) {
      return AppColors.sand.dark;
    }
    if (label.contains('暂离') || label.contains('离开')) {
      return AppColors.winter.dark;
    }
    if (label.contains('占') || label.contains('使用')) {
      return AppColors.summer.dark;
    }
    if (label.contains('不可') || label.contains('关闭')) {
      return AppColors.textTertiary.resolve(context);
    }
    return AppColors.textSecondary.resolve(context);
  }
}

class _SeatPoint extends StatelessWidget {
  final LibrarySeatDetail seat;
  final double size;
  final Color color;

  const _SeatPoint({
    required this.seat,
    required this.size,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final left = ((seat.pointX ?? 0) / 100 * size).clamp(0.0, size).toDouble();
    final top = ((seat.pointY ?? 0) / 100 * size).clamp(0.0, size).toDouble();

    return Positioned(
      left: left - 6,
      top: top - 6,
      child: Tooltip(
        message: '${seat.displayName} · ${seat.statusLabel}',
        child: Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.55),
            shape: BoxShape.circle,
            border: Border.all(color: color, width: 1.5),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.12),
                blurRadius: 4,
                offset: const Offset(0, 1),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MapFallback extends StatelessWidget {
  final String message;
  final List<LibrarySeatDetail> seats;
  final Color Function(LibrarySeatDetail seat) colorForSeat;
  final bool framed;

  const _MapFallback({
    required this.message,
    required this.seats,
    required this.colorForSeat,
    this.framed = true,
  });

  @override
  Widget build(BuildContext context) {
    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              LucideIcons.list,
              size: 18,
              color: AppColors.textSecondary.resolve(context),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                message,
                style: TextStyle(
                  fontSize: 13,
                  color: AppColors.textSecondary.resolve(context),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (seats.isEmpty)
          Text(
            '暂无座位',
            style: TextStyle(color: AppColors.textSecondary.resolve(context)),
          )
        else
          ...seats.map(
            (seat) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: colorForSeat(seat),
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      seat.displayName,
                      style: TextStyle(
                        color: AppColors.textPrimary.resolve(context),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  Text(
                    seat.statusLabel,
                    style: TextStyle(
                      color: colorForSeat(seat),
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );

    if (!framed) {
      return Container(
        color: context.cardColor,
        padding: const EdgeInsets.all(16),
        child: SingleChildScrollView(child: content),
      );
    }

    return ModernCard(
      showShadow: false,
      padding: const EdgeInsets.all(16),
      child: content,
    );
  }
}

class _RoomStatusView extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Widget? action;

  const _RoomStatusView({
    required this.icon,
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
                color: AppColors.winter.resolve(context),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Icon(icon, size: 36, color: AppColors.winter.dark),
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
            if (action != null) ...[const SizedBox(height: 24), action!],
          ],
        ),
      ),
    );
  }
}
