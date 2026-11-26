import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/providers/app_providers.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/domain_badge.dart';
import '../../../core/widgets/ide_code_block.dart';
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
  static const _readingModeKey = 'lessonReadingMode';

  final ScrollController _scrollController = ScrollController();
  late PageController _pageController;
  Timer? _scrollSaveTimer;

  LessonDetail? _lesson;
  List<LessonSection> _sections = [];
  List<GlobalKey> _sectionKeys = [];
  double _scrollRatio = 0.0;
  int _currentCardIndex = 0;
  String? _readingModePreference; // 'cards' | 'scroll'
  bool _isLoading = true;
  bool _isSaving = false;
  bool _isCompleted = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    _scrollController.addListener(_onScroll);
    _loadLessonCacheFirst();
  }

  @override
  void dispose() {
    _scrollSaveTimer?.cancel();
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    _pageController.dispose();
    super.dispose();
  }

  bool _isCardsMode(BuildContext context) {
    if (_readingModePreference == 'cards') return true;
    if (_readingModePreference == 'scroll') return false;
    return MediaQuery.sizeOf(context).width < 600;
  }

  Future<void> _setReadingMode(String mode) async {
    if (_readingModePreference == mode) return;
    HapticFeedback.selectionClick();
    setState(() => _readingModePreference = mode);
    await ref.read(localDatabaseProvider).setMetadata(_readingModeKey, mode);

    if (mode == 'cards') {
      final targetIndex = _estimatedSectionIndex();
      _currentCardIndex = targetIndex;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_pageController.hasClients) {
          _pageController.jumpToPage(targetIndex);
        }
      });
    } else {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!_scrollController.hasClients) return;
        final maxExtent = _scrollController.position.maxScrollExtent;
        if (maxExtent > 0) {
          _scrollController.jumpTo(maxExtent * _scrollRatio);
        }
      });
    }
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

    _scheduleProgressSave();
  }

  void _onCardPageChanged(int index) {
    HapticFeedback.selectionClick();
    final ratio = _sections.length <= 1
        ? 1.0
        : (index / (_sections.length - 1)).clamp(0.0, 1.0);
    setState(() {
      _currentCardIndex = index;
      _scrollRatio = ratio;
    });
    _scheduleProgressSave();
  }

  void _scheduleProgressSave() {
    _scrollSaveTimer?.cancel();
    _scrollSaveTimer = Timer(const Duration(seconds: 2), () {
      if (mounted && !_isCompleted) {
        _saveProgress(markAsCompleted: false);
      }
    });
  }

  /// Stratégie Cache-First : affiche immédiatement la leçon pré-chargée (0 ms)
  /// puis rafraîchit silencieusement en arrière-plan.
  Future<void> _loadLessonCacheFirst() async {
    final localDb = ref.read(localDatabaseProvider);

    try {
      final savedMode = await localDb.getMetadata(_readingModeKey);
      if (savedMode == 'cards' || savedMode == 'scroll') {
        _readingModePreference = savedMode;
      }
    } catch (_) {}

    LessonDetail? cached;
    try {
      cached = await localDb.getCachedLesson(widget.lessonId);
    } catch (_) {}

    if (cached != null) {
      _applyLoadedLesson(cached, preserveViewport: false);
      // Rafraîchissement silencieux en arrière-plan.
      try {
        final fresh = await ref
            .read(lessonServiceProvider)
            .getLessonDetail(widget.lessonId);
        await localDb.cacheLessons([fresh]);
        if (mounted) {
          _applyLoadedLesson(fresh, preserveViewport: true);
        }
      } catch (_) {}
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final detail = await ref
          .read(lessonServiceProvider)
          .getLessonDetail(widget.lessonId);
      await localDb.cacheLessons([detail]);
      _applyLoadedLesson(detail, preserveViewport: false);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  void _applyLoadedLesson(
    LessonDetail detail, {
    required bool preserveViewport,
  }) {
    final sorted = [...detail.sections]
      ..sort((a, b) => a.orderIndex.compareTo(b.orderIndex));
    final savedRatio =
        (detail.userProgress?.scrollOffsetRatio ?? 0.0).clamp(0.0, 1.0);
    final savedCardIndex = sorted.isEmpty
        ? 0
        : (detail.userProgress?.lastReadSectionIndex ?? 0)
            .clamp(0, sorted.length - 1);

    if (!mounted) return;
    setState(() {
      _lesson = detail;
      _sections = sorted;
      if (!preserveViewport || _sectionKeys.length != sorted.length) {
        _sectionKeys = List.generate(sorted.length, (_) => GlobalKey());
      }
      if (!preserveViewport) {
        _scrollRatio = savedRatio;
        _currentCardIndex = savedCardIndex;
        _pageController.dispose();
        _pageController = PageController(initialPage: savedCardIndex);
      }
      _isCompleted = _isCompleted ||
          detail.userProgress?.status == LessonProgressStatus.COMPLETED;
      _isLoading = false;
      _error = null;
    });

    if (!preserveViewport && savedRatio > 0) {
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
    if (_readingModePreference == 'cards') {
      return _currentCardIndex.clamp(0, _sections.length - 1);
    }
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
        color: const Color(0xFF0B1120),
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      codeblockPadding: EdgeInsets.zero,
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

  /// Extrait les chaînes de flux d'architecture (`Client -> Gateway -> Service -> DB`)
  /// pour offrir un diagramme mobile lisible même sur 360px.
  List<List<String>> _extractArchitectureFlows(
    String cleanedMarkdown, {
    required bool isIllustrationSection,
  }) {
    final flows = <List<String>>[];
    final seen = <String>{};
    final arrowPattern = RegExp(r'\s*(?:-->|->|=>|→)\s*');
    final minSteps = isIllustrationSection ? 2 : 3;

    for (final rawLine in cleanedMarkdown.split('\n')) {
      var line = rawLine.trim();
      if (line.isEmpty || line.startsWith('```') || line.startsWith('//')) {
        continue;
      }
      line = line
          .replaceFirst(RegExp(r'^[-*•>]\s*'), '')
          .replaceFirst(RegExp(r'^\d+\.\s*'), '')
          .trim();
      if (!arrowPattern.hasMatch(line)) continue;
      if (line.contains('{') ||
          line.contains('}') ||
          line.contains(';') ||
          line.contains('public ') ||
          line.contains('return ')) {
        continue;
      }

      final parts = line
          .split(arrowPattern)
          .map(
            (s) => s
                .replaceAll('`', '')
                .replaceAll('**', '')
                .replaceAll('[', '')
                .replaceAll(']', '')
                .trim(),
          )
          .where((s) => s.length >= 2 && s.length <= 58)
          .toList();

      if (parts.length >= minSteps) {
        final signature = parts.join('->');
        if (seen.add(signature)) {
          flows.add(parts);
        }
      }
    }
    return flows;
  }

  /// Découpe le Markdown hors blocs de code pour mettre en valeur les encadrés
  /// Anti-Pattern (`❌`) et Bonne Pratique (`✅`) tout en conservant le rendu riche.
  List<({String kind, String content})> _segmentCallouts(String cleaned) {
    final segments = <({String kind, String content})>[];
    final currentLines = <String>[];
    var currentKind = 'normal';
    var inFence = false;

    void flush() {
      final text = currentLines.join('\n').trim();
      if (text.isNotEmpty) {
        segments.add((kind: currentKind, content: text));
      }
      currentLines.clear();
    }

    for (final line in cleaned.split('\n')) {
      final trimmed = line.trimLeft();
      if (trimmed.startsWith('```')) {
        inFence = !inFence;
        currentLines.add(line);
        continue;
      }

      if (!inFence) {
        final normalized = trimmed
            .replaceFirst(RegExp(r'^[>-]\s*'), '')
            .replaceFirst(RegExp(r'^\*\*'), '');
        final isAntiPattern = normalized.startsWith('❌');
        final isBestPractice = normalized.startsWith('✅');

        if (isAntiPattern || isBestPractice) {
          final targetKind = isAntiPattern ? 'anti' : 'best';
          if (currentKind != targetKind) {
            flush();
            currentKind = targetKind;
          }
          currentLines.add(line.replaceFirst(RegExp(r'^\s*>\s*'), ''));
          continue;
        } else if (trimmed.isEmpty && currentKind != 'normal') {
          flush();
          currentKind = 'normal';
          continue;
        } else if (currentKind != 'normal' &&
            (trimmed.startsWith('#') || trimmed.startsWith('```'))) {
          flush();
          currentKind = 'normal';
        }
      }

      currentLines.add(line);
    }
    flush();
    return segments;
  }

  Widget _buildMarkdownWithCallouts(
    LessonSection section,
    MarkdownStyleSheet mdStyle,
    Color domainAccent,
  ) {
    final cleaned = _cleanSectionMarkdown(section.contentMarkdown);
    final isIllustration = section.sectionType == SectionType.ILLUSTRATIONS;
    final flows = _extractArchitectureFlows(
      cleaned,
      isIllustrationSection: isIllustration,
    );
    final segments = _segmentCallouts(cleaned);

    final builders = <String, MarkdownElementBuilder>{
      'pre': _IdePreElementBuilder(isDiagramSection: isIllustration),
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (flows.isNotEmpty) ...[
          for (final flow in flows)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.md),
              child: _ArchitectureFlowCard(
                steps: flow,
                accentColor: domainAccent,
              ),
            ),
        ],
        for (var i = 0; i < segments.length; i++) ...[
          if (i > 0) const SizedBox(height: AppSpacing.sm + 2),
          if (segments[i].kind == 'anti')
            _CalloutBox(
              title: 'Anti-pattern à éviter',
              color: AppColors.error,
              icon: Icons.warning_amber_rounded,
              child: MarkdownBody(
                data: segments[i].content,
                selectable: true,
                styleSheet: mdStyle,
                builders: builders,
              ),
            )
          else if (segments[i].kind == 'best')
            _CalloutBox(
              title: 'Bonne pratique recommandée',
              color: AppColors.success,
              icon: Icons.verified_rounded,
              child: MarkdownBody(
                data: segments[i].content,
                selectable: true,
                styleSheet: mdStyle,
                builders: builders,
              ),
            )
          else
            MarkdownBody(
              data: segments[i].content,
              selectable: true,
              styleSheet: mdStyle,
              builders: builders,
            ),
        ],
      ],
    );
  }

  Widget _buildSectionBlock(
    BuildContext context,
    LessonSection section,
    MarkdownStyleSheet mdStyle,
    Color domainAccent,
  ) {
    final (icon, color) = _sectionMeta(section.sectionType, domainAccent);
    final body = _buildMarkdownWithCallouts(
      section,
      mdStyle,
      domainAccent,
    );

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

  Widget _buildLessonHeaderMeta(LessonDetail lesson, Color domainAccent) {
    return Column(
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
      ],
    );
  }

  Widget _buildCompletionCard(BuildContext context) {
    return SurfaceCard(
      padding: const EdgeInsets.all(AppSpacing.lg - 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              IconTile(
                icon: _isCompleted ? Icons.check_rounded : Icons.flag_rounded,
                color: _isCompleted ? AppColors.success : AppColors.brand,
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _isCompleted ? 'Leçon terminée' : 'Fin de la leçon',
                      style: context.text.titleMedium,
                    ),
                    Text(
                      'Validez vos acquis avec les défis pratiques (QCM, diagnostic de code & étapes).',
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
              label: 'Marquer terminée',
              icon: Icons.check_rounded,
              isLoading: _isSaving,
              onPressed: () => _saveProgress(markAsCompleted: true),
            ),
            const SizedBox(height: AppSpacing.sm + 2),
          ],
          OutlinedButton.icon(
            onPressed: () => context.push(
              '/lessons/${widget.lessonId}/exercises',
            ),
            icon: const Icon(Icons.quiz_rounded),
            label: const Text('Passer aux Défis (QCM)'),
          ),
        ],
      ),
    );
  }

  Widget _buildReadingModeSwitch(bool cardsMode) {
    final isCompact = MediaQuery.sizeOf(context).width < 440;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.sm,
        AppSpacing.md,
        AppSpacing.xs,
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 740),
          child: Row(
            children: [
              Expanded(
                child: SegmentedButton<String>(
                  showSelectedIcon: false,
                  segments: [
                    ButtonSegment<String>(
                      value: 'cards',
                      icon: const Icon(Icons.view_carousel_outlined, size: 17),
                      label: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          isCompact ? 'Cartes' : 'Mode Cartes (Étapes)',
                          maxLines: 1,
                        ),
                      ),
                    ),
                    ButtonSegment<String>(
                      value: 'scroll',
                      icon: const Icon(Icons.article_outlined, size: 17),
                      label: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          isCompact ? 'Article' : 'Mode Article',
                          maxLines: 1,
                        ),
                      ),
                    ),
                  ],
                  selected: {cardsMode ? 'cards' : 'scroll'},
                  onSelectionChanged: (s) => _setReadingMode(s.first),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCardsModeBody(
    BuildContext context,
    LessonDetail lesson,
    MarkdownStyleSheet mdStyle,
    Color domainAccent,
  ) {
    final safeIndex = _currentCardIndex.clamp(0, _sections.length - 1);
    final isFirst = safeIndex == 0;
    final isLast = safeIndex == _sections.length - 1;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.xs,
          ),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 740),
            child: Row(
              children: [
                Expanded(
                  child: Row(
                    children: [
                      for (var i = 0; i < _sections.length; i++)
                        Expanded(
                          child: GestureDetector(
                            onTap: () => _pageController.animateToPage(
                              i,
                              duration: const Duration(milliseconds: 260),
                              curve: Curves.easeOutCubic,
                            ),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              height: 5,
                              margin: EdgeInsets.only(
                                right: i < _sections.length - 1 ? 4 : 0,
                              ),
                              decoration: BoxDecoration(
                                color: i <= safeIndex
                                    ? domainAccent
                                    : context.palette.surfaceAlt,
                                borderRadius:
                                    BorderRadius.circular(AppRadius.pill),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: AppSpacing.sm + 2),
                Text(
                  '${safeIndex + 1} / ${_sections.length}',
                  style: context.text.labelSmall?.copyWith(
                    color: domainAccent,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ),
        Expanded(
          child: PageView.builder(
            controller: _pageController,
            itemCount: _sections.length,
            onPageChanged: _onCardPageChanged,
            itemBuilder: (context, index) {
              return SingleChildScrollView(
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
                        if (index == 0) ...[
                          _buildLessonHeaderMeta(lesson, domainAccent),
                          const SizedBox(height: AppSpacing.lg),
                        ],
                        _buildSectionBlock(
                          context,
                          _sections[index],
                          mdStyle,
                          domainAccent,
                        ),
                        if (index == _sections.length - 1) ...[
                          const SizedBox(height: AppSpacing.xl),
                          _buildCompletionCard(context),
                        ],
                        const SizedBox(height: AppSpacing.lg),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        SafeArea(
          top: false,
          child: Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.sm + 2,
            ),
            decoration: BoxDecoration(
              color: context.colors.surface,
              border: Border(top: BorderSide(color: context.palette.border)),
            ),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 740),
                child: Row(
                  children: [
                    Flexible(
                      child: OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.md,
                          ),
                        ),
                        onPressed: isFirst
                            ? null
                            : () => _pageController.previousPage(
                                  duration: const Duration(milliseconds: 260),
                                  curve: Curves.easeOutCubic,
                                ),
                        child: const FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text('← Précédent', maxLines: 1),
                        ),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    const Spacer(),
                    if (!isLast)
                      Flexible(
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: domainAccent,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                              horizontal: AppSpacing.md,
                            ),
                          ),
                          onPressed: () => _pageController.nextPage(
                            duration: const Duration(milliseconds: 260),
                            curve: Curves.easeOutCubic,
                          ),
                          child: const FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text('Étape suivante →', maxLines: 1),
                          ),
                        ),
                      )
                    else
                      Flexible(
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: domainAccent,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                              horizontal: AppSpacing.md,
                            ),
                          ),
                          onPressed: () => context.push(
                            '/lessons/${widget.lessonId}/exercises',
                          ),
                          icon: const Icon(Icons.quiz_rounded, size: 18),
                          label: const FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text('Défis QCM →', maxLines: 1),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
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
          onRetry: _loadLessonCacheFirst,
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
    final cardsMode = _isCardsMode(context);

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
            onPressed: () => _showTableOfContents(context, cardsMode),
          ),
        ],
      ),
      body: Column(
        children: [
          ProgressBar(value: _scrollRatio, height: 4, color: domainAccent),
          _buildReadingModeSwitch(cardsMode),
          Expanded(
            child: cardsMode
                ? _buildCardsModeBody(context, lesson, mdStyle, domainAccent)
                : SingleChildScrollView(
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
                            _buildLessonHeaderMeta(lesson, domainAccent),
                            const SizedBox(height: AppSpacing.lg),
                            for (var i = 0; i < _sections.length; i++) ...[
                              Container(
                                key: i < _sectionKeys.length
                                    ? _sectionKeys[i]
                                    : null,
                                child: _buildSectionBlock(
                                  context,
                                  _sections[i],
                                  mdStyle,
                                  domainAccent,
                                ),
                              ),
                              if (i < _sections.length - 1) ...[
                                const SizedBox(height: AppSpacing.lg),
                                if (_sections[i].sectionType !=
                                    SectionType.TITLE)
                                  const Divider(),
                                if (_sections[i].sectionType !=
                                    SectionType.TITLE)
                                  const SizedBox(height: AppSpacing.lg),
                              ],
                            ],
                            const SizedBox(height: AppSpacing.xl),
                            _buildCompletionCard(context),
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

  void _showTableOfContents(BuildContext context, bool cardsMode) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetCtx) {
        return SafeArea(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.sizeOf(context).height * 0.72,
            ),
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
                  if (cardsMode) {
                    _pageController.animateToPage(
                      index,
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeOutCubic,
                    );
                  } else if (index < _sectionKeys.length) {
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
          ),
        );
      },
    );
  }
}

class _CalloutBox extends StatelessWidget {
  final String title;
  final Color color;
  final IconData icon;
  final Widget child;

  const _CalloutBox({
    required this.title,
    required this.color,
    required this.icon,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border(
          left: BorderSide(color: color, width: 4),
          top: BorderSide(color: color.withValues(alpha: 0.25)),
          right: BorderSide(color: color.withValues(alpha: 0.25)),
          bottom: BorderSide(color: color.withValues(alpha: 0.25)),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 17, color: color),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  title.toUpperCase(),
                  style: context.text.labelSmall?.copyWith(
                    color: color,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs + 2),
          child,
        ],
      ),
    );
  }
}

