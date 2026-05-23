import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

/// Mixin that provides common functionality for data list screens
///
/// Handles:
/// - Loading/error state management
/// - Data fetching with refresh support
/// - Scroll-to-highlight functionality
/// - Standard UI patterns
///
/// Usage:
/// ```dart
/// class MyScreen extends StatefulWidget {
///   final String? highlightId;
///   const MyScreen({super.key, this.highlightId});
/// }
///
/// class _MyScreenState extends State<MyScreen>
///     with DataListScreenMixin<MyDataModel, MyScreen> {
///
///   @override
///   Future<List<MyDataModel>> fetchData() async {
///     return await myService.fetchData();
///   }
///
///   @override
///   String getItemId(MyDataModel item) => item.id;
///
///   @override
///   Widget buildItem(BuildContext context, MyDataModel item, bool isHighlighted) {
///     return MyCard(item: item, isHighlighted: isHighlighted);
///   }
/// }
/// ```
mixin DataListScreenMixin<T, W extends StatefulWidget> on State<W> {
  // ============ State Management ============

  /// Loading state
  bool get isLoading => _isLoading;
  bool _isLoading = true;

  /// Error message
  String? get error => _error;
  String? _error;

  /// Data items
  List<T> get items => _items;
  List<T> _items = [];

  /// Highlighted item ID
  String? get highlightedId => _highlightedId;
  String? _highlightedId;

  /// Scroll controller
  final ScrollController scrollController = ScrollController();

  // ============ Configuration ============

  /// Get the initial highlight ID from widget (override in subclass)
  String? getInitialHighlightId();

  /// Fetch data from service (must be implemented by subclass)
  Future<List<T>> fetchData();

  /// Get unique ID from item (must be implemented by subclass)
  String getItemId(T item);

  /// Build item widget (must be implemented by subclass)
  Widget buildItem(BuildContext context, T item, bool isHighlighted);

  /// Optional: Filter items before display (default: no filtering)
  List<T> filterItems(List<T> items) => items;

  /// Optional: Header height for scroll calculation (default: 100)
  double get headerHeight => 100.0;

  /// Optional: Card height for scroll calculation (default: 160)
  double get cardHeight => 160.0;

  /// Optional: Additional offset for scroll calculation (default: 70)
  double get additionalScrollOffset => 70.0;

  /// Optional: Highlight duration in seconds (default: 3)
  int get highlightDurationSeconds => 3;

  // ============ Lifecycle ============

  /// Initialize mixin (call this in initState)
  void initDataListScreen() {
    _highlightedId = getInitialHighlightId();
    loadData();
  }

  /// Dispose mixin (call this in dispose)
  void disposeDataListScreen() {
    scrollController.dispose();
  }

  // ============ Data Loading ============

  /// Load data from service
  Future<void> loadData() async {
    if (!mounted) return;

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final data = await fetchData();
      if (!mounted) return;

      setState(() {
        _items = data;
        _isLoading = false;
      });

      // Scroll to highlighted item after data loads
      if (_highlightedId != null) {
        scrollToHighlightedItem();
      }
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _isLoading = false;
        _error = e.toString();
      });
    }
  }

  // ============ Scroll to Highlight ============

  /// Scroll to highlighted item
  void scrollToHighlightedItem() {
    if (_highlightedId == null) return;

    // Execute in next frame to ensure UI is rendered
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;

      // Get filtered items to find correct index
      final filteredItems = filterItems(_items);

      // Find index of highlighted item
      final index = filteredItems.indexWhere(
        (item) => getItemId(item) == _highlightedId,
      );

      if (index != -1 && scrollController.hasClients) {
        // Calculate scroll position
        final targetOffset =
            headerHeight + additionalScrollOffset + (index * cardHeight) - 20;

        // Smooth scroll to target position
        scrollController.animateTo(
          targetOffset.clamp(0.0, scrollController.position.maxScrollExtent),
          duration: const Duration(milliseconds: 500),
          curve: Curves.easeOutCubic,
        );

        // Clear highlight after duration
        Future.delayed(Duration(seconds: highlightDurationSeconds), () {
          if (mounted) {
            setState(() {
              _highlightedId = null;
            });
          }
        });
      }
    });
  }

  // ============ UI Builders ============

  /// Build the complete screen body
  Widget buildScreenBody({
    required Widget header,
    Widget? additionalContent,
    EdgeInsets? listPadding,
  }) {
    final filteredItems = filterItems(_items);

    return RefreshIndicator(
      onRefresh: loadData,
      color: Theme.of(context).colorScheme.primary,
      child: CustomScrollView(
        controller: scrollController,
        slivers: [
          // Header
          SliverToBoxAdapter(child: header),

          // Additional content (e.g., filters, stats)
          if (additionalContent != null)
            SliverToBoxAdapter(child: additionalContent),

          // Content states
          if (_isLoading)
            buildLoadingState()
          else if (_error != null)
            buildErrorState()
          else if (filteredItems.isEmpty)
            buildEmptyState()
          else
            buildListContent(
              filteredItems,
              padding:
                  listPadding ?? const EdgeInsets.symmetric(horizontal: 20),
            ),

          // Bottom padding
          const SliverToBoxAdapter(
            child: SizedBox(height: 100),
          ),
        ],
      ),
    );
  }

  /// Build loading state (can be overridden)
  Widget buildLoadingState() {
    return SliverFillRemaining(
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CupertinoActivityIndicator(
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(height: 16),
            Text(
              '加载中...',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).textTheme.bodySmall?.color,
                  ),
            ),
          ],
        ),
      ),
    );
  }

  /// Build error state (can be overridden)
  Widget buildErrorState() {
    return SliverFillRemaining(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                CupertinoIcons.exclamationmark_circle,
                size: 64,
                color: Colors.orange,
              ),
              const SizedBox(height: 16),
              Text(
                '数据加载失败',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              Text(
                _error ?? '未知错误',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).textTheme.bodySmall?.color,
                    ),
              ),
              const SizedBox(height: 24),
              CupertinoButton.filled(
                onPressed: loadData,
                padding: const EdgeInsets.symmetric(
                  horizontal: 22,
                  vertical: 10,
                ),
                child: const Text('重试'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Build empty state (can be overridden)
  Widget buildEmptyState() {
    return SliverFillRemaining(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                CupertinoIcons.tray,
                size: 64,
                color: Theme.of(context).textTheme.bodySmall?.color,
              ),
              const SizedBox(height: 16),
              Text(
                '暂无数据',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              Text(
                '请稍后重试',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).textTheme.bodySmall?.color,
                    ),
              ),
              const SizedBox(height: 24),
              CupertinoButton.filled(
                onPressed: loadData,
                padding: const EdgeInsets.symmetric(
                  horizontal: 22,
                  vertical: 10,
                ),
                child: const Text('重试'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Build list content
  Widget buildListContent(List<T> filteredItems,
      {required EdgeInsets padding}) {
    return SliverPadding(
      padding: padding,
      sliver: SliverList(
        delegate: SliverChildBuilderDelegate(
          (context, index) {
            final item = filteredItems[index];
            final isHighlighted = _highlightedId == getItemId(item);

            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: buildItem(context, item, isHighlighted),
            );
          },
          childCount: filteredItems.length,
        ),
      ),
    );
  }
}
