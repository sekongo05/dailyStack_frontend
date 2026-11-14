import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
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
  final TextEditingController _searchController = TextEditingController();
  WatchCategory? _selectedCategory;
  bool _onlyBookmarks = false;
  List<TechNewsSummary> _items = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadNews();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadNews() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    final localDb = ref.read(localDatabaseProvider);
    try {
      final newsService = ref.read(newsServiceProvider);
      final list = _onlyBookmarks
          ? await newsService.getBookmarks(size: 30)
          : await newsService.getNews(
              category: _selectedCategory,
              keyword: _searchController.text.trim(),
              size: 30,
            );
      if (!_onlyBookmarks &&
          _selectedCategory == null &&
          _searchController.text.trim().isEmpty) {
        await localDb.cacheNews(list);
      }
      if (!mounted) return;
      setState(() {
        _items = list;
        _isLoading = false;
      });
    } catch (e) {
      final cached = await localDb.getCachedNews();
      if (cached.isNotEmpty) {
        final query = _searchController.text.trim().toLowerCase();
        final filtered = cached.where((item) {
          if (_onlyBookmarks && !item.bookmarked) return false;
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
          _isLoading = false;
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
        _items[index] = TechNewsSummary(
          id: item.id,
          title: item.title,
          category: item.category,
          targetTechnology: item.targetTechnology,
          summary: item.summary,
          importance: item.importance,
          publishedDate: item.publishedDate,
          lastVerifiedDate: item.lastVerifiedDate,
          aiGenerated: item.aiGenerated,
          bookmarked: bookmarked,
        );
      });
    }
  }

  void _resetFilters() {
    _searchController.clear();
    setState(() {
      _onlyBookmarks = false;
      _selectedCategory = null;
    });
    _loadNews();
  }

  @override
  Widget build(BuildContext context) {
    final hasActiveFilters = _onlyBookmarks ||
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
                prefixIcon: const Icon(Icons.search_rounded),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        constraints: const BoxConstraints(
                          minWidth: 44,
                          minHeight: 44,
                        ),
                        tooltip: 'Effacer la recherche',
                        icon: const Icon(Icons.clear_rounded),
                        onPressed: () {
                          _searchController.clear();
                          _loadNews();
                        },
                      )
                    : null,
              ),
              onChanged: (_) => setState(() {}),
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
                              padding: const EdgeInsets.fromLTRB(
                                AppSpacing.md,
                                AppSpacing.xs,
                                AppSpacing.md,
                                AppSpacing.xl,
                              ),
                              itemCount: _items.length,
                              separatorBuilder: (_, _) =>
                                  const SizedBox(height: AppSpacing.md),
                              itemBuilder: (context, index) {
                                final item = _items[index];
                                return _NewsCard(
                                  item: item,
                                  onBookmarkTap: () => _toggleBookmark(index),
                                  onTap: () async {
                                    await context.push('/watch/${item.id}');
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
              _onlyBookmarks
                  ? Icons.bookmark_rounded
                  : Icons.bookmark_outline_rounded,
              size: 16,
            ),
            label: const Text('Favoris'),
            selected: _onlyBookmarks,
            onSelected: (val) {
              setState(() => _onlyBookmarks = val);
              _loadNews();
            },
          ),
          const SizedBox(width: AppSpacing.sm),
          FilterChip(
            label: const Text('Toutes'),
            selected: !_onlyBookmarks && _selectedCategory == null,
            onSelected: (_) {
              setState(() {
                _onlyBookmarks = false;
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
  final VoidCallback onTap;
  final VoidCallback onBookmarkTap;

  const _NewsCard({
    required this.item,
    required this.onTap,
    required this.onBookmarkTap,
  });

  @override
  Widget build(BuildContext context) {
    return SurfaceCard(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Wrap(
                  spacing: AppSpacing.xs,
                  runSpacing: AppSpacing.xs,
                  children: [
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
                  item.bookmarked
                      ? Icons.bookmark_rounded
                      : Icons.bookmark_outline_rounded,
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
                Icon(
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
    );
  }
}
