import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/providers/app_providers.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/domain_badge.dart';
import '../../../core/widgets/state_views.dart';
import '../models/practice_models.dart';
import '../widgets/mastery_badge.dart';

class ReviewsScreen extends ConsumerStatefulWidget {
  const ReviewsScreen({super.key});

  @override
  ConsumerState<ReviewsScreen> createState() => _ReviewsScreenState();
}

class _ReviewsScreenState extends ConsumerState<ReviewsScreen> {
  late Future<List<ConceptMasterySummary>> _reviewsFuture;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    _reviewsFuture = ref.read(practiceServiceProvider).getDueReviews();
  }

  void _refresh() => setState(_load);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Notions à réviser')),
      body: FutureBuilder<List<ConceptMasterySummary>>(
        future: _reviewsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const AppLoadingView(message: 'Chargement des révisions...');
          }
          if (snapshot.hasError) {
            return AppErrorView(
              message: snapshot.error.toString(),
              onRetry: _refresh,
            );
          }

          final reviews = snapshot.data ?? [];
          if (reviews.isEmpty) {
            return AppEmptyView(
              title: 'Aucune révision prévue aujourd\'hui',
              subtitle:
                  'Vos notions sont à jour. Continuez votre parcours d\'apprentissage !',
              icon: Icons.verified_outlined,
              onAction: () => context.go('/learning'),
              actionLabel: 'Voir les parcours',
            );
          }

          return RefreshIndicator(
            onRefresh: () async => _refresh(),
            child: ListView.separated(
              padding: const EdgeInsets.all(AppSpacing.md),
              itemCount: reviews.length,
              separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.sm),
              itemBuilder: (context, index) {
                final notion = reviews[index];
                final percent = (notion.scoreRatio * 100).round();
                return Card(
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            DomainBadge(domainCode: notion.domainCode),
                            MasteryBadge(level: notion.masteryLevel),
                          ],
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        Text(
                          notion.conceptName,
                          style:
                              Theme.of(context).textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                        ),
                        const SizedBox(height: AppSpacing.xs),
                        Text(
                          'Score : $percent% • ${notion.evaluationsCount} évaluation(s)'
                          '${notion.nextReviewDate != null ? ' • Échéance : ${notion.nextReviewDate}' : ''}',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}

