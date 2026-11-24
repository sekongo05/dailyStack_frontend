---
name: senior-flutter-architect
description: >-
  Use this skill when designing, refactoring, or implementing new features,
  screens, Riverpod providers, GoRouter routes, or offline sync in the
  DailyStak Flutter frontend.
---

# Senior Flutter Architect (DailyStak)

Apply these architectural standards when adding or modifying features in `dailystack`.

## Core Principles

1. **Feature-First Structure (`lib/features/<feature>/`)**:
   - Keep `screens/`, `widgets/`, `providers/`, `models/`, and `repositories/` cleanly separated per feature.
   - Never put `Dio` HTTP calls or raw `sqflite` SQL queries inside UI widgets or `build()` methods.

2. **State Management (`flutter_riverpod`)**:
   - Keep business logic and async state transitions inside `AsyncNotifier` / `Notifier` / `Provider` classes.
   - Use `ref.watch` only for reactive UI rebuilds and `ref.read` inside callbacks/event handlers.
   - Handle `AsyncValue` (`when(data:, loading:, error:)`) explicitly on every async screen.

3. **Routing (`go_router`) & Auth Guards**:
   - Define routes centrally in the router configuration with typed parameters and `redirect` guards based on auth state.
   - Never hardcode imperative `Navigator.push` flows where a `GoRouter` route belongs.

4. **Networking (`dio`) & Offline Sync (`sqflite` + `connectivity_plus`)**:
   - Route all backend requests through the shared `Dio` client with base URL config, timeouts, and JWT auth interceptor.
   - Ensure offline-capable screens read/write local `sqflite` cache and reconcile cleanly with `/api/v1/sync/pull` and `/api/v1/sync/push`.

## Validation

1. Verify no widget contains direct `Dio` or `sqflite` calls.
2. Run `flutter analyze` and `flutter test` in `/Users/macbookairm1/Desktop/DailyStaskFrontend/dailystack`.
