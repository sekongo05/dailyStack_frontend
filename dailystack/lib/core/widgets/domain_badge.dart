import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class DomainBadge extends StatelessWidget {
  final String domainCode;

  const DomainBadge({super.key, required this.domainCode});

  @override
  Widget build(BuildContext context) {
    final isBackend = domainCode.toUpperCase() == 'BACKEND';
    final color = isBackend ? AppColors.backend : AppColors.devops;
    final icon = isBackend ? Icons.dns_rounded : Icons.cloud_sync_rounded;
    final label = isBackend ? 'Backend' : 'DevOps';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm + 2, vertical: AppSpacing.xs),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color, semanticLabel: label),
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

