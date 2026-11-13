import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/providers/app_providers.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/domain_badge.dart';
import '../../../core/widgets/state_views.dart';
import '../models/lesson_models.dart';

class TracksScreen extends ConsumerStatefulWidget {
  const TracksScreen({super.key});

  @override
  ConsumerState<TracksScreen> createState() => _TracksScreenState();
}

class _TracksScreenState extends ConsumerState<TracksScreen> {
  String? _selectedDomain;
  int? _selectedLevel;
  late Future<List<Track>> _tracksFuture;

  @override
  void initState() {
    super.initState();
    _loadTracks();
  }

  void _loadTracks() {
    _tracksFuture = ref
        .read(lessonServiceProvider)
        .getTracks(domain: _selectedDomain, level: _selectedLevel);
  }

  void _refresh() {
    setState(_loadTracks);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Apprentissage')),
      body: Column(
        children: [
          _buildFilters(),
          Expanded(
            child: FutureBuilder<List<Track>>(
              future: _tracksFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const AppLoadingView(message: 'Chargement des parcours...');
                }
                if (snapshot.hasError) {
                  return AppErrorView(
                    message: snapshot.error.toString(),
                    onRetry: _refresh,
                  );
                }
                final tracks = snapshot.data ?? [];
                if (tracks.isEmpty) {
                  return AppEmptyView(
                    title: 'Aucun parcours trouvé',
                    subtitle: 'Essayez de modifier vos filtres de domaine ou de niveau.',
                    icon: Icons.school_outlined,
                    onAction: () {
                      _selectedDomain = null;
                      _selectedLevel = null;
                      _refresh();
                    },
                    actionLabel: 'Réinitialiser les filtres',
                  );
                }

                return RefreshIndicator(
                  onRefresh: () async => _refresh(),
                  child: ListView.separated(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    itemCount: tracks.length,
                    separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.md),
                    itemBuilder: (context, index) => _TrackCard(
                      track: tracks[index],
                      onLessonTap: (lessonId) async {
                        await context.push('/lessons/$lessonId');
                        _refresh();
                      },
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilters() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      child: Row(
        children: [
          FilterChip(
            label: const Text('Tous'),
            selected: _selectedDomain == null,
            onSelected: (_) {
              _selectedDomain = null;
              _refresh();
            },
          ),
          const SizedBox(width: AppSpacing.sm),
          FilterChip(
            label: const Text('Backend'),
            selected: _selectedDomain == 'BACKEND',
            onSelected: (_) {
              _selectedDomain = _selectedDomain == 'BACKEND' ? null : 'BACKEND';
              _refresh();
            },
          ),
          const SizedBox(width: AppSpacing.sm),
          FilterChip(
            label: const Text('DevOps'),
            selected: _selectedDomain == 'DEVOPS',
            onSelected: (_) {
              _selectedDomain = _selectedDomain == 'DEVOPS' ? null : 'DEVOPS';
              _refresh();
            },
          ),
          const SizedBox(width: AppSpacing.md),
          for (var lvl = 1; lvl <= 5; lvl++) ...[
            ChoiceChip(
              label: Text('Niv. $lvl'),
              selected: _selectedLevel == lvl,
              onSelected: (selected) {
                _selectedLevel = selected ? lvl : null;
                _refresh();
              },
            ),
            const SizedBox(width: AppSpacing.xs),
          ],
        ],
      ),
    );
  }
}

class _TrackCard extends StatelessWidget {
  final Track track;
  final void Function(int lessonId) onLessonTap;

  const _TrackCard({required this.track, required this.onLessonTap});

  @override
  Widget build(BuildContext context) {
    final progress = track.totalLessons > 0
        ? track.completedLessons / track.totalLessons
        : 0.0;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                DomainBadge(domainCode: track.domainCode),
                Text(
                  'Niveau ${track.level} • ${track.completedLessons}/${track.totalLessons} leçons',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              track.title,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            if (track.description != null && track.description!.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.xs),
              Text(
                track.description!,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
            const SizedBox(height: AppSpacing.sm),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: progress.clamp(0.0, 1.0),
                minHeight: 8,
              ),
            ),
            if (track.lessons.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.md),
              const Divider(height: 1),
              const SizedBox(height: AppSpacing.sm),
              ...track.lessons.map((lesson) => _LessonRow(
                    lesson: lesson,
                    onTap: () => onLessonTap(lesson.id),
                  )),
            ],
          ],
        ),
      ),
    );
  }
}

class _LessonRow extends StatelessWidget {
  final DailyLessonSummary lesson;
  final VoidCallback onTap;

  const _LessonRow({required this.lesson, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final isLocked = lesson.status == LessonProgressStatus.LOCKED;
    final (icon, color, statusLabel) = switch (lesson.status) {
      LessonProgressStatus.COMPLETED => (
          Icons.check_circle_rounded,
          AppColors.success,
          'Terminée'
        ),
      LessonProgressStatus.IN_PROGRESS => (
          Icons.play_circle_fill_rounded,
          AppColors.devops,
          'En cours'
        ),
      LessonProgressStatus.AVAILABLE => (
          Icons.radio_button_unchecked_rounded,
          AppColors.backend,
          'Disponible'
        ),
      LessonProgressStatus.LOCKED => (
          Icons.lock_outline_rounded,
          Theme.of(context).colorScheme.outline,
          'Verrouillée'
        ),
    };

    return InkWell(
      onTap: isLocked ? null : onTap,
      borderRadius: BorderRadius.circular(10),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 48),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            vertical: AppSpacing.sm,
            horizontal: AppSpacing.xs,
          ),
          child: Row(
            children: [
              Icon(icon, color: color, size: 22, semanticLabel: statusLabel),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      lesson.title,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w500,
                            color: isLocked
                                ? Theme.of(context).colorScheme.outline
                                : null,
                          ),
                    ),
                    Text(
                      '$statusLabel • ${lesson.estimatedMinutes} min',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              if (!isLocked) const Icon(Icons.chevron_right_rounded),
            ],
          ),
        ),
      ),
    );
  }
}

