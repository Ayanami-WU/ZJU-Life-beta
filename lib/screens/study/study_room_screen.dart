import 'dart:math' as math;

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

const double _floorPlanSeatVisualScale = 1.12;
const double _floorPlanSeatTapScale = 1.0;
const double _floorPlanSeatTapPadding = 2;
const double _floorPlanSeatMinTapSize = 12;

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
          if (detail.seats.isNotEmpty)
            _buildMap(detail)
          else
            _buildSeatList(detail),
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
    return _OfficialSeatMap(
      detail: detail,
      colorForSeat: _statusColorForSeat,
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
  final Size mapSize;
  final Color color;
  final bool selected;
  final VoidCallback onSelected;

  const _SeatPoint({
    required this.seat,
    required this.mapSize,
    required this.color,
    required this.selected,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    final left = ((seat.pointX ?? 0) / 100 * mapSize.width)
        .clamp(0.0, mapSize.width)
        .toDouble();
    final top = ((seat.pointY ?? 0) / 100 * mapSize.height)
        .clamp(0.0, mapSize.height)
        .toDouble();

    return Positioned(
      left: left - 6,
      top: top - 6,
      child: Tooltip(
        message: '${seat.displayName} · ${seat.statusLabel}',
        child: MouseRegion(
          cursor: SystemMouseCursors.click,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onSelected,
            child: Container(
              width: selected ? 16 : 12,
              height: selected ? 16 : 12,
              decoration: BoxDecoration(
                color: color.withValues(alpha: selected ? 0.78 : 0.55),
                shape: BoxShape.circle,
                border: Border.all(
                  color: selected ? AppColors.winter.dark : color,
                  width: selected ? 2 : 1.5,
                ),
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
        ),
      ),
    );
  }
}

class _OfficialSeatMap extends StatefulWidget {
  final LibraryRoomDetail detail;
  final Color Function(LibrarySeatDetail seat) colorForSeat;

  const _OfficialSeatMap({
    required this.detail,
    required this.colorForSeat,
  });

  @override
  State<_OfficialSeatMap> createState() => _OfficialSeatMapState();
}

class _OfficialSeatMapState extends State<_OfficialSeatMap> {
  ImageStream? _imageStream;
  ImageStreamListener? _imageListener;
  Size? _imageSize;
  String? _imageUrl;
  LibrarySeatDetail? _selectedSeat;
  bool _showReadableGrid = true;
  bool _imageFailed = false;

  @override
  void initState() {
    super.initState();
    _resolveBaseImage();
  }

  @override
  void didUpdateWidget(covariant _OfficialSeatMap oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.detail.map.floorPlanImageUrl !=
        widget.detail.map.floorPlanImageUrl) {
      _resolveBaseImage();
    }
    final selectedSeat = _selectedSeat;
    if (selectedSeat != null &&
        !widget.detail.seats.any((seat) => seat.id == selectedSeat.id)) {
      _selectedSeat = null;
    }
  }

  @override
  void dispose() {
    _removeImageListener();
    super.dispose();
  }

  void _resolveBaseImage() {
    _removeImageListener();
    _imageUrl = widget.detail.map.floorPlanImageUrl;
    _imageSize = null;
    _imageFailed = _imageUrl == null;

    final imageUrl = _imageUrl;
    if (imageUrl == null) return;

    final map = widget.detail.map;
    if (map.hasNaturalSize) {
      _imageSize = Size(map.width!, map.height!);
      return;
    }

    final stream = NetworkImage(imageUrl).resolve(const ImageConfiguration());
    final listener = ImageStreamListener(
      (image, synchronousCall) {
        if (!mounted) return;
        setState(() {
          _imageSize = Size(
            image.image.width.toDouble(),
            image.image.height.toDouble(),
          );
          _imageFailed = false;
        });
      },
      onError: (error, stackTrace) {
        if (!mounted) return;
        setState(() => _imageFailed = true);
      },
    );

    _imageStream = stream;
    _imageListener = listener;
    stream.addListener(listener);
  }

  void _removeImageListener() {
    final stream = _imageStream;
    final listener = _imageListener;
    if (stream != null && listener != null) {
      stream.removeListener(listener);
    }
    _imageStream = null;
    _imageListener = null;
  }

  @override
  Widget build(BuildContext context) {
    final imageUrl = _imageUrl;
    final seatsWithPoint =
        widget.detail.seats.where((seat) => seat.hasPoint).toList();
    final canShowFloorPlan = imageUrl != null && seatsWithPoint.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (canShowFloorPlan) ...[
          _SeatModeTabs(
            showReadableGrid: _showReadableGrid,
            onChanged: (showReadableGrid) {
              setState(() => _showReadableGrid = showReadableGrid);
            },
          ),
          const SizedBox(height: 10),
        ],
        if (_showReadableGrid || !canShowFloorPlan)
          _ReadableSeatGrid(
            seats: widget.detail.seats,
            selectedSeatId: _selectedSeat?.id,
            colorForSeat: widget.colorForSeat,
            onSelected: _selectSeat,
          )
        else
          _buildFloorPlan(context, imageUrl, seatsWithPoint),
        if (_selectedSeat != null) ...[
          const SizedBox(height: 12),
          _SeatPreviewCard(
            seat: _selectedSeat!,
            color: widget.colorForSeat(_selectedSeat!),
            onClose: () => setState(() => _selectedSeat = null),
          ),
        ],
      ],
    );
  }

  void _selectSeat(LibrarySeatDetail seat) {
    setState(() => _selectedSeat = seat);
  }

  Widget _buildFloorPlan(
    BuildContext context,
    String imageUrl,
    List<LibrarySeatDetail> seatsWithPoint,
  ) {
    if (_imageFailed) {
      return _ReadableSeatGrid(
        seats: widget.detail.seats,
        selectedSeatId: _selectedSeat?.id,
        colorForSeat: widget.colorForSeat,
        onSelected: _selectSeat,
      );
    }

    final imageSize = _imageSize;
    if (imageSize == null) {
      return const ModernCard(
        showShadow: false,
        padding: EdgeInsets.all(24),
        child: LoadingIndicator(message: '加载座位平面图...'),
      );
    }

    final aspectRatio =
        imageSize.height == 0 ? 1.0 : imageSize.width / imageSize.height;

    return ModernCard(
      padding: EdgeInsets.zero,
      showShadow: false,
      child: ClipRRect(
        borderRadius: DesignConstants.cardRadius(),
        child: AspectRatio(
          aspectRatio: aspectRatio,
          child: InteractiveViewer(
            minScale: 1,
            maxScale: 5,
            boundaryMargin: const EdgeInsets.all(80),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final mapSize = Size(
                  constraints.maxWidth,
                  constraints.maxHeight,
                );
                final selectedSeat = _selectedSeat;
                return Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Positioned.fill(
                      child: Image.network(
                        imageUrl,
                        fit: BoxFit.fill,
                        errorBuilder: (context, error, stackTrace) {
                          return ColoredBox(color: context.cardColor);
                        },
                      ),
                    ),
                    ...seatsWithPoint.map(
                      (seat) => _SeatMarker(
                        seat: seat,
                        map: widget.detail.map,
                        mapSize: mapSize,
                        color: widget.colorForSeat(seat),
                        selected: _selectedSeat?.id == seat.id,
                        visualScale: _floorPlanSeatVisualScale,
                        tapScale: _floorPlanSeatTapScale,
                        onSelected: () => _selectSeat(seat),
                      ),
                    ),
                    if (selectedSeat != null && selectedSeat.hasPoint)
                      _SeatMapCallout(
                        seat: selectedSeat,
                        mapSize: mapSize,
                        color: widget.colorForSeat(selectedSeat),
                      ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

class _SeatModeTabs extends StatelessWidget {
  final bool showReadableGrid;
  final ValueChanged<bool> onChanged;

  const _SeatModeTabs({
    required this.showReadableGrid,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: AppColors.secondaryBackground.resolve(context),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          _SeatModeButton(
            icon: LucideIcons.grid2x2,
            label: '座位格',
            selected: showReadableGrid,
            onTap: () => onChanged(true),
          ),
          _SeatModeButton(
            icon: LucideIcons.map,
            label: '平面图',
            selected: !showReadableGrid,
            onTap: () => onChanged(false),
          ),
        ],
      ),
    );
  }
}

class _SeatModeButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _SeatModeButton({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final foreground = selected
        ? context.primaryColor
        : AppColors.textSecondary.resolve(context);
    return Expanded(
      child: InkWell(
        borderRadius: BorderRadius.circular(6),
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: selected ? context.cardColor : Colors.transparent,
            borderRadius: BorderRadius.circular(6),
            boxShadow: selected
                ? [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 6,
                      offset: const Offset(0, 1),
                    ),
                  ]
                : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 16, color: foreground),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  color: foreground,
                  fontSize: 13,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ReadableSeatGrid extends StatelessWidget {
  final List<LibrarySeatDetail> seats;
  final String? selectedSeatId;
  final Color Function(LibrarySeatDetail seat) colorForSeat;
  final ValueChanged<LibrarySeatDetail> onSelected;

  const _ReadableSeatGrid({
    required this.seats,
    required this.selectedSeatId,
    required this.colorForSeat,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return ModernCard(
      showShadow: false,
      padding: const EdgeInsets.all(12),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final columns = (constraints.maxWidth / 44).floor().clamp(6, 12);
          return GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: seats.length,
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: columns,
              crossAxisSpacing: 4,
              mainAxisSpacing: 4,
              childAspectRatio: 1.45,
            ),
            itemBuilder: (context, index) {
              final seat = seats[index];
              return _SeatGridTile(
                seat: seat,
                selected: selectedSeatId == seat.id,
                color: colorForSeat(seat),
                onTap: () => onSelected(seat),
              );
            },
          );
        },
      ),
    );
  }
}

class _SeatGridTile extends StatelessWidget {
  final LibrarySeatDetail seat;
  final bool selected;
  final Color color;
  final VoidCallback onTap;

  const _SeatGridTile({
    required this.seat,
    required this.selected,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final fill = _tileFill(context);
    final label = _shortSeatLabel(seat.displayName);

    return Tooltip(
      message: '${seat.displayName} · ${seat.statusLabel}',
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 120),
            decoration: BoxDecoration(
              color: fill,
              borderRadius: BorderRadius.circular(4),
              border: Border.all(
                color: selected
                    ? context.primaryColor
                    : color.withValues(alpha: 0.28),
                width: selected ? 1.6 : 1,
              ),
            ),
            alignment: Alignment.center,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2),
                child: Text(
                  label,
                  maxLines: 1,
                  style: TextStyle(
                    color: selected
                        ? context.primaryColor
                        : AppColors.textPrimary.resolve(context),
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    height: 1,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Color _tileFill(BuildContext context) {
    final label = seat.statusLabel;
    if (seat.isFree) return AppColors.okGreen.resolve(context);
    if (label.contains('预约') || label.contains('即将')) {
      return AppColors.sand.resolve(context);
    }
    if (label.contains('占') || label.contains('使用')) {
      return AppColors.summer.resolve(context);
    }
    if (label.contains('暂离') || label.contains('离开')) {
      return AppColors.winter.resolve(context);
    }
    return AppColors.secondaryBackground.resolve(context);
  }

  static String _shortSeatLabel(String value) {
    final match = RegExp(r'(\d{1,4})$').firstMatch(value);
    if (match != null) return match.group(1)!;
    if (value.length <= 4) return value;
    return value.substring(value.length - 4);
  }
}

class _SeatMarker extends StatelessWidget {
  final LibrarySeatDetail seat;
  final LibraryRoomMap map;
  final Size mapSize;
  final Color color;
  final bool selected;
  final double visualScale;
  final double tapScale;
  final VoidCallback onSelected;

  const _SeatMarker({
    required this.seat,
    required this.map,
    required this.mapSize,
    required this.color,
    required this.selected,
    required this.visualScale,
    required this.tapScale,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    final left = ((seat.pointX ?? 0) / 100 * mapSize.width)
        .clamp(0.0, mapSize.width)
        .toDouble();
    final top = ((seat.pointY ?? 0) / 100 * mapSize.height)
        .clamp(0.0, mapSize.height)
        .toDouble();
    final selectedImageUrl = selected ? map.config : null;
    final imageUrl = selectedImageUrl ?? map.imageForSeat(seat);

    if (!seat.hasMapRect || imageUrl == null) {
      return _SeatPoint(
        seat: seat,
        mapSize: mapSize,
        color: color,
        selected: selected,
        onSelected: onSelected,
      );
    }

    final seatWidth = _scaledDimension(
      percent: seat.width,
      fullSize: mapSize.width,
      start: left,
    );
    final seatHeight = _scaledDimension(
      percent: seat.height,
      fullSize: mapSize.height,
      start: top,
    );
    final visualWidth = _clampedVisualSize(
      size: seatWidth,
      scale: visualScale,
      maxSize: mapSize.width,
    );
    final visualHeight = _clampedVisualSize(
      size: seatHeight,
      scale: visualScale,
      maxSize: mapSize.height,
    );
    final tapTargetWidth = _clampedVisualSize(
      size: seatWidth,
      scale: tapScale,
      maxSize: mapSize.width,
    );
    final tapTargetHeight = _clampedVisualSize(
      size: seatHeight,
      scale: tapScale,
      maxSize: mapSize.height,
    );
    final centerX = left + seatWidth / 2;
    final centerY = top + seatHeight / 2;
    final drawLeft = _hitOrigin(
      center: centerX,
      size: visualWidth,
      fullSize: mapSize.width,
    );
    final drawTop = _hitOrigin(
      center: centerY,
      size: visualHeight,
      fullSize: mapSize.height,
    );
    final tapWidth = math.max(
      tapTargetWidth + _floorPlanSeatTapPadding,
      _floorPlanSeatMinTapSize,
    );
    final tapHeight = math.max(
      tapTargetHeight + _floorPlanSeatTapPadding,
      _floorPlanSeatMinTapSize,
    );
    final hitLeft = _hitOrigin(
      center: centerX,
      size: tapWidth,
      fullSize: mapSize.width,
    );
    final hitTop = _hitOrigin(
      center: centerY,
      size: tapHeight,
      fullSize: mapSize.height,
    );
    final visualLeft = drawLeft - hitLeft;
    final visualTop = drawTop - hitTop;
    final labelWidth = selected
        ? math.max(28.0, math.min(40.0, tapWidth * 0.68))
        : math.max(22.0, math.min(32.0, tapWidth * 0.55));
    final labelHeight = selected ? 15.0 : 12.0;

    return Positioned(
      left: hitLeft,
      top: hitTop,
      width: tapWidth,
      height: tapHeight,
      child: Tooltip(
        message: '${seat.displayName} · ${seat.statusLabel}',
        child: MouseRegion(
          cursor: SystemMouseCursors.click,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onSelected,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Positioned(
                  left: visualLeft,
                  top: visualTop,
                  width: visualWidth,
                  height: visualHeight,
                  child: Stack(
                    clipBehavior: Clip.none,
                    fit: StackFit.expand,
                    children: [
                      _SeatSprite(
                        imageUrl: imageUrl,
                        mapSize: mapSize,
                        offset: Offset(left, top),
                        sourceSize: Size(seatWidth, seatHeight),
                        scale: visualScale,
                        fallbackColor: color,
                      ),
                      if (selected)
                        DecoratedBox(
                          decoration: BoxDecoration(
                            border: Border.all(
                              color: AppColors.winter.dark,
                              width: 1.2,
                            ),
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                    ],
                  ),
                ),
                Positioned(
                  left: visualLeft + visualWidth / 2 - labelWidth / 2,
                  top: visualTop + visualHeight / 2 - labelHeight / 2,
                  width: labelWidth,
                  height: labelHeight,
                  child: _SeatNumberLabel(
                    label: _shortSeatLabel(seat.displayName),
                    selected: selected,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  static double _scaledDimension({
    required double? percent,
    required double fullSize,
    required double start,
  }) {
    final value = ((percent ?? 2) / 100 * fullSize).clamp(1.0, fullSize);
    final available = math.max(1.0, fullSize - start);
    return math.min(value.toDouble(), available);
  }

  static double _clampedVisualSize({
    required double size,
    required double scale,
    required double maxSize,
  }) {
    return (size * scale).clamp(1.0, maxSize).toDouble();
  }

  static double _hitOrigin({
    required double center,
    required double size,
    required double fullSize,
  }) {
    if (size >= fullSize) return 0;
    return (center - size / 2).clamp(0.0, fullSize - size).toDouble();
  }

  static String _shortSeatLabel(String value) {
    final match = RegExp(r'(\d{1,4})$').firstMatch(value);
    if (match != null) return match.group(1)!;
    if (value.length <= 4) return value;
    return value.substring(value.length - 4);
  }
}

class _SeatSprite extends StatelessWidget {
  final String imageUrl;
  final Size mapSize;
  final Offset offset;
  final Size sourceSize;
  final double scale;
  final Color fallbackColor;

  const _SeatSprite({
    required this.imageUrl,
    required this.mapSize,
    required this.offset,
    required this.sourceSize,
    required this.scale,
    required this.fallbackColor,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveScale = math.max(1.0, scale);
    return ClipRect(
      child: OverflowBox(
        alignment: Alignment.topLeft,
        minWidth: mapSize.width * effectiveScale,
        maxWidth: mapSize.width * effectiveScale,
        minHeight: mapSize.height * effectiveScale,
        maxHeight: mapSize.height * effectiveScale,
        child: Transform.translate(
          offset: Offset(
            -offset.dx * effectiveScale,
            -offset.dy * effectiveScale,
          ),
          child: Image.network(
            imageUrl,
            width: mapSize.width * effectiveScale,
            height: mapSize.height * effectiveScale,
            fit: BoxFit.fill,
            errorBuilder: (context, error, stackTrace) {
              return Align(
                alignment: Alignment.topLeft,
                child: Container(
                  width: sourceSize.width * effectiveScale,
                  height: sourceSize.height * effectiveScale,
                  decoration: BoxDecoration(
                    color: fallbackColor,
                    shape: BoxShape.circle,
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _SeatNumberLabel extends StatelessWidget {
  final String label;
  final bool selected;

  const _SeatNumberLabel({
    required this.label,
    required this.selected,
  });

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Center(
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 1.5, vertical: 0.5),
            decoration: BoxDecoration(
              color: selected
                  ? AppColors.winter.resolve(context).withValues(alpha: 0.92)
                  : Colors.white.withValues(alpha: 0.58),
              borderRadius: BorderRadius.circular(2),
            ),
            child: Text(
              label,
              maxLines: 1,
              style: TextStyle(
                color: AppColors.textPrimary.resolve(context),
                fontSize: selected ? 8.5 : 7.5,
                fontWeight: selected ? FontWeight.w800 : FontWeight.w700,
                height: 1,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SeatMapCallout extends StatelessWidget {
  final LibrarySeatDetail seat;
  final Size mapSize;
  final Color color;

  const _SeatMapCallout({
    required this.seat,
    required this.mapSize,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final left = ((seat.pointX ?? 0) / 100 * mapSize.width)
        .clamp(0.0, mapSize.width)
        .toDouble();
    final top = ((seat.pointY ?? 0) / 100 * mapSize.height)
        .clamp(0.0, mapSize.height)
        .toDouble();
    const width = 112.0;
    const height = 38.0;
    final calloutLeft = (left - width / 2)
        .clamp(4.0, math.max(4.0, mapSize.width - width - 4))
        .toDouble();
    final calloutTop = (top - height - 10)
        .clamp(4.0, math.max(4.0, mapSize.height - height - 4))
        .toDouble();

    return Positioned(
      left: calloutLeft,
      top: calloutTop,
      width: width,
      child: IgnorePointer(
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: context.cardColor.withValues(alpha: 0.96),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: color.withValues(alpha: 0.32)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.12),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            child: Row(
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
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        seat.displayName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: AppColors.textPrimary.resolve(context),
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          height: 1,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        seat.statusLabel,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: color,
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          height: 1,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SeatPreviewCard extends StatelessWidget {
  final LibrarySeatDetail seat;
  final Color color;
  final VoidCallback onClose;

  const _SeatPreviewCard({
    required this.seat,
    required this.color,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    return ModernCard(
      showShadow: false,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: color.withValues(alpha: 0.28)),
            ),
            child: Center(
              child: Icon(
                LucideIcons.armchair,
                size: 18,
                color: color,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '座位 ${seat.displayName}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: AppColors.textPrimary.resolve(context),
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  seat.areaName?.isNotEmpty == true
                      ? seat.areaName!
                      : seat.statusLabel,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: AppColors.textSecondary.resolve(context),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          StatusChip(text: seat.statusLabel, color: color),
          IconButton(
            onPressed: onClose,
            icon: const Icon(LucideIcons.x, size: 18),
            color: AppColors.textSecondary.resolve(context),
            tooltip: '关闭',
          ),
        ],
      ),
    );
  }
}

class _MapFallback extends StatelessWidget {
  final String message;
  final List<LibrarySeatDetail> seats;
  final Color Function(LibrarySeatDetail seat) colorForSeat;

  const _MapFallback({
    required this.message,
    required this.seats,
    required this.colorForSeat,
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
