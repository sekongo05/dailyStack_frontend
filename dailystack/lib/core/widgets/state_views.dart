import 'package:flutter/material.dart';
import '../network/api_response.dart';
import '../theme/app_theme.dart';
import 'ui.dart';

class AppLoadingView extends StatelessWidget {
  final String? message;
  const AppLoadingView({super.key, this.message});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(
            width: 28,
            height: 28,
            child: CircularProgressIndicator(strokeWidth: 3, strokeCap: StrokeCap.round),
          ),
          if (message != null) ...[
            const SizedBox(height: AppSpacing.md),
            Text(message!, style: context.text.bodySmall),
          ],
        ],
      ),
    );
  }
}

class AppEmptyView extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback? onAction;
  final String? actionLabel;

  const AppEmptyView({
    super.key,
    required this.title,
    required this.subtitle,
    this.icon = Icons.inbox_outlined,
    this.onAction,
    this.actionLabel,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconTile(icon: icon, color: AppColors.brand, size: 64),
            const SizedBox(height: AppSpacing.lg),
            Text(title, style: context.text.titleLarge, textAlign: TextAlign.center),
            const SizedBox(height: AppSpacing.sm),
            Text(subtitle, style: context.text.bodySmall, textAlign: TextAlign.center),
            if (onAction != null && actionLabel != null) ...[
              const SizedBox(height: AppSpacing.lg),
              ElevatedButton(onPressed: onAction, child: Text(actionLabel!)),
            ],
          ],
        ),
      ),
    );
  }
}

class AppErrorView extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const AppErrorView({super.key, required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    final safeMessage = sanitizeErrorMessage(message);
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const IconTile(icon: Icons.wifi_off_rounded, color: AppColors.error, size: 64),
            const SizedBox(height: AppSpacing.lg),
            Text('Oups, un souci de chargement', style: context.text.titleLarge, textAlign: TextAlign.center),
            const SizedBox(height: AppSpacing.sm),
            Text(safeMessage, style: context.text.bodySmall, textAlign: TextAlign.center),
            const SizedBox(height: AppSpacing.lg),
            OutlinedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Réessayer'),
            ),
          ],
        ),
      ),
    );
  }
}

class OfflineBanner extends StatelessWidget {
  final bool pendingSync;
  final int pendingCount;
  final bool isOnline;
  final bool isSyncing;
  final VoidCallback? onSyncNow;

  const OfflineBanner({
    super.key,
    this.pendingSync = false,
    this.pendingCount = 0,
    this.isOnline = false,
    this.isSyncing = false,
    this.onSyncNow,
  });

  @override
  Widget build(BuildContext context) {
    final hasPending = pendingSync || pendingCount > 0;
    final label = !isOnline
        ? (hasPending
            ? (pendingCount > 0
                ? 'Données stockées localement - en attente de synchronisation ($pendingCount)'
                : 'Données stockées localement - en attente de synchronisation')
            : 'Mode hors ligne • Vos leçons enregistrées restent disponibles')
        : (isSyncing
            ? 'Synchronisation de $pendingCount action(s) en cours…'
            : '$pendingCount action(s) en attente de synchronisation');

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.sm, AppSpacing.md, 0),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.warning.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Row(
        children: [
          Icon(
            isOnline ? Icons.sync_rounded : Icons.cloud_off_rounded,
            size: 18,
            color: context.warningFg,
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              label,
              style: context.text.labelMedium?.copyWith(color: context.warningFg),
            ),
          ),
          if (isOnline && hasPending && !isSyncing && onSyncNow != null)
            TextButton(
              style: TextButton.styleFrom(
                foregroundColor: context.warningFg,
                padding: const EdgeInsets.symmetric(horizontal: 10),
                minimumSize: const Size(44, 36),
              ),
              onPressed: onSyncNow,
              child: const Text('Synchroniser'),
            ),
        ],
      ),
    );
  }
}

/// Bloc squelette pulsant pour les états de chargement.
class SkeletonBox extends StatefulWidget {
  final double? width;
  final double height;
  final double radius;

  const SkeletonBox({
    super.key,
    this.width,
    required this.height,
    this.radius = AppRadius.md,
  });

  @override
  State<SkeletonBox> createState() => _SkeletonBoxState();
}

class _SkeletonBoxState extends State<SkeletonBox> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 950),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: Tween<double>(begin: 0.45, end: 0.95).animate(
        CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
      ),
      child: Container(
        width: widget.width,
        height: widget.height,
        decoration: BoxDecoration(
          color: context.palette.surfaceAlt,
          borderRadius: BorderRadius.circular(widget.radius),
        ),
      ),
    );
  }
}

/// Squelette structuré pour l'écran d'accueil pendant le chargement initial.
class HomeSkeletonView extends StatelessWidget {
  const HomeSkeletonView({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.md),
      children: const [
        SizedBox(height: AppSpacing.sm),
        SkeletonBox(width: 140, height: 14),
        SizedBox(height: AppSpacing.xs),
        SkeletonBox(width: 210, height: 28),
        SizedBox(height: AppSpacing.lg),
        SkeletonBox(height: 210, radius: AppRadius.lg + 4),
        SizedBox(height: AppSpacing.lg),
        Row(
          children: [
            Expanded(child: SkeletonBox(height: 86, radius: AppRadius.lg)),
            SizedBox(width: AppSpacing.sm),
            Expanded(child: SkeletonBox(height: 86, radius: AppRadius.lg)),
            SizedBox(width: AppSpacing.sm),
            Expanded(child: SkeletonBox(height: 86, radius: AppRadius.lg)),
          ],
        ),
        SizedBox(height: AppSpacing.lg),
        SkeletonBox(width: 170, height: 18),
        SizedBox(height: AppSpacing.sm),
        SkeletonBox(height: 84, radius: AppRadius.lg),
        SizedBox(height: AppSpacing.sm),
        SkeletonBox(height: 84, radius: AppRadius.lg),
      ],
    );
  }
}
