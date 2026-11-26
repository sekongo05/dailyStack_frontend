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
import '../models/lesson_models.dart';
import '../services/lesson_service.dart';

class TracksState {
  final String? selectedDomain;
  final int? selectedLevel;
  final List<Track> tracks;
  final bool isLoading;
  final String? error;

  const TracksState({
    this.selectedDomain,
    this.selectedLevel,
    this.tracks = const [],
    this.isLoading = true,
    this.error,
  });

  TracksState copyWith({
    String? selectedDomain,
    bool clearDomain = false,
    int? selectedLevel,
    bool clearLevel = false,
    List<Track>? tracks,
    bool? isLoading,
    String? error,
    bool clearError = false,
  }) {
    return TracksState(
      selectedDomain:
          clearDomain ? null : (selectedDomain ?? this.selectedDomain),
      selectedLevel: clearLevel ? null : (selectedLevel ?? this.selectedLevel),
      tracks: tracks ?? this.tracks,
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

class TracksNotifier extends StateNotifier<TracksState> {
  final LessonService _lessonService;
  final LocalDatabase _localDb;

  TracksNotifier({
    required this._lessonService,
    required this._localDb,
  }) : super(const TracksState()) {
    loadTracks();
  }

  String _cacheKey(String? domain, int? level) =>
      'tracks_v1_${domain ?? 'ALL'}_${level ?? 'ALL'}';

  Future<void> setFilters({
    String? domain,
    bool updateDomain = false,
    int? level,
    bool updateLevel = false,
  }) async {
    state = state.copyWith(
      selectedDomain: domain,
      clearDomain: updateDomain && domain == null,
      selectedLevel: level,
      clearLevel: updateLevel && level == null,
    );
    await loadTracks();
  }

  Future<void> resetFilters() async {
    state = state.copyWith(clearDomain: true, clearLevel: true);
    await loadTracks();
  }

  Future<void> loadTracks() async {
    final domain = state.selectedDomain;
    final level = state.selectedLevel;
    final key = _cacheKey(domain, level);

    var foundCache = false;
    try {
      final raw = await _localDb.getMetadata(key);
      if (raw != null && raw.isNotEmpty) {
        final decoded = (jsonDecode(raw) as List<dynamic>)
            .map((e) => Track.fromJson(e as Map<String, dynamic>))
            .toList();
        foundCache = true;
        if (mounted) {
          state = state.copyWith(
            tracks: decoded,
            isLoading: false,
            clearError: true,
          );
        }
      } else {
        // Filtrage instantané depuis le cache global si disponible.
        final rawAll = await _localDb.getMetadata(_cacheKey(null, null));
        if (rawAll != null && rawAll.isNotEmpty) {
          final allTracks = (jsonDecode(rawAll) as List<dynamic>)
              .map((e) => Track.fromJson(e as Map<String, dynamic>))
              .where((t) {
            if (domain != null && t.domainCode.toUpperCase() != domain) {
              return false;
            }
            if (level != null && t.level != level) return false;
            return true;
          }).toList();
          foundCache = true;
          if (mounted) {
            state = state.copyWith(
              tracks: allTracks,
              isLoading: false,
              clearError: true,
            );
          }
        }
      }
    } catch (_) {}

    if (!foundCache && mounted) {
      state = state.copyWith(isLoading: true, clearError: true);
    }

    try {
      final fresh = await _lessonService.getTracks(
        domain: domain,
        level: level,
      );
      await _localDb.setMetadata(
        key,
        jsonEncode(fresh.map((t) => t.toJson()).toList()),
      );
      if (!mounted) return;
      state = state.copyWith(
        tracks: fresh,
        isLoading: false,
        clearError: true,
      );
    } catch (e) {
      if (!mounted) return;
      if (foundCache) {
        state = state.copyWith(isLoading: false);
      } else {
        state = state.copyWith(isLoading: false, error: e.toString());
      }
    }
  }
}

final tracksNotifierProvider =
    StateNotifierProvider<TracksNotifier, TracksState>(
  (ref) => TracksNotifier(
    lessonService: ref.watch(lessonServiceProvider),
    localDb: ref.watch(localDatabaseProvider),
  ),
);

class TracksScreen extends ConsumerWidget {
  const TracksScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tracksState = ref.watch(tracksNotifierProvider);
    final notifier = ref.read(tracksNotifierProvider.notifier);

    return Scaffold(
      body: Column(
        children: [
          const ScreenHeader(
            title: 'Apprendre',
            subtitle: 'Parcours progressifs Backend & DevOps',
          ),
          _buildFilters(tracksState, notifier),
          Expanded(
            child: tracksState.isLoading && tracksState.tracks.isEmpty
                ? const AppLoadingView(message: 'Chargement des parcours...')
                : tracksState.error != null && tracksState.tracks.isEmpty
                    ? AppErrorView(
                        message: tracksState.error!,
                        onRetry: notifier.loadTracks,
                      )
                    : tracksState.tracks.isEmpty
                        ? AppEmptyView(
                            title: 'Aucun parcours trouvé',
                            subtitle:
                                'Essayez de modifier vos filtres de domaine ou de niveau.',
                            icon: Icons.auto_stories_outlined,
                            onAction: notifier.resetFilters,
                            actionLabel: 'Réinitialiser les filtres',
                          )
                        : RefreshIndicator(
                            onRefresh: notifier.loadTracks,
                            child: ListView.separated(
                              padding: const EdgeInsets.fromLTRB(
                                AppSpacing.md,
                                AppSpacing.sm,
                                AppSpacing.md,
                                AppSpacing.xl,
                              ),
                              itemCount: tracksState.tracks.length,
                              separatorBuilder: (_, _) =>
                                  const SizedBox(height: AppSpacing.md),
                              itemBuilder: (context, index) => _TrackCard(
                                track: tracksState.tracks[index],
                                onLessonTap: (lessonId) async {
                                  await context.push('/lessons/$lessonId');
                                  await notifier.loadTracks();
                                },
                              ),
                            ),
                          ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilters(TracksState state, TracksNotifier notifier) {
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
            selected: state.selectedDomain == null,
            onSelected: (_) => notifier.setFilters(
              domain: null,
              updateDomain: true,
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          FilterChip(
            label: const Text('Backend'),
            selected: state.selectedDomain == 'BACKEND',
            onSelected: (_) => notifier.setFilters(
              domain: state.selectedDomain == 'BACKEND' ? null : 'BACKEND',
              updateDomain: true,
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          FilterChip(
            label: const Text('DevOps'),
            selected: state.selectedDomain == 'DEVOPS',
            onSelected: (_) => notifier.setFilters(
              domain: state.selectedDomain == 'DEVOPS' ? null : 'DEVOPS',
              updateDomain: true,
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          for (var lvl = 1; lvl <= 5; lvl++) ...[
            ChoiceChip(
              label: Text('Niv. $lvl'),
              selected: state.selectedLevel == lvl,
              onSelected: (selected) => notifier.setFilters(
                level: selected ? lvl : null,
                updateLevel: true,
              ),
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
                      style: context.text.labelLarge
                          ?.copyWith(color: domainColor),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                Text(track.title, style: context.text.titleLarge),
                if (track.description != null &&
                    track.description!.isNotEmpty) ...[
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
              if (i > 0)
                const Divider(
                  indent: AppSpacing.md,
                  endIndent: AppSpacing.md,
                ),
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
                Icon(
                  Icons.chevron_right_rounded,
                  color: context.palette.textMuted,
                ),
            ],
          ),
        ),
      ),
    );
  }
}
