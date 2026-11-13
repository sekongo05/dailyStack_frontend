import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/providers/app_providers.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/state_views.dart';
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
    } catch (e) {
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
        title: Text('Exercice ${_currentIndex + 1} / ${_exercises.length}'),
      ),
      body: Column(
        children: [
          LinearProgressIndicator(
            value: (_currentIndex + 1) / _exercises.length,
            minHeight: 5,
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      if (exercise.conceptName != null)
                        Flexible(
                          child: Chip(
                            label: Text(
                              exercise.conceptName!,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                      Text(
                        '${exercise.points} pts',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Text(
                    exercise.question,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  if (exercise.codeSnippet != null &&
                      exercise.codeSnippet!.isNotEmpty) ...[
                    const SizedBox(height: AppSpacing.md),
                    Container(
                      padding: const EdgeInsets.all(AppSpacing.md),
                      decoration: BoxDecoration(
                        color: Theme.of(context)
                            .colorScheme
                            .surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: SelectableText(
                        exercise.codeSnippet!,
                        style: const TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: AppSpacing.lg),
                  if (options.isNotEmpty)
                    ...options.map((opt) {
                      final isSelected = _selectedOptionId == opt.id;
                      return Padding(
                        padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                        child: InkWell(
                          onTap: _result != null
                              ? null
                              : () =>
                                  setState(() => _selectedOptionId = opt.id),
                          borderRadius: BorderRadius.circular(12),
                          child: Container(
                            constraints: const BoxConstraints(minHeight: 52),
                            padding: const EdgeInsets.symmetric(
                              horizontal: AppSpacing.md,
                              vertical: AppSpacing.sm,
                            ),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: isSelected
                                    ? Theme.of(context).colorScheme.primary
                                    : Theme.of(context).dividerColor,
                                width: isSelected ? 2 : 1,
                              ),
                              color: isSelected
                                  ? Theme.of(context)
                                      .colorScheme
                                      .primary
                                      .withValues(alpha: 0.08)
                                  : null,
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  isSelected
                                      ? Icons.radio_button_checked_rounded
                                      : Icons.radio_button_unchecked_rounded,
                                  color: isSelected
                                      ? Theme.of(context).colorScheme.primary
                                      : null,
                                ),
                                const SizedBox(width: AppSpacing.md),
                                Expanded(child: Text(opt.text)),
                              ],
                            ),
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
                        border: OutlineInputBorder(),
                      ),
                    ),
                  if (_result != null) ...[
                    const SizedBox(height: AppSpacing.lg),
                    _FeedbackCard(result: _result!),
                  ],
                ],
              ),
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: SizedBox(
                width: double.infinity,
                child: _result == null
                    ? ElevatedButton(
                        onPressed: canSubmit ? _submit : null,
                        child: _isSubmitting
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Text('Valider ma réponse'),
                      )
                    : ElevatedButton.icon(
                        onPressed: _nextExercise,
                        icon: Icon(
                          isLast
                              ? Icons.check_rounded
                              : Icons.arrow_forward_rounded,
                        ),
                        label: Text(
                          isLast ? 'Terminer la session' : 'Exercice suivant',
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

class _FeedbackCard extends StatelessWidget {
  final EvaluationResult result;

  const _FeedbackCard({required this.result});

  @override
  Widget build(BuildContext context) {
    final color = result.correct ? AppColors.success : AppColors.warning;
    final icon =
        result.correct ? Icons.check_circle_rounded : Icons.lightbulb_rounded;
    final title = result.correct
        ? 'Bonne réponse ! (+${result.scoreEarned} pts)'
        : 'À consolider — Voici l\'explication';

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: color, semanticLabel: title),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    title,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: color,
                        ),
                  ),
                ),
              ],
            ),
            if (result.optionFeedback != null &&
                result.optionFeedback!.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.sm),
              Text(
                result.optionFeedback!,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w500,
                    ),
              ),
            ],
            if (result.explanation.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.sm),
              Text(
                result.explanation,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ],
            const SizedBox(height: AppSpacing.md),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Maîtrise de la notion :'),
                MasteryBadge(level: result.conceptMasteryLevel),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

