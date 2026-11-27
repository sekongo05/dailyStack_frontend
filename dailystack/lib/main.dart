import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/providers/app_providers.dart';
import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';
import 'features/notifications/screens/notifications_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const ProviderScope(child: DailyStackApp()));
}

class DailyStackApp extends ConsumerStatefulWidget {
  const DailyStackApp({super.key});

  @override
  ConsumerState<DailyStackApp> createState() => _DailyStackAppState();
}

class _DailyStackAppState extends ConsumerState<DailyStackApp> {
  final Set<int> _acknowledgedNotifs = {};

  @override
  void initState() {
    super.initState();
    AppRouter.router.routeInformationProvider.addListener(_onRouteChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) => _onRouteChanged());
  }

  @override
  void dispose() {
    AppRouter.router.routeInformationProvider.removeListener(_onRouteChanged);
    super.dispose();
  }

  Future<void> _onRouteChanged() async {
    final uri = AppRouter.router.routeInformationProvider.value.uri;
    final rawId = uri.queryParameters['notifId'];
    final notifId = rawId != null ? int.tryParse(rawId) : null;
    if (notifId == null || !_acknowledgedNotifs.add(notifId)) return;
    try {
      await ref.read(notificationServiceProvider).markAsRead(notifId);
      ref.invalidate(notificationsListProvider);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final themeMode = ref.watch(themeModeProvider);
    final textScale = ref.watch(textScaleFactorProvider);

    return MaterialApp.router(
      title: 'DailyStack',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: themeMode,
      routerConfig: AppRouter.router,
      builder: (context, child) {
        final mediaQuery = MediaQuery.of(context);
        return MediaQuery(
          data: mediaQuery.copyWith(
            textScaler: TextScaler.linear(textScale),
          ),
          child: child ?? const SizedBox.shrink(),
        );
      },
    );
  }
}

