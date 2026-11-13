import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/providers/app_providers.dart';
import '../../../core/theme/app_theme.dart';

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _bootstrapSession();
  }

  Future<void> _bootstrapSession() async {
    final authService = ref.read(authServiceProvider);
    final hasSession = await authService.hasStoredSession();

    if (!hasSession) {
      if (mounted) context.go('/login');
      return;
    }

    try {
      final profile = await authService.getMe();
      if (!mounted) return;
      ref.read(currentUserProvider.notifier).state = profile;
      applyUserPreferences(ref, profile.preferences);
      ref.read(offlineSyncProvider.notifier).syncNow();
      context.go('/home');
    } catch (_) {
      // Si hors ligne mais session présente, on laisse entrer vers /home (Phase 5 gérera le cache)
      // Si 401 + refresh expiré, DioClient aura déjà redirigé vers /login.
      if (!mounted) return;
      final stillHasSession = await authService.hasStoredSession();
      if (!mounted) return;
      context.go(stillHasSession ? '/home' : '/login');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'DailyStack',
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: AppSpacing.md),
            const CircularProgressIndicator(),
          ],
        ),
      ),
    );
  }
}