class _ArchitectureFlowCard extends StatelessWidget {
  final List<String> steps;
  final Color accentColor;

  const _ArchitectureFlowCard({
    required this.steps,
    required this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    final isCompact = MediaQuery.sizeOf(context).width < 460;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: accentColor.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: accentColor.withValues(alpha: 0.28)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.account_tree_rounded,
                size: 16,
                color: accentColor,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'FLUX D\'ARCHITECTURE',
                  style: context.text.labelSmall?.copyWith(
                    color: accentColor,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.6,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm + 4),
          if (isCompact)
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (var i = 0; i < steps.length; i++) ...[
                  _FlowNodePill(
                    index: i + 1,
                    label: steps[i],
                    accentColor: accentColor,
                  ),
                  if (i < steps.length - 1)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Center(
                        child: Icon(
                          Icons.arrow_downward_rounded,
                          size: 18,
                          color: accentColor,
                        ),
                      ),
                    ),
                ],
              ],
            )
          else
            Wrap(
              spacing: 8,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                for (var i = 0; i < steps.length; i++) ...[
                  _FlowNodePill(
                    index: i + 1,
                    label: steps[i],
                    accentColor: accentColor,
                  ),
                  if (i < steps.length - 1)
                    Icon(
                      Icons.arrow_forward_rounded,
                      size: 18,
                      color: accentColor,
                    ),
                ],
              ],
            ),
        ],
      ),
    );
  }
}

