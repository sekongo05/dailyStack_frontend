import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/providers/app_providers.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/domain_badge.dart';
import '../../../core/widgets/state_views.dart';
import '../../../core/widgets/ui.dart';
import '../../learning/models/lesson_models.dart';
import '../../notifications/screens/notifications_screen.dart';
import '../../practice/models/practice_models.dart';
import '../../watch/models/news_models.dart';

final todayLessonProvider = FutureProvider.autoDispose<DailyLessonSummary>((ref) async {
  final localDb = ref.watch(localDatabaseProvider);
  try {
    final lesson = await ref.watch(lessonServiceProvider).getTodayLesson();
    await localDb.setMetadata('todayLesson', jsonEncode(lesson.toJson()));
    return lesson;
  } catch (_) {
    final cached = await localDb.getMetadata('todayLesson');
    if (cached != null) {
      return DailyLessonSummary.fromJson(jsonDecode(cached) as Map<String, dynamic>);
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

final homeProgressProvider = FutureProvider.autoDispose<ProgressSummary?>((ref) async {
  try {
    return await ref.watch(practiceServiceProvider).getProgressSummary();
  } catch (_) {
    return null;
  }
});

final homeNewsProvider = FutureProvider.autoDispose<List<TechNewsSummary>>((ref) async {
  try {
    return await ref.watch(newsServiceProvider).getNews(size: 3);
  } catch (_) {
    return [];
  }
});

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  void _refreshAll(WidgetRef ref) {
    ref.invalidate(todayLessonProvider);
    ref.invalidate(dueReviewsProvider);
    ref.invalidate(homeProgressProvider);
    ref.invalidate(homeNewsProvider);
    ref.invalidate(notificationsListProvider);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final todayAsync = ref.watch(todayLessonProvider);

    return Scaffold(
      body: todayAsync.when(
        loading: () => const AppLoadingView(message: 'Préparation de votre journée...'),
        error: (err, _) => AppErrorView(message: err.toString(), onRetry: () => _refreshAll(ref)),
        data: (lesson) => RefreshIndicator(
          onRefresh: () async => _refreshAll(ref),
          child: ListView(
            padding: const EdgeInsets.only(bottom: AppSpacing.xl),
            children: [
              const _Greeting(),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: AppSpacing.sm),
                    _TodayLessonHero(
                      lesson: lesson,
                      onOpen: () async {
                        await context.push('/lessons/${lesson.id}');
                        _refreshAll(ref);
                      },
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    const _StatsRow(),
                    const _ReviewsCard(),
                    const SizedBox(height: AppSpacing.lg),
                    const _NewsPreview(),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Greeting extends ConsumerWidget {
  const _Greeting();

  static const _days = ['lundi', 'mardi', 'mercredi', 'jeudi', 'vendredi', 'samedi', 'dimanche'];
  static const _months = [
    'janvier', 'février', 'mars', 'avril', 'mai', 'juin',
    'juillet', 'août', 'septembre', 'octobre', 'novembre', 'décembre',
  ];

  String _todayLabel() {
    final now = DateTime.now();
    final day = _days[now.weekday - 1];
    return '${day[0].toUpperCase()}${day.substring(1)} ${now.day} ${_months[now.month - 1]}';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    final unread = ref.watch(notificationsListProvider).valueOrNull?.where((n) => !n.read).length ?? 0;
    final name = user?.username;

    return Padding(
      padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.md, AppSpacing.sm, 0),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_todayLabel(), style: context.text.bodySmall),
                const SizedBox(height: 2),
                Text(
                  name != null ? 'Bonjour, $name' : 'Bonjour',
                  style: context.text.headlineMedium,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          if (user != null) _StreakChip(days: user.streakDays),
          IconButton(
            tooltip: 'Notifications',
            onPressed: () async {
              await context.push('/notifications');
              ref.invalidate(notificationsListProvider);
            },
            icon: Badge(
              isLabelVisible: unread > 0,
              label: Text('$unread'),
              child: const Icon(Icons.notifications_none_rounded, size: 26),
            ),
          ),
        ],
      ),
    );
  }
}

class _StreakChip extends StatelessWidget {
  final int days;
  const _StreakChip({required this.days});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Série de $days jours',
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: AppColors.streak.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(AppRadius.pill),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.local_fire_department_rounded, color: AppColors.streak, size: 18),
            const SizedBox(width: 4),
            Text(
              '$days',
              style: context.text.labelLarge?.copyWith(color: AppColors.streak),
            ),
          ],
        ),
      ),
    );
  }
}

class _TodayLessonHero extends StatelessWidget {
  final DailyLessonSummary lesson;
  final VoidCallback onOpen;

  const _TodayLessonHero({required this.lesson, required this.onOpen});

  @override
  Widget build(BuildContext context) {
    final isInProgress = lesson.status == LessonProgressStatus.IN_PROGRESS;
    final isCompleted = lesson.status == LessonProgressStatus.COMPLETED;
    final (ctaLabel, ctaIcon) = isInProgress
        ? ('Continuer', Icons.play_arrow_rounded)
        : isCompleted
            ? ('Relire la leçon', Icons.replay_rounded)
            : ('Commencer', Icons.arrow_forward_rounded);
    final statusLabel = isCompleted
        ? 'Terminée aujourd\'hui'
        : isInProgress
            ? 'En cours'
            : 'Leçon du jour';

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadius.lg + 4),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.brand, AppColors.brandDark],
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.brand.withValues(alpha: 0.28),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      padding: const EdgeInsets.all(AppSpacing.lg - 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _HeroPill(
                icon: isCompleted ? Icons.check_circle_rounded : DomainBadge.iconFor(lesson.domainCode),
                label: statusLabel,
              ),
              const Spacer(),
              _HeroPill(icon: Icons.schedule_rounded, label: '${lesson.estimatedMinutes} min'),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          Text(
            'Jour ${lesson.sequenceDay} · ${DomainBadge.isBackend(lesson.domainCode) ? 'Backend' : 'DevOps'}',
            style: context.text.labelMedium?.copyWith(color: Colors.white.withValues(alpha: 0.8)),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            lesson.title,
            style: context.text.headlineSmall?.copyWith(color: Colors.white),
          ),
          if (isInProgress) ...[
            const SizedBox(height: AppSpacing.md),
            ClipRRect(
              borderRadius: BorderRadius.circular(AppRadius.pill),
              child: LinearProgressIndicator(
                value: lesson.scrollOffsetRatio.clamp(0.0, 1.0),
                minHeight: 6,
                color: Colors.white,
                backgroundColor: Colors.white.withValues(alpha: 0.25),
              ),
            ),
          ],
          const SizedBox(height: AppSpacing.lg),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: AppColors.brandDark,
              ),
              onPressed: onOpen,
              icon: Icon(ctaIcon),
              label: Text(ctaLabel),
            ),
          ),
        ],
      ),
    );
  }
}

