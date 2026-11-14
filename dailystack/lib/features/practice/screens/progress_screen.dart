import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/providers/app_providers.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/domain_badge.dart';
import '../../../core/widgets/state_views.dart';
import '../../../core/widgets/ui.dart';
import '../models/practice_models.dart';
import '../widgets/mastery_badge.dart';

class ProgressScreen extends ConsumerStatefulWidget {
  const ProgressScreen({super.key});

  @override
  ConsumerState<ProgressScreen> createState() => _ProgressScreenState();
}

class _ProgressScreenState extends ConsumerState<ProgressScreen> {
  late Future<ProgressSummary> _summaryFuture;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    _summaryFuture = ref.read(practiceServiceProvider).getProgressSummary();
  }

  void _refresh() => setState(_load);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          const ScreenHeader(
            title: 'Progrès',
            subtitle: 'Votre maîtrise Backend & DevOps',
          ),
          Expanded(
            child: FutureBuilder<ProgressSummary>(
              future: _summaryFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const AppLoadingView(
                    message: 'Calcul de votre progression...',
                  );
                }
                if (snapshot.hasError) {
                  return AppErrorView(
                    message: snapshot.error.toString(),
                    onRetry: _refresh,
                  );
                }

                final summary = snapshot.data!;
                return RefreshIndicator(
                  onRefresh: () async => _refresh(),
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
                                  value: summary.exercisesSuccessRate / 100,
                                  size: 48,
                                  color: AppColors.success,
                                  stroke: 5,
                                  center: Text(
                                    '${summary.exercisesSuccessRate.round()}%',
                                    style: context.text.labelSmall?.copyWith(
                                      color: AppColors.success,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: AppSpacing.md),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
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
                          onTap: () => context.push('/reviews'),
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
                              for (var i = 0; i < summary.notions.length; i++) ...[
                                if (i > 0)
                                  const Divider(
                                    indent: AppSpacing.md,
                                    endIndent: AppSpacing.md,
                                  ),
                                _NotionRow(notion: summary.notions[i]),
                              ],
                            ],
                          ),
                        ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
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
  const _NotionRow({required this.notion});

  @override
  Widget build(BuildContext context) {
    final scorePct = (notion.scoreRatio * 100).round();

    return Padding(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              DomainBadge(domainCode: notion.domainCode),
              const SizedBox(width: AppSpacing.xs + 2),
              MasteryBadge(level: notion.masteryLevel),
              const Spacer(),
              Text(
                '$scorePct%',
                style: context.text.labelLarge,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(notion.conceptName, style: context.text.titleSmall),
          const SizedBox(height: 2),
          Text(
            '${notion.evaluationsCount} évaluation(s)'
            '${notion.nextReviewDate != null ? ' · Prochaine révision : ${notion.nextReviewDate}' : ''}',
            style: context.text.bodySmall,
          ),
        ],
      ),
    );
  }
}
