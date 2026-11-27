import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../../core/notifications/web_notification_helper.dart';
import '../../../core/providers/app_providers.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/ui.dart';

class NotificationOptInCard extends ConsumerStatefulWidget {
  final bool dismissible;
  final bool showWhenDenied;

  const NotificationOptInCard({
    super.key,
    this.dismissible = true,
    this.showWhenDenied = false,
  });

  @override
  ConsumerState<NotificationOptInCard> createState() =>
      _NotificationOptInCardState();
}

class _NotificationOptInCardState extends ConsumerState<NotificationOptInCard> {
  static const String _snoozeKey = 'notif_optin_snoozed_until_v1';

  bool _isSnoozed = false;
  bool _checkedSnooze = false;
  bool _isRequesting = false;

  @override
  void initState() {
    super.initState();
    _checkSnooze();
  }

  Future<void> _checkSnooze() async {
    if (!widget.dismissible) {
      if (mounted) setState(() => _checkedSnooze = true);
      return;
    }
    try {
      final raw = await ref.read(localDatabaseProvider).getMetadata(_snoozeKey);
      if (raw != null && raw.isNotEmpty) {
        final until = DateTime.tryParse(raw);
        if (until != null && DateTime.now().isBefore(until)) {
          if (mounted) {
            setState(() {
              _isSnoozed = true;
              _checkedSnooze = true;
            });
          }
          return;
        }
      }
    } catch (_) {}
    if (mounted) setState(() => _checkedSnooze = true);
  }

  Future<void> _snooze() async {
    setState(() => _isSnoozed = true);
    try {
      final until = DateTime.now().add(const Duration(hours: 24));
      await ref
          .read(localDatabaseProvider)
          .setMetadata(_snoozeKey, until.toIso8601String());
    } catch (_) {}
  }

  Future<void> _activate() async {
    setState(() => _isRequesting = true);
    final messenger = ScaffoldMessenger.of(context);
    final notifService = ref.read(notificationServiceProvider);
    try {
      final status = await requestWebNotificationPermission();
      var registered = false;
      if (status == 'granted') {
        final token = await fetchWebFcmToken(promptIfNeeded: false);
        if (token != null) {
          try {
            await notifService.registerDeviceToken(token, platform: 'web');
            registered = true;
          } catch (_) {}
        }
      }
      if (!mounted) return;
      setState(() => _isRequesting = false);
      final feedback = registered || status == 'granted'
          ? 'Rappels activés sur cet appareil !'
          : status == 'denied'
              ? 'Permission refusée. Autorisez les alertes dans les réglages du navigateur.'
              : 'Activation annulée.';
      messenger.showSnackBar(SnackBar(content: Text(feedback)));
    } catch (_) {
      if (mounted) setState(() => _isRequesting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!isWebNotificationSupported || !_checkedSnooze || _isSnoozed) {
      return const SizedBox.shrink();
    }

    final permission = webNotificationPermission;
    if (permission == 'granted') {
      return const SizedBox.shrink();
    }
    if (permission == 'denied' && !widget.showWhenDenied) {
      return const SizedBox.shrink();
    }

    final isDenied = permission == 'denied';
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: SurfaceCard(
        borderColor: (isDenied ? AppColors.warning : AppColors.brand)
            .withValues(alpha: 0.45),
        color: (isDenied ? AppColors.warning : AppColors.brand)
            .withValues(alpha: isDark ? 0.12 : 0.05),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                IconTile(
                  icon: isDenied ? LucideIcons.bellOff : LucideIcons.bellRing,
                  color: isDenied ? AppColors.warning : AppColors.brand,
                  size: 40,
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isDenied
                            ? 'Rappels bloqués par le navigateur'
                            : 'Activez les rappels sur votre téléphone',
                        style: context.text.titleSmall,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        isDenied
                            ? 'Autorisez DailyStack dans les paramètres du navigateur pour recevoir votre leçon du jour et protéger votre série.'
                            : 'Recevez votre leçon du matin, les alertes de série avant minuit et les mises à jour critiques.',
                        style: context.text.bodySmall,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (!isDenied) ...[
              const SizedBox(height: AppSpacing.md),
              Row(
                children: [
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: _isRequesting ? null : _activate,
                      icon: _isRequesting
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(LucideIcons.bellRing, size: 16),
                      label: Text(
                        _isRequesting ? 'Activation...' : 'Activer les alertes',
                      ),
                    ),
                  ),
                  if (widget.dismissible) ...[
                    const SizedBox(width: AppSpacing.sm),
                    TextButton(
                      onPressed: _snooze,
                      child: const Text('Plus tard'),
                    ),
                  ],
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
