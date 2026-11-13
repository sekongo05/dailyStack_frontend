import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/providers/app_providers.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/state_views.dart';
import '../models/news_models.dart';

class NewsDetailScreen extends ConsumerStatefulWidget {
  final int newsId;

  const NewsDetailScreen({super.key, required this.newsId});

  @override
  ConsumerState<NewsDetailScreen> createState() => _NewsDetailScreenState();
}

class _NewsDetailScreenState extends ConsumerState<NewsDetailScreen> {
  TechNewsDetail? _detail;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final data =
          await ref.read(newsServiceProvider).getNewsDetail(widget.newsId);
      if (!mounted) return;
      setState(() {
        _detail = data;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _toggleBookmark() async {
    if (_detail == null) return;
    try {
      final bookmarked =
          await ref.read(newsServiceProvider).toggleBookmark(_detail!.id);
      if (!mounted) return;
      setState(() {
        final d = _detail!;
        _detail = TechNewsDetail(
          id: d.id,
          title: d.title,
          category: d.category,
          targetTechnology: d.targetTechnology,
          summary: d.summary,
          importance: d.importance,
          publishedDate: d.publishedDate,
          lastVerifiedDate: d.lastVerifiedDate,
          aiGenerated: d.aiGenerated,
          bookmarked: bookmarked,
          changesSummary: d.changesSummary,
          developerImpact: d.developerImpact,
          originalSourceUrl: d.originalSourceUrl,
        );
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString())),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Détail de la veille'),
        actions: [
          if (_detail != null)
            IconButton(
              constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
              onPressed: _toggleBookmark,
              tooltip: _detail!.bookmarked
                  ? 'Retirer des favoris'
                  : 'Ajouter aux favoris',
              icon: Icon(
                _detail!.bookmarked
                    ? Icons.bookmark_rounded
                    : Icons.bookmark_outline_rounded,
              ),
            ),
        ],
      ),
      body: _isLoading
          ? const AppLoadingView(message: 'Chargement de l\'article...')
          : _error != null || _detail == null
              ? AppErrorView(
                  message: _error ?? 'Article introuvable.',
                  onRetry: _load,
                )
              : ListView(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  children: [
                    Wrap(
                      spacing: AppSpacing.sm,
                      runSpacing: AppSpacing.xs,
                      children: [
                        Chip(label: Text(_detail!.targetTechnology)),
                        if (_detail!.aiGenerated)
                          const Chip(
                            avatar: Icon(Icons.auto_awesome_rounded, size: 16),
                            label: Text('Synthèse assistée par IA'),
                          ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      _detail!.title,
                      style:
                          Theme.of(context).textTheme.headlineSmall?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      'Publié le ${_detail!.publishedDate} • Vérifié le ${_detail!.lastVerifiedDate}',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Text(
                      _detail!.summary,
                      style: Theme.of(context).textTheme.bodyLarge,
                    ),
                    if (_detail!.changesSummary != null &&
                        _detail!.changesSummary!.isNotEmpty) ...[
                      const SizedBox(height: AppSpacing.lg),
                      _InfoSection(
                        icon: Icons.update_rounded,
                        title: 'Ce qui change',
                        content: _detail!.changesSummary!,
                      ),
                    ],
                    if (_detail!.developerImpact != null &&
                        _detail!.developerImpact!.isNotEmpty) ...[
                      const SizedBox(height: AppSpacing.md),
                      _InfoSection(
                        icon: Icons.code_rounded,
                        title: 'Impact développeur',
                        content: _detail!.developerImpact!,
                      ),
                    ],
                    if (_detail!.originalSourceUrl.isNotEmpty) ...[
                      const SizedBox(height: AppSpacing.lg),
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(AppSpacing.md),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  const Icon(Icons.link_rounded, size: 18),
                                  const SizedBox(width: AppSpacing.sm),
                                  Text(
                                    'Source officielle',
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleSmall
                                        ?.copyWith(fontWeight: FontWeight.bold),
                                  ),
                                ],
                              ),
                              const SizedBox(height: AppSpacing.xs),
                              SelectableText(
                                _detail!.originalSourceUrl,
                                style: TextStyle(
                                  color: Theme.of(context).colorScheme.primary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
    );
  }
}

class _InfoSection extends StatelessWidget {
  final IconData icon;
  final String title;
  final String content;

  const _InfoSection({
    required this.icon,
    required this.title,
    required this.content,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 20, color: AppColors.devops),
                const SizedBox(width: AppSpacing.sm),
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(content, style: Theme.of(context).textTheme.bodyMedium),
          ],
        ),
      ),
    );
  }
}

