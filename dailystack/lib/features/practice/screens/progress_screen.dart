import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/providers/app_providers.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/domain_badge.dart';
import '../../../core/widgets/state_views.dart';
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
      appBar: AppBar(title: const Text('Progression')),
      body: FutureBuilder<ProgressSummary>(
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
              padding: const EdgeInsets.all(AppSpacing.md),
              children: [
                Row(
                  children: [
                    Expanded(
                      child: _StatCard(
                        icon: Icons.local_fire_department_rounded,
                        color: AppColors.warning,
                        value: '${summary.streakDays} j',
                        label: 'Série active',
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: _StatCard(
                        icon: Icons.menu_book_rounded,
                        color: AppColors.devops,
                        value: '${summary.totalLessonsCompleted}',
                        label: 'Leçons terminées',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.sm),
                Row(
                  children: [
                    Expanded(
                      child: _StatCard(
                        icon: Icons.verified_rounded,
                        color: AppColors.success,
                        value: '${summary.totalNotionsMastered}',
                        label: 'Notions maîtrisées',
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: _StatCard(
                        icon: Icons.trending_up_rounded,
                        color: AppColors.warning,
                        value: '${summary.notionsToConsolidate}',
                        label: 'À consolider',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Avancement par domaine',
                          style: Theme.of(context)
                              .textTheme
                              .titleMedium
                              ?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: AppSpacing.md),
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
                        Text(
                          'Taux de réussite aux exercices : ${summary.exercisesSuccessRate.round()}%',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ],
                    ),
                  ),
                ),
                if (summary.dueReviewsCount > 0) ...[
                  const SizedBox(height: AppSpacing.md),
                  Card(
                    child: ListTile(
                      minVerticalPadding: AppSpacing.md,
                      leading: const Icon(
                        Icons.auto_awesome_rounded,
                        color: AppColors.warning,
                      ),
                      title: Text(
                        '${summary.dueReviewsCount} notion(s) à réviser aujourd\'hui',
                      ),
                      trailing: const Icon(Icons.chevron_right_rounded),
                      onTap: () => context.push('/reviews'),
                    ),
                  ),
                ],
                const SizedBox(height: AppSpacing.lg),
                Text(
                  'Détail des notions',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const SizedBox(height: AppSpacing.sm),
                if (summary.notions.isEmpty)
                  const Card(
                    child: Padding(
                      padding: EdgeInsets.all(AppSpacing.md),
                      child: Text(
                        'Complétez votre première leçon et ses exercices pour voir vos notions ici.',
                      ),
                    ),
                  )
                else
                  ...summary.notions.map((n) {
                    final scorePct = (n.scoreRatio * 100).round();
                    return Padding(
                      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                      child: Card(
                        child: Padding(
                          padding: const EdgeInsets.all(AppSpacing.md),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  DomainBadge(domainCode: n.domainCode),
                                  MasteryBadge(level: n.masteryLevel),
                                ],
                              ),
                              const SizedBox(height: AppSpacing.sm),
                              Text(
                                n.conceptName,
                                style: Theme.of(context)
                                    .textTheme
                                    .titleSmall
                                    ?.copyWith(fontWeight: FontWeight.w600),
                              ),
                              const SizedBox(height: AppSpacing.xs),
                              Text(
                                'Score : $scorePct% • ${n.evaluationsCount} évaluation(s)'
                                '${n.nextReviewDate != null ? ' • Prochaine révision : ${n.nextReviewDate}' : ''}',
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  }),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String value;
  final String label;

  const _StatCard({
    required this.icon,
    required this.color,
    required this.value,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color, semanticLabel: label),
            const SizedBox(height: AppSpacing.sm),
            Text(
              value,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            Text(label, style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
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
            Text('${percent.round()}%'),
          ],
        ),
        const SizedBox(height: AppSpacing.xs),
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: LinearProgressIndicator(
            value: (percent / 100).clamp(0.0, 1.0),
            minHeight: 8,
            color: color,
          ),
        ),
      ],
    );
  }
}

