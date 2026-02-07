import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:provider/provider.dart';

import '../../config/theme.dart';
import '../../models/library.dart';
import '../../models/favorite.dart';
import '../../services/library_service.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/header.dart';
import '../../widgets/cards.dart';
import '../../widgets/indicators.dart';
import '../../widgets/favorite_button.dart';
import '../../widgets/data_list_screen_mixin.dart';
import '../../design/design_constants.dart';
import 'library_webview_screen.dart';

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

class _StudyScreenState extends State<StudyScreen>
    with DataListScreenMixin<LibrarySeat, StudyScreen> {
  final LibraryService _libraryService = LibraryService();

  @override
  void initState() {
    super.initState();
    // Delay initialization to allow auth check
    WidgetsBinding.instance.addPostFrameCallback((_) {
      initDataListScreen();
    });
  }

  @override
  void dispose() {
    disposeDataListScreen();
    super.dispose();
  }

  // ============ Mixin Implementation ============

  @override
  String? getInitialHighlightId() => widget.highlightRoomId ?? widget.highlightSeatId;

  @override
  Future<List<LibrarySeat>> fetchData() async {
    final auth = context.read<AuthProvider>();

    // Check authentication
    if (!auth.isAuthenticated) {
      throw Exception('need_login');
    }

    // Set auth cookie
    if (auth.authCookie != null) {
      _libraryService.setAuthCookie(auth.authCookie!);
    }

    return await _libraryService.fetchSeats();
  }

  @override
  String getItemId(LibrarySeat item) => item.id;

  @override
  Widget buildItem(BuildContext context, LibrarySeat item, bool isHighlighted) {
    return _SeatCard(
      seat: item,
      isHighlighted: isHighlighted,
    );
  }

  @override
  double get headerHeight => 180.0;

  @override
  double get cardHeight => 140.0;

  // ============ Custom UI Overrides ============

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();

    // Show login prompt if not authenticated
    if (!auth.isAuthenticated) {
      return Scaffold(
        backgroundColor: context.backgroundColor,
        body: SafeArea(
          child: CustomScrollView(
            slivers: [
              const SliverToBoxAdapter(
                child: ZJUHeader(
                  title: '自习',
                  subtitle: '图书馆座位',
                ),
              ),
              SliverFillRemaining(
                child: _buildLoginPrompt(),
              ),
            ],
          ),
        ),
      );
    }

    // Group seats by building for display
    final groupedSeats = _libraryService.groupByBuilding(items);

    return Scaffold(
      backgroundColor: context.backgroundColor,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: loadData,
          color: context.primaryColor,
          child: CustomScrollView(
            controller: scrollController,
            slivers: [
              // Header
              const SliverToBoxAdapter(
                child: ZJUHeader(
                  title: '自习',
                  subtitle: '图书馆座位',
                ),
              ),

              // Content
              if (isLoading)
                const SliverFillRemaining(
                  child: LoadingIndicator(message: '加载座位数据...'),
                )
              else if (error != null && error != 'need_login')
                SliverFillRemaining(
                  child: _buildErrorWithWebViewOption(),
                )
              else if (items.isEmpty)
                SliverFillRemaining(
                  child: _buildEmptyWithWebViewOption(),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.all(20),
                  sliver: SliverList(
                    delegate: SliverChildListDelegate([
                      // Summary Card
                      _buildSummaryCard(),
                      const SizedBox(height: 20),

                      // Grouped by Building
                      ...groupedSeats.entries.map((entry) {
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            SectionHeader(title: entry.key),
                            const SizedBox(height: 12),
                            ...entry.value.map((seat) {
                              final isHighlighted = highlightedId == seat.id;
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 10),
                                child: _SeatCard(
                                  seat: seat,
                                  isHighlighted: isHighlighted,
                                ),
                              );
                            }),
                            const SizedBox(height: 16),
                          ],
                        );
                      }),

                      const SizedBox(height: 80),
                    ]),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLoginPrompt() {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              color: context.primaryColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(24),
            ),
            child: Icon(
              LucideIcons.lock,
              size: 44,
              color: context.primaryColor,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            '需要登录',
            style: context.textTheme.headlineMedium,
          ),
          const SizedBox(height: 12),
          Text(
            '图书馆座位数据需要统一身份认证\n请先登录后查看',
            textAlign: TextAlign.center,
            style: context.textTheme.bodyMedium?.copyWith(
              color: context.secondaryColor,
            ),
          ),
          const SizedBox(height: 32),
          ElevatedButton.icon(
            onPressed: () => context.go('/login'),
            icon: const Icon(LucideIcons.logIn, size: 18),
            label: const Text('登录'),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(
                horizontal: 32,
                vertical: 14,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorWithWebViewOption() {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              color: Colors.orange.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(24),
            ),
            child: const Icon(
              LucideIcons.alertCircle,
              size: 44,
              color: Colors.orange,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            '数据获取失败',
            style: context.textTheme.headlineMedium,
          ),
          const SizedBox(height: 12),
          Text(
            '无法通过 API 获取座位数据\n您可以使用网页版查看',
            textAlign: TextAlign.center,
            style: context.textTheme.bodyMedium?.copyWith(
              color: context.secondaryColor,
            ),
          ),
          const SizedBox(height: 32),
          ElevatedButton.icon(
            onPressed: _openWebView,
            icon: const Icon(LucideIcons.globe, size: 18),
            label: const Text('打开网页版'),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(
                horizontal: 32,
                vertical: 14,
              ),
            ),
          ),
          const SizedBox(height: 12),
          TextButton.icon(
            onPressed: loadData,
            icon: const Icon(LucideIcons.refreshCw, size: 16),
            label: const Text('重试'),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyWithWebViewOption() {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              color: context.primaryColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(24),
            ),
            child: Icon(
              LucideIcons.bookOpen,
              size: 44,
              color: context.primaryColor,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            '暂无座位数据',
            style: context.textTheme.headlineMedium,
          ),
          const SizedBox(height: 12),
          Text(
            '您可以使用网页版查看实时座位信息',
            textAlign: TextAlign.center,
            style: context.textTheme.bodyMedium?.copyWith(
              color: context.secondaryColor,
            ),
          ),
          const SizedBox(height: 32),
          ElevatedButton.icon(
            onPressed: _openWebView,
            icon: const Icon(LucideIcons.globe, size: 18),
            label: const Text('打开网页版'),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(
                horizontal: 32,
                vertical: 14,
              ),
            ),
          ),
          const SizedBox(height: 12),
          TextButton.icon(
            onPressed: loadData,
            icon: const Icon(LucideIcons.refreshCw, size: 16),
            label: const Text('重试'),
          ),
        ],
      ),
    );
  }

  void _openWebView() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => const LibraryWebViewScreen(),
      ),
    );
  }

  Widget _buildSummaryCard() {
    int totalSeats = 0;
    int availableSeats = 0;

    for (final seat in items) {
      totalSeats += seat.totalSeats;
      availableSeats += seat.availableSeats;
    }

    final occupancyRate = totalSeats > 0
        ? (totalSeats - availableSeats) / totalSeats
        : 0.0;

    return ModernCard(
      gradient: AppTheme.primaryGradient,
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  LucideIcons.bookOpen,
                  color: Colors.white,
                  size: 22,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '座位概览',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '共 ${items.length} 个自习区域',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.white.withValues(alpha: 0.8),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              _StatItem(
                value: '$availableSeats',
                label: '空闲座位',
                color: Colors.white,
              ),
              Container(
                height: 36,
                width: 1,
                color: Colors.white.withValues(alpha: 0.2),
                margin: const EdgeInsets.symmetric(horizontal: 24),
              ),
              _StatItem(
                value: '$totalSeats',
                label: '总座位',
                color: Colors.white,
              ),
              Container(
                height: 36,
                width: 1,
                color: Colors.white.withValues(alpha: 0.2),
                margin: const EdgeInsets.symmetric(horizontal: 24),
              ),
              _StatItem(
                value: '${(occupancyRate * 100).round()}%',
                label: '使用率',
                color: Colors.white,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatItem extends StatelessWidget {
  final String value;
  final String label;
  final Color color;

  const _StatItem({
    required this.value,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w700,
            color: color,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: color.withValues(alpha: 0.8),
          ),
        ),
      ],
    );
  }
}

