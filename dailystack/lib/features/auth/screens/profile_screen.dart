import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/network/api_response.dart';
import '../../../core/notifications/web_notification_helper.dart';
import '../../../core/providers/app_providers.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/pwa_install_sheet.dart';
import '../../../core/widgets/state_views.dart';
import '../../../core/widgets/ui.dart';
import '../../home/screens/home_screen.dart';
import '../../learning/models/lesson_models.dart';
import '../../learning/screens/tracks_screen.dart';
import '../../practice/screens/progress_screen.dart';
import '../models/auth_models.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  UserProfile? _profile;
  ThemePreference _theme = ThemePreference.SYSTEM;
  TextSizePreference _textSize = TextSizePreference.MEDIUM;
  String _reminderTime = '06:00:00';
  bool _notifyDailyLesson = true;
  bool _notifyReviews = true;
  bool _notifyImportantNews = true;
  bool _isLoading = true;
  bool _isSaving = false;
  bool _isSendingTestPush = false;
  bool _hasUnsavedChanges = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final authService = ref.read(authServiceProvider);
      final profile = await authService.getMe();
      final prefs = await authService.getPreferences();
      if (!mounted) return;
      ref.read(currentUserProvider.notifier).state = profile;
      setState(() {
        _profile = profile;
        _theme = prefs.theme;
        _textSize = prefs.textSize;
        _reminderTime = prefs.dailyReminderTime;
        _notifyDailyLesson = prefs.notifyDailyLesson;
        _notifyReviews = prefs.notifyReviews;
        _notifyImportantNews = prefs.notifyImportantNews;
        _hasUnsavedChanges = false;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _savePreferences() async {
    setState(() => _isSaving = true);
    try {
      final updated = await ref.read(authServiceProvider).updatePreferences({
        'theme': _theme.name,
        'textSize': _textSize.name,
        'dailyReminderTime': _reminderTime,
        'notifyDailyLesson': _notifyDailyLesson,
        'notifyReviews': _notifyReviews,
        'notifyImportantNews': _notifyImportantNews,
      });
      final refreshedProfile = await ref.read(authServiceProvider).getMe();
      if (!mounted) return;
      ref.read(currentUserProvider.notifier).state = refreshedProfile;
      ref.invalidate(todayLessonProvider);
      ref.read(homeBootstrapProvider.notifier).refresh();
      ref.read(tracksNotifierProvider.notifier).loadTracks();
      ref.read(progressSummaryProvider.notifier).refresh();
      setState(() {
        _profile = refreshedProfile;
        _hasUnsavedChanges = false;
      });
      applyUserPreferences(ref, updated);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Préférences enregistrées.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(userFriendlyError(e))),
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _pickReminderTime() async {
    final parts = _reminderTime.split(':');
    final initial = TimeOfDay(
      hour: int.tryParse(parts[0]) ?? 6,
      minute: parts.length > 1 ? (int.tryParse(parts[1]) ?? 0) : 0,
    );
    final picked = await showTimePicker(
      context: context,
      initialTime: initial,
    );
    if (picked != null) {
      final h = picked.hour.toString().padLeft(2, '0');
      final m = picked.minute.toString().padLeft(2, '0');
      setState(() {
        _reminderTime = '$h:$m:00';
        _hasUnsavedChanges = true;
      });
    }
  }

  Future<void> _logout() async {
    await ref.read(authServiceProvider).logout();
    ref.read(currentUserProvider.notifier).state = null;
    if (mounted) context.go('/login');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          const ScreenHeader(
            title: 'Profil',
            subtitle: 'Compte, apparence et notifications',
          ),
          Expanded(
            child: _isLoading
                ? const AppLoadingView(message: 'Chargement du profil...')
                : _error != null || _profile == null
                    ? AppErrorView(
                        message: _error ?? 'Profil indisponible.',
                        onRetry: _loadProfile,
                      )
                    : RefreshIndicator(
                        onRefresh: _loadProfile,
                        child: ListView(
                          padding: const EdgeInsets.fromLTRB(
                            AppSpacing.md,
                            AppSpacing.sm,
                            AppSpacing.md,
                            AppSpacing.xl,
                          ),
                          children: [
                            _UserHeaderCard(profile: _profile!),
                            const SizedBox(height: AppSpacing.lg),
                            const SectionHeader(title: 'Parcours pédagogique'),
                            SurfaceCard(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          'Niveau actuel',
                                          style: context.text.titleSmall,
                                        ),
                                      ),
                                      TagPill(
                                        label:
                                            'Niveau ${_profile?.currentLevel ?? 1} — ${DailyLessonSummary.levelLabel(_profile?.currentLevel ?? 1)}',
                                        color: AppColors.brand,
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: AppSpacing.sm),
                                  Text(
                                    'Votre niveau progresse automatiquement lorsque vous terminez les leçons et quiz de votre palier actuel.',
                                    style: context.text.bodySmall,
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: AppSpacing.lg),
                            const SectionHeader(title: 'Application mobile'),
                            SurfaceCard(
                              padding: EdgeInsets.zero,
                              child: ListTile(
                                leading: const IconTile(
                                  icon: Icons.install_mobile_rounded,
                                  color: AppColors.brand,
                                  size: 38,
                                ),
                                title: const Text(
                                  'Installer l\'application sur l\'écran d\'accueil',
                                ),
                                subtitle: const Text(
                                  'Plein écran instantané & accès hors-ligne (iOS Safari / Android Chrome)',
                                ),
                                trailing: Icon(
                                  Icons.chevron_right_rounded,
                                  color: context.palette.textMuted,
                                ),
                                onTap: () => showPwaInstallGuideSheet(context),
                              ),
                            ),
                            const SizedBox(height: AppSpacing.lg),
                            const SectionHeader(title: 'Apparence'),
                            SurfaceCard(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  Text('Thème', style: context.text.titleSmall),
                                  const SizedBox(height: AppSpacing.sm),
                                  SegmentedButton<ThemePreference>(
                                    showSelectedIcon: false,
                                    segments: const [
                                      ButtonSegment(
                                        value: ThemePreference.LIGHT,
                                        label: FittedBox(
                                          fit: BoxFit.scaleDown,
                                          child: Text('Clair', maxLines: 1),
                                        ),
                                        icon: Icon(Icons.light_mode_outlined),
                                      ),
                                      ButtonSegment(
                                        value: ThemePreference.DARK,
                                        label: FittedBox(
                                          fit: BoxFit.scaleDown,
                                          child: Text('Sombre', maxLines: 1),
                                        ),
                                        icon: Icon(Icons.dark_mode_outlined),
                                      ),
                                      ButtonSegment(
                                        value: ThemePreference.SYSTEM,
                                        label: FittedBox(
                                          fit: BoxFit.scaleDown,
                                          child: Text('Système', maxLines: 1),
                                        ),
                                        icon: Icon(
                                          Icons.settings_suggest_outlined,
                                        ),
                                      ),
                                    ],
                                    selected: {_theme},
                                    onSelectionChanged: (s) {
                                      final nextTheme = s.first;
                                      ref
                                          .read(themeModeProvider.notifier)
                                          .state = switch (nextTheme) {
                                        ThemePreference.LIGHT => ThemeMode.light,
                                        ThemePreference.DARK => ThemeMode.dark,
                                        ThemePreference.SYSTEM =>
                                          ThemeMode.system,
                                      };
                                      setState(() {
                                        _theme = nextTheme;
                                        _hasUnsavedChanges = true;
                                      });
                                    },
                                  ),
                                  const SizedBox(height: AppSpacing.md),
                                  Text(
                                    'Taille du texte',
                                    style: context.text.titleSmall,
                                  ),
                                  const SizedBox(height: AppSpacing.sm),
                                  SegmentedButton<TextSizePreference>(
                                    segments: const [
                                      ButtonSegment(
                                        value: TextSizePreference.SMALL,
                                        label: Text('Petit'),
                                      ),
                                      ButtonSegment(
                                        value: TextSizePreference.MEDIUM,
                                        label: Text('Moyen'),
                                      ),
                                      ButtonSegment(
                                        value: TextSizePreference.LARGE,
                                        label: Text('Grand'),
                                      ),
                                    ],
                                    selected: {_textSize},
                                    onSelectionChanged: (s) {
                                      final nextSize = s.first;
                                      ref
                                          .read(
                                            textScaleFactorProvider.notifier,
                                          )
                                          .state = switch (nextSize) {
                                        TextSizePreference.SMALL => 0.9,
                                        TextSizePreference.MEDIUM => 1.0,
                                        TextSizePreference.LARGE => 1.15,
                                      };
                                      setState(() {
                                        _textSize = nextSize;
                                        _hasUnsavedChanges = true;
                                      });
                                    },
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: AppSpacing.lg),
                            SurfaceCard(
                              onTap: () => context.push('/guide'),
                              child: Row(
                                children: [
                                  const IconTile(
                                    icon: Icons.help_outline_rounded,
                                    color: AppColors.brand,
                                    size: 40,
                                  ),
                                  const SizedBox(width: AppSpacing.md),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Guide d’utilisation',
                                          style: context.text.titleSmall,
                                        ),
                                        Text(
                                          'Leçons, quiz, flamme, boucliers et classement expliqués.',
                                          style: context.text.bodySmall,
                                        ),
                                      ],
                                    ),
                                  ),
                                  Icon(
                                    Icons.chevron_right_rounded,
                                    color: context.palette.textMuted,
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: AppSpacing.lg),
                            const SectionHeader(
                              title: 'Rappels & notifications',
                            ),
                            SurfaceCard(
                              padding: EdgeInsets.zero,
                              child: Column(
                                children: [
                                  ListTile(
                                    leading: const IconTile(
                                      icon: Icons.alarm_rounded,
                                      color: AppColors.brand,
                                      size: 38,
                                    ),
                                    title: const Text('Heure du rappel'),
                                    subtitle: Text(
                                      _reminderTime.length >= 5
                                          ? _reminderTime.substring(0, 5)
                                          : _reminderTime,
                                    ),
                                    trailing: Icon(
                                      Icons.chevron_right_rounded,
                                      color: context.palette.textMuted,
                                    ),
                                    onTap: _pickReminderTime,
                                  ),
                                  const Divider(
                                    indent: AppSpacing.md,
                                    endIndent: AppSpacing.md,
                                  ),
                                  SwitchListTile(
                                    title: const Text('Leçon du jour'),
                                    subtitle: const Text(
                                      'Notification quotidienne',
                                    ),
                                    value: _notifyDailyLesson,
                                    onChanged: (v) => setState(() {
                                      _notifyDailyLesson = v;
                                      _hasUnsavedChanges = true;
                                    }),
                                  ),
                                  const Divider(
                                    indent: AppSpacing.md,
                                    endIndent: AppSpacing.md,
                                  ),
                                  SwitchListTile(
                                    title: const Text('Révisions'),
                                    subtitle: const Text(
                                      'Rappel des notions à consolider',
                                    ),
                                    value: _notifyReviews,
                                    onChanged: (v) => setState(() {
                                      _notifyReviews = v;
                                      _hasUnsavedChanges = true;
                                    }),
                                  ),
                                  const Divider(
                                    indent: AppSpacing.md,
                                    endIndent: AppSpacing.md,
                                  ),
                                  SwitchListTile(
                                    title: const Text('Veille tech importante'),
                                    subtitle: const Text(
                                      'Alertes critiques uniquement',
                                    ),
                                    value: _notifyImportantNews,
                                    onChanged: (v) => setState(() {
                                      _notifyImportantNews = v;
                                      _hasUnsavedChanges = true;
                                    }),
                                  ),
                                  if (isWebNotificationSupported) ...[
                                    const Divider(
                                      indent: AppSpacing.md,
                                      endIndent: AppSpacing.md,
                                    ),
                                    ListTile(
                                      leading: const IconTile(
                                        icon: Icons.notifications_active_outlined,
                                        color: AppColors.brand,
                                        size: 38,
                                      ),
                                      title: const Text('Notifications sur cet appareil'),
                                      subtitle: Text(
                                        webNotificationPermission == 'granted'
                                            ? 'Autorisées sur cet appareil'
                                            : webNotificationPermission == 'denied'
                                                ? 'Bloquées dans les réglages du navigateur'
                                                : 'Appuyez pour autoriser les rappels',
                                      ),
                                      trailing: Icon(
                                        webNotificationPermission == 'granted'
                                            ? Icons.check_circle_rounded
                                            : Icons.chevron_right_rounded,
                                        color: webNotificationPermission == 'granted'
                                            ? AppColors.success
                                            : context.palette.textMuted,
                                      ),
                                      onTap: () async {
                                        final messenger =
                                            ScaffoldMessenger.of(context);
                                        final notifService = ref.read(
                                          notificationServiceProvider,
                                        );
                                        final status =
                                            await requestWebNotificationPermission();
                                        var registered = false;
                                        if (status == 'granted') {
                                          final token = await fetchWebFcmToken(
                                            promptIfNeeded: false,
                                          );
                                          if (token != null) {
                                            try {
                                              await notifService
                                                  .registerDeviceToken(
                                                token,
                                                platform: 'web',
                                              );
                                              registered = true;
                                            } catch (_) {}
                                          }
                                        }
                                        if (!mounted) return;
                                        setState(() {});
                                        final feedback = registered
                                            ? 'Notifications activées sur cet appareil !'
                                            : status == 'granted'
                                                ? 'Notifications activées !'
                                                : status == 'denied'
                                                    ? 'Notifications bloquées dans les réglages de votre navigateur.'
                                                    : 'Autorisation des notifications en attente.';
                                        messenger.showSnackBar(
                                          SnackBar(content: Text(feedback)),
                                        );
                                      },
                                    ),
                                    const Divider(
                                      height: 1,
                                      indent: AppSpacing.md,
                                      endIndent: AppSpacing.md,
                                    ),
                                    ListTile(
                                      leading: const IconTile(
                                        icon: Icons.send_rounded,
                                        color: AppColors.brand,
                                        size: 38,
                                      ),
                                      title: const Text(
                                        'Envoyer une notification de test',
                                      ),
                                      subtitle: const Text(
                                        'Vérifier la réception sur votre téléphone',
                                      ),
                                      trailing: _isSendingTestPush
                                          ? const SizedBox(
                                              width: 18,
                                              height: 18,
                                              child:
                                                  CircularProgressIndicator(
                                                strokeWidth: 2,
                                              ),
                                            )
                                          : Icon(
                                              Icons.chevron_right_rounded,
                                              color:
                                                  context.palette.textMuted,
                                            ),
                                      onTap: _isSendingTestPush
                                          ? null
                                          : () async {
                                              final messenger =
                                                  ScaffoldMessenger.of(context);
                                              final notifService = ref.read(
                                                notificationServiceProvider,
                                              );
                                              setState(() =>
                                                  _isSendingTestPush = true);
                                              try {
                                                if (webNotificationPermission !=
                                                    'granted') {
                                                  final perm =
                                                      await requestWebNotificationPermission();
                                                  if (perm != 'granted') {
                                                    if (!mounted) return;
                                                    messenger.showSnackBar(
                                                      const SnackBar(
                                                        content: Text(
                                                          'Autorisez d\'abord les notifications sur cet appareil.',
                                                        ),
                                                      ),
                                                    );
                                                    return;
                                                  }
                                                }
                                                final token =
                                                    await fetchWebFcmToken(
                                                  promptIfNeeded: false,
                                                );
                                                if (token != null) {
                                                  await notifService
                                                      .registerDeviceToken(
                                                    token,
                                                    platform: 'web',
                                                  );
                                                }
                                                final resultMessage =
                                                    await notifService
                                                        .sendTestPush();
                                                if (!mounted) return;
                                                messenger.showSnackBar(
                                                  SnackBar(
                                                    content:
                                                        Text(resultMessage),
                                                  ),
                                                );
                                              } catch (e) {
                                                if (!mounted) return;
                                                messenger.showSnackBar(
                                                  SnackBar(
                                                    content: Text(
                                                      'Impossible d\'envoyer le test : $e',
                                                    ),
                                                  ),
                                                );
                                              } finally {
                                                if (mounted) {
                                                  setState(() =>
                                                      _isSendingTestPush =
                                                          false);
                                                }
                                              }
                                            },
                                    ),
                                  ],
                                ],
                              ),
                            ),
                            const SizedBox(height: AppSpacing.lg),
                            PrimaryButton(
                              label: 'Enregistrer les préférences',
                              icon: Icons.check_rounded,
                              isLoading: _isSaving,
                              onPressed: _savePreferences,
                            ),
                            const SizedBox(height: AppSpacing.sm + 4),
                            OutlinedButton.icon(
                              style: OutlinedButton.styleFrom(
                                foregroundColor: AppColors.error,
                                side: BorderSide(
                                  color: AppColors.error.withValues(alpha: 0.35),
                                ),
                              ),
                              onPressed: _logout,
                              icon: const Icon(Icons.logout_rounded),
                              label: const Text('Se déconnecter'),
                            ),
                          ],
                        ),
                      ),
          ),
          if (_hasUnsavedChanges && !_isLoading && _profile != null)
            SafeArea(
              top: false,
              child: Container(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.md,
                  AppSpacing.sm,
                  AppSpacing.md,
                  AppSpacing.sm,
                ),
                decoration: BoxDecoration(
                  color: context.colors.surface,
                  border: Border(
                    top: BorderSide(color: context.palette.border),
                  ),
                ),
                child: PrimaryButton(
                  label: 'Enregistrer les modifications',
                  icon: Icons.check_rounded,
                  isLoading: _isSaving,
                  onPressed: _savePreferences,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _UserHeaderCard extends StatelessWidget {
  final UserProfile profile;
  const _UserHeaderCard({required this.profile});

  @override
  Widget build(BuildContext context) {
    final initial = profile.username.isNotEmpty
        ? profile.username[0].toUpperCase()
        : 'U';

    return SurfaceCard(
      child: Row(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: AppColors.brand,
              borderRadius: BorderRadius.circular(AppRadius.md + 2),
            ),
            alignment: Alignment.center,
            child: Text(
              initial,
              style: context.text.headlineSmall?.copyWith(color: Colors.white),
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  profile.username,
                  style: context.text.titleLarge,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  profile.email,
                  style: context.text.bodySmall,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: AppSpacing.sm),
                Wrap(
                  spacing: AppSpacing.sm,
                  runSpacing: AppSpacing.xs,
                  children: [
                    TagPill(
                      label: 'Niveau ${profile.currentLevel}',
                      color: AppColors.brand,
                      icon: Icons.workspace_premium_rounded,
                    ),
                    TagPill(
                      label: '${profile.streakDays} j de suite',
                      color: AppColors.streak,
                      icon: Icons.local_fire_department_rounded,
                    ),
                    TagPill(
                      label: '${profile.streakShields} bouclier(s)',
                      color: AppColors.backend,
                      icon: Icons.shield_rounded,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
