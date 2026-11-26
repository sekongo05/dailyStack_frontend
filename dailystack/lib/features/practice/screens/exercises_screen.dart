import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/providers/app_providers.dart';
import '../../../core/theme/app_theme.dart';
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

  Future<void> _submit() async {
    final exercise = _exercises[_currentIndex];
    final hasOptions = exercise.options.isNotEmpty;

    if (hasOptions && _selectedOptionId == null) return;
    if (!hasOptions && _textController.text.trim().isEmpty) return;

    setState(() => _isSubmitting = true);
    final selectedOpt = hasOptions ? _selectedOptionId : null;
    final textAnswer = hasOptions ? null : _textController.text.trim();
    try {
      final result = await ref.read(practiceServiceProvider).submitAnswer(
            exerciseId: exercise.id,
            selectedOptionId: selectedOpt,
            submittedText: textAnswer,
          );
      if (!mounted) return;
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
            submittedText: textAnswer,
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
      _result = null;
    });
  }

  void _nextExercise() {
    if (_currentIndex < _exercises.length - 1) {
      setState(() {
        _currentIndex++;
        _selectedOptionId = null;
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
      _textController.clear();
      _result = null;
      _earnedPoints = 0;
      _correctCount = 0;
      _sessionFinished = false;
    });
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
        appBar: AppBar(title: const Text('Quiz pratique')),
        body: const AppLoadingView(message: 'Chargement du QCM...'),
      );
    }

    if (_error != null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Quiz pratique')),
        body: AppErrorView(message: _error!, onRetry: _loadExercises),
      );
    }

    if (_exercises.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('Quiz pratique')),
        body: AppEmptyView(
          title: 'Aucun exercice disponible',
          subtitle: 'Cette leçon ne possède pas encore de QCM.',
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
    final options = [...exercise.options]
      ..sort((a, b) => a.orderIndex.compareTo(b.orderIndex));
    final isLast = _currentIndex == _exercises.length - 1;
    final canSubmit = _result == null &&
        !_isSubmitting &&
        (options.isNotEmpty
            ? _selectedOptionId != null
            : _textController.text.trim().isNotEmpty);

    return Scaffold(
      appBar: AppBar(
        title: Text('Question ${_currentIndex + 1} sur ${_exercises.length}'),
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
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Wrap(
                        spacing: AppSpacing.sm,
                        runSpacing: AppSpacing.xs,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          if (exercise.conceptName != null)
                            TagPill(
                              label: sanitizeQuizMarkdown(exercise.conceptName!),
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
                          exercise.codeSnippet!.isNotEmpty) ...[
                        const SizedBox(height: AppSpacing.md),
                        Container(
                          padding: const EdgeInsets.all(AppSpacing.md),
                          decoration: BoxDecoration(
                            color: context.palette.surfaceAlt,
                            borderRadius: BorderRadius.circular(AppRadius.md),
                            border: Border.all(color: context.palette.border),
                          ),
                          child: SelectableText(
                            exercise.codeSnippet!,
                            style: const TextStyle(
                              fontFamily: 'monospace',
                              fontSize: 13.5,
                              height: 1.5,
                            ),
                          ),
                        ),
                      ],
                      const SizedBox(height: AppSpacing.lg),
                      if (options.isNotEmpty)
                        for (var idx = 0; idx < options.length; idx++)
                          _buildOptionTile(
                            context,
                            options[idx],
                            idx < _letters.length ? _letters[idx] : '${idx + 1}',
                          )
                      else
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
                      if (_result != null) ...[
                        const SizedBox(height: AppSpacing.md),
                        _FeedbackCard(
                          result: _result!,
                          onRetry: !_result!.correct ? _retryCurrentQuestion : null,
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: _result == null
                  ? PrimaryButton(
                      label: 'Valider ma réponse',
                      isLoading: _isSubmitting,
                      onPressed: canSubmit ? _submit : null,
                    )
                  : PrimaryButton(
                      label: isLast ? 'Voir mon bilan' : 'Question suivante',
                      icon: isLast
                          ? Icons.emoji_events_outlined
                          : Icons.arrow_forward_rounded,
                      onPressed: _nextExercise,
                    ),
            ),
          ),
        ],
      ),
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
            : () => setState(() => _selectedOptionId = opt.id),
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
    final ratio = _exercises.isNotEmpty ? _correctCount / _exercises.length : 1.0;
    final percent = (ratio * 100).round();
    final isGreat = ratio >= 0.75;
    final accent = isGreat ? AppColors.success : AppColors.brand;

    return Scaffold(
      appBar: AppBar(title: const Text('Bilan du QCM')),
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
                      style: context.text.headlineSmall?.copyWith(color: accent),
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
                    '$_correctCount sur ${_exercises.length} réponse(s) juste(s) · +$_earnedPoints / $totalPoints pts',
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
                      label: const Text('Refaire le QCM pour consolider'),
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
        : 'À consolider — Regardez la réponse en vert';

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
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Maîtrise de la notion', style: context.text.bodySmall),
              MasteryBadge(level: result.conceptMasteryLevel),
            ],
          ),
        ],
      ),
    );
  }
}