class _SeatCard extends StatelessWidget {
  final LibrarySeat seat;
  final bool isHighlighted;

  const _SeatCard({
    required this.seat,
    this.isHighlighted = false,
  });

  @override
  Widget build(BuildContext context) {
    final occupancy = seat.totalSeats > 0
        ? (seat.totalSeats - seat.availableSeats) / seat.totalSeats
        : 0.0;

    return AnimatedContainer(
      duration: DesignConstants.highlightAnimationDuration,
      decoration: BoxDecoration(
        borderRadius: DesignConstants.cardRadius(),
        border: isHighlighted
            ? Border.all(
                color: context.primaryColor,
                width: DesignConstants.highlightBorderWidth,
              )
            : null,
      ),
      child: ModernCard(
        child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        if (seat.floor != null && seat.floor!.isNotEmpty) ...[
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: context.primaryColor.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              seat.floor!,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: context.primaryColor,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                        ],
                        Expanded(
                          child: Text(
                            seat.roomName,
                            style: context.textTheme.bodyLarge?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        // 收藏按钮
                        FavoriteButton(
                          itemId: 'library_${seat.id}',
                          type: FavoriteType.libraryRoom,
                          title: seat.roomName,
                          subtitle: '${seat.buildingName} ${seat.floor ?? ""}',
                          data: {
                            'building': seat.buildingName,
                            'floor': seat.floor,
                            'totalSeats': seat.totalSeats,
                          },
                          size: 20,
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Text(
                          '空闲 ',
                          style: context.textTheme.bodySmall,
                        ),
                        Text(
                          '${seat.availableSeats}',
                          style: context.textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: _getOccupancyColor(occupancy),
                          ),
                        ),
                        Text(
                          ' / ${seat.totalSeats}',
                          style: context.textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              CrowdLevel(
                level: occupancy,
                compact: true,
              ),
            ],
          ),
          const SizedBox(height: 12),
          ProgressIndicatorBar(
            progress: occupancy,
            showPercentage: false,
            height: 5,
          ),
        ],
      ),
      ),
    );
  }

  Color _getOccupancyColor(double level) {
    if (level < 0.3) return AppTheme.success;
    if (level < 0.6) return AppTheme.warning;
    if (level < 0.85) return AppTheme.accentOrange;
    return AppTheme.error;
  }
}
