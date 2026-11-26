import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/providers/app_providers.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/ide_code_block.dart';
import '../../../core/widgets/state_views.dart';
import '../../../core/widgets/ui.dart';
import '../models/practice_models.dart';
import '../widgets/mastery_badge.dart';

String sanitizeQuizMarkdown(String raw) {
  if (raw.isEmpty) return raw;
  return raw
      .replaceAll(r'\r\n', '\n')
      .replaceAll(r'\n', '\n')
      .replaceAll(r'\t', '  ')
      .replaceAll(r'\"', '"')
      .replaceAll(r'\times', '×')
      .replaceAll(r'\le', '≤')
      .replaceAll(r'\ge', '≥')
      .trim();
}

class ExercisesScreen extends ConsumerStatefulWidget {
  final int lessonId;

  const ExercisesScreen({super.key, required this.lessonId});

  @override
  ConsumerState<ExercisesScreen> createState() => _ExercisesScreenState();
}

class _ExercisesScreenState extends ConsumerState<ExercisesScreen> {
  static const _letters = ['A', 'B', 'C', 'D', 'E', 'F'];

  final TextEditingController _textController = TextEditingController();
  List<Exercise> _exercises = [];
  int _currentIndex = 0;
  int? _selectedOptionId;
  final List<int> _selectedOrderIds = [];
  int _confidenceLevel = 2; // 1 = Difficile, 2 = Bien, 3 = Facile
  EvaluationResult? _result;
  int _earnedPoints = 0;
  int _correctCount = 0;
  bool _sessionFinished = false;
  bool _isLoading = true;
  bool _isSubmitting = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadExercises();
  }

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  Future<void> _loadExercises() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final list = await ref
          .read(practiceServiceProvider)
          .getExercisesForLesson(widget.lessonId);
      if (!mounted) return;
      setState(() {
        _exercises = list;
        _currentIndex = 0;
        _selectedOptionId = null;
        _selectedOrderIds.clear();
        _confidenceLevel = 2;
        _result = null;
        _earnedPoints = 0;
        _correctCount = 0;
        _sessionFinished = false;
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

  bool _isOrderingChallenge(Exercise exercise) {
    return exercise.type == ExerciseType.SHORT_CHALLENGE &&
        exercise.options.isNotEmpty;
  }

  void _toggleOrderedOption(int optionId) {
    if (_result != null) return;
    HapticFeedback.selectionClick();
    setState(() {
      if (_selectedOrderIds.contains(optionId)) {
        _selectedOrderIds.remove(optionId);
      } else {
        _selectedOrderIds.add(optionId);
      }
    });
  }

  void _resetOrder() {
    if (_result != null) return;
    HapticFeedback.lightImpact();
    setState(_selectedOrderIds.clear);
  }

  Future<void> _submit() async {
    final exercise = _exercises[_currentIndex];
    final hasOptions = exercise.options.isNotEmpty;
    final isOrdering = _isOrderingChallenge(exercise);

    if (isOrdering && _selectedOrderIds.length != exercise.options.length) {
      return;
    }
    if (!isOrdering && hasOptions && _selectedOptionId == null) return;
    if (!hasOptions && _textController.text.trim().isEmpty) return;

    setState(() => _isSubmitting = true);
    final selectedOpt = (!isOrdering && hasOptions) ? _selectedOptionId : null;
    final orderedIds = isOrdering ? List<int>.from(_selectedOrderIds) : null;
    final textAnswer = hasOptions ? null : _textController.text.trim();

    try {
      final result = await ref.read(practiceServiceProvider).submitAnswer(
            exerciseId: exercise.id,
            selectedOptionId: selectedOpt,
            orderedOptionIds: orderedIds,
            submittedText: textAnswer,
            confidenceLevel: _confidenceLevel,
          );
      if (!mounted) return;
      HapticFeedback.mediumImpact();
      setState(() {
        _result = result;
        _earnedPoints += result.scoreEarned;
        if (result.correct) {
          _correctCount++;
        }
      });
    } catch (_) {
      await ref.read(offlineSyncProvider.notifier).queueAttempt(
            exerciseId: exercise.id,
            selectedOptionId: selectedOpt,
            orderedOptionIds: orderedIds,
            submittedText: textAnswer,
            confidenceLevel: _confidenceLevel,
          );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Données stockées localement - en attente de synchronisation',
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  void _retryCurrentQuestion() {
    setState(() {
      _selectedOptionId = null;
      _selectedOrderIds.clear();
      _result = null;
    });
  }

  void _nextExercise() {
    if (_currentIndex < _exercises.length - 1) {
      setState(() {
        _currentIndex++;
        _selectedOptionId = null;
        _selectedOrderIds.clear();
        _confidenceLevel = 2;
        _textController.clear();
        _result = null;
      });
    } else {
      setState(() => _sessionFinished = true);
    }
  }

  void _restartQuiz() {
    setState(() {
      _currentIndex = 0;
      _selectedOptionId = null;
      _selectedOrderIds.clear();
      _confidenceLevel = 2;
      _textController.clear();
      _result = null;
      _earnedPoints = 0;
      _correctCount = 0;
      _sessionFinished = false;
    });
  }

  (String label, Color color, IconData icon) _formatBadgeMeta(
    ExerciseType type,
  ) {
    return switch (type) {
      ExerciseType.CODE_SNIPPET => (
          'Diagnostic de code',
          AppColors.devops,
          Icons.terminal_rounded,
        ),
      ExerciseType.SHORT_CHALLENGE => (
          'Ordonner les étapes',
          AppColors.backend,
          Icons.format_list_numbered_rounded,
        ),
      _ => (
          'QCM Conceptuel',
          AppColors.brand,
          Icons.quiz_outlined,
        ),
    };
  }

  MarkdownStyleSheet _inlineMarkdownStyle(
    BuildContext context, {
    TextStyle? baseStyle,
  }) {
    final pStyle = baseStyle ?? context.text.bodyLarge;
    return MarkdownStyleSheet.fromTheme(Theme.of(context)).copyWith(
      p: pStyle,
      pPadding: EdgeInsets.zero,
      code: pStyle?.copyWith(
        fontFamily: 'monospace',
        fontWeight: FontWeight.w600,
        backgroundColor: context.palette.surfaceAlt,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Défis pratiques')),
        body: const AppLoadingView(message: 'Chargement des défis...'),
      );
    }

    if (_error != null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Défis pratiques')),
        body: AppErrorView(message: _error!, onRetry: _loadExercises),
      );
    }

    if (_exercises.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('Défis pratiques')),
        body: AppEmptyView(
          title: 'Aucun exercice disponible',
          subtitle: 'Cette leçon ne possède pas encore de défi pratique.',
          icon: Icons.quiz_outlined,
          onAction: () => context.pop(),
          actionLabel: 'Retour à la leçon',
        ),
      );
    }

    if (_sessionFinished) {
      return _buildSummaryScreen(context);
    }

    final exercise = _exercises[_currentIndex];
    final isOrdering = _isOrderingChallenge(exercise);
    final options = [...exercise.options]
      ..sort((a, b) => a.orderIndex.compareTo(b.orderIndex));
    final isLast = _currentIndex == _exercises.length - 1;

    final canSubmit = _result == null &&
        !_isSubmitting &&
        (isOrdering
            ? _selectedOrderIds.length == options.length
            : (options.isNotEmpty
                ? _selectedOptionId != null
                : _textController.text.trim().isNotEmpty));

    final (formatLabel, formatColor, formatIcon) =
        _formatBadgeMeta(exercise.type);

    return Scaffold(
      appBar: AppBar(
        title: Text('Défi ${_currentIndex + 1} sur ${_exercises.length}'),
        actions: [
          IconButton(
            tooltip: 'Relire la leçon',
            icon: const Icon(Icons.menu_book_outlined),
            onPressed: () => context.push('/lessons/${widget.lessonId}'),
          ),
        ],
      ),
      body: Column(
        children: [
          ProgressBar(
            value: (_currentIndex + 1) / _exercises.length,
            height: 4,
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 680),
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 220),
                    child: KeyedSubtree(
                      key: ValueKey<int>(exercise.id),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Wrap(
                            spacing: AppSpacing.sm,
                            runSpacing: AppSpacing.xs,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              TagPill(
                                label: formatLabel,
                                color: formatColor,
                                icon: formatIcon,
                              ),
                              if (exercise.conceptName != null)
                                TagPill(
                                  label: sanitizeQuizMarkdown(
                                    exercise.conceptName!,
                                  ),
                                  color: AppColors.brand,
                                  icon: Icons.lightbulb_outline_rounded,
                                ),
                              TagPill(
                                label: '${exercise.points} pts',
                                color: AppColors.streak,
                                icon: Icons.bolt_rounded,
                              ),
                            ],
                          ),
                          const SizedBox(height: AppSpacing.md),
                          MarkdownBody(
                            data: sanitizeQuizMarkdown(exercise.question),
                            styleSheet: _inlineMarkdownStyle(
                              context,
                              baseStyle: context.text.titleLarge,
                            ),
                          ),
                          if (exercise.codeSnippet != null &&
                              exercise.codeSnippet!.trim().isNotEmpty) ...[
                            const SizedBox(height: AppSpacing.md),
                            IdeCodeBlock(code: exercise.codeSnippet!),
                          ],
                          const SizedBox(height: AppSpacing.lg),
                          if (isOrdering) ...[
                            _buildOrderingChallengeSection(context, options),
                          ] else if (options.isNotEmpty) ...[
                            for (var idx = 0; idx < options.length; idx++)
                              _buildOptionTile(
                                context,
                                options[idx],
                                idx < _letters.length
                                    ? _letters[idx]
                                    : '${idx + 1}',
                              ),
                          ] else ...[
                            TextField(
                              controller: _textController,
                              enabled: _result == null,
                              maxLines: 5,
                              onChanged: (_) => setState(() {}),
                              decoration: const InputDecoration(
                                labelText: 'Votre réponse',
                                alignLabelWithHint: true,
                              ),
                            ),
                          ],
                          if (_result != null) ...[
                            const SizedBox(height: AppSpacing.md),
                            if (isOrdering &&
                                !_result!.correct &&
                                _result!.correctOrderedOptionIds != null &&
                                _result!.correctOrderedOptionIds!.isNotEmpty) ...[
                              _OrderedSolutionCard(
                                correctOrderedIds:
                                    _result!.correctOrderedOptionIds!,
                                options: options,
                              ),
                              const SizedBox(height: AppSpacing.md),
                            ],
                            _FeedbackCard(
                              result: _result!,
                              onRetry: !_result!.correct
                                  ? _retryCurrentQuestion
                                  : null,
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.md,
                AppSpacing.sm,
                AppSpacing.md,
                AppSpacing.md,
              ),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 680),
                  child: _result == null
                      ? Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            _ConfidenceSelector(
                              selectedLevel: _confidenceLevel,
                              onChanged: (lvl) {
                                HapticFeedback.selectionClick();
                                setState(() => _confidenceLevel = lvl);
                              },
                            ),
                            const SizedBox(height: AppSpacing.sm + 2),
                            PrimaryButton(
                              label: isOrdering
                                  ? 'Valider l\'ordre (${_selectedOrderIds.length}/${options.length})'
                                  : 'Valider ma réponse',
                              isLoading: _isSubmitting,
                              onPressed: canSubmit ? _submit : null,
                            ),
                          ],
                        )
                      : PrimaryButton(
                          label: isLast ? 'Voir mon bilan' : 'Défi suivant',
                          icon: isLast
                              ? Icons.emoji_events_outlined
                              : Icons.arrow_forward_rounded,
                          onPressed: _nextExercise,
                        ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOrderingChallengeSection(
    BuildContext context,
    List<ExerciseOption> options,
  ) {
    final hasSubmitted = _result != null;
    final correctOrder = _result?.correctOrderedOptionIds;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Icon(
              Icons.touch_app_rounded,
              size: 16,
              color: context.palette.textMuted,
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                'Touchez les cartes dans l\'ordre chronologique (1 → ${options.length}).',
                style: context.text.bodySmall,
              ),
            ),
            if (!hasSubmitted && _selectedOrderIds.isNotEmpty)
              TextButton.icon(
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                ),
                onPressed: _resetOrder,
                icon: const Icon(Icons.restart_alt_rounded, size: 17),
                label: const Text('Réinitialiser'),
              ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        for (final opt in options)
          Builder(
            builder: (context) {
              final chosenPos = _selectedOrderIds.indexOf(opt.id);
              final isSelected = chosenPos != -1;
              final stepNumber = isSelected ? chosenPos + 1 : null;

              var isPositionCorrect = false;
              var isPositionWrong = false;
              if (hasSubmitted && isSelected) {
                if (_result!.correct) {
                  isPositionCorrect = true;
                } else if (correctOrder != null &&
                    chosenPos < correctOrder.length) {
                  isPositionCorrect = correctOrder[chosenPos] == opt.id;
                  isPositionWrong = !isPositionCorrect;
                } else {
                  isPositionWrong = true;
                }
              }

              Color? cardBg;
              Color? borderColor;
              var badgeColor = context.palette.textMuted;
              IconData? trailingIcon;

              if (isPositionCorrect) {
                cardBg = AppColors.success.withValues(alpha: 0.10);
                borderColor = AppColors.success;
                badgeColor = AppColors.success;
                trailingIcon = Icons.check_circle_rounded;
              } else if (isPositionWrong) {
                cardBg = AppColors.warning.withValues(alpha: 0.10);
                borderColor = AppColors.warning;
                badgeColor = AppColors.warning;
                trailingIcon = Icons.swap_vert_circle_outlined;
              } else if (isSelected) {
                cardBg = AppColors.backend.withValues(alpha: 0.09);
                borderColor = AppColors.backend;
                badgeColor = AppColors.backend;
              }

              return Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.sm + 2),
                child: SurfaceCard(
                  onTap:
                      hasSubmitted ? null : () => _toggleOrderedOption(opt.id),
                  color: cardBg,
                  borderColor: borderColor,
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md,
                    vertical: 14,
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 32,
                        height: 32,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: isSelected
                              ? badgeColor
                              : badgeColor.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(9),
                          border: Border.all(
                            color: badgeColor.withValues(alpha: 0.45),
                          ),
                        ),
                        child: stepNumber != null
                            ? Text(
                                '$stepNumber',
                                style: context.text.labelLarge?.copyWith(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w800,
                                ),
                              )
                            : Icon(
                                Icons.drag_indicator_rounded,
                                size: 16,
                                color: context.palette.textMuted,
                              ),
                      ),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: MarkdownBody(
                          data: sanitizeQuizMarkdown(opt.text),
                          styleSheet: _inlineMarkdownStyle(
                            context,
                            baseStyle: context.text.bodyLarge?.copyWith(
                              fontWeight: isSelected
                                  ? FontWeight.w600
                                  : FontWeight.w400,
                            ),
                          ),
                        ),
                      ),
                      if (trailingIcon != null) ...[
                        const SizedBox(width: AppSpacing.sm),
                        Icon(trailingIcon, color: badgeColor, size: 22),
                      ],
                    ],
                  ),
                ),
              );
            },
          ),
      ],
    );
  }

  Widget _buildOptionTile(
    BuildContext context,
    ExerciseOption opt,
    String letter,
  ) {
    final isSelected = _selectedOptionId == opt.id;
    final hasSubmitted = _result != null;
    final isCorrectOption = hasSubmitted &&
        (_result!.correctOptionId == opt.id ||
            (isSelected && _result!.correct));
    final isWrongSelected = hasSubmitted && isSelected && !_result!.correct;

    Color? cardBg;
    Color? borderColor;
    Color badgeColor = context.palette.textMuted;
    IconData? trailingIcon;

    if (isCorrectOption) {
      cardBg = AppColors.success.withValues(alpha: 0.10);
      borderColor = AppColors.success;
      badgeColor = AppColors.success;
      trailingIcon = Icons.check_circle_rounded;
    } else if (isWrongSelected) {
      cardBg = AppColors.warning.withValues(alpha: 0.10);
      borderColor = AppColors.warning;
      badgeColor = AppColors.warning;
      trailingIcon = Icons.cancel_rounded;
    } else if (isSelected) {
      cardBg = AppColors.brand.withValues(alpha: 0.08);
      borderColor = AppColors.brand;
      badgeColor = AppColors.brand;
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm + 2),
      child: SurfaceCard(
        onTap: hasSubmitted
            ? null
            : () {
                HapticFeedback.selectionClick();
                setState(() => _selectedOptionId = opt.id);
              },
        color: cardBg,
        borderColor: borderColor,
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: 14,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              width: 30,
              height: 30,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: badgeColor.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: badgeColor.withValues(alpha: 0.45)),
              ),
              child: Text(
                letter,
                style: context.text.labelLarge?.copyWith(
                  color: badgeColor,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: MarkdownBody(
                data: sanitizeQuizMarkdown(opt.text),
                styleSheet: _inlineMarkdownStyle(
                  context,
                  baseStyle: context.text.bodyLarge?.copyWith(
                    fontWeight: (isSelected || isCorrectOption)
                        ? FontWeight.w600
                        : FontWeight.w400,
                  ),
                ),
              ),
            ),
            if (trailingIcon != null) ...[
              const SizedBox(width: AppSpacing.sm),
              Icon(trailingIcon, color: badgeColor, size: 22),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryScreen(BuildContext context) {
    final totalPoints =
        _exercises.fold<int>(0, (sum, item) => sum + item.points);
    final ratio =
        _exercises.isNotEmpty ? _correctCount / _exercises.length : 1.0;
    final percent = (ratio * 100).round();
    final isGreat = ratio >= 0.75;
    final accent = isGreat ? AppColors.success : AppColors.brand;

    return Scaffold(
      appBar: AppBar(title: const Text('Bilan des défis')),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: SurfaceCard(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ProgressRing(
                    value: ratio.clamp(0.0, 1.0),
                    size: 96,
                    stroke: 8,
                    color: accent,
                    center: Text(
                      '$percent%',
                      style:
                          context.text.headlineSmall?.copyWith(color: accent),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  Text(
                    isGreat
                        ? 'Excellent travail !'
                        : 'Belle progression, continuez !',
                    style: context.text.headlineSmall,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    '$_correctCount sur ${_exercises.length} défi(s) réussi(s) · +$_earnedPoints / $totalPoints pts',
                    style: context.text.bodyMedium?.copyWith(
                      color: context.palette.textMuted,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  PrimaryButton(
                    label: 'Terminer',
                    icon: Icons.check_rounded,
                    onPressed: () => context.pop(),
                  ),
                  const SizedBox(height: AppSpacing.sm + 2),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: _restartQuiz,
                      icon: const Icon(Icons.replay_rounded),
                      label: const Text('Refaire les défis pour consolider'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ConfidenceSelector extends StatelessWidget {
  final int selectedLevel;
  final ValueChanged<int> onChanged;

  const _ConfidenceSelector({
    required this.selectedLevel,
    required this.onChanged,
  });

  static const _items = [
    (level: 1, label: 'Difficile', color: AppColors.warning),
    (level: 2, label: 'Bien', color: AppColors.brand),
    (level: 3, label: 'Facile', color: AppColors.success),
  ];

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          'Ressenti :',
          style: context.text.labelMedium?.copyWith(
            color: context.palette.textMuted,
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        for (final item in _items) ...[
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 3),
              child: ChoiceChip(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
                labelPadding: EdgeInsets.zero,
                label: SizedBox(
                  width: double.infinity,
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      item.label,
                      maxLines: 1,
                      textAlign: TextAlign.center,
                      style: context.text.labelSmall?.copyWith(
                        color: selectedLevel == item.level
                            ? item.color
                            : context.palette.textMuted,
                        fontWeight: selectedLevel == item.level
                            ? FontWeight.w700
                            : FontWeight.w500,
                      ),
                    ),
                  ),
                ),
                selected: selectedLevel == item.level,
                selectedColor: item.color.withValues(alpha: 0.14),
                side: BorderSide(
                  color: selectedLevel == item.level
                      ? item.color.withValues(alpha: 0.6)
                      : context.palette.border,
                ),
                onSelected: (_) => onChanged(item.level),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _OrderedSolutionCard extends StatelessWidget {
  final List<int> correctOrderedIds;
  final List<ExerciseOption> options;

  const _OrderedSolutionCard({
    required this.correctOrderedIds,
    required this.options,
  });

  @override
  Widget build(BuildContext context) {
    final optionById = {for (final opt in options) opt.id: opt};

    return SurfaceCard(
      color: AppColors.success.withValues(alpha: 0.07),
      borderColor: AppColors.success.withValues(alpha: 0.40),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.format_list_numbered_rounded,
                size: 18,
                color: AppColors.success,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'Séquence exacte attendue (1 → ${correctOrderedIds.length})',
                  style: context.text.titleSmall?.copyWith(
                    color: AppColors.success,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm + 2),
          for (var i = 0; i < correctOrderedIds.length; i++) ...[
            if (optionById[correctOrderedIds[i]] != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 22,
                      height: 22,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: AppColors.success,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        '${i + 1}',
                        style: context.text.labelSmall?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        sanitizeQuizMarkdown(
                          optionById[correctOrderedIds[i]]!.text,
                        ),
                        style: context.text.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ],
      ),
    );
  }
}

class _FeedbackCard extends StatelessWidget {
  final EvaluationResult result;
  final VoidCallback? onRetry;

  const _FeedbackCard({required this.result, this.onRetry});

  @override
  Widget build(BuildContext context) {
    final color = result.correct ? AppColors.success : AppColors.warning;
    final icon =
        result.correct ? Icons.check_rounded : Icons.lightbulb_rounded;
    final title = result.correct
        ? 'Bonne réponse ! (+${result.scoreEarned} pts)'
        : 'À consolider — Regardez la solution en vert';

    final mdStyle = MarkdownStyleSheet.fromTheme(Theme.of(context)).copyWith(
      p: context.text.bodyMedium?.copyWith(height: 1.5),
      pPadding: EdgeInsets.zero,
      code: context.text.bodyMedium?.copyWith(
        fontFamily: 'monospace',
        fontWeight: FontWeight.w600,
        backgroundColor: context.palette.surfaceAlt,
      ),
    );

    return SurfaceCard(
      color: color.withValues(alpha: 0.06),
      borderColor: color.withValues(alpha: 0.35),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              IconTile(icon: icon, color: color, size: 38),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Text(
                  title,
                  style: context.text.titleMedium?.copyWith(color: color),
                ),
              ),
            ],
          ),
          if (result.optionFeedback != null &&
              result.optionFeedback!.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.md),
            MarkdownBody(
              data: sanitizeQuizMarkdown(result.optionFeedback!),
              styleSheet: mdStyle.copyWith(
                p: context.text.titleSmall?.copyWith(height: 1.45),
              ),
            ),
          ],
          if (result.explanation.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.sm + 2),
            MarkdownBody(
              data: sanitizeQuizMarkdown(result.explanation),
              styleSheet: mdStyle,
            ),
          ],
          if (result.reviewIntervalDays != null) ...[
            const SizedBox(height: AppSpacing.md),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.brand.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(AppRadius.sm),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.event_repeat_rounded,
                    size: 16,
                    color: AppColors.brand,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Prochaine révision programmée dans ${result.reviewIntervalDays} jour(s)',
                      style: context.text.labelMedium?.copyWith(
                        color: AppColors.brand,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          if (onRetry != null) ...[
            const SizedBox(height: AppSpacing.md),
            TextButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.replay_rounded, size: 18),
              label: const Text('Réessayer cette question'),
            ),
          ],
          const SizedBox(height: AppSpacing.sm),
          const Divider(),
          const SizedBox(height: AppSpacing.sm + 4),
          SizedBox(
            width: double.infinity,
            child: Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.xs,
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text('Maîtrise de la notion', style: context.text.bodySmall),
                MasteryBadge(level: result.conceptMasteryLevel),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
