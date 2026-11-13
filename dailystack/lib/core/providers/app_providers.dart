import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../network/dio_client.dart';
import '../router/app_router.dart';
import '../storage/local_database.dart';
import '../../features/auth/models/auth_models.dart';
import '../../features/auth/services/auth_service.dart';
import '../../features/learning/services/lesson_service.dart';
import '../../features/practice/services/practice_service.dart';
import '../../features/watch/services/news_service.dart';
import '../../features/sync/services/offline_sync_manager.dart';
import '../../features/sync/services/sync_service.dart';

final dioClientProvider = Provider<DioClient>(
  (ref) => DioClient(
    onSessionExpired: () {
      ref.read(currentUserProvider.notifier).state = null;
      ref.read(localDatabaseProvider).clearAll();
      AppRouter.router.go('/login');
    },
  ),
);

final authServiceProvider = Provider<AuthService>(
  (ref) => AuthService(
    ref.watch(dioClientProvider),
    localDb: ref.watch(localDatabaseProvider),
  ),
);

final lessonServiceProvider = Provider<LessonService>(
  (ref) => LessonService(ref.watch(dioClientProvider)),
);

final practiceServiceProvider = Provider<PracticeService>(
  (ref) => PracticeService(ref.watch(dioClientProvider)),
);

final newsServiceProvider = Provider<NewsService>(
  (ref) => NewsService(ref.watch(dioClientProvider)),
);

final syncServiceProvider = Provider<SyncService>(
  (ref) => SyncService(ref.watch(dioClientProvider)),
);

final localDatabaseProvider = Provider<LocalDatabase>((ref) => LocalDatabase());

final offlineSyncProvider =
    StateNotifierProvider<OfflineSyncNotifier, OfflineSyncState>(
  (ref) => OfflineSyncNotifier(
    syncService: ref.watch(syncServiceProvider),
    localDb: ref.watch(localDatabaseProvider),
  ),
);

final currentUserProvider = StateProvider<UserProfile?>((ref) => null);

final themeModeProvider = StateProvider<ThemeMode>((ref) => ThemeMode.system);

final textScaleFactorProvider = StateProvider<double>((ref) => 1.0);

void applyUserPreferences(WidgetRef ref, UserPreferences? prefs) {
  if (prefs == null) return;
  ref.read(themeModeProvider.notifier).state = switch (prefs.theme) {
    ThemePreference.LIGHT => ThemeMode.light,
    ThemePreference.DARK => ThemeMode.dark,
    ThemePreference.SYSTEM => ThemeMode.system,
  };
  ref.read(textScaleFactorProvider.notifier).state = switch (prefs.textSize) {
    TextSizePreference.SMALL => 0.9,
    TextSizePreference.MEDIUM => 1.0,
    TextSizePreference.LARGE => 1.15,
  };
}

