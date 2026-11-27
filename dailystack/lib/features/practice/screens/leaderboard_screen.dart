import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../../core/providers/app_providers.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/state_views.dart';
import '../../../core/widgets/ui.dart';
import '../models/practice_models.dart';

class LeaderboardScreen extends ConsumerStatefulWidget {
  const LeaderboardScreen({super.key});

  @override
  ConsumerState<LeaderboardScreen> createState() => _LeaderboardScreenState();
}

class _LeaderboardScreenState extends ConsumerState<LeaderboardScreen> {
  String _period = 'WEEKLY';
  LeaderboardData? _data;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = _data == null;
      _error = null;
    });
    try {
      final res = await ref
          .read(practiceServiceProvider)
          .getLeaderboard(period: _period);
      if (!mounted) return;
      setState(() {
        _data = res;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final data = _data;
    return Scaffold(
      appBar: AppBar(title: const Text('Classement')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.md,
              AppSpacing.xs,
              AppSpacing.md,
              AppSpacing.sm,
            ),
            child: SizedBox(
              width: double.infinity,
              child: SegmentedButton<String>(
                segments: const [
                  ButtonSegment(
                    value: 'WEEKLY',
                    label: Text('Cette semaine'),
                  ),
                  ButtonSegment(
                    value: 'ALL_TIME',
                    label: Text('Global'),
                  ),
                ],
                selected: {_period},
                onSelectionChanged: (val) {
                  setState(() => _period = val.first);
                  _load();
                },
              ),
            ),
          ),
          Expanded(
            child: _isLoading
                ? const AppLoadingView(message: 'Chargement du classement...')
                : _error != null
                    ? AppErrorView(message: _error!, onRetry: _load)
                    : data == null || data.entries.isEmpty
                        ? const AppEmptyView(
                            icon: LucideIcons.trophy,
                            title: 'Aucun participant',
                            subtitle:
                                'Terminez une leçon ou un quiz pour apparaître dans le classement.',
                          )
                        : RefreshIndicator(
                            onRefresh: _load,
                            child: ListView(
                              padding: const EdgeInsets.fromLTRB(
                                AppSpacing.md,
                                AppSpacing.xs,
                                AppSpacing.md,
                                AppSpacing.xl,
                              ),
                              children: [
                                if (data.currentUserEntry != null) ...[
                                  _CurrentUserRankBanner(
                                    entry: data.currentUserEntry!,
                                    total: data.totalParticipants,
                                  ),
                                  const SizedBox(height: AppSpacing.md),
                                ],
                                if (data.entries.length >= 3) ...[
                                  _TopPodium(entries: data.entries.take(3).toList()),
                                  const SizedBox(height: AppSpacing.md),
                                ],
                                for (final entry in data.entries) ...[
                                  _LeaderboardRow(entry: entry),
                                  const SizedBox(height: AppSpacing.sm),
                                ],
                              ],
                            ),
                          ),
          ),
        ],
      ),
    );
  }
}

class _CurrentUserRankBanner extends StatelessWidget {
  final LeaderboardEntry entry;
  final int total;

  const _CurrentUserRankBanner({
    required this.entry,
    required this.total,
  });

  @override
  Widget build(BuildContext context) {
    return SurfaceCard(
      borderColor: AppColors.brand.withValues(alpha: 0.5),
      color: AppColors.brand.withValues(
        alpha: Theme.of(context).brightness == Brightness.dark ? 0.14 : 0.06,
      ),
      child: Row(
        children: [
          const IconTile(
            icon: LucideIcons.trophy,
            color: AppColors.brand,
            size: 42,
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Votre position',
                  style: context.text.bodySmall,
                ),
                const SizedBox(height: 2),
                Text(
                  '#${entry.rank} sur $total participants',
                  style: context.text.titleMedium,
                ),
              ],
            ),
          ),
          Text(
            '${entry.xpPoints} XP',
            style: AppTheme.monoStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: AppColors.brandBright,
            ),
          ),
        ],
      ),
    );
  }
}

