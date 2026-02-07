import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../models/favorite.dart';
import '../providers/favorites_provider.dart';

/// 收藏按钮组件
class FavoriteButton extends StatefulWidget {
  final String itemId;
  final FavoriteType type;
  final String title;
  final String? subtitle;
  final Map<String, dynamic>? data;
  final double size;
  final Color? activeColor;
  final Color? inactiveColor;
  final VoidCallback? onToggle;

  const FavoriteButton({
    super.key,
    required this.itemId,
    required this.type,
    required this.title,
    this.subtitle,
    this.data,
    this.size = 24,
    this.activeColor,
    this.inactiveColor,
    this.onToggle,
  });
  
  @override
  State<FavoriteButton> createState() => _FavoriteButtonState();
}

class _FavoriteButtonState extends State<FavoriteButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  
  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
    _scaleAnimation = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.3), weight: 50),
      TweenSequenceItem(tween: Tween(begin: 1.3, end: 1.0), weight: 50),
    ]).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
  }
  
  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
  
  @override
  Widget build(BuildContext context) {
    final favorites = context.watch<FavoritesProvider>();
    final isFavorite = favorites.isFavorite(widget.itemId);
    
    final activeColor = widget.activeColor ?? Colors.red.shade400;
    final inactiveColor = widget.inactiveColor ?? 
        Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.4);
    
    return GestureDetector(
      onTap: () async {
        HapticFeedback.lightImpact();
        
        final item = FavoriteItem(
          id: widget.itemId,
          type: widget.type,
          title: widget.title,
          subtitle: widget.subtitle,
          data: widget.data,
        );
        
        final wasAdded = await favorites.toggleFavorite(item);
        
        if (wasAdded) {
          _controller.forward(from: 0);
        }
        
        widget.onToggle?.call();
      },
      child: ScaleTransition(
        scale: _scaleAnimation,
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 200),
          transitionBuilder: (child, animation) {
            return ScaleTransition(scale: animation, child: child);
          },
          child: Icon(
            isFavorite ? Icons.favorite_rounded : Icons.favorite_border_rounded,
            key: ValueKey(isFavorite),
            size: widget.size,
            color: isFavorite ? activeColor : inactiveColor,
          ),
        ),
      ),
    );
  }
}

/// 收藏星标按钮（用于另一种样式）
class StarFavoriteButton extends StatelessWidget {
  final String itemId;
  final FavoriteType type;
  final String title;
  final String? subtitle;
  final Map<String, dynamic>? data;
  final double size;

  const StarFavoriteButton({
    super.key,
    required this.itemId,
    required this.type,
    required this.title,
    this.subtitle,
    this.data,
    this.size = 24,
  });
  
  @override
  Widget build(BuildContext context) {
    final favorites = context.watch<FavoritesProvider>();
    final isFavorite = favorites.isFavorite(itemId);
    
    return GestureDetector(
      onTap: () async {
        HapticFeedback.lightImpact();
        
        final item = FavoriteItem(
          id: itemId,
          type: type,
          title: title,
          subtitle: subtitle,
          data: data,
        );
        
        await favorites.toggleFavorite(item);
      },
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 200),
        child: Icon(
          isFavorite ? Icons.star_rounded : Icons.star_outline_rounded,
          key: ValueKey(isFavorite),
          size: size,
          color: isFavorite ? Colors.amber : Colors.grey.shade400,
        ),
      ),
    );
  }
}

/// 收藏项卡片
class FavoriteItemCard extends StatelessWidget {
  final FavoriteItem item;
  final VoidCallback? onTap;
  final VoidCallback? onRemove;
  
  const FavoriteItemCard({
    super.key,
    required this.item,
    this.onTap,
    this.onRemove,
  });
  
  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Ink(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: brightness == Brightness.dark 
                  ? const Color(0xFF1E293B)
                  : Colors.white,
              borderRadius: BorderRadius.circular(12),
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
              mainAxisSize: MainAxisSize.max,
              children: [
                // 图标
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: _getTypeColor(item.type).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    item.icon,
                    color: _getTypeColor(item.type),
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
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
                        item.subtitle ?? item.typeName,
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
                // 删除按钮
                if (onRemove != null)
                  SizedBox(
                    width: 32,
                    height: 32,
                    child: IconButton(
                      onPressed: onRemove,
                      icon: Icon(
                        Icons.close_rounded,
                        size: 18,
                        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.4),
                      ),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
  
  Color _getTypeColor(FavoriteType type) {
    switch (type) {
      case FavoriteType.busRoute:
      case FavoriteType.busStop:
        return const Color(0xFF8B5CF6);
      case FavoriteType.canteen:
      case FavoriteType.canteenWindow:
        return const Color(0xFFFF6B35);
      case FavoriteType.libraryRoom:
      case FavoriteType.librarySeat:
        return const Color(0xFF10B981);
      case FavoriteType.custom:
        return const Color(0xFF3B82F6);
    }
  }
}

/// 空收藏提示
class EmptyFavoritesHint extends StatelessWidget {
  final String? message;
  
  const EmptyFavoritesHint({super.key, this.message});
  
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.star_outline_rounded,
            size: 48,
            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.2),
          ),
          const SizedBox(height: 12),
          Text(
            message ?? '暂无收藏',
            style: TextStyle(
              fontSize: 14,
              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.4),
            ),
          ),
        ],
      ),
    );
  }
}
