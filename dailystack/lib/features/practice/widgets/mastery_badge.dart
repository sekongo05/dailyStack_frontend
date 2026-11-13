import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../models/practice_models.dart';

class MasteryBadge extends StatelessWidget {
  final MasteryLevel level;

  const MasteryBadge({super.key, required this.level});

  @override
  Widget build(BuildContext context) {
    final (icon, color, label) = switch (level) {
      MasteryLevel.DISCOVERY => (
          Icons.explore_outlined,
          AppColors.devops,
          'Découverte',
        ),
      MasteryLevel.IN_PROGRESS => (
          Icons.trending_up_rounded,
          AppColors.warning,
          'À consolider',
        ),
      MasteryLevel.MASTERED => (
          Icons.verified_rounded,
          AppColors.success,
          'Maîtrisée',
        ),
    };

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm + 2,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: color, semanticLabel: label),
          const SizedBox(width: AppSpacing.xs),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w600,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

