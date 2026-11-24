import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
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
    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _fieldErrors = null;
    });

    try {
      final auth = await ref.read(authServiceProvider).register(
            email: _emailController.text.trim(),
            password: _passwordController.text,
            username: _usernameController.text.trim(),
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
    return AuthLayout(
      badge: 'NOUVEAU COMPTE',
      title: 'Créer un compte',
      subtitle: 'Commencez votre progression Backend & DevOps dès aujourd\'hui.',
      leadingAction: IconButton(
        tooltip: 'Retour',
        onPressed: () => context.go('/login'),
        icon: const Icon(Icons.arrow_back_rounded),
      ),
      children: [
        if (_errorMessage != null) ...[
          InlineError(message: _errorMessage!),
          const SizedBox(height: AppSpacing.md),
        ],
        TextField(
          controller: _usernameController,
          textInputAction: TextInputAction.next,
          decoration: InputDecoration(
            labelText: 'Nom d\'utilisateur',
            prefixIcon: const Icon(Icons.person_outline_rounded),
            errorText: _fieldErrors?['username'] as String?,
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        TextField(
          controller: _emailController,
          keyboardType: TextInputType.emailAddress,
          textInputAction: TextInputAction.next,
          decoration: InputDecoration(
            labelText: 'Adresse e-mail',
            prefixIcon: const Icon(Icons.mail_outline_rounded),
            errorText: _fieldErrors?['email'] as String?,
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        TextField(
          controller: _passwordController,
          obscureText: _obscurePassword,
          textInputAction: TextInputAction.done,
          onSubmitted: (_) => _isLoading ? null : _submit(),
          decoration: InputDecoration(
            labelText: 'Mot de passe',
            prefixIcon: const Icon(Icons.lock_outline_rounded),
            suffixIcon: IconButton(
              tooltip: _obscurePassword ? 'Afficher' : 'Masquer',
              onPressed: () => setState(
                () => _obscurePassword = !_obscurePassword,
              ),
              icon: Icon(
                _obscurePassword
                    ? Icons.visibility_outlined
                    : Icons.visibility_off_outlined,
              ),
            ),
            errorText: _fieldErrors?['password'] as String?,
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        PrimaryButton(
          label: 'S\'inscrire',
          isLoading: _isLoading,
          onPressed: _submit,
        ),
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
