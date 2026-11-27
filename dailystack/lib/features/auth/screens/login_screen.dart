import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../../core/network/api_response.dart';
import '../../../core/providers/app_providers.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/ui.dart';
import '../widgets/auth_layout.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;
  bool _isLoading = false;
  String? _errorMessage;
  Map<String, dynamic>? _fieldErrors;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text;
    final localErrors = <String, String>{};
    if (email.isEmpty || !email.contains('@')) {
      localErrors['email'] = 'Saisissez une adresse e-mail valide.';
    }
    if (password.isEmpty) {
      localErrors['password'] = 'Saisissez votre mot de passe.';
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
      final auth = await ref.read(authServiceProvider).login(
            email: email,
            password: password,
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
      setState(() => _errorMessage = 'Impossible de se connecter.');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AuthLayout(
      badge: 'CONNEXION',
      title: 'Bon retour',
      subtitle:
          'Reprenez votre séance quotidienne Backend & DevOps là où vous l’avez laissée.',
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
                autofillHints: const [AutofillHints.password],
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => _isLoading ? null : _submit(),
                onChanged: (_) {
                  if (_fieldErrors?.containsKey('password') == true) {
                    setState(() => _fieldErrors?.remove('password'));
                  }
                },
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
        const SizedBox(height: AppSpacing.xs),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton(
            onPressed: () => context.push('/forgot-password'),
            child: const Text('Mot de passe oublié ?'),
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        PrimaryButton(
          label: 'Se connecter',
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
            Text('Nouveau sur DailyStack ?', style: context.text.bodySmall),
            TextButton(
              onPressed: () => context.go('/register'),
              child: const Text('Créer un compte'),
            ),
          ],
        ),
      ],
    );
  }
}
