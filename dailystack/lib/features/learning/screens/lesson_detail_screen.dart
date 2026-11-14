import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/providers/app_providers.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/domain_badge.dart';
import '../../../core/widgets/state_views.dart';
import '../../../core/widgets/ui.dart';
import '../models/lesson_models.dart';

class LessonDetailScreen extends ConsumerStatefulWidget {
  final int lessonId;

  const LessonDetailScreen({super.key, required this.lessonId});

  @override
  ConsumerState<LessonDetailScreen> createState() => _LessonDetailScreenState();
}

class _LessonDetailScreenState extends ConsumerState<LessonDetailScreen> {
  final ScrollController _scrollController = ScrollController();
  Timer? _scrollSaveTimer;
  LessonDetail? _lesson;
  List<LessonSection> _sections = [];
  double _scrollRatio = 0.0;
  bool _isLoading = true;
  bool _isSaving = false;
  bool _isCompleted = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _loadLesson();
  }

  @override
  void dispose() {
    _scrollSaveTimer?.cancel();
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final maxExtent = _scrollController.position.maxScrollExtent;
    final ratio = maxExtent > 0
        ? (_scrollController.position.pixels / maxExtent).clamp(0.0, 1.0)
        : 1.0;

    if ((ratio - _scrollRatio).abs() >= 0.02) {
      setState(() => _scrollRatio = ratio);
    }

    _scrollSaveTimer?.cancel();
    _scrollSaveTimer = Timer(const Duration(seconds: 2), () {
      if (mounted && !_isCompleted) {
        _saveProgress(markAsCompleted: false);
      }
    });
  }

  Future<void> _loadLesson() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    final localDb = ref.read(localDatabaseProvider);
    try {
      final detail = await ref
          .read(lessonServiceProvider)
          .getLessonDetail(widget.lessonId);
      await localDb.cacheLessons([detail]);
      _applyLoadedLesson(detail);
    } catch (e) {
      final cached = await localDb.getCachedLesson(widget.lessonId);
      if (cached != null) {
        _applyLoadedLesson(cached);
        return;
      }
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  void _applyLoadedLesson(LessonDetail detail) {
    final sorted = [...detail.sections]
      ..sort((a, b) => a.orderIndex.compareTo(b.orderIndex));
    final savedRatio =
        (detail.userProgress?.scrollOffsetRatio ?? 0.0).clamp(0.0, 1.0);

    if (!mounted) return;
    setState(() {
      _lesson = detail;
      _sections = sorted;
      _scrollRatio = savedRatio;
      _isCompleted =
          detail.userProgress?.status == LessonProgressStatus.COMPLETED;
      _isLoading = false;
    });

    if (savedRatio > 0) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!_scrollController.hasClients) return;
        final maxExtent = _scrollController.position.maxScrollExtent;
        if (maxExtent > 0) {
          _scrollController.jumpTo(maxExtent * savedRatio);
        }
      });
    }
  }

  int _estimatedSectionIndex() {
    if (_sections.isEmpty) return 0;
    return (_scrollRatio * (_sections.length - 1)).round().clamp(
          0,
          _sections.length - 1,
        );
  }

  Future<void> _saveProgress({bool markAsCompleted = false}) async {
    if (_sections.isEmpty) return;
    if (markAsCompleted) setState(() => _isSaving = true);

    final ratio = double.parse(
      (markAsCompleted ? 1.0 : _scrollRatio).toStringAsFixed(2),
    );
    final sectionIndex =
        markAsCompleted ? _sections.length - 1 : _estimatedSectionIndex();

    try {
      await ref.read(lessonServiceProvider).updateProgress(
            lessonId: widget.lessonId,
            lastReadSectionIndex: sectionIndex,
            scrollOffsetRatio: ratio,
            markAsCompleted: markAsCompleted,
          );
      if (!mounted) return;
      if (markAsCompleted) {
        setState(() {
          _isCompleted = true;
          _scrollRatio = 1.0;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Bravo ! Leçon terminée avec succès.'),
          ),
        );
      }
    } catch (_) {
      await ref.read(offlineSyncProvider.notifier).queueProgress(
            lessonId: widget.lessonId,
            lastReadSectionIndex: sectionIndex,
            scrollOffsetRatio: ratio,
            status: markAsCompleted ? 'COMPLETED' : 'IN_PROGRESS',
          );
      if (mounted && markAsCompleted) {
        setState(() {
          _isCompleted = true;
          _scrollRatio = 1.0;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Données stockées localement - en attente de synchronisation',
            ),
          ),
        );
      }
    } finally {
      if (mounted && markAsCompleted) {
        setState(() => _isSaving = false);
      }
    }
  }

  MarkdownStyleSheet _markdownStyle(BuildContext context) {
    return MarkdownStyleSheet.fromTheme(Theme.of(context)).copyWith(
      p: context.text.bodyLarge,
      h1: context.text.headlineMedium,
      h2: context.text.headlineSmall,
      h3: context.text.titleLarge,
      listBullet: context.text.bodyLarge,
      code: context.text.bodyMedium?.copyWith(
        fontFamily: 'monospace',
        backgroundColor: context.palette.surfaceAlt,
      ),
      codeblockDecoration: BoxDecoration(
        color: context.palette.surfaceAlt,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: context.palette.border),
      ),
      codeblockPadding: const EdgeInsets.all(AppSpacing.md),
      blockquoteDecoration: BoxDecoration(
        color: AppColors.brand.withValues(alpha: 0.06),
        border: const Border(
          left: BorderSide(color: AppColors.brand, width: 3.5),
        ),
        borderRadius: const BorderRadius.only(
          topRight: Radius.circular(AppRadius.sm),
          bottomRight: Radius.circular(AppRadius.sm),
        ),
      ),
      blockquotePadding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm + 2,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Leçon')),
        body: const AppLoadingView(message: 'Chargement de la leçon...'),
      );
    }

    if (_error != null || _lesson == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Leçon')),
        body: AppErrorView(
          message: _error ?? 'Leçon introuvable.',
          onRetry: _loadLesson,
        ),
      );
    }

    final lesson = _lesson!;
    if (_sections.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: Text(lesson.title)),
        body: const AppEmptyView(
          title: 'Contenu indisponible',
          subtitle: 'Cette leçon ne contient aucune section pour le moment.',
        ),
      );
    }

    final mdStyle = _markdownStyle(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          lesson.trackTitle,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: context.text.titleSmall?.copyWith(
            color: context.palette.textMuted,
          ),
        ),
      ),
      body: Column(
        children: [
          ProgressBar(value: _scrollRatio, height: 4),
          Expanded(
            child: SingleChildScrollView(
              controller: _scrollController,
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.lg - 4,
                vertical: AppSpacing.md,
              ),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 720),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Wrap(
                        spacing: AppSpacing.sm,
                        runSpacing: AppSpacing.xs,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          DomainBadge(domainCode: lesson.domainCode),
                          TagPill(
                            label: '${lesson.estimatedMinutes} min · Jour ${lesson.sequenceDay}',
                            color: AppColors.brand,
                            icon: Icons.schedule_rounded,
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.md),
                      Text(lesson.title, style: context.text.headlineMedium),
                      const SizedBox(height: AppSpacing.lg),
                      for (var i = 0; i < _sections.length; i++) ...[
                        if (_sections[i].sectionType != SectionType.TITLE) ...[
                          Text(_sections[i].title, style: context.text.titleLarge),
                          const SizedBox(height: AppSpacing.sm),
                        ],
                        MarkdownBody(
                          data: _sections[i].contentMarkdown,
                          selectable: true,
                          styleSheet: mdStyle,
                        ),
                        if (i < _sections.length - 1) ...[
                          const SizedBox(height: AppSpacing.lg),
                          const Divider(),
                          const SizedBox(height: AppSpacing.lg),
                        ],
                      ],
                      const SizedBox(height: AppSpacing.xl),
                      SurfaceCard(
                        padding: const EdgeInsets.all(AppSpacing.lg - 4),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Row(
                              children: [
                                IconTile(
                                  icon: _isCompleted
                                      ? Icons.check_rounded
                                      : Icons.flag_rounded,
                                  color: _isCompleted
                                      ? AppColors.success
                                      : AppColors.brand,
                                ),
                                const SizedBox(width: AppSpacing.md),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        _isCompleted
                                            ? 'Leçon terminée'
                                            : 'Fin de la leçon',
                                        style: context.text.titleMedium,
                                      ),
                                      Text(
                                        'Validez vos acquis avec les exercices pratiques.',
                                        style: context.text.bodySmall,
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: AppSpacing.md),
                            if (!_isCompleted) ...[
                              PrimaryButton(
                                label: 'Terminer la leçon',
                                icon: Icons.check_rounded,
                                isLoading: _isSaving,
                                onPressed: () =>
                                    _saveProgress(markAsCompleted: true),
                              ),
                              const SizedBox(height: AppSpacing.sm + 2),
                            ],
                            OutlinedButton.icon(
                              onPressed: () => context.push(
                                '/lessons/${widget.lessonId}/exercises',
                              ),
                              icon: const Icon(Icons.quiz_rounded),
                              label: const Text('Passer aux exercices'),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: AppSpacing.lg),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
