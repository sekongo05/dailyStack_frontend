import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/providers/app_providers.dart';
import '../../../core/storage/local_database.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/domain_badge.dart';
import '../../../core/widgets/state_views.dart';
import '../../../core/widgets/ui.dart';
import '../../learning/models/lesson_models.dart';
import '../models/practice_models.dart';
import '../services/practice_service.dart';
import '../widgets/mastery_badge.dart';

class ProgressSummaryState {
  final ProgressSummary? summary;
  final bool isLoading;
  final String? error;

  const ProgressSummaryState({
    this.summary,
    this.isLoading = true,
    this.error,
  });

  ProgressSummaryState copyWith({
    ProgressSummary? summary,
    bool? isLoading,
    String? error,
    bool clearError = false,
  }) {
    return ProgressSummaryState(
      summary: summary ?? this.summary,
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

class ProgressSummaryNotifier extends StateNotifier<ProgressSummaryState> {
  static const _cacheKey = 'progressSummary_v1';
  static const _bootstrapKey = 'homeBootstrap_v1';

  final PracticeService _practiceService;
  final LocalDatabase _localDb;

  ProgressSummaryNotifier({
    required this._practiceService,
    required this._localDb,
  }) : super(const ProgressSummaryState()) {
    _init();
  }

  Future<void> _init() async {
    try {
      final raw = await _localDb.getMetadata(_cacheKey);
      if (raw != null && raw.isNotEmpty) {
        final cached = ProgressSummary.fromJson(
          jsonDecode(raw) as Map<String, dynamic>,
        );
        if (mounted) {
          state = state.copyWith(
            summary: cached,
            isLoading: false,
            clearError: true,
          );
        }
      } else {
        final rawBootstrap = await _localDb.getMetadata(_bootstrapKey);
        if (rawBootstrap != null && rawBootstrap.isNotEmpty) {
          final boot = HomeBootstrap.fromJson(
            jsonDecode(rawBootstrap) as Map<String, dynamic>,
          );
          if (boot.progressSummary != null && mounted) {
            state = state.copyWith(
              summary: boot.progressSummary,
              isLoading: false,
              clearError: true,
            );
          }
        }
      }
    } catch (_) {}

    await refresh();
  }

  Future<void> refresh() async {
    if (state.summary == null && mounted) {
      state = state.copyWith(isLoading: true, clearError: true);
    }
    try {
      final fresh = await _practiceService.getProgressSummary();
      await _localDb.setMetadata(_cacheKey, jsonEncode(fresh.toJson()));
      if (!mounted) return;
      state = state.copyWith(
        summary: fresh,
        isLoading: false,
        clearError: true,
      );
    } catch (e) {
      if (!mounted) return;
      if (state.summary != null) {
        state = state.copyWith(isLoading: false);
      } else {
        state = state.copyWith(isLoading: false, error: e.toString());
      }
    }
  }
}

final progressSummaryProvider =
    StateNotifierProvider<ProgressSummaryNotifier, ProgressSummaryState>(
  (ref) => ProgressSummaryNotifier(
    practiceService: ref.watch(practiceServiceProvider),
    localDb: ref.watch(localDatabaseProvider),
  ),
);

class ProgressScreen extends ConsumerWidget {
  const ProgressScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final progState = ref.watch(progressSummaryProvider);
    final summary = progState.summary;

    return Scaffold(
      body: Column(
        children: [
          const ScreenHeader(
            title: 'Progrès',
            subtitle: 'Votre maîtrise Backend & DevOps',
          ),
          Expanded(
            child: progState.isLoading && summary == null
                ? const AppLoadingView(
                    message: 'Calcul de votre progression...',
                  )
                : summary == null
                    ? AppErrorView(
                        message: progState.error ?? 'Progression indisponible.',
                        onRetry: () => ref
                            .read(progressSummaryProvider.notifier)
                            .refresh(),
                      )
                    : RefreshIndicator(
                        onRefresh: () => ref
                            .read(progressSummaryProvider.notifier)
                            .refresh(),
                        child: ListView(
                          padding: const EdgeInsets.fromLTRB(
                            AppSpacing.md,
                            AppSpacing.sm,
                            AppSpacing.md,
                            AppSpacing.xl,
                          ),
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: StatTile(
                                    icon: Icons.local_fire_department_rounded,
                                    color: AppColors.streak,
                                    value: '${summary.streakDays} j',
                                    label: 'Série active',
                                  ),
                                ),
                                const SizedBox(width: AppSpacing.sm + 2),
                                Expanded(
                                  child: StatTile(
                                    icon: Icons.menu_book_rounded,
                                    color: AppColors.brand,
                                    value: '${summary.totalLessonsCompleted}',
                                    label: 'Leçons terminées',
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: AppSpacing.sm + 2),
                            Row(
                              children: [
                                Expanded(
                                  child: StatTile(
                                    icon: Icons.verified_rounded,
                                    color: AppColors.success,
                                    value: '${summary.totalNotionsMastered}',
                                    label: 'Notions maîtrisées',
                                  ),
                                ),
                                const SizedBox(width: AppSpacing.sm + 2),
                                Expanded(
                                  child: StatTile(
                                    icon: Icons.trending_up_rounded,
                                    color: AppColors.warning,
                                    value: '${summary.notionsToConsolidate}',
                                    label: 'À consolider',
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: AppSpacing.lg),
                            const SectionHeader(
                              title: 'Activité sur 12 semaines',
                            ),
                            _ActivityHeatmapCard(summary: summary),
                            const SizedBox(height: AppSpacing.lg),
                            const SectionHeader(title: 'Avancement par domaine'),
                            SurfaceCard(
                              child: Column(
                                children: [
                                  _DomainProgressRow(
                                    domainCode: 'BACKEND',
                                    percent: summary.backendCompletionPercent,
                                    color: AppColors.backend,
                                  ),
                                  const SizedBox(height: AppSpacing.md),
                                  _DomainProgressRow(
                                    domainCode: 'DEVOPS',
                                    percent: summary.devopsCompletionPercent,
                                    color: AppColors.devops,
                                  ),
                                  const SizedBox(height: AppSpacing.md),
                                  const Divider(),
                                  const SizedBox(height: AppSpacing.md),
                                  Row(
                                    children: [
                                      ProgressRing(
                                        value:
                                            summary.exercisesSuccessRate / 100,
                                        size: 48,
                                        color: AppColors.success,
                                        stroke: 5,
                                        center: Text(
                                          '${summary.exercisesSuccessRate.round()}%',
                                          style: context.text.labelSmall
                                              ?.copyWith(
                                            color: AppColors.success,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: AppSpacing.md),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              'Réussite aux exercices',
                                              style: context.text.titleSmall,
                                            ),
                                            Text(
                                              'Moyenne sur toutes vos évaluations',
                                              style: context.text.bodySmall,
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            if (summary.dueReviewsCount > 0) ...[
                              const SizedBox(height: AppSpacing.md),
                              SurfaceCard(
                                onTap: () async {
                                  await context.push('/reviews');
                                  ref
                                      .read(progressSummaryProvider.notifier)
                                      .refresh();
                                },
                                child: Row(
                                  children: [
                                    const IconTile(
                                      icon: Icons.auto_awesome_rounded,
                                      color: AppColors.warning,
                                    ),
                                    const SizedBox(width: AppSpacing.md),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            'Révisions du jour',
                                            style: context.text.titleSmall,
                                          ),
                                          Text(
                                            '${summary.dueReviewsCount} notion(s) à consolider',
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
                            ],
                            const SizedBox(height: AppSpacing.lg),
                            const SectionHeader(title: 'Détail des notions'),
                            if (summary.notions.isEmpty)
                              SurfaceCard(
                                child: Text(
                                  'Complétez votre première leçon et ses exercices pour voir vos notions ici.',
                                  style: context.text.bodySmall,
                                ),
                              )
                            else
                              SurfaceCard(
                                padding: EdgeInsets.zero,
                                child: Column(
                                  children: [
                                    for (var i = 0;
                                        i < summary.notions.length;
                                        i++) ...[
                                      if (i > 0)
                                        const Divider(
                                          indent: AppSpacing.md,
                                          endIndent: AppSpacing.md,
                                        ),
                                      _NotionRow(
                                        notion: summary.notions[i],
                                        onTap: summary.notions[i].lessonId !=
                                                null
                                            ? () async {
                                                await context.push(
                                                  '/lessons/${summary.notions[i].lessonId}/exercises',
                                                );
                                                ref
                                                    .read(
                                                      progressSummaryProvider
                                                          .notifier,
                                                    )
                                                    .refresh();
                                              }
                                            : null,
                                      ),
                                    ],
                                  ],
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

class _ActivityHeatmapCard extends StatelessWidget {
  final ProgressSummary summary;

  const _ActivityHeatmapCard({required this.summary});

  static String _formatIsoDate(DateTime dt) {
    final y = dt.year.toString().padLeft(4, '0');
    final m = dt.month.toString().padLeft(2, '0');
    final d = dt.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  /// Construit toujours exactement 84 jours (12 semaines × 7 jours) se terminant aujourd'hui.
  List<ActivityDay> _normalized84Days() {
    if (summary.activityCalendar.length == 84) {
      return summary.activityCalendar;
    }
    final byDate = <String, ActivityDay>{
      for (final day in summary.activityCalendar) day.date: day,
    };
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final start = today.subtract(const Duration(days: 83));
    return List<ActivityDay>.generate(84, (idx) {
      final d = start.add(Duration(days: idx));
      final iso = _formatIsoDate(d);
      return byDate[iso] ?? ActivityDay(date: iso);
    });
  }

  Color _cellColor(BuildContext context, ActivityDay day) {
    final intensity = day.intensity.clamp(0, 4);
    if (intensity == 0) return context.palette.surfaceAlt;

    final isDevops = day.primaryDomain?.toUpperCase() == 'DEVOPS';
    final base = isDevops ? AppColors.devops : AppColors.backend;
    final alpha = switch (intensity) {
      1 => 0.30,
      2 => 0.52,
      3 => 0.76,
      _ => 1.0,
    };
    return base.withValues(alpha: alpha);
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final todayIso = _formatIsoDate(now);
    final days = _normalized84Days();
    final activeDays = days.where((d) => d.intensity > 0).length;

    return SurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.xs,
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(
                '$activeDays jour(s) actif(s) sur 84j',
                style: context.text.titleSmall,
              ),
              TagPill(
                label:
                    '${summary.streakShields} bouclier${summary.streakShields > 1 ? 's' : ''} dispo',
                color: AppColors.brand,
                icon: Icons.shield_rounded,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (var week = 0; week < 12; week++)
                  Padding(
                    padding: EdgeInsets.only(right: week < 11 ? 5 : 0),
                    child: Column(
                      children: [
                        for (var dow = 0; dow < 7; dow++)
                          Builder(
                            builder: (context) {
                              final day = days[week * 7 + dow];
                              final isToday = day.date == todayIso;
                              return Tooltip(
                                message:
                                    '${day.date} · ${day.lessonsCompleted} leçon(s), ${day.exercisesCompleted} défi(s)',
                                child: Container(
                                  width: 15,
                                  height: 15,
                                  margin: EdgeInsets.only(
                                    bottom: dow < 6 ? 5 : 0,
                                  ),
                                  decoration: BoxDecoration(
                                    color: _cellColor(context, day),
                                    borderRadius: BorderRadius.circular(4),
                                    border: isToday
                                        ? Border.all(
                                            color: context.colors.onSurface
                                                .withValues(alpha: 0.70),
                                            width: 1.4,
                                          )
                                        : null,
                                  ),
                                ),
                              );
                            },
                          ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Wrap(
            spacing: AppSpacing.md,
            runSpacing: AppSpacing.xs,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const _LegendSwatch(color: AppColors.backend),
                  const SizedBox(width: 5),
                  Text('Backend', style: context.text.bodySmall),
                ],
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const _LegendSwatch(color: AppColors.devops),
                  const SizedBox(width: 5),
                  Text('DevOps', style: context.text.bodySmall),
                ],
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('Moins', style: context.text.bodySmall),
                  const SizedBox(width: 6),
                  _LegendSwatch(color: context.palette.surfaceAlt),
                  const SizedBox(width: 3),
                  _LegendSwatch(
                    color: AppColors.backend.withValues(alpha: 0.30),
                  ),
                  const SizedBox(width: 3),
                  _LegendSwatch(
                    color: AppColors.backend.withValues(alpha: 0.60),
                  ),
                  const SizedBox(width: 3),
                  const _LegendSwatch(color: AppColors.backend),
                  const SizedBox(width: 6),
                  Text('Plus', style: context.text.bodySmall),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _LegendSwatch extends StatelessWidget {
  final Color color;
  const _LegendSwatch({required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 11,
      height: 11,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(3),
      ),
    );
  }
}

class _DomainProgressRow extends StatelessWidget {
  final String domainCode;
  final double percent;
  final Color color;

  const _DomainProgressRow({
    required this.domainCode,
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
            DomainBadge(domainCode: domainCode),
            Text(
              '${percent.round()}%',
              style: context.text.labelLarge?.copyWith(color: color),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        ProgressBar(value: percent / 100, color: color),
      ],
    );
  }
}

class _NotionRow extends StatelessWidget {
  final ConceptMasterySummary notion;
  final VoidCallback? onTap;
  const _NotionRow({required this.notion, this.onTap});

  @override
  Widget build(BuildContext context) {
    final scorePct = (notion.scoreRatio * 100).round();

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Expanded(
                        child: Wrap(
                          spacing: AppSpacing.xs + 2,
                          runSpacing: AppSpacing.xs,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            DomainBadge(domainCode: notion.domainCode),
                            MasteryBadge(level: notion.masteryLevel),
                          ],
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Text(
                        '$scorePct%',
                        style: context.text.labelLarge,
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text(notion.conceptName, style: context.text.titleSmall),
                  const SizedBox(height: AppSpacing.xs - 2),
                  Text(
                    '${notion.evaluationsCount} évaluation(s)'
                    '${notion.nextReviewDate != null ? ' · Prochaine révision : ${notion.nextReviewDate}' : ''}',
                    style: context.text.bodySmall,
                  ),
                ],
              ),
            ),
            if (onTap != null) ...[
              const SizedBox(width: AppSpacing.sm),
              Icon(
                Icons.chevron_right_rounded,
                color: context.palette.textMuted,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
