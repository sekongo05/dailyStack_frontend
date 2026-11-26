import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers/app_providers.dart';
import '../theme/app_theme.dart';
import '../widgets/state_views.dart';
import '../widgets/ui.dart';
import '../../features/auth/screens/forgot_password_screen.dart';
import '../../features/auth/screens/login_screen.dart';
import '../../features/auth/screens/profile_screen.dart';
import '../../features/auth/screens/register_screen.dart';
import '../../features/auth/screens/splash_screen.dart';
import '../../features/home/screens/home_screen.dart';
import '../../features/learning/screens/lesson_detail_screen.dart';
import '../../features/learning/screens/tracks_screen.dart';
import '../../features/practice/screens/exercises_screen.dart';
import '../../features/practice/screens/progress_screen.dart';
import '../../features/practice/screens/reviews_screen.dart';
import '../../features/watch/screens/news_detail_screen.dart';
import '../../features/watch/screens/watch_screen.dart';
import '../../features/notifications/screens/notifications_screen.dart';

class AppRouter {
  AppRouter._();

  static final router = GoRouter(
    initialLocation: '/splash',
    routes: [
      GoRoute(
        path: '/splash',
        builder: (context, state) => const SplashScreen(),
      ),
      GoRoute(
        path: '/login',
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: '/forgot-password',
        builder: (context, state) => const ForgotPasswordScreen(),
      ),
      GoRoute(
        path: '/register',
        builder: (context, state) => const RegisterScreen(),
      ),
      GoRoute(
        path: '/lessons/:id',
        builder: (context, state) {
          final id = int.tryParse(state.pathParameters['id'] ?? '');
          if (id == null) {
            return _InvalidRouteScreen(onBack: () => context.go('/home'));
          }
          return LessonDetailScreen(lessonId: id);
        },
      ),
      GoRoute(
        path: '/lessons/:id/exercises',
        builder: (context, state) {
          final id = int.tryParse(state.pathParameters['id'] ?? '');
          if (id == null) {
            return _InvalidRouteScreen(onBack: () => context.go('/home'));
          }
          return ExercisesScreen(lessonId: id);
        },
      ),
      GoRoute(
        path: '/reviews',
        builder: (context, state) => const ReviewsScreen(),
      ),
      GoRoute(
        path: '/notifications',
        builder: (context, state) => const NotificationsScreen(),
      ),
      GoRoute(
        path: '/watch/:id',
        builder: (context, state) {
          final id = int.tryParse(state.pathParameters['id'] ?? '');
          if (id == null) {
            return _InvalidRouteScreen(onBack: () => context.go('/watch'));
          }
          return NewsDetailScreen(newsId: id);
        },
      ),
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) {
          return _MainShell(navigationShell: navigationShell);
        },
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/home',
                builder: (context, state) => const HomeScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/learning',
                builder: (context, state) => const TracksScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/watch',
                builder: (context, state) => const WatchScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/progress',
                builder: (context, state) => const ProgressScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/profile',
                builder: (context, state) => const ProfileScreen(),
              ),
            ],
          ),
        ],
      ),
    ],
  );
}

class _MainShell extends ConsumerWidget {
  final StatefulNavigationShell navigationShell;

  const _MainShell({required this.navigationShell});

  static const _destinations = [
    (icon: Icons.home_outlined, selectedIcon: Icons.home_rounded, label: 'Accueil'),
    (icon: Icons.auto_stories_outlined, selectedIcon: Icons.auto_stories_rounded, label: 'Apprendre'),
    (icon: Icons.bolt_outlined, selectedIcon: Icons.bolt_rounded, label: 'Veille'),
    (icon: Icons.bar_chart_outlined, selectedIcon: Icons.bar_chart_rounded, label: 'Progrès'),
    (icon: Icons.person_outline_rounded, selectedIcon: Icons.person_rounded, label: 'Profil'),
  ];

  void _onSelect(int index) {
    navigationShell.goBranch(
      index,
      initialLocation: index == navigationShell.currentIndex,
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final syncState = ref.watch(offlineSyncProvider);
    final isWide = MediaQuery.sizeOf(context).width >= 840;

    final content = SafeArea(
      bottom: false,
      child: Column(
        children: [
          if (!syncState.isOnline || syncState.pendingCount > 0)
            OfflineBanner(
              pendingSync: syncState.pendingCount > 0,
              pendingCount: syncState.pendingCount,
              isOnline: syncState.isOnline,
              isSyncing: syncState.isSyncing,
              onSyncNow: () => ref.read(offlineSyncProvider.notifier).syncNow(),
            ),
          Expanded(
            child: Align(
              alignment: Alignment.topCenter,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 960),
                child: navigationShell,
              ),
            ),
          ),
        ],
      ),
    );

    if (isWide) {
      return Scaffold(
        body: Row(
          children: [
            NavigationRail(
              selectedIndex: navigationShell.currentIndex,
              onDestinationSelected: _onSelect,
              labelType: NavigationRailLabelType.all,
              backgroundColor: context.colors.surface,
              indicatorColor: Theme.of(context).brightness == Brightness.dark
                  ? AppColors.brand.withValues(alpha: 0.25)
                  : AppColors.brandSoft,
              leading: Padding(
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
                child: Column(
                  children: [
                    const AppLogo(size: 40),
                    const SizedBox(height: 6),
                    Text('DailyStack', style: context.text.labelSmall),
                  ],
                ),
              ),
              destinations: [
                for (final d in _destinations)
                  NavigationRailDestination(
                    icon: Icon(d.icon),
                    selectedIcon: Icon(d.selectedIcon, color: AppColors.brand),
                    label: Text(d.label),
                  ),
              ],
            ),
            VerticalDivider(width: 1, thickness: 1, color: context.palette.border),
            Expanded(child: content),
          ],
        ),
      );
    }

    return Scaffold(
      body: content,
      bottomNavigationBar: DecoratedBox(
        decoration: BoxDecoration(
          border: Border(top: BorderSide(color: context.palette.border)),
        ),
        child: NavigationBar(
          selectedIndex: navigationShell.currentIndex,
          onDestinationSelected: _onSelect,
          destinations: [
            for (final d in _destinations)
              NavigationDestination(
                icon: Icon(d.icon),
                selectedIcon: Icon(d.selectedIcon),
                label: d.label,
              ),
          ],
        ),
      ),
    );
  }
}

class _InvalidRouteScreen extends StatelessWidget {
  final VoidCallback onBack;
  const _InvalidRouteScreen({required this.onBack});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Page introuvable')),
      body: AppEmptyView(
        title: 'Identifiant invalide',
        subtitle: 'La ressource demandée est introuvable.',
        icon: Icons.link_off_rounded,
        onAction: onBack,
        actionLabel: 'Retour',
      ),
    );
  }
}
