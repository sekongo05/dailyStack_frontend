import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/providers/app_providers.dart';
import '../../../core/storage/local_database.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/domain_badge.dart';
import '../../../core/widgets/pwa_install_sheet.dart';
import '../../../core/widgets/state_views.dart';
import '../../../core/widgets/ui.dart';
import '../../learning/models/lesson_models.dart';
import '../../learning/services/lesson_service.dart';
import '../../notifications/screens/notifications_screen.dart';
import '../../practice/models/practice_models.dart';
import '../../watch/models/news_models.dart';

class HomeBootstrapState {
  final HomeBootstrap? bootstrap;
  final DailyLessonSummary? fallbackLesson;
  final bool isInitialLoading;
  final bool isRefreshing;
  final String? error;

  const HomeBootstrapState({
    this.bootstrap,
    this.fallbackLesson,
    this.isInitialLoading = true,
    this.isRefreshing = false,
    this.error,
  });

  DailyLessonSummary? get activeLesson =>
      bootstrap?.todayLesson ?? fallbackLesson;

  HomeBootstrapState copyWith({
    HomeBootstrap? bootstrap,
    DailyLessonSummary? fallbackLesson,
    bool? isInitialLoading,
    bool? isRefreshing,
    String? error,
    bool clearError = false,
  }) {
    return HomeBootstrapState(
      bootstrap: bootstrap ?? this.bootstrap,
      fallbackLesson: fallbackLesson ?? this.fallbackLesson,
      isInitialLoading: isInitialLoading ?? this.isInitialLoading,
      isRefreshing: isRefreshing ?? this.isRefreshing,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

class HomeBootstrapNotifier extends StateNotifier<HomeBootstrapState> {
  static const _bootstrapCacheKey = 'homeBootstrap_v1';
  static const _legacyTodayKey = 'todayLesson';
  static const _progressCacheKey = 'progressSummary_v1';

  final LessonService _lessonService;
  final LocalDatabase _localDb;

  HomeBootstrapNotifier({
    required this._lessonService,
    required this._localDb,
  }) : super(const HomeBootstrapState()) {
    _loadStaleWhileRevalidate();
  }

  Future<void> _loadStaleWhileRevalidate() async {
    try {
      final rawBootstrap = await _localDb.getMetadata(_bootstrapCacheKey);
      if (rawBootstrap != null && rawBootstrap.isNotEmpty) {
        final cachedBootstrap = HomeBootstrap.fromJson(
          jsonDecode(rawBootstrap) as Map<String, dynamic>,
        );
        if (mounted) {
          state = state.copyWith(
            bootstrap: cachedBootstrap,
            fallbackLesson: cachedBootstrap.todayLesson,
            isInitialLoading: false,
            isRefreshing: true,
            clearError: true,
          );
        }
      } else {
        final rawToday = await _localDb.getMetadata(_legacyTodayKey);
        if (rawToday != null && rawToday.isNotEmpty) {
          final cachedLesson = DailyLessonSummary.fromJson(
            jsonDecode(rawToday) as Map<String, dynamic>,
          );
          if (mounted) {
            state = state.copyWith(
              fallbackLesson: cachedLesson,
              isInitialLoading: false,
              isRefreshing: true,
              clearError: true,
            );
          }
        }
      }
    } catch (_) {
      // Cache absent ou obsolète : on poursuit sur le réseau.
    }

    await refresh();
  }

  Future<void> refresh() async {
    final hasCachedContent = state.activeLesson != null;
    if (mounted) {
      state = state.copyWith(
        isInitialLoading: !hasCachedContent,
        isRefreshing: hasCachedContent,
        clearError: true,
      );
    }

    try {
      final fresh = await _lessonService.getHomeBootstrap();
      await _persistBootstrap(fresh);
      if (!mounted) return;
      state = state.copyWith(
        bootstrap: fresh,
        fallbackLesson: fresh.todayLesson,
        isInitialLoading: false,
        isRefreshing: false,
        clearError: true,
      );
    } catch (_) {
      if (state.activeLesson != null) {
        if (mounted) {
          state = state.copyWith(
            isInitialLoading: false,
            isRefreshing: false,
          );
        }
        return;
      }

      // Repli vers l'endpoint unitaire si /home/bootstrap est momentanément indisponible.
      try {
        final today = await _lessonService.getTodayLesson();
        await _localDb.setMetadata(
          _legacyTodayKey,
          jsonEncode(today.toJson()),
        );
        if (!mounted) return;
        state = state.copyWith(
          fallbackLesson: today,
          isInitialLoading: false,
          isRefreshing: false,
          clearError: true,
        );
      } catch (fallbackErr) {
        if (!mounted) return;
        state = state.copyWith(
          isInitialLoading: false,
          isRefreshing: false,
          error: fallbackErr.toString(),
        );
      }
    }
  }

  Future<void> _persistBootstrap(HomeBootstrap bootstrap) async {
    try {
      await _localDb.setMetadata(
        _bootstrapCacheKey,
        jsonEncode(bootstrap.toJson()),
      );
      await _localDb.setMetadata(
        _legacyTodayKey,
        jsonEncode(bootstrap.todayLesson.toJson()),
      );
      if (bootstrap.progressSummary != null) {
        await _localDb.setMetadata(
          _progressCacheKey,
          jsonEncode(bootstrap.progressSummary!.toJson()),
        );
      }
      final lessonsToPrefetch = <LessonDetail>[
        if (bootstrap.todayLessonDetail != null) bootstrap.todayLessonDetail!,
        if (bootstrap.tomorrowLessonDetail != null)
          bootstrap.tomorrowLessonDetail!,
      ];
      if (lessonsToPrefetch.isNotEmpty) {
        await _localDb.cacheLessons(lessonsToPrefetch);
      }
      if (bootstrap.recentNews.isNotEmpty) {
        final existingNews = await _localDb.getCachedNews();
        if (existingNews.isEmpty) {
          await _localDb.cacheNews(bootstrap.recentNews);
        }
      }
    } catch (_) {}
  }
}

final homeBootstrapProvider =
    StateNotifierProvider<HomeBootstrapNotifier, HomeBootstrapState>(
  (ref) => HomeBootstrapNotifier(
    lessonService: ref.watch(lessonServiceProvider),
    localDb: ref.watch(localDatabaseProvider),
  ),
);

/// Conservé pour compatibilité avec les écrans invalidant `todayLessonProvider`.
final todayLessonProvider =
    FutureProvider.autoDispose<DailyLessonSummary>((ref) async {
  final state = ref.watch(homeBootstrapProvider);
  if (state.activeLesson != null) return state.activeLesson!;
  return ref.watch(lessonServiceProvider).getTodayLesson();
});

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  Future<void> _refreshAll(WidgetRef ref) async {
    await ref.read(homeBootstrapProvider.notifier).refresh();
    ref.invalidate(notificationsListProvider);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final homeState = ref.watch(homeBootstrapProvider);
    final lesson = homeState.activeLesson;

    if (homeState.isInitialLoading && lesson == null) {
      return const Scaffold(body: HomeSkeletonView());
    }

    if (lesson == null) {
      return Scaffold(
        body: AppErrorView(
          message: homeState.error ?? 'Impossible de charger votre accueil.',
          onRetry: () => _refreshAll(ref),
        ),
      );
    }

    final bootstrap = homeState.bootstrap;
    final tomorrowPreview = bootstrap?.tomorrowLessonPreview;
    final isTomorrowCached = bootstrap?.tomorrowLessonDetail != null;

    return Scaffold(
      body: RefreshIndicator(
        onRefresh: () => _refreshAll(ref),
        child: ListView(
          padding: const EdgeInsets.only(bottom: AppSpacing.xl),
          children: [
            _Greeting(
              bootstrap: bootstrap,
              isRefreshing: homeState.isRefreshing,
              onNotificationsTap: () async {
                await context.push('/notifications');
                await _refreshAll(ref);
              },
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: AppSpacing.sm),
                  const PwaInstallBanner(),
                  if (tomorrowPreview != null &&
                      MediaQuery.sizeOf(context).width >= 840)
                    IntrinsicHeight(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Expanded(
                            flex: 3,
                            child: _TodayLessonHero(
                              lesson: lesson,
                              onOpen: () async {
                                await context.push('/lessons/${lesson.id}');
                                await _refreshAll(ref);
                              },
                              onOpenExercises: () async {
                                await context.push(
                                  '/lessons/${lesson.id}/exercises',
                                );
                                await _refreshAll(ref);
                              },
                            ),
                          ),
                          const SizedBox(width: AppSpacing.md),
                          Expanded(
                            flex: 2,
                            child: _TomorrowPreviewCard(
                              lesson: tomorrowPreview,
                              isOfflineReady: isTomorrowCached,
                              onTap: () async {
                                await context.push(
                                  '/lessons/${tomorrowPreview.id}',
                                );
                                await _refreshAll(ref);
                              },
                            ),
                          ),
                        ],
                      ),
                    )
                  else ...[
                    _TodayLessonHero(
                      lesson: lesson,
                      onOpen: () async {
                        await context.push('/lessons/${lesson.id}');
                        await _refreshAll(ref);
                      },
                      onOpenExercises: () async {
                        await context.push('/lessons/${lesson.id}/exercises');
                        await _refreshAll(ref);
                      },
                    ),
                    if (tomorrowPreview != null) ...[
                      const SizedBox(height: AppSpacing.md),
                      _TomorrowPreviewCard(
                        lesson: tomorrowPreview,
                        isOfflineReady: isTomorrowCached,
                        onTap: () async {
                          await context.push('/lessons/${tomorrowPreview.id}');
                          await _refreshAll(ref);
                        },
                      ),
                    ],
                  ],
                  const SizedBox(height: AppSpacing.lg),
                  _StatsRow(summary: bootstrap?.progressSummary),
                  _DomainProgressMiniCard(summary: bootstrap?.progressSummary),
                  _ReviewsCard(
                    reviews: bootstrap?.dueReviews ?? const [],
                    onTap: () async {
                      await context.push('/reviews');
                      await _refreshAll(ref);
                    },
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  _NewsPreview(news: bootstrap?.recentNews ?? const []),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Greeting extends ConsumerWidget {
  final HomeBootstrap? bootstrap;
  final bool isRefreshing;
  final VoidCallback onNotificationsTap;

  const _Greeting({
    required this.bootstrap,
    required this.isRefreshing,
    required this.onNotificationsTap,
  });

  static const _days = [
    'lundi',
    'mardi',
    'mercredi',
    'jeudi',
    'vendredi',
    'samedi',
    'dimanche',
  ];
  static const _months = [
    'janvier',
    'février',
    'mars',
    'avril',
    'mai',
    'juin',
    'juillet',
    'août',
    'septembre',
    'octobre',
    'novembre',
    'décembre',
  ];

  String _todayLabel() {
    final now = DateTime.now();
    final day = _days[now.weekday - 1];
    return '${day[0].toUpperCase()}${day.substring(1)} ${now.day} ${_months[now.month - 1]}';
  }

  void _showStreakShieldSheet(
    BuildContext context, {
    required int shields,
    required bool usedRecently,
    required int completedLessons,
  }) {
    final lessonsIntoCycle = completedLessons % 7;
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg,
            0,
            AppSpacing.lg,
            AppSpacing.xl,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  const IconTile(
                    icon: Icons.shield_rounded,
                    color: AppColors.brand,
                    size: 46,
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Bouclier de série',
                          style: ctx.text.titleLarge,
                        ),
                        Text(
                          '$shields / 3 bouclier(s) disponible(s)',
                          style: ctx.text.bodySmall?.copyWith(
                            color: AppColors.brand,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                'Bouclier de série : protège automatiquement votre série si vous manquez 1 journée. +1 bouclier toutes les 7 leçons terminées (max 3).',
                style: ctx.text.bodyMedium,
              ),
              if (shields < 3) ...[
                const SizedBox(height: AppSpacing.md),
                ProgressBar(
                  value: lessonsIntoCycle / 7,
                  color: AppColors.brand,
                  height: 7,
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  '$lessonsIntoCycle / 7 leçons avant le prochain bouclier',
                  style: ctx.text.bodySmall?.copyWith(
                    color: ctx.palette.textMuted,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
              if (usedRecently) ...[
                const SizedBox(height: AppSpacing.md),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.success.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(AppRadius.md),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.verified_user_rounded,
                        size: 18,
                        color: AppColors.success,
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: Text(
                          'Un bouclier a récemment protégé votre série active !',
                          style: ctx.text.labelMedium?.copyWith(
                            color: AppColors.success,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: AppSpacing.lg),
              PrimaryButton(
                label: 'Parfait',
                onPressed: () => Navigator.of(ctx).pop(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    final unreadFromList = ref
        .watch(notificationsListProvider)
        .valueOrNull
        ?.where((n) => !n.read)
        .length;
    final unread = unreadFromList ?? bootstrap?.unreadNotificationsCount ?? 0;
    final streakDays =
        bootstrap?.progressSummary?.streakDays ?? user?.streakDays ?? 0;
    final shields = bootstrap?.streakShields ??
        bootstrap?.progressSummary?.streakShields ??
        user?.streakShields ??
        1;
    final shieldUsedRecently =
        bootstrap?.progressSummary?.shieldUsedRecently ?? false;
    final name = user?.username;
    final initial = (name != null && name.isNotEmpty)
        ? name[0].toUpperCase()
        : 'D';
    final showAvatar = MediaQuery.sizeOf(context).width >= 360;
    final levelBadge = user != null
        ? 'Niveau ${user.currentLevel} · ${DailyLessonSummary.levelLabel(user.currentLevel)}'
        : null;

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.sm + 4,
        AppSpacing.xs,
        0,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (showAvatar) ...[
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [AppColors.brand, AppColors.brandDark],
                    ),
                    borderRadius: BorderRadius.circular(13),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    initial,
                    style: context.text.titleMedium?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm + 4),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: AppSpacing.sm,
                      runSpacing: 4,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text(
                          _todayLabel(),
                          style: context.text.bodySmall,
                        ),
                        if (isRefreshing) const _SyncingPill(),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      name != null ? 'Bonjour, $name' : 'Bonjour',
                      style: context.text.headlineMedium,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (levelBadge != null) ...[
                      const SizedBox(height: 1),
                      Text(
                        levelBadge,
                        style: context.text.labelSmall?.copyWith(
                          color: AppColors.brand,
                          fontWeight: FontWeight.w700,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
              _StreakChip(days: streakDays),
              const SizedBox(width: 6),
              _StreakShieldChip(
                shields: shields,
                onTap: () => _showStreakShieldSheet(
                  context,
                  shields: shields,
                  usedRecently: shieldUsedRecently,
                  completedLessons:
                      bootstrap?.progressSummary?.totalLessonsCompleted ?? 0,
                ),
              ),
              IconButton(
                tooltip: 'Notifications',
                onPressed: onNotificationsTap,
                icon: Badge(
                  isLabelVisible: unread > 0,
                  label: Text('$unread'),
                  child: const Icon(Icons.notifications_none_rounded, size: 26),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SyncingPill extends StatelessWidget {
  const _SyncingPill();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: AppColors.brand.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(
            width: 10,
            height: 10,
            child: CircularProgressIndicator(
              strokeWidth: 1.8,
              color: AppColors.brand,
            ),
          ),
          const SizedBox(width: 5),
          Text(
            'Synchronisation…',
            style: context.text.labelSmall?.copyWith(
              fontSize: 10.5,
              color: AppColors.brand,
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
            const Icon(
              Icons.local_fire_department_rounded,
              color: AppColors.streak,
              size: 18,
            ),
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

class _StreakShieldChip extends StatelessWidget {
  final int shields;
  final VoidCallback onTap;

  const _StreakShieldChip({
    required this.shields,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Bouclier de série : $shields disponible(s)',
      child: Material(
        color: AppColors.brand.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppRadius.pill),
        child: InkWell(
          borderRadius: BorderRadius.circular(AppRadius.pill),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.shield_rounded,
                  color: AppColors.brand,
                  size: 17,
                ),
                const SizedBox(width: 4),
                Text(
                  '$shields',
                  style:
                      context.text.labelLarge?.copyWith(color: AppColors.brand),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _TodayLessonHero extends StatelessWidget {
  final DailyLessonSummary lesson;
  final VoidCallback onOpen;
  final VoidCallback onOpenExercises;

  const _TodayLessonHero({
    required this.lesson,
    required this.onOpen,
    required this.onOpenExercises,
  });

  @override
  Widget build(BuildContext context) {
    final isInProgress = lesson.status == LessonProgressStatus.IN_PROGRESS;
    final isCompleted = lesson.status == LessonProgressStatus.COMPLETED;
    final isBackend = DomainBadge.isBackend(lesson.domainCode);
    final accentColor = isBackend ? AppColors.backend : AppColors.devops;
    final gradientColors = isBackend
        ? const [Color(0xFF0F172A), Color(0xFF0A2E26)]
        : const [Color(0xFF0F172A), Color(0xFF0A273D)];
    final progressPercent =
        (lesson.scrollOffsetRatio.clamp(0.0, 1.0) * 100).round();

    final (ctaLabel, ctaIcon) = isInProgress
        ? ('Continuer ($progressPercent%)', Icons.play_arrow_rounded)
        : ('Commencer', Icons.arrow_forward_rounded);
    final statusLabel = isCompleted
        ? 'Terminée aujourd\'hui'
        : isInProgress
            ? 'En cours'
            : lesson.revisionDay
                ? 'Révision du jour'
                : 'Leçon du jour';
    final codePrefix =
        (lesson.curriculumCode != null && lesson.curriculumCode!.isNotEmpty)
            ? '${lesson.curriculumCode} · '
            : '';
    final subtitleMeta =
        '$codePrefix${DailyLessonSummary.levelLabel(lesson.level)} · ${isBackend ? 'Backend' : 'DevOps'}';
    final isCompact = MediaQuery.sizeOf(context).width < 400;

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadius.lg + 4),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: gradientColors,
        ),
        border: Border.all(
          color: accentColor.withValues(alpha: 0.45),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: accentColor.withValues(alpha: 0.18),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          Positioned(
            right: -36,
            top: -36,
            child: IgnorePointer(
              child: Container(
                width: 160,
                height: 160,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      accentColor.withValues(alpha: 0.24),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
          ),
          Padding(
            padding: EdgeInsets.all(
              isCompact ? AppSpacing.md : AppSpacing.lg - 4,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: double.infinity,
                      child: Wrap(
                        spacing: AppSpacing.sm,
                        runSpacing: AppSpacing.xs,
                        alignment: WrapAlignment.spaceBetween,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          _HeroPill(
                            icon: isCompleted
                                ? Icons.check_circle_rounded
                                : DomainBadge.iconFor(lesson.domainCode),
                            label: statusLabel,
                          ),
                          _HeroPill(
                            icon: Icons.schedule_rounded,
                            label: '${lesson.estimatedMinutes} min',
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    Text(
                      subtitleMeta,
                      style: context.text.labelMedium?.copyWith(
                        color: Colors.white.withValues(alpha: 0.85),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      lesson.title,
                      style: context.text.headlineSmall?.copyWith(
                        color: Colors.white,
                      ),
                    ),
                    if (isInProgress) ...[
                      const SizedBox(height: AppSpacing.md),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(AppRadius.pill),
                        child: LinearProgressIndicator(
                          value: lesson.scrollOffsetRatio.clamp(0.0, 1.0),
                          minHeight: 6,
                          color: Colors.white,
                          backgroundColor:
                              Colors.white.withValues(alpha: 0.25),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: AppSpacing.lg),
                if (isCompleted)
                  Row(
                    children: [
                      Expanded(
                        flex: 3,
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: accentColor,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                              horizontal: AppSpacing.md,
                            ),
                          ),
                          onPressed: onOpenExercises,
                          icon: const Icon(Icons.quiz_rounded, size: 18),
                          label: const FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text('Défis QCM', maxLines: 1),
                          ),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        flex: 2,
                        child: OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.white,
                            side: BorderSide(
                              color: Colors.white.withValues(alpha: 0.35),
                            ),
                            padding: const EdgeInsets.symmetric(
                              horizontal: AppSpacing.sm,
                            ),
                          ),
                          onPressed: onOpen,
                          icon: const Icon(Icons.replay_rounded, size: 18),
                          label: const FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text('Relire', maxLines: 1),
                          ),
                        ),
                      ),
                    ],
                  )
                else
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: accentColor,
                        foregroundColor: Colors.white,
                      ),
                      onPressed: onOpen,
                      icon: Icon(ctaIcon),
                      label: Text(ctaLabel),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TomorrowPreviewCard extends StatelessWidget {
  final DailyLessonSummary lesson;
  final bool isOfflineReady;
  final VoidCallback onTap;

  const _TomorrowPreviewCard({
    required this.lesson,
    required this.isOfflineReady,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final domainColor = DomainBadge.colorFor(lesson.domainCode);
    final codePrefix =
        (lesson.curriculumCode != null && lesson.curriculumCode!.isNotEmpty)
            ? '${lesson.curriculumCode} · '
            : '';

    return SurfaceCard(
      onTap: onTap,
      borderColor: domainColor.withValues(alpha: 0.30),
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.xs,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(
                'APERÇU DE DEMAIN (J+1)',
                style: context.text.labelSmall?.copyWith(
                  color: context.palette.textMuted,
                  letterSpacing: 0.5,
                ),
              ),
              DomainBadge(domainCode: lesson.domainCode),
              if (isOfflineReady)
                const TagPill(
                  label: 'Pré-chargé hors-ligne ✓',
                  color: AppColors.success,
                  icon: Icons.offline_pin_rounded,
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm + 2),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '$codePrefix${lesson.title}',
                      style: context.text.titleSmall,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${DailyLessonSummary.levelLabel(lesson.level)} · ${lesson.estimatedMinutes} min',
                      style: context.text.bodySmall,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Icon(
                Icons.chevron_right_rounded,
                color: context.palette.textMuted,
              ),
            ],
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
          Text(
            label,
            style: context.text.labelSmall?.copyWith(color: Colors.white),
          ),
        ],
      ),
    );
  }
}

class _StatsRow extends StatelessWidget {
  final ProgressSummary? summary;
  const _StatsRow({required this.summary});

  @override
  Widget build(BuildContext context) {
    if (summary == null) return const SizedBox.shrink();

    return Row(
      children: [
        Expanded(
          child: StatTile(
            icon: Icons.local_fire_department_rounded,
            color: AppColors.streak,
            value: '${summary!.streakDays}',
            label: 'Jours de suite',
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: StatTile(
            icon: Icons.menu_book_rounded,
            color: AppColors.brand,
            value: '${summary!.totalLessonsCompleted}',
            label: 'Leçons',
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: StatTile(
            icon: Icons.verified_rounded,
            color: AppColors.success,
            value: '${summary!.totalNotionsMastered}',
            label: 'Maîtrisées',
          ),
        ),
      ],
    );
  }
}

class _DomainProgressMiniCard extends StatelessWidget {
  final ProgressSummary? summary;
  const _DomainProgressMiniCard({required this.summary});

  @override
  Widget build(BuildContext context) {
    if (summary == null) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.sm + 2),
      child: SurfaceCard(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm + 4,
        ),
        child: Row(
          children: [
            Expanded(
              child: _MiniDomainBar(
                label: 'Backend',
                percent: summary!.backendCompletionPercent,
                color: AppColors.backend,
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: _MiniDomainBar(
                label: 'DevOps',
                percent: summary!.devopsCompletionPercent,
                color: AppColors.devops,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MiniDomainBar extends StatelessWidget {
  final String label;
  final double percent;
  final Color color;

  const _MiniDomainBar({
    required this.label,
    required this.percent,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: context.text.labelSmall),
            Text(
              '${percent.round()}%',
              style: context.text.labelSmall?.copyWith(
                color: color,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        const SizedBox(height: 5),
        ProgressBar(value: percent / 100, color: color, height: 6),
      ],
    );
  }
}

class _ReviewsCard extends StatelessWidget {
  final List<ConceptMasterySummary> reviews;
  final VoidCallback onTap;

  const _ReviewsCard({required this.reviews, required this.onTap});

  @override
  Widget build(BuildContext context) {
    if (reviews.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.md),
      child: SurfaceCard(
        onTap: onTap,
        color: AppColors.warning.withValues(alpha: 0.05),
        borderColor: AppColors.warning.withValues(alpha: 0.35),
        child: Row(
          children: [
            const IconTile(
              icon: Icons.auto_awesome_rounded,
              color: AppColors.warning,
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          'Révision disponible',
                          style: context.text.titleSmall,
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      TagPill(
                        label: '${reviews.length} à revoir',
                        color: AppColors.warning,
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${reviews.length} notion${reviews.length > 1 ? 's' : ''} à consolider aujourd\'hui',
                    style: context.text.bodySmall,
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              color: context.palette.textMuted,
            ),
          ],
        ),
      ),
    );
  }
}

class _NewsPreview extends StatelessWidget {
  final List<TechNewsSummary> news;
  const _NewsPreview({required this.news});

  @override
  Widget build(BuildContext context) {
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
                if (i > 0)
                  const Divider(
                    indent: AppSpacing.md,
                    endIndent: AppSpacing.md,
                  ),
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
                  Wrap(
                    spacing: AppSpacing.xs + 2,
                    runSpacing: 4,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      TagPill(
                        label: item.targetTechnology.toUpperCase(),
                        color: AppColors.brand,
                      ),
                      if (item.relatedCurriculumCode != null &&
                          item.relatedCurriculumCode!.isNotEmpty)
                        TagPill(
                          label: 'Cours ${item.relatedCurriculumCode}',
                          color: AppColors.backend,
                          icon: Icons.school_rounded,
                        ),
                    ],
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
            Icon(
              Icons.chevron_right_rounded,
              color: context.palette.textMuted,
            ),
          ],
        ),
      ),
    );
  }
}
