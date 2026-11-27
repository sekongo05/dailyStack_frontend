import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../../core/network/api_response.dart';
import '../../../core/providers/app_providers.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/ui.dart';
import '../widgets/auth_layout.dart';

class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _usernameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;
  bool _isLoading = false;
  String? _errorMessage;
  Map<String, dynamic>? _fieldErrors;

  @override
  void dispose() {
    _usernameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final username = _usernameController.text.trim();
    final email = _emailController.text.trim();
    final password = _passwordController.text;
    final localErrors = <String, String>{};
    if (username.length < 3) {
      localErrors['username'] = 'Minimum 3 caractères.';
    }
    if (email.isEmpty || !email.contains('@')) {
      localErrors['email'] = 'Saisissez une adresse e-mail valide.';
    }
    if (password.length < 8) {
      localErrors['password'] = 'Minimum 8 caractères requis.';
    }
    if (localErrors.isNotEmpty) {
      setState(() {
        _fieldErrors = localErrors;
        _errorMessage = null;
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _fieldErrors = null;
    });

    try {
      final auth = await ref.read(authServiceProvider).register(
            email: email,
            password: password,
            username: username,
            initialLevel: 1,
          );
      ref.read(currentUserProvider.notifier).state = auth.user;
      applyUserPreferences(ref, auth.user.preferences);
      ref.read(offlineSyncProvider.notifier).syncNow();
      if (mounted) {
        context.go('/home');
      }
    } on ApiException catch (e) {
      setState(() {
        _errorMessage = e.message;
        _fieldErrors = e.fieldErrors;
      });
    } catch (_) {
      setState(() => _errorMessage = 'Impossible de créer le compte.');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final pwd = _passwordController.text;
    final hasMinLen = pwd.length >= 8;
    final hasUpperOrDigit =
        pwd.contains(RegExp(r'[A-Z]')) && pwd.contains(RegExp(r'[0-9]'));

    return AuthLayout(
      badge: 'INSCRIPTION',
      title: 'Créer un compte',
      subtitle:
          '5 minutes par jour pour progresser en Backend & DevOps du Niveau 1 à 5.',
      leadingAction: IconButton(
        tooltip: 'Retour',
        onPressed: () => context.go('/login'),
        icon: const Icon(LucideIcons.arrowLeft, size: 20),
      ),
      children: [
        if (_errorMessage != null) ...[
          InlineError(message: _errorMessage!),
          const SizedBox(height: AppSpacing.md),
        ],
        AutofillGroup(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                controller: _usernameController,
                autofillHints: const [AutofillHints.username],
                textInputAction: TextInputAction.next,
                onChanged: (_) {
                  if (_fieldErrors?.containsKey('username') == true) {
                    setState(() => _fieldErrors?.remove('username'));
                  }
                },
                decoration: InputDecoration(
                  labelText: 'Nom d’utilisateur',
                  hintText: 'Ex. MoussaDev',
                  prefixIcon: const Icon(LucideIcons.user, size: 18),
                  errorText: _fieldErrors?['username'] as String?,
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              TextField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                autofillHints: const [AutofillHints.email],
                textInputAction: TextInputAction.next,
                onChanged: (_) {
                  if (_fieldErrors?.containsKey('email') == true) {
                    setState(() => _fieldErrors?.remove('email'));
                  }
                },
                decoration: InputDecoration(
                  labelText: 'Adresse e-mail',
                  hintText: 'vous@exemple.com',
                  prefixIcon: const Icon(LucideIcons.mail, size: 18),
                  errorText: _fieldErrors?['email'] as String?,
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              TextField(
                controller: _passwordController,
                obscureText: _obscurePassword,
                autofillHints: const [AutofillHints.newPassword],
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => _isLoading ? null : _submit(),
                onChanged: (_) => setState(() {
                  _fieldErrors?.remove('password');
                }),
                decoration: InputDecoration(
                  labelText: 'Mot de passe',
                  prefixIcon: const Icon(LucideIcons.lock, size: 18),
                  suffixIcon: IconButton(
                    tooltip: _obscurePassword ? 'Afficher' : 'Masquer',
                    onPressed: () => setState(
                      () => _obscurePassword = !_obscurePassword,
                    ),
                    icon: Icon(
                      _obscurePassword
                          ? LucideIcons.eye
                          : LucideIcons.eyeOff,
                      size: 18,
                    ),
                  ),
                  errorText: _fieldErrors?['password'] as String?,
                ),
              ),
            ],
          ),
        ),
        if (pwd.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: AppSpacing.md,
            runSpacing: 4,
            children: [
              _PasswordRuleCheck(
                label: '8+ caractères',
                ok: hasMinLen,
              ),
              _PasswordRuleCheck(
                label: '1 majuscule & 1 chiffre',
                ok: hasUpperOrDigit,
              ),
            ],
          ),
        ],
        const SizedBox(height: AppSpacing.md),
        Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.sm + 4,
          ),
          decoration: BoxDecoration(
            color: context.palette.surfaceAlt,
            borderRadius: BorderRadius.circular(AppRadius.md),
            border: Border.all(color: context.palette.border),
          ),
          child: Row(
            children: [
              const Icon(
                LucideIcons.award,
                size: 18,
                color: AppColors.brand,
              ),
              const SizedBox(width: AppSpacing.sm + 2),
              Expanded(
                child: Text(
                  'Départ au Niveau 1 (Amateur). Chaque niveau supérieur se débloque en validant vos leçons.',
                  style: context.text.bodySmall,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        PrimaryButton(
          label: 'Créer mon compte',
          icon: LucideIcons.arrowRight,
          isLoading: _isLoading,
          onPressed: _submit,
        ),
        const SizedBox(height: AppSpacing.lg),
        const Divider(),
        const SizedBox(height: AppSpacing.md),
        Wrap(
          alignment: WrapAlignment.center,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text('Déjà inscrit ?', style: context.text.bodySmall),
            TextButton(
              onPressed: () => context.go('/login'),
              child: const Text('Se connecter'),
            ),
          ],
        ),
      ],
    );
  }
}

class _PasswordRuleCheck extends StatelessWidget {
  final String label;
  final bool ok;

  const _PasswordRuleCheck({required this.label, required this.ok});

  @override
  Widget build(BuildContext context) {
    final color = ok ? AppColors.success : context.palette.textMuted;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          ok ? LucideIcons.check : LucideIcons.circle,
          size: 13,
          color: color,
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: context.text.bodySmall?.copyWith(fontSize: 12, color: color),
        ),
      ],
    );
  }
}
