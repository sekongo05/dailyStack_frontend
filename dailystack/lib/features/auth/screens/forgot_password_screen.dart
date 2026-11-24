import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/network/api_response.dart';
import '../../../core/providers/app_providers.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/ui.dart';
import '../widgets/auth_layout.dart';

class ForgotPasswordScreen extends ConsumerStatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  ConsumerState<ForgotPasswordScreen> createState() =>
      _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends ConsumerState<ForgotPasswordScreen> {
  final _emailController = TextEditingController();
  final _codeController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _codeSent = false;
  bool _obscurePassword = true;
  bool _isLoading = false;
  String? _infoMessage;
  String? _errorMessage;
  Map<String, dynamic>? _fieldErrors;

  @override
  void dispose() {
    _emailController.dispose();
    _codeController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _requestCode() async {
    final email = _emailController.text.trim();
    if (email.isEmpty) {
      setState(() => _errorMessage = 'Veuillez saisir votre adresse e-mail.');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _fieldErrors = null;
    });

    try {
      final msg = await ref.read(authServiceProvider).forgotPassword(email);
      if (!mounted) return;
      setState(() {
        _codeSent = true;
        _infoMessage = msg;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = e.message;
        _fieldErrors = e.fieldErrors;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _errorMessage = userFriendlyError(e));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _resetPassword() async {
    final email = _emailController.text.trim();
    final code = _codeController.text.trim();
    final newPassword = _newPasswordController.text;
    final confirmPassword = _confirmPasswordController.text;

    if (code.isEmpty) {
      setState(() => _errorMessage = 'Veuillez saisir le code de réinitialisation.');
      return;
    }
    if (newPassword.length < 6) {
      setState(
        () => _errorMessage = 'Le mot de passe doit contenir au moins 6 caractères.',
      );
      return;
    }
    if (newPassword != confirmPassword) {
      setState(
        () => _errorMessage = 'Les deux mots de passe ne correspondent pas.',
      );
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _fieldErrors = null;
    });

    try {
      final msg = await ref.read(authServiceProvider).resetPassword(
            email: email,
            code: code,
            newPassword: newPassword,
          );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
      context.go('/login');
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = e.message;
        _fieldErrors = e.fieldErrors;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _errorMessage = userFriendlyError(e));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AuthLayout(
      badge: 'RÉCUPÉRATION',
      title: _codeSent
          ? 'Réinitialisez votre mot de passe'
          : 'Mot de passe oublié',
      subtitle: _codeSent
          ? 'Saisissez le code temporaire à 6 chiffres et choisissez un nouveau mot de passe.'
          : 'Indiquez votre adresse e-mail pour recevoir un code de réinitialisation.',
      leadingAction: IconButton(
        tooltip: 'Retour',
        onPressed: () => context.pop(),
        icon: const Icon(Icons.arrow_back_rounded),
      ),
      children: [
        if (_infoMessage != null) ...[
          SurfaceCard(
            color: AppColors.brand.withValues(alpha: 0.08),
            borderColor: AppColors.brand.withValues(alpha: 0.3),
            child: Row(
              children: [
                const Icon(Icons.mark_email_read_outlined, color: AppColors.brand),
                const SizedBox(width: AppSpacing.sm),
                Expanded(child: Text(_infoMessage!, style: context.text.bodySmall)),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.md),
        ],
        if (_errorMessage != null) ...[
          InlineError(message: _errorMessage!),
          const SizedBox(height: AppSpacing.md),
        ],
        TextField(
          controller: _emailController,
          enabled: !_codeSent,
          keyboardType: TextInputType.emailAddress,
          textInputAction:
              _codeSent ? TextInputAction.next : TextInputAction.done,
          onSubmitted: (_) =>
              (!_codeSent && !_isLoading) ? _requestCode() : null,
          decoration: InputDecoration(
            labelText: 'Adresse e-mail',
            prefixIcon: const Icon(Icons.mail_outline_rounded),
            errorText: _fieldErrors?['email'] as String?,
          ),
        ),
        if (_codeSent) ...[
          const SizedBox(height: AppSpacing.md),
          TextField(
            controller: _codeController,
            keyboardType: TextInputType.number,
            textInputAction: TextInputAction.next,
            decoration: InputDecoration(
              labelText: 'Code à 6 chiffres',
              prefixIcon: const Icon(Icons.pin_outlined),
              errorText: _fieldErrors?['code'] as String?,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          TextField(
            controller: _newPasswordController,
            obscureText: _obscurePassword,
            textInputAction: TextInputAction.next,
            decoration: InputDecoration(
              labelText: 'Nouveau mot de passe',
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
              errorText: _fieldErrors?['newPassword'] as String?,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          TextField(
            controller: _confirmPasswordController,
            obscureText: _obscurePassword,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _isLoading ? null : _resetPassword(),
            decoration: const InputDecoration(
              labelText: 'Confirmer le mot de passe',
              prefixIcon: Icon(Icons.lock_outline_rounded),
            ),
          ),
        ],
        const SizedBox(height: AppSpacing.lg),
        PrimaryButton(
          label: _codeSent ? 'Réinitialiser le mot de passe' : 'Envoyer le code',
          isLoading: _isLoading,
          onPressed: _codeSent ? _resetPassword : _requestCode,
        ),
        if (_codeSent) ...[
          const SizedBox(height: AppSpacing.sm),
          TextButton(
            onPressed: _isLoading
                ? null
                : () => setState(() {
                      _codeSent = false;
                      _infoMessage = null;
                      _errorMessage = null;
                    }),
            child: const Text('Modifier l\'adresse e-mail'),
          ),
        ],
      ],
    );
  }
}
