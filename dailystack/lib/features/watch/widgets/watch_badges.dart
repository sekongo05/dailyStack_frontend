import 'package:flutter/material.dart';
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
