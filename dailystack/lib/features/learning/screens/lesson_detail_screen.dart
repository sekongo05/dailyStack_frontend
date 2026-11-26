import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
  List<GlobalKey> _sectionKeys = [];
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
      _sectionKeys = List.generate(sorted.length, (_) => GlobalKey());
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

  MarkdownStyleSheet _markdownStyle(BuildContext context, Color accentColor) {
    return MarkdownStyleSheet.fromTheme(Theme.of(context)).copyWith(
      p: context.text.bodyLarge?.copyWith(height: 1.62),
      pPadding: const EdgeInsets.only(bottom: 10),
      h1: context.text.headlineMedium,
      h2: context.text.headlineSmall,
      h3: context.text.titleLarge?.copyWith(fontWeight: FontWeight.w700),
      h4: context.text.titleMedium?.copyWith(
        fontWeight: FontWeight.w700,
        color: accentColor,
      ),
      h4Padding: const EdgeInsets.only(top: 12, bottom: 6),
      listBullet: context.text.bodyLarge?.copyWith(color: accentColor),
      listIndent: 20,
      tableColumnWidth: const IntrinsicColumnWidth(),
      tableHead: context.text.labelLarge?.copyWith(fontWeight: FontWeight.w700),
      tableBody: context.text.bodyMedium?.copyWith(height: 1.45),
      tableCellsPadding: const EdgeInsets.symmetric(
        horizontal: 12,
        vertical: 9,
      ),
      tableBorder: TableBorder.all(
        color: context.palette.border,
        width: 1,
        borderRadius: BorderRadius.circular(AppRadius.sm),
      ),
      code: context.text.bodyMedium?.copyWith(
        fontFamily: 'monospace',
        fontWeight: FontWeight.w600,
        backgroundColor: context.palette.surfaceAlt,
      ),
      codeblockDecoration: BoxDecoration(
        color: context.palette.surfaceAlt,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: context.palette.border),
      ),
      codeblockPadding: const EdgeInsets.all(AppSpacing.md),
      blockquoteDecoration: BoxDecoration(
        color: accentColor.withValues(alpha: 0.08),
        border: Border(
          left: BorderSide(color: accentColor, width: 4),
        ),
        borderRadius: const BorderRadius.only(
          topRight: Radius.circular(AppRadius.md),
          bottomRight: Radius.circular(AppRadius.md),
        ),
      ),
      blockquotePadding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm + 4,
      ),
    );
  }

  (IconData, Color) _sectionMeta(SectionType type, Color domainAccent) {
    return switch (type) {
      SectionType.TITLE => (Icons.tips_and_updates_rounded, domainAccent),
      SectionType.INTRODUCTION => (Icons.explore_outlined, domainAccent),
      SectionType.OBJECTIVES => (Icons.track_changes_rounded, AppColors.brand),
      SectionType.EXPLANATION => (Icons.school_outlined, domainAccent),
      SectionType.EXAMPLES => (Icons.code_rounded, AppColors.brand),
      SectionType.ILLUSTRATIONS => (Icons.account_tree_outlined, domainAccent),
      SectionType.PRO_SCENARIO => (Icons.bolt_rounded, AppColors.warning),
      SectionType.SUMMARY => (Icons.task_alt_rounded, AppColors.success),
    };
  }

  String _cleanSectionMarkdown(String raw) {
    if (raw.isEmpty) return raw;
    final lines = raw.split('\n');
    final buffer = StringBuffer();
    var inFence = false;
    for (var i = 0; i < lines.length; i++) {
      final line = lines[i];
      if (line.trimLeft().startsWith('```')) {
        inFence = !inFence;
        buffer.write(line);
      } else if (inFence) {
        buffer.write(line);
      } else {
        buffer.write(
          line
              .replaceAll(r'\r\n', '\n')
              .replaceAll(r'\n', '\n')
              .replaceAll(r'\t', '  ')
              .replaceAll(r'\"', '"')
              .replaceAll(r'\times', '×')
              .replaceAll(r'\le', '≤')
              .replaceAll(r'\ge', '≥'),
        );
      }
      if (i < lines.length - 1) buffer.write('\n');
    }
    return buffer.toString();
  }

  Widget _buildSectionBlock(
    BuildContext context,
    LessonSection section,
    MarkdownStyleSheet mdStyle,
    Color domainAccent,
  ) {
    final (icon, color) = _sectionMeta(section.sectionType, domainAccent);
    final body = MarkdownBody(
      data: _cleanSectionMarkdown(section.contentMarkdown),
      selectable: true,
      styleSheet: mdStyle,
      builders: {
        'pre': _CodeBlockBuilder(
          context,
          isDiagram: section.sectionType == SectionType.ILLUSTRATIONS,
        ),
      },
    );

    // 1. Accroche d'ouverture mise en avant dans un encadré lumineux
    if (section.sectionType == SectionType.TITLE) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: domainAccent.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(color: domainAccent.withValues(alpha: 0.3)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: domainAccent, size: 22),
            const SizedBox(width: AppSpacing.sm + 2),
            Expanded(child: body),
          ],
        ),
      );
    }

    // 2. Cartes encadrées pour Objectifs, Cas réel en production et Points clés à retenir
    final isHighlightedCard = section.sectionType == SectionType.OBJECTIVES ||
        section.sectionType == SectionType.PRO_SCENARIO ||
        section.sectionType == SectionType.SUMMARY;

    final header = Row(
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(9),
          ),
          child: Icon(icon, size: 18, color: color),
        ),
        const SizedBox(width: AppSpacing.sm + 2),
        Expanded(
          child: Text(section.title, style: context.text.titleLarge),
        ),
      ],
    );

    if (isHighlightedCard) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(AppRadius.md + 2),
          border: Border.all(color: color.withValues(alpha: 0.25)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            header,
            const SizedBox(height: AppSpacing.sm + 2),
            body,
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        header,
        const SizedBox(height: AppSpacing.sm + 2),
        body,
      ],
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

    final domainAccent = DomainBadge.colorFor(lesson.domainCode);
    final mdStyle = _markdownStyle(context, domainAccent);

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
        actions: [
          IconButton(
            tooltip: 'Sommaire de la leçon',
            icon: const Icon(Icons.toc_rounded),
            onPressed: () => _showTableOfContents(context),
          ),
        ],
      ),
      body: Column(
        children: [
          ProgressBar(value: _scrollRatio, height: 4, color: domainAccent),
          Expanded(
            child: SingleChildScrollView(
              controller: _scrollController,
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.lg - 4,
                vertical: AppSpacing.md,
              ),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 740),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Wrap(
                        spacing: AppSpacing.sm,
                        runSpacing: AppSpacing.xs,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          DomainBadge(domainCode: lesson.domainCode),
                          if (lesson.curriculumCode != null &&
                              lesson.curriculumCode!.isNotEmpty)
                            TagPill(
                              label: lesson.curriculumCode!,
                              color: domainAccent,
                            ),
                          TagPill(
                            label: DailyLessonSummary.levelLabel(lesson.level),
                            color: AppColors.brand,
                            icon: Icons.workspace_premium_rounded,
                          ),
                          TagPill(
                            label: '${lesson.estimatedMinutes} min',
                            color: AppColors.brand,
                            icon: Icons.schedule_rounded,
                          ),
                          if (lesson.revisionDay)
                            const TagPill(
                              label: 'Révision',
                              color: AppColors.warning,
                              icon: Icons.auto_awesome_rounded,
                            ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.md),
                      Text(lesson.title, style: context.text.headlineMedium),
                      const SizedBox(height: AppSpacing.lg),
                      for (var i = 0; i < _sections.length; i++) ...[
                        Container(
                          key: i < _sectionKeys.length ? _sectionKeys[i] : null,
                          child: _buildSectionBlock(
                            context,
                            _sections[i],
                            mdStyle,
                            domainAccent,
                          ),
                        ),
                        if (i < _sections.length - 1) ...[
                          const SizedBox(height: AppSpacing.lg),
                          if (_sections[i].sectionType != SectionType.TITLE)
                            const Divider(),
                          if (_sections[i].sectionType != SectionType.TITLE)
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
                                        'Validez vos acquis avec le QCM pratique.',
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

  void _showTableOfContents(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetCtx) {
        return SafeArea(
          child: ListView.separated(
            shrinkWrap: true,
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.md,
              0,
              AppSpacing.md,
              AppSpacing.lg,
            ),
            itemCount: _sections.length,
            separatorBuilder: (_, _) => const Divider(height: 1),
            itemBuilder: (_, index) {
              final section = _sections[index];
              return ListTile(
                leading: CircleAvatar(
                  radius: 14,
                  backgroundColor: AppColors.brand.withValues(alpha: 0.12),
                  child: Text(
                    '${index + 1}',
                    style: context.text.labelSmall
                        ?.copyWith(color: AppColors.brand),
                  ),
                ),
                title: Text(section.title),
                onTap: () {
                  Navigator.of(sheetCtx).pop();
                  if (index < _sectionKeys.length) {
                    final target = _sectionKeys[index].currentContext;
                    if (target != null) {
                      Scrollable.ensureVisible(
                        target,
                        duration: const Duration(milliseconds: 350),
                        curve: Curves.easeOutCubic,
                      );
                    }
                  }
                },
              );
            },
          ),
        );
      },
    );
  }
}

class _CodeBlockBuilder extends MarkdownElementBuilder {
  final BuildContext parentContext;
  final bool isDiagram;

  _CodeBlockBuilder(this.parentContext, {this.isDiagram = false});

  @override
  Widget? visitElementAfter(element, TextStyle? preferredStyle) {
    final code = element.textContent.trimRight();
    if (code.isEmpty) return null;
    final ctx = parentContext;
    final headerLabel = isDiagram ? 'SCHÉMA VISUEL' : 'EXEMPLE DE CODE';

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      decoration: BoxDecoration(
        color: ctx.palette.surfaceAlt,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: ctx.palette.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: 6,
            ),
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: ctx.palette.border)),
            ),
            child: Row(
              children: [
                Icon(
                  isDiagram ? Icons.account_tree_outlined : Icons.terminal_rounded,
                  size: 15,
                  color: ctx.palette.textMuted,
                ),
                const SizedBox(width: 6),
                Text(
                  headerLabel,
                  style: ctx.text.labelSmall?.copyWith(
                    color: ctx.palette.textMuted,
                    letterSpacing: 0.6,
                  ),
                ),
                const Spacer(),
                InkWell(
                  borderRadius: BorderRadius.circular(6),
                  onTap: () {
                    Clipboard.setData(ClipboardData(text: code));
                    ScaffoldMessenger.of(ctx).showSnackBar(
                      const SnackBar(
                        content: Text('Copié dans le presse-papiers'),
                      ),
                    );
                  },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.copy_rounded,
                          size: 14,
                          color: ctx.palette.textMuted,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'Copier',
                          style: ctx.text.labelSmall?.copyWith(
                            color: ctx.palette.textMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.all(AppSpacing.md),
            child: SelectableText(
              code,
              style: ctx.text.bodyMedium?.copyWith(
                fontFamily: 'monospace',
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
