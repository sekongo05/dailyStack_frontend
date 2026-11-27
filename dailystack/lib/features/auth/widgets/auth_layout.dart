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
    final isCompact = MediaQuery.sizeOf(context).width < 480;

    return Scaffold(
      appBar: leadingAction != null
          ? AppBar(
              backgroundColor: Colors.transparent,
              leading: leadingAction,
            )
          : null,
      body: Stack(
        children: [
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                padding: EdgeInsets.symmetric(
                  horizontal: isCompact ? AppSpacing.md : AppSpacing.lg,
                  vertical: isCompact ? AppSpacing.md : AppSpacing.xl,
                ),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 440),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          AppLogo(size: isCompact ? 46 : 52),
                          const SizedBox(width: AppSpacing.md),
                          Expanded(
                            child: Column(
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
                          ),
                        ],
                      ),
                      SizedBox(height: isCompact ? AppSpacing.lg : AppSpacing.xl),
                      Text(
                        title,
                        style: isCompact
                            ? context.text.headlineMedium
                            : context.text.headlineLarge,
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        subtitle,
                        style: context.text.bodyMedium?.copyWith(
                          color: context.palette.textMuted,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      SurfaceCard(
                        padding: EdgeInsets.all(isCompact ? AppSpacing.md + 4 : AppSpacing.lg),
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
