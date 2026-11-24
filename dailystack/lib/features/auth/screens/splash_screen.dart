import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/providers/app_providers.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/ui.dart';

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
      if (!mounted) return;
      final stillHasSession = await authService.hasStoredSession();
      if (!mounted) return;
      context.go(stillHasSession ? '/home' : '/login');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.darkBackground,
      body: Stack(
        children: [
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: const Alignment(0, -0.2),
                  radius: 0.9,
                  colors: [
                    AppColors.brandBright.withValues(alpha: 0.16),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
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
