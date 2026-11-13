import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/providers/app_providers.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/state_views.dart';
import '../models/news_models.dart';

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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Veille technologique')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.md,
              AppSpacing.sm,
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
                        icon: const Icon(Icons.clear_rounded),
                        onPressed: () {
                          _searchController.clear();
                          _loadNews();
                        },
                      )
                    : null,
                border: const OutlineInputBorder(),
                isDense: true,
              ),
              onChanged: (_) => setState(() {}),
            ),
          ),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.sm,
            ),
            child: Row(
              children: [
                FilterChip(
                  avatar: const Icon(Icons.bookmark_rounded, size: 16),
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
                    label: Text(_categoryLabel(cat)),
                    selected: !_onlyBookmarks && _selectedCategory == cat,
                    onSelected: (_) {
                      setState(() {
                        _onlyBookmarks = false;
                        _selectedCategory =
                            _selectedCategory == cat ? null : cat;
                      });
                      _loadNews();
                    },
                  ),
                  const SizedBox(width: AppSpacing.sm),
                ],
              ],
            ),
          ),
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
                          )
                        : RefreshIndicator(
                            onRefresh: _loadNews,
                            child: ListView.separated(
                              padding: const EdgeInsets.all(AppSpacing.md),
                              itemCount: _items.length,
                              separatorBuilder: (_, _) =>
                                  const SizedBox(height: AppSpacing.sm),
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
}

String _categoryLabel(WatchCategory cat) => switch (cat) {
      WatchCategory.BACKEND => 'Backend',
      WatchCategory.DEVOPS => 'DevOps',
      WatchCategory.AI => 'IA',
      WatchCategory.EMERGING_TECH => 'Tech Émergente',
    };

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
    final (impIcon, impColor, impLabel) = switch (item.importance) {
      WatchImportance.CRITICAL => (
          Icons.priority_high_rounded,
          AppColors.error,
          'Critique'
        ),
      WatchImportance.HIGH => (
          Icons.arrow_upward_rounded,
          AppColors.warning,
          'Importante'
        ),
      WatchImportance.MEDIUM => (
          Icons.remove_rounded,
          AppColors.devops,
          'Moyenne'
        ),
      WatchImportance.LOW => (
          Icons.arrow_downward_rounded,
          AppColors.backend,
          'Info'
        ),
    };

    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Chip(
                    label: Text(_categoryLabel(item.category)),
                    visualDensity: VisualDensity.compact,
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(impIcon, size: 16, color: impColor),
                      const SizedBox(width: 2),
                      Text(
                        impLabel,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: impColor,
                        ),
                      ),
                    ],
                  ),
                  const Spacer(),
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
                      color: item.bookmarked ? AppColors.devops : null,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                item.title,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                item.summary,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                '${item.targetTechnology} • Publié le ${item.publishedDate}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

