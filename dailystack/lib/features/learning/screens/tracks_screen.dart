import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/providers/app_providers.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/domain_badge.dart';
import '../../../core/widgets/state_views.dart';
import '../../../core/widgets/ui.dart';
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

  void _refresh() => setState(_loadTracks);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          const ScreenHeader(
            title: 'Apprendre',
            subtitle: 'Parcours progressifs Backend & DevOps',
          ),
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
                    icon: Icons.auto_stories_outlined,
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
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.md,
                      AppSpacing.sm,
                      AppSpacing.md,
                      AppSpacing.xl,
                    ),
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
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.xs,
        AppSpacing.md,
        AppSpacing.sm,
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
    final domainColor = DomainBadge.colorFor(track.domainCode);

    return SurfaceCard(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    DomainBadge(domainCode: track.domainCode),
                    const SizedBox(width: AppSpacing.sm),
                    TagPill(
                      label: 'Niveau ${track.level}',
                      color: AppColors.brand,
                    ),
                    const Spacer(),
                    Text(
                      '${track.completedLessons}/${track.totalLessons}',
                      style: context.text.labelLarge?.copyWith(color: domainColor),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                Text(track.title, style: context.text.titleLarge),
                if (track.description != null && track.description!.isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.xs),
                  Text(track.description!, style: context.text.bodySmall),
                ],
                const SizedBox(height: AppSpacing.md),
                ProgressBar(value: progress, color: domainColor),
              ],
            ),
          ),
          if (track.lessons.isNotEmpty) ...[
            const Divider(),
            for (var i = 0; i < track.lessons.length; i++) ...[
              if (i > 0) const Divider(indent: AppSpacing.md, endIndent: AppSpacing.md),
              _LessonRow(
                lesson: track.lessons[i],
                onTap: () => onLessonTap(track.lessons[i].id),
              ),
            ],
          ],
        ],
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
          Icons.check_rounded,
          AppColors.success,
          'Terminée',
        ),
      LessonProgressStatus.IN_PROGRESS => (
          Icons.play_arrow_rounded,
          AppColors.brand,
          'En cours',
        ),
      LessonProgressStatus.AVAILABLE => (
          Icons.menu_book_rounded,
          AppColors.backend,
          'Disponible',
        ),
      LessonProgressStatus.LOCKED => (
          Icons.lock_outline_rounded,
          context.palette.textMuted,
          'Verrouillée',
        ),
    };

    return InkWell(
      onTap: isLocked ? null : onTap,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 56),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.sm + 4,
          ),
          child: Row(
            children: [
              IconTile(icon: icon, color: color, size: 38),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      lesson.title,
                      style: context.text.titleSmall?.copyWith(
                        color: isLocked ? context.palette.textMuted : null,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '$statusLabel · ${lesson.estimatedMinutes} min',
                      style: context.text.bodySmall,
                    ),
                  ],
                ),
              ),
              if (!isLocked)
                Icon(Icons.chevron_right_rounded, color: context.palette.textMuted),
            ],
          ),
        ),
      ),
    );
  }
}
