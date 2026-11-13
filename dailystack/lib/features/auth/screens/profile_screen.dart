import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/providers/app_providers.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/state_views.dart';
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
      final profile = await ref.read(authServiceProvider).getMe();
      if (!mounted) return;
      ref.read(currentUserProvider.notifier).state = profile;
      final prefs = profile.preferences;
      setState(() {
        _profile = profile;
        if (prefs != null) {
          _theme = prefs.theme;
          _textSize = prefs.textSize;
          _reminderTime = prefs.dailyReminderTime;
          _notifyDailyLesson = prefs.notifyDailyLesson;
          _notifyReviews = prefs.notifyReviews;
          _notifyImportantNews = prefs.notifyImportantNews;
        }
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
      if (!mounted) return;
      applyUserPreferences(ref, updated);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Préférences enregistrées.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString())),
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
      setState(() => _reminderTime = '$h:$m:00');
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
      appBar: AppBar(title: const Text('Profil & Préférences')),
      body: _isLoading
          ? const AppLoadingView(message: 'Chargement du profil...')
          : _error != null || _profile == null
              ? AppErrorView(
                  message: _error ?? 'Profil indisponible.',
                  onRetry: _loadProfile,
                )
              : ListView(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  children: [
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(AppSpacing.md),
                        child: Row(
                          children: [
                            CircleAvatar(
                              radius: 26,
                              child: Text(
                                _profile!.username.isNotEmpty
                                    ? _profile!.username[0].toUpperCase()
                                    : 'U',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 20,
                                ),
                              ),
                            ),
                            const SizedBox(width: AppSpacing.md),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _profile!.username,
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleMedium
                                        ?.copyWith(fontWeight: FontWeight.bold),
                                  ),
                                  Text(
                                    _profile!.email,
                                    style:
                                        Theme.of(context).textTheme.bodySmall,
                                  ),
                                  const SizedBox(height: AppSpacing.xs),
                                  Text(
                                    'Niveau ${_profile!.currentLevel} • Série : ${_profile!.streakDays} jour(s)',
                                    style:
                                        Theme.of(context).textTheme.bodySmall,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(AppSpacing.md),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Apparence',
                              style: Theme.of(context)
                                  .textTheme
                                  .titleMedium
                                  ?.copyWith(fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: AppSpacing.sm),
                            SegmentedButton<ThemePreference>(
                              segments: const [
                                ButtonSegment(
                                  value: ThemePreference.LIGHT,
                                  label: Text('Clair'),
                                  icon: Icon(Icons.light_mode_outlined),
                                ),
                                ButtonSegment(
                                  value: ThemePreference.DARK,
                                  label: Text('Sombre'),
                                  icon: Icon(Icons.dark_mode_outlined),
                                ),
                                ButtonSegment(
                                  value: ThemePreference.SYSTEM,
                                  label: Text('Système'),
                                  icon: Icon(Icons.settings_suggest_outlined),
                                ),
                              ],
                              selected: {_theme},
                              onSelectionChanged: (s) =>
                                  setState(() => _theme = s.first),
                            ),
                            const SizedBox(height: AppSpacing.md),
                            Text(
                              'Taille du texte',
                              style: Theme.of(context)
                                  .textTheme
                                  .titleSmall
                                  ?.copyWith(fontWeight: FontWeight.w600),
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
                              onSelectionChanged: (s) =>
                                  setState(() => _textSize = s.first),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Card(
                      child: Column(
                        children: [
                          ListTile(
                            leading: const Icon(Icons.alarm_rounded),
                            title: const Text('Heure du rappel quotidien'),
                            subtitle: Text(_reminderTime.substring(0, 5)),
                            trailing: const Icon(Icons.edit_outlined),
                            onTap: _pickReminderTime,
                          ),
                          const Divider(height: 1),
                          SwitchListTile(
                            title: const Text('Rappel leçon du jour'),
                            value: _notifyDailyLesson,
                            onChanged: (v) =>
                                setState(() => _notifyDailyLesson = v),
                          ),
                          SwitchListTile(
                            title: const Text('Rappel des révisions'),
                            value: _notifyReviews,
                            onChanged: (v) =>
                                setState(() => _notifyReviews = v),
                          ),
                          SwitchListTile(
                            title: const Text('Alertes veille importantes'),
                            value: _notifyImportantNews,
                            onChanged: (v) =>
                                setState(() => _notifyImportantNews = v),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    ElevatedButton.icon(
                      onPressed: _isSaving ? null : _savePreferences,
                      icon: const Icon(Icons.save_rounded),
                      label: _isSaving
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('Enregistrer les préférences'),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size(44, 48),
                        foregroundColor: AppColors.error,
                      ),
                      onPressed: _logout,
                      icon: const Icon(Icons.logout_rounded),
                      label: const Text('Se déconnecter'),
                    ),
                  ],
                ),
    );
  }
}

