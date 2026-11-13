import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/providers/app_providers.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/domain_badge.dart';
import '../../../core/widgets/state_views.dart';
import '../models/lesson_models.dart';

class LessonDetailScreen extends ConsumerStatefulWidget {
  final int lessonId;

  const LessonDetailScreen({super.key, required this.lessonId});

  @override
  ConsumerState<LessonDetailScreen> createState() => _LessonDetailScreenState();
}

class _LessonDetailScreenState extends ConsumerState<LessonDetailScreen> {
  final ScrollController _scrollController = ScrollController();
  LessonDetail? _lesson;
  List<LessonSection> _sections = [];
  int _currentIndex = 0;
  bool _isLoading = true;
  bool _isSaving = false;
  bool _isCompleted = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadLesson();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
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
    final savedIndex = detail.userProgress?.lastReadSectionIndex ?? 0;
    final clampedIndex =
        sorted.isEmpty ? 0 : savedIndex.clamp(0, sorted.length - 1);

    if (!mounted) return;
    setState(() {
      _lesson = detail;
      _sections = sorted;
      _currentIndex = clampedIndex;
      _isCompleted =
          detail.userProgress?.status == LessonProgressStatus.COMPLETED;
      _isLoading = false;
    });
  }

  Future<void> _saveProgress({bool markAsCompleted = false}) async {
    if (_sections.isEmpty) return;
    setState(() => _isSaving = true);
    final ratio =
        double.parse(((_currentIndex + 1) / _sections.length).toStringAsFixed(2));
    try {
      await ref.read(lessonServiceProvider).updateProgress(
            lessonId: widget.lessonId,
            lastReadSectionIndex: _currentIndex,
            scrollOffsetRatio: ratio,
            markAsCompleted: markAsCompleted,
          );
      if (!mounted) return;
      if (markAsCompleted) {
        setState(() => _isCompleted = true);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Bravo ! Leçon terminée avec succès.'),
          ),
        );
      }
    } catch (_) {
      await ref.read(offlineSyncProvider.notifier).queueProgress(
            lessonId: widget.lessonId,
            lastReadSectionIndex: _currentIndex,
            scrollOffsetRatio: ratio,
            status: markAsCompleted ? 'COMPLETED' : 'IN_PROGRESS',
          );
      if (mounted && markAsCompleted) {
        setState(() => _isCompleted = true);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Données stockées localement - en attente de synchronisation',
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _goToSection(int newIndex) {
    if (newIndex < 0 || newIndex >= _sections.length) return;
    setState(() => _currentIndex = newIndex);
    if (_scrollController.hasClients) {
      _scrollController.jumpTo(0);
    }
    _saveProgress();
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

    final section = _sections[_currentIndex];
    final isLastSection = _currentIndex == _sections.length - 1;
    final progressValue = (_currentIndex + 1) / _sections.length;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          lesson.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
      body: Column(
        children: [
          LinearProgressIndicator(value: progressValue, minHeight: 5),
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.md,
              AppSpacing.sm,
              AppSpacing.md,
              0,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                DomainBadge(domainCode: lesson.domainCode),
                Text(
                  'Section ${_currentIndex + 1} / ${_sections.length}',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                ),
              ],
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              controller: _scrollController,
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    section.title,
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  MarkdownBody(
                    data: section.contentMarkdown,
                    selectable: true,
                  ),
                  if (isLastSection) ...[
                    const SizedBox(height: AppSpacing.xl),
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(AppSpacing.md),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  _isCompleted
                                      ? Icons.check_circle_rounded
                                      : Icons.flag_rounded,
                                  color: _isCompleted
                                      ? AppColors.success
                                      : AppColors.devops,
                                ),
                                const SizedBox(width: AppSpacing.sm),
                                Expanded(
                                  child: Text(
                                    _isCompleted
                                        ? 'Leçon terminée'
                                        : 'Vous avez atteint la fin de la leçon',
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleMedium
                                        ?.copyWith(fontWeight: FontWeight.bold),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: AppSpacing.md),
                            if (!_isCompleted)
                              ElevatedButton.icon(
                                onPressed: _isSaving
                                    ? null
                                    : () => _saveProgress(markAsCompleted: true),
                                icon: const Icon(Icons.check_rounded),
                                label: const Text('Terminer la leçon'),
                              ),
                            const SizedBox(height: AppSpacing.sm),
                            OutlinedButton.icon(
                              style: OutlinedButton.styleFrom(
                                minimumSize: const Size(44, 48),
                              ),
                              onPressed: () => context.push(
                                '/lessons/${widget.lessonId}/exercises',
                              ),
                              icon: const Icon(Icons.quiz_rounded),
                              label: const Text('Passer aux exercices'),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size(44, 48),
                      ),
                      onPressed: _currentIndex > 0
                          ? () => _goToSection(_currentIndex - 1)
                          : null,
                      icon: const Icon(Icons.arrow_back_rounded),
                      label: const Text('Précédent'),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: !isLastSection
                          ? () => _goToSection(_currentIndex + 1)
                          : () => context.push(
                                '/lessons/${widget.lessonId}/exercises',
                              ),
                      icon: Icon(
                        isLastSection
                            ? Icons.quiz_rounded
                            : Icons.arrow_forward_rounded,
                      ),
                      label: Text(isLastSection ? 'Exercices' : 'Suivant'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

