import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/app_providers.dart';
import '../pwa/pwa_install_helper.dart';
import '../theme/app_theme.dart';
import 'ui.dart';

/// Bannière intelligente proposant l'installation PWA sur l'écran d'accueil
/// lorsque l'utilisateur consulte DailyStack dans un onglet navigateur classique.
class PwaInstallBanner extends ConsumerStatefulWidget {
  const PwaInstallBanner({super.key});

  @override
  ConsumerState<PwaInstallBanner> createState() => _PwaInstallBannerState();
}

class _PwaInstallBannerState extends ConsumerState<PwaInstallBanner> {
  static const _dismissKey = 'pwaInstallDismissed';
  bool _visible = false;

  @override
  void initState() {
    super.initState();
    _checkVisibility();
  }

  Future<void> _checkVisibility() async {
    if (!isRunningInBrowserTab) return;
    final dismissed =
        await ref.read(localDatabaseProvider).getMetadata(_dismissKey);
    if (!mounted) return;
    if (dismissed != 'true') {
      setState(() => _visible = true);
    }
  }

  Future<void> _dismiss() async {
    setState(() => _visible = false);
    await ref.read(localDatabaseProvider).setMetadata(_dismissKey, 'true');
  }

  @override
  Widget build(BuildContext context) {
    if (!_visible) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: SurfaceCard(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: 12,
        ),
        borderColor: AppColors.brand.withValues(alpha: 0.40),
        color: AppColors.brand.withValues(alpha: 0.07),
        onTap: () => showPwaInstallGuideSheet(context),
        child: Row(
          children: [
            const IconTile(
              icon: Icons.install_mobile_rounded,
              color: AppColors.brand,
              size: 40,
            ),
            const SizedBox(width: AppSpacing.sm + 4),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Installer DailyStack sur votre écran d\'accueil',
                    style: context.text.titleSmall,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Ouverture plein écran instantanée et mode hors-ligne complet.',
                    style: context.text.bodySmall,
                  ),
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.xs),
            TextButton(
              onPressed: () => showPwaInstallGuideSheet(context),
              child: const Text('Installer'),
            ),
            IconButton(
              tooltip: 'Masquer',
              visualDensity: VisualDensity.compact,
              onPressed: _dismiss,
              icon: Icon(
                Icons.close_rounded,
                size: 18,
                color: context.palette.textMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Ouvre la feuille modale guidant l'installation PWA adaptée à iOS Safari ou Android Chrome.
Future<void> showPwaInstallGuideSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => const _PwaInstallGuideSheet(),
  );
}

class _PwaInstallGuideSheet extends StatefulWidget {
  const _PwaInstallGuideSheet();

  @override
  State<_PwaInstallGuideSheet> createState() => _PwaInstallGuideSheetState();
}

class _PwaInstallGuideSheetState extends State<_PwaInstallGuideSheet> {
  late bool _showIos = isIosDevice;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg,
          0,
          AppSpacing.lg,
          AppSpacing.xl,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const AppLogo(size: 46),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Installer sur l\'écran d\'accueil',
                        style: context.text.titleLarge,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Expérience native sans barre d\'adresse et cache hors-ligne.',
                        style: context.text.bodySmall,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),
            SegmentedButton<bool>(
              segments: const [
                ButtonSegment<bool>(
                  value: true,
                  icon: Icon(Icons.phone_iphone_rounded, size: 18),
                  label: Text('iPhone / Safari'),
                ),
                ButtonSegment<bool>(
                  value: false,
                  icon: Icon(Icons.android_rounded, size: 18),
                  label: Text('Android / Chrome'),
                ),
              ],
              selected: {_showIos},
              onSelectionChanged: (selection) {
                setState(() => _showIos = selection.first);
              },
            ),
            const SizedBox(height: AppSpacing.lg),
            if (_showIos) ...[
              const _InstallStepTile(
                stepNumber: 1,
                icon: Icons.ios_share_rounded,
                title: 'Appuyez sur Partager ↑ en bas de Safari',
                subtitle:
                    'Ouvrez DailyStack dans Safari puis touchez l\'icône Partager dans la barre inférieure.',
              ),
              const SizedBox(height: AppSpacing.sm + 2),
              const _InstallStepTile(
                stepNumber: 2,
                icon: Icons.add_box_outlined,
                title: 'Choisissez « Sur l\'écran d\'accueil » ➕',
                subtitle:
                    'Faites défiler la feuille d\'actions vers le bas jusqu\'à l\'option d\'ajout.',
              ),
              const SizedBox(height: AppSpacing.sm + 2),
              const _InstallStepTile(
                stepNumber: 3,
                icon: Icons.check_circle_outline_rounded,
                title: 'Appuyez sur « Ajouter » en haut à droite',
                subtitle:
                    'L\'icône DailyStack apparaît immédiatement avec vos autres applications.',
              ),
            ] else ...[
              const _InstallStepTile(
                stepNumber: 1,
                icon: Icons.more_vert_rounded,
                title: 'Ouvrez le menu ⋮ du navigateur',
                subtitle:
                    'Touchez les trois points verticaux en haut à droite de Chrome (ou Edge / Brave).',
              ),
              const SizedBox(height: AppSpacing.sm + 2),
              const _InstallStepTile(
                stepNumber: 2,
                icon: Icons.install_mobile_rounded,
                title:
                    'Appuyez sur « Installer l\'application » ou « Ajouter à l\'écran d\'accueil »',
                subtitle:
                    'Confirmez l\'installation pour profiter du mode plein écran et de l\'accès hors-ligne.',
              ),
              const SizedBox(height: AppSpacing.sm + 2),
              const _InstallStepTile(
                stepNumber: 3,
                icon: Icons.bolt_rounded,
                title: 'Lancez DailyStack en < 100 ms',
                subtitle:
                    'Vos leçons du jour et de demain (J+1) restent accessibles même dans le métro.',
              ),
            ],
            const SizedBox(height: AppSpacing.lg),
            PrimaryButton(
              label: 'Compris',
              icon: Icons.check_rounded,
              onPressed: () => Navigator.of(context).pop(),
            ),
          ],
        ),
      ),
    );
  }
}

class _InstallStepTile extends StatelessWidget {
  final int stepNumber;
  final IconData icon;
  final String title;
  final String subtitle;

  const _InstallStepTile({
    required this.stepNumber,
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return SurfaceCard(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 34,
            height: 34,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.brand.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              '$stepNumber',
              style: context.text.labelLarge?.copyWith(color: AppColors.brand),
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(icon, size: 18, color: AppColors.brand),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(title, style: context.text.titleSmall),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(subtitle, style: context.text.bodySmall),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
