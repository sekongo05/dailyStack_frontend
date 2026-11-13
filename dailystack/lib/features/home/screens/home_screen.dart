import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/providers/app_providers.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/domain_badge.dart';
import '../../../core/widgets/state_views.dart';
import '../../learning/models/lesson_models.dart';
import '../../practice/models/practice_models.dart';

final todayLessonProvider = FutureProvider.autoDispose<DailyLessonSummary>((ref) async {
  final localDb = ref.watch(localDatabaseProvider);
  try {
    final lesson = await ref.watch(lessonServiceProvider).getTodayLesson();
    await localDb.setMetadata('todayLesson', jsonEncode(lesson.toJson()));
    return lesson;
  } catch (_) {
    final cached = await localDb.getMetadata('todayLesson');
    if (cached != null) {
      return DailyLessonSummary.fromJson(
        jsonDecode(cached) as Map<String, dynamic>,
      );
    }
    rethrow;
  }
});

final dueReviewsProvider = FutureProvider.autoDispose<List<ConceptMasterySummary>>((ref) async {
  try {
    return await ref.watch(practiceServiceProvider).getDueReviews();
  } catch (_) {
    return [];
  }
});

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final todayAsync = ref.watch(todayLessonProvider);
    final dueReviewsAsync = ref.watch(dueReviewsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Accueil')),
      body: todayAsync.when(
        loading: () => const AppLoadingView(message: 'Chargement de votre leçon du jour...'),
        error: (err, _) => AppErrorView(
          message: err.toString(),
          onRetry: () {
            ref.invalidate(todayLessonProvider);
            ref.invalidate(dueReviewsProvider);
          },
        ),
        data: (lesson) {
          final isInProgress = lesson.status == LessonProgressStatus.IN_PROGRESS;
          final isCompleted = lesson.status == LessonProgressStatus.COMPLETED;
          final dueReviews = dueReviewsAsync.valueOrNull ?? [];

          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(todayLessonProvider);
              ref.invalidate(dueReviewsProvider);
            },
            child: ListView(
              padding: const EdgeInsets.all(AppSpacing.md),
              children: [
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            DomainBadge(domainCode: lesson.domainCode),
                            Text(
                              '${lesson.estimatedMinutes} min • Jour ${lesson.sequenceDay}',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ],
                        ),
                        const SizedBox(height: AppSpacing.md),
                        Text(
                          lesson.title,
                          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                        ),
                        const SizedBox(height: AppSpacing.md),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: () async {
                              await context.push('/lessons/${lesson.id}');
                              ref.invalidate(todayLessonProvider);
                            },
                            icon: Icon(
                              isInProgress
                                  ? Icons.play_arrow_rounded
                                  : isCompleted
                                      ? Icons.refresh_rounded
                                      : Icons.menu_book_rounded,
                            ),
                            label: Text(
                              isInProgress
                                  ? 'Continuer'
                                  : isCompleted
                                      ? 'Relire la leçon'
                                      : 'Commencer',
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                if (dueReviews.isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.md),
                  Card(
                    child: InkWell(
                      borderRadius: BorderRadius.circular(16),
                      onTap: () async {
                        await context.push('/reviews');
                        ref.invalidate(dueReviewsProvider);
                      },
                      child: Padding(
                        padding: const EdgeInsets.all(AppSpacing.md),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.auto_awesome_rounded,
                              color: AppColors.warning,
                              semanticLabel: 'Révision disponible',
                            ),
                            const SizedBox(width: AppSpacing.md),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Une révision est disponible aujourd\'hui',
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleSmall
                                        ?.copyWith(fontWeight: FontWeight.w600),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    '${dueReviews.length} notion(s) à réviser',
                                    style: Theme.of(context).textTheme.bodySmall,
                                  ),
                                ],
                              ),
                            ),
                            const Icon(Icons.chevron_right_rounded),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          );
        },
      ),
    );
  }
}
