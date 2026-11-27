import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../../core/providers/app_providers.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/state_views.dart';
import '../../../core/widgets/ui.dart';
import '../models/news_models.dart';
import '../widgets/watch_badges.dart';

class WatchScreen extends ConsumerStatefulWidget {
  const WatchScreen({super.key});

  @override
  ConsumerState<WatchScreen> createState() => _WatchScreenState();
}

class _WatchScreenState extends ConsumerState<WatchScreen> {
  static const String _readNewsStorageKey = 'read_news_ids_v1';
  static const int _pageSize = 15;

  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  Timer? _searchDebounce;
  WatchCategory? _selectedCategory;
  bool _onlyBookmarks = false;
  bool _onlyImportant = false;
  List<TechNewsSummary> _items = [];
  Set<int> _readNewsIds = {};
  int _currentPage = 0;
  bool _hasMore = true;
  bool _isLoadingMore = false;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _loadReadNewsIds();
    _loadNews();
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollController.hasClients ||
        _isLoading ||
        _isLoadingMore ||
        !_hasMore ||
        _onlyBookmarks) {
      return;
    }
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 250) {
      _loadMore();
    }
  }

  Future<void> _loadReadNewsIds() async {
    try {
      final raw =
          await ref.read(localDatabaseProvider).getMetadata(_readNewsStorageKey);
      if (raw == null || raw.isEmpty) return;
      final decoded = jsonDecode(raw) as List<dynamic>;
      if (!mounted) return;
      setState(() {
        _readNewsIds = decoded.map((e) => (e as num).toInt()).toSet();
      });
    } catch (_) {}
  }

  Future<void> _markAsRead(int newsId) async {
    if (_readNewsIds.contains(newsId)) return;
    final updated = {..._readNewsIds, newsId};
    if (mounted) {
      setState(() => _readNewsIds = updated);
    }
    try {
      final capped = updated.toList();
      final toSave =
          capped.length > 500 ? capped.sublist(capped.length - 500) : capped;
      await ref
          .read(localDatabaseProvider)
          .setMetadata(_readNewsStorageKey, jsonEncode(toSave));
    } catch (_) {}
  }

  Future<void> _loadNews() async {
    final localDb = ref.read(localDatabaseProvider);
    final isDefaultFeed = !_onlyBookmarks &&
        !_onlyImportant &&
        _selectedCategory == null &&
        _searchController.text.trim().isEmpty;

    if (isDefaultFeed && _items.isEmpty) {
      try {
        final cached = await localDb.getCachedNews();
        if (cached.isNotEmpty && mounted) {
          setState(() {
            _items = cached;
            _isLoading = false;
            _error = null;
          });
        }
      } catch (_) {}
    }

    if (_items.isEmpty) {
      setState(() {
        _isLoading = true;
        _error = null;
      });
    }

    try {
      final newsService = ref.read(newsServiceProvider);
      if (_onlyBookmarks) {
        final list = await newsService.getBookmarks(size: 30);
        if (!mounted) return;
        setState(() {
          _items = list;
          _currentPage = 0;
          _hasMore = false;
          _isLoading = false;
          _error = null;
        });
        return;
      }

      final page = await newsService.getNewsPage(
        category: _selectedCategory,
        keyword: _searchController.text.trim(),
        importantOnly: _onlyImportant,
        page: 0,
        size: _pageSize,
      );
      if (isDefaultFeed) {
        await localDb.cacheNews(page.items);
      }
      if (!mounted) return;
      setState(() {
        _items = page.items;
        _currentPage = 0;
        _hasMore = page.hasMore;
        _isLoading = false;
        _error = null;
      });
    } catch (e) {
      final cached = await localDb.getCachedNews();
      if (cached.isNotEmpty) {
        final query = _searchController.text.trim().toLowerCase();
        final filtered = cached.where((item) {
          if (_onlyBookmarks && !item.bookmarked) return false;
          if (_onlyImportant &&
              item.importance != WatchImportance.HIGH &&
              item.importance != WatchImportance.CRITICAL) {
            return false;
          }
          if (!_onlyBookmarks &&
              _selectedCategory != null &&
              item.category != _selectedCategory) {
            return false;
          }
          if (query.isNotEmpty) {
            final hay =
                '${item.title} ${item.summary} ${item.targetTechnology}'
                    .toLowerCase();
            if (!hay.contains(query)) return false;
          }
          return true;
        }).toList();

        if (!mounted) return;
        setState(() {
          _items = filtered;
          _hasMore = false;
          _isLoading = false;
          _error = null;
        });
        return;
      }
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _loadMore() async {
    if (_isLoadingMore || !_hasMore || _onlyBookmarks) return;
    setState(() => _isLoadingMore = true);
    try {
      final nextPage = _currentPage + 1;
      final page = await ref.read(newsServiceProvider).getNewsPage(
            category: _selectedCategory,
            keyword: _searchController.text.trim(),
            importantOnly: _onlyImportant,
            page: nextPage,
            size: _pageSize,
          );
      if (!mounted) return;
      final existingIds = _items.map((e) => e.id).toSet();
      final newItems =
          page.items.where((e) => !existingIds.contains(e.id)).toList();
      setState(() {
        _items = [..._items, ...newItems];
        _currentPage = nextPage;
        _hasMore = page.hasMore;
        _isLoadingMore = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _isLoadingMore = false);
    }
  }

  Future<void> _toggleBookmark(int index) async {
    final item = _items[index];
    bool bookmarked;
    try {
      bookmarked =
          await ref.read(newsServiceProvider).toggleBookmark(item.id);
    } catch (_) {
      bookmarked = !item.bookmarked;
      await ref.read(offlineSyncProvider.notifier).queueBookmark(
            newsId: item.id,
            bookmarked: bookmarked,
          );
    }
    if (!mounted) return;
    if (_onlyBookmarks && !bookmarked) {
      setState(() => _items.removeAt(index));
    } else {
      setState(() {
        _items[index] = item.copyWith(bookmarked: bookmarked);
      });
    }
  }

  void _resetFilters() {
    _searchController.clear();
    setState(() {
      _onlyBookmarks = false;
      _onlyImportant = false;
      _selectedCategory = null;
    });
    _loadNews();
  }

  @override
  Widget build(BuildContext context) {
    final hasActiveFilters = _onlyBookmarks ||
        _onlyImportant ||
        _selectedCategory != null ||
        _searchController.text.trim().isNotEmpty;

    return Scaffold(
      body: Column(
        children: [
          const ScreenHeader(
            title: 'Veille',
            subtitle: 'Actualités Backend, DevOps & IA',
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.md,
              AppSpacing.xs,
              AppSpacing.md,
              0,
            ),
            child: TextField(
              controller: _searchController,
              textInputAction: TextInputAction.search,
              onSubmitted: (_) => _loadNews(),
              decoration: InputDecoration(
                hintText: 'Rechercher une technologie, un mot-clé...',
                prefixIcon: const Icon(LucideIcons.search, size: 18),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        constraints: const BoxConstraints(
                          minWidth: 44,
                          minHeight: 44,
                        ),
                        tooltip: 'Effacer la recherche',
                        icon: const Icon(LucideIcons.x, size: 18),
                        onPressed: () {
                          _searchDebounce?.cancel();
                          _searchController.clear();
                          _loadNews();
                        },
                      )
                    : null,
              ),
              onChanged: (_) {
                setState(() {});
                _searchDebounce?.cancel();
                _searchDebounce = Timer(
                  const Duration(milliseconds: 400),
                  _loadNews,
                );
              },
            ),
          ),
          _buildFilters(),
          Expanded(
            child: _isLoading
                ? const AppLoadingView(message: 'Chargement de la veille...')
                : _error != null
                    ? AppErrorView(message: _error!, onRetry: _loadNews)
                    : _items.isEmpty
                        ? AppEmptyView(
                            title: _onlyBookmarks
                                ? 'Aucun favori enregistré'
                                : 'Aucune actualité trouvée',
                            subtitle: _onlyBookmarks
                                ? 'Ajoutez des articles en favoris pour les retrouver ici.'
                                : 'Essayez un autre mot-clé ou une autre catégorie.',
                            icon: Icons.newspaper_outlined,
                            onAction: hasActiveFilters ? _resetFilters : null,
                            actionLabel: hasActiveFilters
                                ? 'Réinitialiser les filtres'
                                : null,
                          )
                        : RefreshIndicator(
                            onRefresh: _loadNews,
                            child: ListView.separated(
                              controller: _scrollController,
                              padding: const EdgeInsets.fromLTRB(
                                AppSpacing.md,
                                AppSpacing.xs,
                                AppSpacing.md,
                                AppSpacing.xl,
                              ),
                              itemCount: _items.length + (_isLoadingMore ? 1 : 0),
                              separatorBuilder: (_, _) =>
                                  const SizedBox(height: AppSpacing.md),
                              itemBuilder: (context, index) {
                                if (index >= _items.length) {
                                  return const Padding(
                                    padding: EdgeInsets.symmetric(
                                      vertical: AppSpacing.md,
                                    ),
                                    child: Center(
                                      child: SizedBox(
                                        width: 24,
                                        height: 24,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2.5,
                                        ),
                                      ),
                                    ),
                                  );
                                }
                                final item = _items[index];
                                final isRead = _readNewsIds.contains(item.id);
                                return _NewsCard(
                                  item: item,
                                  isRead: isRead,
                                  onBookmarkTap: () => _toggleBookmark(index),
                                  onTap: () async {
                                    await _markAsRead(item.id);
                                    if (!context.mounted) return;
                                    await context.push('/watch/${item.id}');
                                    await _loadReadNewsIds();
                                    _loadNews();
                                  },
                                );
                              },
                            ),
                          ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilters() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.sm,
        AppSpacing.md,
        AppSpacing.sm,
      ),
      child: Row(
        children: [
          FilterChip(
            avatar: Icon(
              LucideIcons.bookmark,
              size: 15,
              color: _onlyBookmarks ? AppColors.brand : null,
            ),
            label: const Text('Favoris'),
            selected: _onlyBookmarks,
            onSelected: (val) {
              setState(() {
                _onlyBookmarks = val;
                if (val) _onlyImportant = false;
              });
              _loadNews();
            },
          ),
          const SizedBox(width: AppSpacing.sm),
          FilterChip(
            avatar: Icon(
              LucideIcons.zap,
              size: 15,
              color: _onlyImportant ? AppColors.warning : null,
            ),
            label: const Text('Importantes'),
            selected: !_onlyBookmarks && _onlyImportant,
            onSelected: (val) {
              setState(() {
                _onlyBookmarks = false;
                _onlyImportant = val;
              });
              _loadNews();
            },
          ),
          const SizedBox(width: AppSpacing.sm),
          FilterChip(
            label: const Text('Toutes'),
            selected:
                !_onlyBookmarks && !_onlyImportant && _selectedCategory == null,
            onSelected: (_) {
              setState(() {
                _onlyBookmarks = false;
                _onlyImportant = false;
                _selectedCategory = null;
              });
              _loadNews();
            },
          ),
          const SizedBox(width: AppSpacing.sm),
          for (final cat in WatchCategory.values) ...[
            FilterChip(
              label: Text(watchCategoryLabel(cat)),
              selected: !_onlyBookmarks && _selectedCategory == cat,
              onSelected: (_) {
                setState(() {
                  _onlyBookmarks = false;
                  _selectedCategory = _selectedCategory == cat ? null : cat;
                });
                _loadNews();
              },
            ),
            const SizedBox(width: AppSpacing.sm),
          ],
        ],
      ),
    );
  }
}

class _NewsCard extends StatelessWidget {
  final TechNewsSummary item;
  final bool isRead;
  final VoidCallback onTap;
  final VoidCallback onBookmarkTap;

  const _NewsCard({
    required this.item,
    required this.isRead,
    required this.onTap,
    required this.onBookmarkTap,
  });

  @override
  Widget build(BuildContext context) {
    final hasRelatedLesson = item.relatedLessonId != null ||
        (item.relatedCurriculumCode != null &&
            item.relatedCurriculumCode!.trim().isNotEmpty);

    return SurfaceCard(
      onTap: onTap,
      child: Opacity(
        opacity: isRead ? 0.78 : 1.0,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Wrap(
                    spacing: AppSpacing.xs,
                    runSpacing: AppSpacing.xs,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      if (!isRead)
                        Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(
                            color: AppColors.brand,
                            shape: BoxShape.circle,
                          ),
                        ),
                      WatchCategoryPill(category: item.category),
                      WatchImportancePill(importance: item.importance),
                    ],
                  ),
                ),
              IconButton(
                constraints: const BoxConstraints(
                  minWidth: 44,
                  minHeight: 44,
                ),
                onPressed: onBookmarkTap,
                tooltip: item.bookmarked
                    ? 'Retirer des favoris'
                    : 'Ajouter aux favoris',
                icon: Icon(
                  LucideIcons.bookmark,
                  size: 18,
                  color: item.bookmarked
                      ? AppColors.brand
                      : context.palette.textMuted,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            item.title,
            style: context.text.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            item.summary,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: context.text.bodyMedium?.copyWith(
              color: context.palette.textMuted,
            ),
          ),
          if (hasRelatedLesson) ...[
            const SizedBox(height: AppSpacing.sm + 4),
            RelatedLessonBanner(
              relatedLessonId: item.relatedLessonId,
              relatedCurriculumCode: item.relatedCurriculumCode,
              relatedLessonTitle: item.relatedLessonTitle,
              compact: true,
            ),
          ],
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              Icon(
                Icons.memory_rounded,
                size: 14,
                color: context.palette.textMuted,
              ),
              const SizedBox(width: 4),
              Flexible(
                child: Text(
                  '${item.targetTechnology} · ${item.publishedDate}',
                  overflow: TextOverflow.ellipsis,
                  style: context.text.bodySmall,
                ),
              ),
              if (item.aiGenerated) ...[
                const SizedBox(width: AppSpacing.sm),
                const Icon(
                  Icons.auto_awesome_rounded,
                  size: 14,
                  color: AppColors.brand,
                ),
                const SizedBox(width: 4),
                Text(
                  'Synthèse IA',
                  style: context.text.labelSmall?.copyWith(
                    color: AppColors.brand,
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
      ),
    );
  }
}
