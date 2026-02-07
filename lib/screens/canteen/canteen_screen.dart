import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:provider/provider.dart';

import '../../config/theme.dart';
import '../../models/canteen.dart';
import '../../models/favorite.dart';
import '../../services/canteen_service.dart';
import '../../widgets/header.dart';
import '../../widgets/cards.dart';
import '../../widgets/indicators.dart';
import '../../widgets/favorite_button.dart';
import '../../widgets/data_list_screen_mixin.dart';
import '../../providers/favorites_provider.dart';
import '../../design/design_constants.dart';

class CanteenScreen extends StatefulWidget {
  final String? highlightCanteenId;
  final String? highlightWindowId;

  const CanteenScreen({
    super.key,
    this.highlightCanteenId,
    this.highlightWindowId,
  });

  @override
  State<CanteenScreen> createState() => _CanteenScreenState();
}

class _CanteenScreenState extends State<CanteenScreen>
    with DataListScreenMixin<CanteenData, CanteenScreen> {
  final CanteenService _canteenService = CanteenService();
  String _selectedCampus = 'all';
  DateTime _lastUpdated = DateTime.now();

  final List<Map<String, String>> _campusOptions = [
    {'id': 'all', 'name': '全部'},
    {'id': 'zijingang', 'name': '紫金港'},
    {'id': 'yuquan', 'name': '玉泉'},
    {'id': 'xixi', 'name': '西溪'},
    {'id': 'huajiachi', 'name': '华家池'},
  ];

  @override
  void initState() {
    super.initState();
    initDataListScreen();
  }

  @override
  void dispose() {
    disposeDataListScreen();
    super.dispose();
  }

  // ============ Mixin Implementation ============

  @override
  String? getInitialHighlightId() => widget.highlightCanteenId;

  @override
  Future<List<CanteenData>> fetchData() async {
    final response = await _canteenService.fetchCanteenData();
    _lastUpdated = response.fetchedAt;
    return response.canteens;
  }

  @override
  String getItemId(CanteenData item) => item.id;

  @override
  Widget buildItem(BuildContext context, CanteenData item, bool isHighlighted) {
    return _CanteenCard(
      canteen: item,
      isHighlighted: isHighlighted,
    );
  }

  @override
  List<CanteenData> filterItems(List<CanteenData> items) {
    // Filter by campus
    List<CanteenData> filtered;
    if (_selectedCampus == 'all') {
      filtered = List.from(items);
    } else {
      filtered = _canteenService.filterByCampus(items, _selectedCampus);
    }

    // Sort favorites to top
    final favoritesProvider = context.read<FavoritesProvider>();
    final favoriteIds = favoritesProvider.favorites
        .where((f) => f.type == FavoriteType.canteen)
        .map((f) => f.id)
        .toSet();

    filtered.sort((a, b) {
      final aFav = favoriteIds.contains('canteen_${a.id}');
      final bFav = favoriteIds.contains('canteen_${b.id}');
      if (aFav && !bFav) return -1;
      if (!aFav && bFav) return 1;
      return 0;
    });

    return filtered;
  }

  // ============ Custom UI ============

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.backgroundColor,
      body: SafeArea(
        child: buildScreenBody(
          header: const ZJUHeader(
            title: '食堂',
            subtitle: '实时拥挤度',
          ),
          additionalContent: Column(
            children: [
              _buildCampusFilter(),
              _buildUpdateInfo(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCampusFilter() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Row(
          children: _campusOptions.map((campus) {
            final isSelected = campus['id'] == _selectedCampus;
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: FilterChip(
                label: Text(campus['name']!),
                selected: isSelected,
                onSelected: (_) => setState(() => _selectedCampus = campus['id']!),
                selectedColor: context.primaryColor.withValues(alpha: 0.15),
                checkmarkColor: context.primaryColor,
                labelStyle: TextStyle(
                  fontSize: 13,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                  color: isSelected ? context.primaryColor : context.secondaryColor,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                side: BorderSide(
                  color: isSelected ? context.primaryColor : context.dividerColor,
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildUpdateInfo() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Icon(
                LucideIcons.clock,
                size: 14,
                color: context.secondaryColor,
              ),
              const SizedBox(width: 6),
              Text(
                '更新于 ${_formatTime(_lastUpdated)}',
                style: context.textTheme.bodySmall,
              ),
            ],
          ),
          TextButton.icon(
            onPressed: loadData,
            icon: const Icon(LucideIcons.refreshCw, size: 14),
            label: const Text('刷新'),
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
          ),
        ],
      ),
    );
  }

  String _formatTime(DateTime time) {
    final now = DateTime.now();
    final diff = now.difference(time);
    if (diff.inMinutes < 1) return '刚刚';
    if (diff.inMinutes < 60) return '${diff.inMinutes}分钟前';
    return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
  }
}

class _CanteenCard extends StatelessWidget {
  final CanteenData canteen;
  final bool isHighlighted;

  const _CanteenCard({
    required this.canteen,
    this.isHighlighted = false,
  });

  @override
  Widget build(BuildContext context) {
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
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: _getStatusColor(canteen.crowdLevel).withValues(alpha: 0.1),
                  borderRadius: DesignConstants.cardRadius(),
                ),
                child: Icon(
                  LucideIcons.utensils,
                  size: 20,
                  color: _getStatusColor(canteen.crowdLevel),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      canteen.name,
                      style: context.textTheme.bodyLarge?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        if (canteen.currentCount != null) ...[
                          Text(
                            '${canteen.currentCount}',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: _getStatusColor(canteen.crowdLevel),
                            ),
                          ),
                          Text(
                            ' / ${canteen.capacity} 人',
                            style: context.textTheme.bodySmall,
                          ),
                        ] else
                          Text(
                            '容量 ${canteen.capacity} 人',
                            style: context.textTheme.bodySmall,
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              // 收藏按钮
              FavoriteButton(
                itemId: 'canteen_${canteen.id}',
                type: FavoriteType.canteen,
                title: canteen.name,
                subtitle: '容量 ${canteen.capacity} 人',
                data: {
                  'campus': canteen.campus,
                  'capacity': canteen.capacity,
                },
                size: 22,
              ),
              const SizedBox(width: 8),
              CrowdLevel(
                level: canteen.crowdLevel,
                compact: true,
              ),
            ],
          ),
          const SizedBox(height: 14),
          ProgressIndicatorBar(
            progress: canteen.crowdLevel,
            showPercentage: false,
            height: 6,
          ),
        ],
      ),
      ),
    );
  }

  Color _getStatusColor(double level) {
    if (level < 0.3) return AppTheme.success;
    if (level < 0.6) return AppTheme.warning;
    if (level < 0.85) return AppTheme.accentOrange;
    return AppTheme.error;
  }
}
