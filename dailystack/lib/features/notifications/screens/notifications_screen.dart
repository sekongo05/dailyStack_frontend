import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/providers/app_providers.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/state_views.dart';
import '../../../core/widgets/ui.dart';
import '../models/notification_models.dart';

final notificationsListProvider =
    FutureProvider.autoDispose<List<DailyNotificationItem>>((ref) async {
  return ref.read(notificationServiceProvider).getNotifications();
});

class NotificationsScreen extends ConsumerWidget {
  const NotificationsScreen({super.key});

  Future<void> _markAllAsRead(
    BuildContext context,
    WidgetRef ref,
    List<DailyNotificationItem> unread,
  ) async {
    if (unread.isEmpty) return;
    final service = ref.read(notificationServiceProvider);
    await Future.wait(
      unread.map((item) async {
        try {
          await service.markAsRead(item.id);
        } catch (_) {}
      }),
    );
    ref.invalidate(notificationsListProvider);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Toutes les notifications ont été marquées comme lues.'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncList = ref.watch(notificationsListProvider);
    final unreadItems = asyncList.valueOrNull
            ?.where((n) => !n.read)
            .toList() ??
        const <DailyNotificationItem>[];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
        actions: [
          if (unreadItems.isNotEmpty)
            TextButton.icon(
              onPressed: () => _markAllAsRead(context, ref, unreadItems),
              icon: const Icon(Icons.done_all_rounded, size: 18),
              label: const Text('Tout lire'),
            ),
        ],
      ),
      body: asyncList.when(
        loading: () =>
            const AppLoadingView(message: 'Chargement des notifications...'),
        error: (err, _) => AppErrorView(
          message: err.toString(),
          onRetry: () => ref.invalidate(notificationsListProvider),
        ),
        data: (items) {
          if (items.isEmpty) {
            return const AppEmptyView(
              icon: Icons.notifications_none_rounded,
              title: 'Aucune notification',
              subtitle: 'Vous recevrez ici vos rappels quotidiens.',
            );
          }
          return RefreshIndicator(
            onRefresh: () => ref.refresh(notificationsListProvider.future),
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.md,
                AppSpacing.sm,
                AppSpacing.md,
                AppSpacing.xl,
              ),
              itemCount: items.length,
              separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.sm),
              itemBuilder: (context, index) {
                final item = items[index];
                final isUnread = !item.read;
                return SurfaceCard(
                  borderColor: isUnread
                      ? AppColors.brand.withValues(alpha: 0.35)
                      : null,
                  onTap: () async {
                    if (isUnread) {
                      try {
                        await ref
                            .read(notificationServiceProvider)
                            .markAsRead(item.id);
                        ref.invalidate(notificationsListProvider);
                      } catch (_) {}
                    }
                    if (context.mounted) {
                      await context.push('/lessons/${item.lessonId}');
                    }
                  },
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      IconTile(
                        icon: isUnread
                            ? Icons.notifications_active_rounded
                            : Icons.notifications_none_rounded,
                        color: isUnread
                            ? AppColors.brand
                            : context.palette.textMuted,
                        size: 42,
                      ),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    item.title,
                                    style: context.text.titleSmall?.copyWith(
                                      fontWeight: isUnread
                                          ? FontWeight.w700
                                          : FontWeight.w500,
                                    ),
                                  ),
                                ),
                                if (isUnread)
                                  Container(
                                    width: 8,
                                    height: 8,
                                    margin: const EdgeInsets.only(
                                      left: AppSpacing.sm,
                                    ),
                                    decoration: const BoxDecoration(
                                      color: AppColors.brand,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                              ],
                            ),
                            const SizedBox(height: AppSpacing.xs),
                            Text(
                              item.message,
                              style: context.text.bodyMedium?.copyWith(
                                color: context.palette.textMuted,
                              ),
                            ),
                            const SizedBox(height: AppSpacing.xs),
                            Text(
                              item.sentDate,
                              style: context.text.bodySmall,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}
