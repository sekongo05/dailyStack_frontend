import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/network/api_response.dart';
import '../../../core/providers/app_providers.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/ui.dart';
import '../models/news_models.dart';

String watchCategoryLabel(WatchCategory category) => switch (category) {
      WatchCategory.BACKEND => 'Backend',
      WatchCategory.DEVOPS => 'DevOps',
      WatchCategory.AI => 'IA',
      WatchCategory.EMERGING_TECH => 'Tech Émergente',
    };

class WatchCategoryPill extends StatelessWidget {
  final WatchCategory category;

  const WatchCategoryPill({super.key, required this.category});

  @override
  Widget build(BuildContext context) {
    final (color, icon) = switch (category) {
      WatchCategory.BACKEND => (AppColors.backend, Icons.dns_rounded),
      WatchCategory.DEVOPS => (AppColors.devops, Icons.cloud_sync_rounded),
      WatchCategory.AI => (AppColors.brand, Icons.auto_awesome_rounded),
      WatchCategory.EMERGING_TECH => (
          AppColors.success,
          Icons.rocket_launch_rounded,
        ),
    };
    return TagPill(
      label: watchCategoryLabel(category),
      color: color,
      icon: icon,
    );
  }
}

class WatchImportancePill extends StatelessWidget {
  final WatchImportance importance;

  const WatchImportancePill({super.key, required this.importance});

  @override
  Widget build(BuildContext context) {
    final (icon, color, label) = switch (importance) {
      WatchImportance.CRITICAL => (
          Icons.priority_high_rounded,
          AppColors.error,
          'Critique',
        ),
      WatchImportance.HIGH => (
          Icons.arrow_upward_rounded,
          AppColors.warning,
          'Importante',
        ),
      WatchImportance.MEDIUM => (
          Icons.remove_rounded,
          AppColors.devops,
          'Moyenne',
        ),
      WatchImportance.LOW => (
          Icons.arrow_downward_rounded,
          AppColors.backend,
          'Info',
        ),
    };
    return TagPill(label: label, color: color, icon: icon);
  }
}

/// Pont interactif entre un article de veille technologique et la leçon associée du cursus.
class RelatedLessonBanner extends ConsumerStatefulWidget {
  final int? relatedLessonId;
  final String? relatedCurriculumCode;
  final String? relatedLessonTitle;
  final bool compact;

  const RelatedLessonBanner({
    super.key,
    this.relatedLessonId,
    this.relatedCurriculumCode,
    this.relatedLessonTitle,
    this.compact = false,
  });

  bool get hasLink =>
      relatedLessonId != null ||
      (relatedCurriculumCode != null && relatedCurriculumCode!.trim().isNotEmpty);

  @override
  ConsumerState<RelatedLessonBanner> createState() =>
      _RelatedLessonBannerState();
}

class _RelatedLessonBannerState extends ConsumerState<RelatedLessonBanner> {
  bool _isOpening = false;

  Future<void> _openRelatedLesson() async {
    if (_isOpening) return;

    if (widget.relatedLessonId != null) {
      await context.push('/lessons/${widget.relatedLessonId}');
      return;
    }

    final code = widget.relatedCurriculumCode?.trim();
    if (code == null || code.isEmpty) return;

    setState(() => _isOpening = true);
    try {
      final detail =
          await ref.read(lessonServiceProvider).getLessonByCode(code);
      await ref.read(localDatabaseProvider).cacheLessons([detail]);
      if (!mounted) return;
      await context.push('/lessons/${detail.id}');
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(userFriendlyError(e))),
      );
    } finally {
      if (mounted) setState(() => _isOpening = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.hasLink) return const SizedBox.shrink();

    final code = widget.relatedCurriculumCode?.trim();
    final title = (widget.relatedLessonTitle != null &&
            widget.relatedLessonTitle!.trim().isNotEmpty)
        ? widget.relatedLessonTitle!.trim()
        : 'Approfondir la notion';
    final label = (code != null && code.isNotEmpty)
        ? 'Cours associé : $code · $title'
        : 'Cours associé : $title';

    if (widget.compact) {
      return Material(
        color: AppColors.backend.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(AppRadius.sm),
        child: InkWell(
          borderRadius: BorderRadius.circular(AppRadius.sm),
          onTap: _openRelatedLesson,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (_isOpening)
                  const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(
                      strokeWidth: 1.8,
                      color: AppColors.backend,
                    ),
                  )
                else
                  const Icon(
                    Icons.school_rounded,
                    size: 15,
                    color: AppColors.backend,
                  ),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: context.text.labelSmall?.copyWith(
                      color: AppColors.backend,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                const Icon(
                  Icons.arrow_forward_rounded,
                  size: 14,
                  color: AppColors.backend,
                ),
              ],
            ),
          ),
        ),
      );
    }

    return SurfaceCard(
      onTap: _openRelatedLesson,
      color: AppColors.backend.withValues(alpha: 0.07),
      borderColor: AppColors.backend.withValues(alpha: 0.35),
      child: Row(
        children: [
          const IconTile(
            icon: Icons.school_rounded,
            color: AppColors.backend,
            size: 40,
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: context.text.titleSmall?.copyWith(
                    color: AppColors.backend,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Ouvrir la leçon complète et ses défis pratiques',
                  style: context.text.bodySmall,
                ),
              ],
            ),
          ),
          if (_isOpening)
            const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: AppColors.backend,
              ),
            )
          else
            const Icon(
              Icons.arrow_forward_rounded,
              color: AppColors.backend,
            ),
        ],
      ),
    );
  }
}
