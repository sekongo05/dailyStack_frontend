import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/storage/local_database.dart';
import 'sync_service.dart';

class OfflineSyncState {
  final bool isOnline;
  final bool isSyncing;
  final int pendingCount;
  final String? lastSyncTimestamp;

  const OfflineSyncState({
    this.isOnline = true,
    this.isSyncing = false,
    this.pendingCount = 0,
    this.lastSyncTimestamp,
  });

  OfflineSyncState copyWith({
    bool? isOnline,
    bool? isSyncing,
    int? pendingCount,
    String? lastSyncTimestamp,
  }) {
    return OfflineSyncState(
      isOnline: isOnline ?? this.isOnline,
      isSyncing: isSyncing ?? this.isSyncing,
      pendingCount: pendingCount ?? this.pendingCount,
      lastSyncTimestamp: lastSyncTimestamp ?? this.lastSyncTimestamp,
    );
  }
}

class OfflineSyncNotifier extends StateNotifier<OfflineSyncState> {
  final SyncService _syncService;
  final LocalDatabase _localDb;
  final Connectivity _connectivity;
  StreamSubscription<List<ConnectivityResult>>? _subscription;

  OfflineSyncNotifier({
    required SyncService syncService,
    required LocalDatabase localDb,
    Connectivity? connectivity,
  })  : _syncService = syncService,
        _localDb = localDb,
        _connectivity = connectivity ?? Connectivity(),
        super(const OfflineSyncState()) {
    _init();
  }

  Future<void> _init() async {
    try {
      final results = await _connectivity.checkConnectivity();
      final online = _hasConnection(results);
      final pending = await _localDb.getPendingCount();
      final lastTs = await _localDb.getLastSyncTimestamp();

      state = state.copyWith(
        isOnline: online,
        pendingCount: pending,
        lastSyncTimestamp: lastTs,
      );

      _subscription = _connectivity.onConnectivityChanged.listen((results) {
        final nowOnline = _hasConnection(results);
        final wasOffline = !state.isOnline;
        state = state.copyWith(isOnline: nowOnline);
        if (nowOnline && (wasOffline || state.pendingCount > 0)) {
          syncNow();
        }
      });
    } catch (_) {
      // En environnement de test sans plugin natif connectivity/sqflite
    }
  }

  bool _hasConnection(List<ConnectivityResult> results) {
    return results.any((r) => r != ConnectivityResult.none);
  }

  Future<void> queueProgress({
    required int lessonId,
    required int lastReadSectionIndex,
    required double scrollOffsetRatio,
    required String status,
  }) async {
    await _localDb.enqueueSyncAction('progress', {
      'lessonId': lessonId,
      'lastReadSectionIndex': lastReadSectionIndex,
      'scrollOffsetRatio': scrollOffsetRatio,
      'status': status,
      'clientTimestamp': DateTime.now().toIso8601String(),
    });
    final pending = await _localDb.getPendingCount();
    state = state.copyWith(pendingCount: pending);
  }

  Future<void> queueAttempt({
    required int exerciseId,
    int? selectedOptionId,
    String? submittedText,
  }) async {
    await _localDb.enqueueSyncAction('attempt', {
      'exerciseId': exerciseId,
      'selectedOptionId': selectedOptionId,
      'submittedText': submittedText,
      'clientTimestamp': DateTime.now().toIso8601String(),
    });
    final pending = await _localDb.getPendingCount();
    state = state.copyWith(pendingCount: pending);
  }

  Future<void> queueBookmark({
    required int newsId,
    required bool bookmarked,
  }) async {
    await _localDb.enqueueSyncAction('bookmark', {
      'newsId': newsId,
      'bookmarked': bookmarked,
      'clientTimestamp': DateTime.now().toIso8601String(),
    });
    final pending = await _localDb.getPendingCount();
    state = state.copyWith(pendingCount: pending);
  }

  Future<void> syncNow() async {
    if (state.isSyncing || !state.isOnline) return;
    state = state.copyWith(isSyncing: true);

    try {
      final pending = await _localDb.getPendingActions();
      if (pending.isNotEmpty) {
        final progresses = pending
            .where((e) => e.actionType == 'progress')
            .map((e) => e.payload)
            .toList();
        final attempts = pending
            .where((e) => e.actionType == 'attempt')
            .map((e) => e.payload)
            .toList();
        final bookmarks = pending
            .where((e) => e.actionType == 'bookmark')
            .map((e) => e.payload)
            .toList();

        await _syncService.pushSync(
          progresses: progresses,
          attempts: attempts,
          bookmarks: bookmarks,
        );
        await _localDb.clearPendingActions(pending.map((e) => e.id).toList());
      }

      final pulled = await _syncService.pullSync();
      await _localDb.cacheLessons(pulled.availableLessons);
      await _localDb.cacheNews(pulled.cachedNews);
      await _localDb.setLastSyncTimestamp(pulled.serverTimestamp);

      state = state.copyWith(
        isSyncing: false,
        pendingCount: 0,
        lastSyncTimestamp: pulled.serverTimestamp,
      );
    } catch (_) {
      final remaining = await _localDb.getPendingCount();
      state = state.copyWith(isSyncing: false, pendingCount: remaining);
    }
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}

