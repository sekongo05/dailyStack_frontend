import 'dart:convert';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/api_response.dart';
import '../../../core/providers/app_providers.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/external_url_launcher.dart';
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

  Future<void> _markAsRead() async {
    try {
      final db = ref.read(localDatabaseProvider);
      final raw = await db.getMetadata('read_news_ids_v1');
      final ids = raw != null && raw.isNotEmpty
          ? (jsonDecode(raw) as List<dynamic>)
              .map((e) => (e as num).toInt())
              .toSet()
          : <int>{};
      if (ids.add(widget.newsId)) {
        final list = ids.toList();
        final toSave =
            list.length > 500 ? list.sublist(list.length - 500) : list;
        await db.setMetadata('read_news_ids_v1', jsonEncode(toSave));
      }
    } catch (_) {}
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final data =
          await ref.read(newsServiceProvider).getNewsDetail(widget.newsId);
      await _markAsRead();
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

  Future<void> _shareArticle(TechNewsDetail detail) async {
    final buffer = StringBuffer()
      ..writeln('${detail.title} (${detail.targetTechnology})')
      ..writeln()
      ..writeln(detail.summary);
    if (detail.developerImpact != null && detail.developerImpact!.isNotEmpty) {
      buffer
        ..writeln()
        ..writeln('Impact : ${detail.developerImpact}');
    }
    if (detail.originalSourceUrl.isNotEmpty) {
      buffer
        ..writeln()
        ..writeln('Source : ${detail.originalSourceUrl}');
    }
    await Clipboard.setData(ClipboardData(text: buffer.toString().trim()));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Résumé et lien copiés pour partage.'),
      ),
    );
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
          if (detail != null) ...[
            IconButton(
              constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
              onPressed: () => _shareArticle(detail),
              tooltip: 'Partager',
              icon: const Icon(Icons.share_outlined),
            ),
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
                                child: _LinkifiedText(
                                  text: detail.summary,
                                  style: context.text.bodyLarge,
                                  onLinkTap: (url) => _openSourceUrl(context, url),
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
                                _SourceUrlCard(
                                  url: detail.originalSourceUrl,
                                  onOpen: () => _openSourceUrl(
                                    context,
                                    detail.originalSourceUrl,
                                  ),
                                  onCopy: () => _copySourceUrl(
                                    context,
                                    detail.originalSourceUrl,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ),
    );
  }
  Future<void> _openSourceUrl(BuildContext context, String rawUrl) async {
    final opened = await openExternalUrl(rawUrl);
    if (!opened && context.mounted) {
      await Clipboard.setData(ClipboardData(text: rawUrl));
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Lien copié dans le presse-papiers.'),
        ),
      );
    }
  }

  Future<void> _copySourceUrl(BuildContext context, String rawUrl) async {
    await Clipboard.setData(ClipboardData(text: rawUrl));
    HapticFeedback.lightImpact();
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Lien source copié.')),
    );
  }
}

class _InfoSection extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String content;

  const _InfoSection({
    required this.icon,
    required this.color,
    required this.title,
    required this.content,
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
          _LinkifiedText(
            text: content,
            style: context.text.bodyMedium,
            onLinkTap: (url) async {
              final opened = await openExternalUrl(url);
              if (!opened && context.mounted) {
                await Clipboard.setData(ClipboardData(text: url));
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Lien copié dans le presse-papiers.'),
                  ),
                );
              }
            },
          ),
        ],
      ),
    );
  }
}

class _SourceUrlCard extends StatelessWidget {
  final String url;
  final VoidCallback onOpen;
  final VoidCallback onCopy;

  const _SourceUrlCard({
    required this.url,
    required this.onOpen,
    required this.onCopy,
  });

  @override
  Widget build(BuildContext context) {
    return SurfaceCard(
      onTap: onOpen,
      borderColor: AppColors.brand.withValues(alpha: 0.35),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const IconTile(
                icon: Icons.link_rounded,
                color: AppColors.brand,
                size: 36,
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  'Source originale',
                  style: context.text.titleMedium,
                ),
              ),
              IconButton(
                tooltip: 'Copier le lien',
                onPressed: onCopy,
                icon: Icon(
                  Icons.copy_rounded,
                  size: 18,
                  color: context.palette.textMuted,
                ),
              ),
              const Icon(
                Icons.open_in_new_rounded,
                size: 18,
                color: AppColors.brand,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            url,
            style: context.text.bodyMedium?.copyWith(
              color: AppColors.brand,
              decoration: TextDecoration.underline,
              decorationColor: AppColors.brand,
            ),
          ),
        ],
      ),
    );
  }
}

class _LinkifiedText extends StatefulWidget {
  final String text;
  final TextStyle? style;
  final ValueChanged<String> onLinkTap;

  const _LinkifiedText({
    required this.text,
    this.style,
    required this.onLinkTap,
  });

  @override
  State<_LinkifiedText> createState() => _LinkifiedTextState();
}

class _LinkifiedTextState extends State<_LinkifiedText> {
  static final RegExp _urlRegex = RegExp(
    r'https?://[^\s<>\[\]()]+',
    caseSensitive: false,
  );

  final List<TapGestureRecognizer> _recognizers = [];

  @override
  void dispose() {
    for (final r in _recognizers) {
      r.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    for (final r in _recognizers) {
      r.dispose();
    }
    _recognizers.clear();

    final matches = _urlRegex.allMatches(widget.text).toList();
    if (matches.isEmpty) {
      return Text(widget.text, style: widget.style);
    }

    final spans = <InlineSpan>[];
    var cursor = 0;

    for (final match in matches) {
      if (match.start > cursor) {
        spans.add(TextSpan(text: widget.text.substring(cursor, match.start)));
      }
      var rawUrl = match.group(0)!;
      var suffix = '';
      while (rawUrl.isNotEmpty &&
          (rawUrl.endsWith('.') ||
              rawUrl.endsWith(',') ||
              rawUrl.endsWith(';') ||
              rawUrl.endsWith(':'))) {
        suffix = '${rawUrl[rawUrl.length - 1]}$suffix';
        rawUrl = rawUrl.substring(0, rawUrl.length - 1);
      }

      final recognizer = TapGestureRecognizer()
        ..onTap = () => widget.onLinkTap(rawUrl);
      _recognizers.add(recognizer);

      spans.add(
        TextSpan(
          text: rawUrl,
          recognizer: recognizer,
          style: widget.style?.copyWith(
            color: AppColors.brand,
            decoration: TextDecoration.underline,
            decorationColor: AppColors.brand,
            fontWeight: FontWeight.w600,
          ),
        ),
      );
      if (suffix.isNotEmpty) {
        spans.add(TextSpan(text: suffix));
      }
      cursor = match.end;
    }

    if (cursor < widget.text.length) {
      spans.add(TextSpan(text: widget.text.substring(cursor)));
    }

    return SelectableText.rich(
      TextSpan(style: widget.style, children: spans),
    );
  }
}