class _FlowNodePill extends StatelessWidget {
  final int index;
  final String label;
  final Color accentColor;

  const _FlowNodePill({
    required this.index,
    required this.label,
    required this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: context.colors.surface,
        borderRadius: BorderRadius.circular(AppRadius.sm),
        border: Border.all(color: accentColor.withValues(alpha: 0.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 20,
            height: 20,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: accentColor.withValues(alpha: 0.14),
              shape: BoxShape.circle,
            ),
            child: Text(
              '$index',
              style: context.text.labelSmall?.copyWith(
                fontSize: 10.5,
                color: accentColor,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              label,
              style: context.text.labelMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _IdePreElementBuilder extends MarkdownElementBuilder {
  final bool isDiagramSection;

  _IdePreElementBuilder({this.isDiagramSection = false});

  @override
  Widget? visitElementAfter(element, TextStyle? preferredStyle) {
    final code = element.textContent.trimRight();
    if (code.isEmpty) return null;

    String? explicitLang;
    try {
      final children = element.children;
      if (children != null && children.isNotEmpty) {
        final first = children.first as dynamic;
        final attrs = first.attributes as Map<String, String>?;
        final cls = attrs?['class'];
        if (cls != null && cls.startsWith('language-')) {
          explicitLang = cls.substring('language-'.length).trim();
        }
      }
    } catch (_) {}

    if (explicitLang == null && isDiagramSection) {
      final inferred = IdeCodeBlock.inferLanguage(code);
      if (inferred == 'CODE') {
        explicitLang = 'SCHÉMA';
      }
    }

    return IdeCodeBlock(
      code: code,
      language: explicitLang,
    );
  }
}
