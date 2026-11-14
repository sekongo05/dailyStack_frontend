import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/ui.dart';
import '../models/practice_models.dart';

class MasteryBadge extends StatelessWidget {
  final MasteryLevel level;

  const MasteryBadge({super.key, required this.level});

  static (IconData, Color, String) styleFor(MasteryLevel level) => switch (level) {
        MasteryLevel.DISCOVERY => (Icons.explore_outlined, AppColors.devops, 'Découverte'),
        MasteryLevel.IN_PROGRESS => (Icons.trending_up_rounded, AppColors.warning, 'À consolider'),
        MasteryLevel.MASTERED => (Icons.verified_rounded, AppColors.success, 'Maîtrisée'),
      };

  @override
  Widget build(BuildContext context) {
    final (icon, color, label) = styleFor(level);
    return TagPill(label: label, color: color, icon: icon);
  }
}
