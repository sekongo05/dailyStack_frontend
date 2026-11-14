import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/providers/app_providers.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/state_views.dart';
import '../../../core/widgets/ui.dart';
import '../models/practice_models.dart';
import '../widgets/mastery_badge.dart';

class ExercisesScreen extends ConsumerStatefulWidget {
  final int lessonId;

  const ExercisesScreen({super.key, required this.lessonId});

  @override
  ConsumerState<ExercisesScreen> createState() => _ExercisesScreenState();
}

class _ExercisesScreenState extends ConsumerState<ExercisesScreen> {
  final TextEditingController _textController = TextEditingController();
  List<Exercise> _exercises = [];
  int _currentIndex = 0;
  int? _selectedOptionId;
  EvaluationResult? _result;
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
      setState(() => _result = result);
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

  void _nextExercise() {
    if (_currentIndex < _exercises.length - 1) {
      setState(() {
        _currentIndex++;
        _selectedOptionId = null;
        _textController.clear();
        _result = null;
      });
    } else {
      context.pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Exercices')),
        body: const AppLoadingView(message: 'Chargement des exercices...'),
      );
    }

    if (_error != null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Exercices')),
        body: AppErrorView(message: _error!, onRetry: _loadExercises),
      );
    }

    if (_exercises.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('Exercices')),
        body: AppEmptyView(
          title: 'Aucun exercice disponible',
          subtitle: 'Cette leçon ne possède pas encore d\'exercices pratiques.',
          icon: Icons.quiz_outlined,
          onAction: () => context.pop(),
          actionLabel: 'Retour à la leçon',
        ),
      );
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
        title: Text('Exercice ${_currentIndex + 1} sur ${_exercises.length}'),
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
                              label: exercise.conceptName!,
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
                      Text(
                        exercise.question,
                        style: context.text.titleLarge,
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
                        ...options.map((opt) {
                          final isSelected = _selectedOptionId == opt.id;
                          return Padding(
                            padding: const EdgeInsets.only(bottom: AppSpacing.sm + 2),
                            child: SurfaceCard(
                              onTap: _result != null
                                  ? null
                                  : () => setState(
                                        () => _selectedOptionId = opt.id,
                                      ),
                              color: isSelected
                                  ? AppColors.brand.withValues(alpha: 0.08)
                                  : null,
                              borderColor: isSelected ? AppColors.brand : null,
                              padding: const EdgeInsets.symmetric(
                                horizontal: AppSpacing.md,
                                vertical: 14,
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    isSelected
                                        ? Icons.radio_button_checked_rounded
                                        : Icons.radio_button_unchecked_rounded,
                                    color: isSelected
                                        ? AppColors.brand
                                        : context.palette.textMuted,
                                  ),
                                  const SizedBox(width: AppSpacing.md),
                                  Expanded(
                                    child: Text(
                                      opt.text,
                                      style: context.text.bodyLarge?.copyWith(
                                        fontWeight: isSelected
                                            ? FontWeight.w600
                                            : FontWeight.w400,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        })
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
                        _FeedbackCard(result: _result!),
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
                      label: isLast ? 'Terminer la session' : 'Exercice suivant',
                      icon: isLast
                          ? Icons.check_rounded
                          : Icons.arrow_forward_rounded,
                      onPressed: _nextExercise,
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FeedbackCard extends StatelessWidget {
  final EvaluationResult result;

  const _FeedbackCard({required this.result});

  @override
  Widget build(BuildContext context) {
    final color = result.correct ? AppColors.success : AppColors.warning;
    final icon =
        result.correct ? Icons.check_rounded : Icons.lightbulb_rounded;
    final title = result.correct
        ? 'Bonne réponse ! (+${result.scoreEarned} pts)'
        : 'À consolider — Explication';

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
            Text(
              result.optionFeedback!,
              style: context.text.titleSmall,
            ),
          ],
          if (result.explanation.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(result.explanation, style: context.text.bodyMedium),
          ],
          const SizedBox(height: AppSpacing.md),
          const Divider(),
          const SizedBox(height: AppSpacing.sm + 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Maîtrise', style: context.text.bodySmall),
              MasteryBadge(level: result.conceptMasteryLevel),
            ],
          ),
        ],
      ),
    );
  }
}