class _HeroPill extends StatelessWidget {
  final IconData icon;
  final String label;
  const _HeroPill({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: Colors.white),
          const SizedBox(width: 5),
          Text(label, style: context.text.labelSmall?.copyWith(color: Colors.white)),
        ],
      ),
    );
  }
}

class _StatsRow extends ConsumerWidget {
  const _StatsRow();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summary = ref.watch(homeProgressProvider).valueOrNull;
    if (summary == null) return const SizedBox.shrink();

    return Row(
      children: [
        Expanded(
          child: StatTile(
            icon: Icons.local_fire_department_rounded,
            color: AppColors.streak,
            value: '${summary.streakDays}',
            label: 'Jours de suite',
          ),
        ),
        const SizedBox(width: AppSpacing.sm + 2),
        Expanded(
          child: StatTile(
            icon: Icons.menu_book_rounded,
            color: AppColors.brand,
            value: '${summary.totalLessonsCompleted}',
            label: 'Leçons',
          ),
        ),
        const SizedBox(width: AppSpacing.sm + 2),
        Expanded(
          child: StatTile(
            icon: Icons.verified_rounded,
            color: AppColors.success,
            value: '${summary.totalNotionsMastered}',
            label: 'Maîtrisées',
          ),
        ),
      ],
    );
  }
}

class _ReviewsCard extends ConsumerWidget {
  const _ReviewsCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reviews = ref.watch(dueReviewsProvider).valueOrNull ?? [];
    if (reviews.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.md),
      child: SurfaceCard(
        onTap: () async {
          await context.push('/reviews');
          ref.invalidate(dueReviewsProvider);
        },
        child: Row(
          children: [
            const IconTile(icon: Icons.auto_awesome_rounded, color: AppColors.warning),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Révision disponible', style: context.text.titleSmall),
                  const SizedBox(height: 2),
                  Text(
                    '${reviews.length} notion${reviews.length > 1 ? 's' : ''} à consolider aujourd\'hui',
                    style: context.text.bodySmall,
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: context.palette.textMuted),
          ],
        ),
      ),
    );
  }
}

class _NewsPreview extends ConsumerWidget {
  const _NewsPreview();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final news = ref.watch(homeNewsProvider).valueOrNull ?? [];
    if (news.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionHeader(
          title: 'À la une en tech',
          actionLabel: 'Tout voir',
          onAction: () => context.go('/watch'),
        ),
        SurfaceCard(
          padding: EdgeInsets.zero,
          child: Column(
            children: [
              for (var i = 0; i < news.length; i++) ...[
                if (i > 0) const Divider(indent: AppSpacing.md, endIndent: AppSpacing.md),
                _NewsRow(item: news[i]),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _NewsRow extends StatelessWidget {
  final TechNewsSummary item;
  const _NewsRow({required this.item});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => context.push('/watch/${item.id}'),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.targetTechnology.toUpperCase(),
                    style: context.text.labelSmall?.copyWith(color: AppColors.brand),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    item.title,
                    style: context.text.titleSmall,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Icon(Icons.chevron_right_rounded, color: context.palette.textMuted),
          ],
        ),
      ),
    );
  }
}
