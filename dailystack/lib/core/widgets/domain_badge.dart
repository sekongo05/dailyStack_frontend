import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import 'ui.dart';

class DomainBadge extends StatelessWidget {
  final String domainCode;

  const DomainBadge({super.key, required this.domainCode});

  static bool isBackend(String code) => code.toUpperCase() == 'BACKEND';

  static Color colorFor(String code) => isBackend(code) ? AppColors.backend : AppColors.devops;

  static IconData iconFor(String code) =>
      isBackend(code) ? Icons.dns_rounded : Icons.cloud_sync_rounded;

  @override
  Widget build(BuildContext context) {
    return TagPill(
      label: isBackend(domainCode) ? 'Backend' : 'DevOps',
      color: colorFor(domainCode),
      icon: iconFor(domainCode),
    );
  }
}
