import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/api_response.dart';
import '../../../core/providers/app_providers.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/state_views.dart';
import '../../../core/widgets/ui.dart';
import '../models/news_models.dart';
import '../widgets/watch_badges.dart';

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
      final cachedList = await ref.read(localDatabaseProvider).getCachedNews();
      final cachedSummary =
          cachedList.where((n) => n.id == widget.newsId).firstOrNull;
      if (!mounted) return;
      if (cachedSummary != null) {
        setState(() {
          _detail = TechNewsDetail(
            id: cachedSummary.id,
            title: cachedSummary.title,
            category: cachedSummary.category,
            targetTechnology: cachedSummary.targetTechnology,
            summary: cachedSummary.summary,
            importance: cachedSummary.importance,
            publishedDate: cachedSummary.publishedDate,
            lastVerifiedDate: cachedSummary.lastVerifiedDate,
            aiGenerated: cachedSummary.aiGenerated,
            bookmarked: cachedSummary.bookmarked,
            relatedLessonId: cachedSummary.relatedLessonId,
            relatedCurriculumCode: cachedSummary.relatedCurriculumCode,
            relatedLessonTitle: cachedSummary.relatedLessonTitle,
            originalSourceUrl: '',
          );
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

  Future<void> _toggleBookmark() async {
    if (_detail == null) return;
    try {
      final bookmarked =
          await ref.read(newsServiceProvider).toggleBookmark(_detail!.id);
      if (!mounted) return;
      setState(() {
        _detail = _detail!.copyWith(bookmarked: bookmarked);
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(userFriendlyError(e))),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final detail = _detail;
    final hasRelatedLesson = detail != null &&
        (detail.relatedLessonId != null ||
            (detail.relatedCurriculumCode != null &&
                detail.relatedCurriculumCode!.trim().isNotEmpty));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Veille'),
        actions: [
          if (detail != null)
            IconButton(
              constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
              onPressed: _toggleBookmark,
              tooltip: detail.bookmarked
                  ? 'Retirer des favoris'
                  : 'Ajouter aux favoris',
              icon: Icon(
                detail.bookmarked
                    ? Icons.bookmark_rounded
                    : Icons.bookmark_outline_rounded,
                color: detail.bookmarked ? AppColors.brand : null,
              ),
            ),
        ],
      ),
      body: _isLoading
          ? const AppLoadingView(message: 'Chargement de l’article...')
          : _error != null
              ? AppErrorView(message: _error!, onRetry: _load)
              : detail == null
                  ? const AppEmptyView(
                      title: 'Article introuvable',
                      subtitle: 'Cet article n’est plus disponible.',
                      icon: Icons.article_outlined,
                    )
                  : SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(
                        AppSpacing.md,
                        AppSpacing.sm,
                        AppSpacing.md,
                        AppSpacing.xl,
                      ),
                      child: Center(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 720),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Wrap(
                                spacing: AppSpacing.xs,
                                runSpacing: AppSpacing.xs,
                                children: [
                                  WatchCategoryPill(category: detail.category),
                                  WatchImportancePill(
                                    importance: detail.importance,
                                  ),
                                  TagPill(
                                    label: detail.targetTechnology,
                                    color: AppColors.brand,
                                    icon: Icons.memory_rounded,
                                  ),
                                  if (detail.aiGenerated)
                                    TagPill(
                                      label: 'Synthèse IA',
                                      color: context.palette.textMuted,
                                      icon: Icons.auto_awesome_rounded,
                                    ),
                                ],
                              ),
                              const SizedBox(height: AppSpacing.md),
                              Text(
                                detail.title,
                                style: context.text.headlineMedium,
                              ),
                              const SizedBox(height: AppSpacing.xs),
                              Text(
                                'Publié le ${detail.publishedDate}${detail.lastVerifiedDate.isNotEmpty ? ' · Vérifié le ${detail.lastVerifiedDate}' : ''}',
                                style: context.text.bodySmall,
                              ),
                              if (hasRelatedLesson) ...[
                                const SizedBox(height: AppSpacing.md),
                                RelatedLessonBanner(
                                  relatedLessonId: detail.relatedLessonId,
                                  relatedCurriculumCode:
                                      detail.relatedCurriculumCode,
                                  relatedLessonTitle: detail.relatedLessonTitle,
                                ),
                              ],
                              const SizedBox(height: AppSpacing.lg),
                              SurfaceCard(
                                child: Text(
                                  detail.summary,
                                  style: context.text.bodyLarge,
                                ),
                              ),
                              if (detail.changesSummary != null &&
                                  detail.changesSummary!.isNotEmpty) ...[
                                const SizedBox(height: AppSpacing.md),
                                _InfoSection(
                                  icon: Icons.compare_arrows_rounded,
                                  color: AppColors.backend,
                                  title: 'Ce qui change',
                                  content: detail.changesSummary!,
                                ),
                              ],
                              if (detail.developerImpact != null &&
                                  detail.developerImpact!.isNotEmpty) ...[
                                const SizedBox(height: AppSpacing.md),
                                _InfoSection(
                                  icon: Icons.engineering_rounded,
                                  color: AppColors.warning,
                                  title: 'Impact développeur',
                                  content: detail.developerImpact!,
                                ),
                              ],
                              if (detail.fullContent != null &&
                                  detail.fullContent!.isNotEmpty) ...[
                                const SizedBox(height: AppSpacing.md),
                                _InfoSection(
                                  icon: Icons.article_rounded,
                                  color: AppColors.devops,
                                  title: 'Article complet',
                                  content: detail.fullContent!,
                                ),
                              ],
                              if (detail.originalSourceUrl.isNotEmpty) ...[
                                const SizedBox(height: AppSpacing.md),
                                _InfoSection(
                                  icon: Icons.link_rounded,
                                  color: context.palette.textMuted,
                                  title: 'Source originale',
                                  content: detail.originalSourceUrl,
                                  selectable: true,
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ),
    );
  }
}

class _InfoSection extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String content;
  final bool selectable;

  const _InfoSection({
    required this.icon,
    required this.color,
    required this.title,
    required this.content,
    this.selectable = false,
  });

  @override
  Widget build(BuildContext context) {
    return SurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              IconTile(icon: icon, color: color, size: 36),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(title, style: context.text.titleMedium),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          selectable
              ? SelectableText(
                  content,
                  style: context.text.bodyMedium?.copyWith(
                    color: AppColors.brand,
                  ),
                )
              : Text(content, style: context.text.bodyMedium),
        ],
      ),
    );
  }
}
