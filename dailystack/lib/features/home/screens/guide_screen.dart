import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/ui.dart';

class GuideScreen extends StatelessWidget {
  const GuideScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Comment ça marche')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.md,
          AppSpacing.sm,
          AppSpacing.md,
          AppSpacing.xl,
        ),
        children: [
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 720),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Votre routine en 5 minutes par jour',
                    style: context.text.headlineSmall,
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    'DailyStack est conçu pour vous faire progresser chaque jour en Backend Java/Spring et DevOps, sans surcharge.',
                    style: context.text.bodyMedium?.copyWith(
                      color: context.palette.textMuted,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  const _GuideStepCard(
                    step: '01',
                    icon: LucideIcons.calendarCheck,
                    color: AppColors.brand,
                    title: 'Une leçon ciblée chaque jour',
                    body:
                        'Chaque journée alterne automatiquement entre un concept Backend et un concept DevOps. Les leçons sont découpées en cartes courtes avec analogie simple, exemples de code et cas réel en production.',
                  ),
                  const SizedBox(height: AppSpacing.md),
                  const _GuideStepCard(
                    step: '02',
                    icon: LucideIcons.graduationCap,
                    color: AppColors.backend,
                    title: 'Validez les quiz pour monter de niveau',
                    body:
                        'Tout le monde démarre au Niveau 1 (Amateur). Pour valider une leçon, réussissez au moins 60 % de sa série de QCM. En validant les 60 leçons de votre palier, vous passez automatiquement au niveau supérieur.',
                  ),
                  const SizedBox(height: AppSpacing.md),
                  const _GuideStepCard(
                    step: '03',
                    icon: LucideIcons.brain,
                    color: AppColors.devops,
                    title: 'Révisions au bon moment',
                    body:
                        'Les notions vues reviennent automatiquement dans votre file de révision (1, 3, 6 jours…) juste avant que vous ne les oubliiez, selon vos réponses et votre niveau de confiance.',
                  ),
                  const SizedBox(height: AppSpacing.md),
                  const _GuideStepCard(
                    step: '04',
                    icon: LucideIcons.flame,
                    color: AppColors.streak,
                    title: 'Flamme, boucliers et classement',
                    body:
                        'Valider votre séance maintient votre flamme. Toutes les 7 leçons terminées, vous gagnez un bouclier (jusqu’à 3) qui protège votre série en cas d’imprévu. Cumulez des XP pour grimper dans le classement hebdomadaire et global.',
                  ),
                  const SizedBox(height: AppSpacing.md),
                  const _GuideStepCard(
                    step: '05',
                    icon: LucideIcons.zap,
                    color: AppColors.warning,
                    title: 'Veille technologique filtrée',
                    body:
                        'Retrouvez des résumés courts de sources officielles (Spring, Docker, Kubernetes, PostgreSQL). Utilisez le filtre « Importantes » pour repérer les versions majeures et failles critiques, ou sauvegardez vos articles en favoris.',
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  PrimaryButton(
                    label: 'Compris, voir ma séance du jour',
                    icon: LucideIcons.arrowRight,
                    onPressed: () => context.go('/home'),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _GuideStepCard extends StatelessWidget {
  final String step;
  final IconData icon;
  final Color color;
  final String title;
  final String body;

  const _GuideStepCard({
    required this.step,
    required this.icon,
    required this.color,
    required this.title,
    required this.body,
  });

  @override
  Widget build(BuildContext context) {
    return SurfaceCard(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          IconTile(icon: icon, color: color, size: 42),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      step,
                      style: AppTheme.monoStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                        color: color,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.xs + 2),
                    Expanded(
                      child: Text(title, style: context.text.titleSmall),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  body,
                  style: context.text.bodyMedium?.copyWith(
                    color: context.palette.textMuted,
                    height: 1.5,
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
