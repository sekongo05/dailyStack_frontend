import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/ui.dart';

/// Gabarit unifié pour les écrans d'authentification (style Linear / Vercel).
class AuthLayout extends StatelessWidget {
  final String badge;
  final String title;
  final String subtitle;
  final Widget? leadingAction;
  final List<Widget> children;

  const AuthLayout({
    super.key,
    required this.badge,
    required this.title,
    required this.subtitle,
    this.leadingAction,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final glowColor = isDark
        ? AppColors.brandBright.withValues(alpha: 0.14)
        : AppColors.brand.withValues(alpha: 0.09);

    return Scaffold(
      appBar: leadingAction != null
          ? AppBar(
              backgroundColor: Colors.transparent,
              leading: leadingAction,
            )
          : null,
      body: Stack(
        children: [
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: const Alignment(0, -0.85),
                  radius: 1.1,
                  colors: [glowColor, Colors.transparent],
                ),
              ),
            ),
          ),
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.lg,
                  vertical: AppSpacing.xl,
                ),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 440),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          const AppLogo(size: 52),
                          const SizedBox(width: AppSpacing.md),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('DailyStack', style: context.text.titleLarge),
                              const SizedBox(height: 2),
                              TagPill(
                                label: badge,
                                color: AppColors.brand,
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.xl),
                      Text(title, style: context.text.headlineLarge),
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        subtitle,
                        style: context.text.bodyMedium?.copyWith(
                          color: context.palette.textMuted,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      SurfaceCard(
                        padding: const EdgeInsets.all(AppSpacing.lg),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: children,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
