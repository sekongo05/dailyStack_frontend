import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/providers/app_providers.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/ui.dart';
import '../models/auth_models.dart';

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

    // Passage immédiat vers /home : HomeBootstrapNotifier charge le cache local en 0 ms
    // tandis que le profil et la synchro se rafraîchissent en arrière-plan.
    if (!mounted) return;
    final container = ProviderScope.containerOf(context, listen: false);
    context.go('/home');

    Future<void>(() async {
      try {
        final profile = await authService.getMe();
        container.read(currentUserProvider.notifier).state = profile;
        final prefs = profile.preferences;
        if (prefs != null) {
          container.read(themeModeProvider.notifier).state = switch (prefs.theme) {
            ThemePreference.LIGHT => ThemeMode.light,
            ThemePreference.DARK => ThemeMode.dark,
            ThemePreference.SYSTEM => ThemeMode.system,
          };
          container.read(textScaleFactorProvider.notifier).state =
              switch (prefs.textSize) {
            TextSizePreference.SMALL => 0.9,
            TextSizePreference.MEDIUM => 1.0,
            TextSizePreference.LARGE => 1.15,
          };
        }
        container.read(offlineSyncProvider.notifier).syncNow();
      } catch (_) {
        // Le DioClient redirigera vers /login si la session a expiré (401 + refresh échoué).
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.darkBackground,
      body: Stack(
        children: [
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const AppLogo(size: 88),
                const SizedBox(height: AppSpacing.lg),
                Text(
                  'DailyStack',
                  style: context.text.headlineLarge?.copyWith(
                    color: AppColors.darkTextPrimary,
                    letterSpacing: -0.8,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  'Backend · DevOps · Veille Tech',
                  style: context.text.bodySmall?.copyWith(
                    color: AppColors.darkTextSecondary,
                  ),
                ),
                const SizedBox(height: AppSpacing.xl),
                const SizedBox(
                  width: 26,
                  height: 26,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.6,
                    strokeCap: StrokeCap.round,
                    color: AppColors.brandBright,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