class _TopPodium extends StatelessWidget {
  final List<LeaderboardEntry> entries;

  const _TopPodium({required this.entries});

  @override
  Widget build(BuildContext context) {
    final first = entries[0];
    final second = entries[1];
    final third = entries[2];
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: _PodiumCard(
            entry: second,
            medalColor: const Color(0xFF71717A),
            topPadding: AppSpacing.md,
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: _PodiumCard(
            entry: first,
            medalColor: const Color(0xFFD97706),
            topPadding: 0,
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: _PodiumCard(
            entry: third,
            medalColor: const Color(0xFFB45309),
            topPadding: AppSpacing.lg,
          ),
        ),
      ],
    );
  }
}

class _PodiumCard extends StatelessWidget {
  final LeaderboardEntry entry;
  final Color medalColor;
  final double topPadding;

  const _PodiumCard({
    required this.entry,
    required this.medalColor,
    required this.topPadding,
  });

  @override
  Widget build(BuildContext context) {
    final initial =
        entry.username.isNotEmpty ? entry.username[0].toUpperCase() : 'U';
    return Padding(
      padding: EdgeInsets.only(top: topPadding),
      child: SurfaceCard(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm,
          vertical: AppSpacing.md,
        ),
        borderColor: entry.isCurrentUser
            ? AppColors.brand
            : medalColor.withValues(alpha: 0.45),
        child: Column(
          children: [
            Text(
              '#${entry.rank}',
              style: AppTheme.monoStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: medalColor,
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            CircleAvatar(
              radius: 18,
              backgroundColor: medalColor.withValues(alpha: 0.16),
              child: Text(
                initial,
                style: context.text.titleSmall?.copyWith(color: medalColor),
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              entry.username,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: context.text.titleSmall,
            ),
            const SizedBox(height: 2),
            Text(
              '${entry.xpPoints} XP',
              style: AppTheme.monoStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: context.palette.textMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LeaderboardRow extends StatelessWidget {
  final LeaderboardEntry entry;

  const _LeaderboardRow({required this.entry});

  @override
  Widget build(BuildContext context) {
    final initial =
        entry.username.isNotEmpty ? entry.username[0].toUpperCase() : 'U';
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return SurfaceCard(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm + 4,
      ),
      borderColor: entry.isCurrentUser ? AppColors.brand : null,
      color: entry.isCurrentUser
          ? AppColors.brand.withValues(alpha: isDark ? 0.12 : 0.05)
          : null,
      child: Row(
        children: [
          SizedBox(
            width: 30,
            child: Text(
              '#${entry.rank}',
              style: AppTheme.monoStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: entry.isCurrentUser
                    ? AppColors.brandBright
                    : context.palette.textMuted,
              ),
            ),
          ),
          CircleAvatar(
            radius: 17,
            backgroundColor: context.palette.surfaceAlt,
            child: Text(
              initial,
              style: context.text.titleSmall,
            ),
          ),
          const SizedBox(width: AppSpacing.sm + 4),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  entry.isCurrentUser
                      ? '${entry.username} (Vous)'
                      : entry.username,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: context.text.titleSmall,
                ),
                const SizedBox(height: 2),
                Text(
                  'Niveau ${entry.currentLevel} · ${entry.completedLessons} leçon(s)',
                  style: context.text.bodySmall?.copyWith(fontSize: 12),
                ),
              ],
            ),
          ),
          if (entry.streakDays > 0) ...[
            Icon(
              LucideIcons.flame,
              size: 14,
              color: AppColors.streak,
            ),
            const SizedBox(width: 3),
            Text(
              '${entry.streakDays}j',
              style: AppTheme.monoStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppColors.streak,
              ),
            ),
            const SizedBox(width: AppSpacing.sm + 2),
          ],
          Text(
            '${entry.xpPoints} XP',
            style: AppTheme.monoStyle(
              fontSize: 13.5,
              fontWeight: FontWeight.w700,
              color: context.colors.onSurface,
            ),
          ),
        ],
      ),
    );
  }
}
