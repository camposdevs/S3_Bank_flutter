import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_colors.dart';
import '../../providers/auth_provider.dart';
import '../../providers/user_provider.dart';
import '../../widgets/atmospheric_background.dart';
import '../../widgets/gradient_button.dart';

/// Tela de cadastro — mesma linguagem visual do login (cenário
/// atmosférico + ficha de vidro fosco ancorada embaixo). Ao criar a
/// conta com sucesso, atualiza o nome exibido no app via [UserProvider]
/// e loga o usuário automaticamente (o AuthGate troca de tela sozinho).
class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _identifierController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();
  bool _obscurePassword = true;
  bool _loading = false;
  String? _errorMessage;

  @override
  void dispose() {
    _nameController.dispose();
    _identifierController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _loading = true;
      _errorMessage = null;
    });

    // Captura antes do await para não usar o context depois do gap assíncrono.
    final authProvider = context.read<AuthProvider>();
    final userProvider = context.read<UserProvider>();
    final navigator = Navigator.of(context);
    final name = _nameController.text;

    final error = await authProvider.signUp(
      name: name,
      identifier: _identifierController.text,
      password: _passwordController.text,
    );

    if (!mounted) return;

    if (error == null) {
      userProvider.updateName(name);
      // Fecha a tela de cadastro (e o login, se estiver empilhado) para
      // revelar o AuthGate, que já mostra a home por causa do isLoggedIn.
      navigator.popUntil((route) => route.isFirst);
      return;
    }

    setState(() {
      _loading = false;
      _errorMessage = error;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        fit: StackFit.expand,
        children: [
          const AtmosphericBackground(),
          SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(4, 4, 20, 0),
                  child: Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.arrow_back, color: Colors.white),
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 32),
                  child: Column(
                    children: [
                      Text(
                        'Criar sua conta',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      SizedBox(height: 6),
                      Text(
                        'Leva menos de um minuto.',
                        style: TextStyle(color: Colors.white70, fontSize: 13),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: Center(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(vertical: 24),
                      child: _SignupCard(
                        formKey: _formKey,
                        nameController: _nameController,
                        identifierController: _identifierController,
                        passwordController: _passwordController,
                        confirmController: _confirmController,
                        obscurePassword: _obscurePassword,
                        loading: _loading,
                        errorMessage: _errorMessage,
                        onToggleObscure: () =>
                            setState(() => _obscurePassword = !_obscurePassword),
                        onSubmit: _submit,
                      ),
                    ),
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

class _SignupCard extends StatelessWidget {
  final GlobalKey<FormState> formKey;
  final TextEditingController nameController;
  final TextEditingController identifierController;
  final TextEditingController passwordController;
  final TextEditingController confirmController;
  final bool obscurePassword;
  final bool loading;
  final String? errorMessage;
  final VoidCallback onToggleObscure;
  final VoidCallback onSubmit;

  const _SignupCard({
    required this.formKey,
    required this.nameController,
    required this.identifierController,
    required this.passwordController,
    required this.confirmController,
    required this.obscurePassword,
    required this.loading,
    required this.errorMessage,
    required this.onToggleObscure,
    required this.onSubmit,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
        child: Container(
          width: double.infinity,
          margin: const EdgeInsets.symmetric(horizontal: 20),
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            color: AppColors.surface.withOpacity(0.82),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Colors.white.withOpacity(0.08)),
          ),
          child: Form(
            key: formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                _Field(
                  controller: nameController,
                  label: 'Nome completo',
                  icon: Icons.badge_outlined,
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? 'Informe seu nome' : null,
                ),
                const SizedBox(height: 12),
                _Field(
                  controller: identifierController,
                  label: 'CPF ou e-mail',
                  icon: Icons.person_outline,
                  keyboardType: TextInputType.emailAddress,
                  validator: (v) => (v == null || v.trim().isEmpty)
                      ? 'Informe seu CPF ou e-mail'
                      : null,
                ),
                const SizedBox(height: 12),
                _Field(
                  controller: passwordController,
                  label: 'Senha',
                  icon: Icons.lock_outline,
                  obscureText: obscurePassword,
                  validator: (v) =>
                      (v == null || v.length < 4) ? 'Mínimo de 4 caracteres' : null,
                  suffixIcon: IconButton(
                    icon: Icon(
                      obscurePassword
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined,
                      color: AppColors.textSecondary,
                      size: 20,
                    ),
                    onPressed: onToggleObscure,
                  ),
                ),
                const SizedBox(height: 12),
                _Field(
                  controller: confirmController,
                  label: 'Confirmar senha',
                  icon: Icons.lock_outline,
                  obscureText: obscurePassword,
                  validator: (v) => (v != passwordController.text)
                      ? 'As senhas não coincidem'
                      : null,
                ),
                const SizedBox(height: 8),
                if (errorMessage != null) ...[
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      color: AppColors.danger.withOpacity(0.14),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      errorMessage!,
                      style: const TextStyle(
                        color: AppColors.danger,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                ],
                GradientButton(
                  label: loading ? 'CRIANDO CONTA...' : 'CRIAR CONTA',
                  onTap: loading ? null : onSubmit,
                ),
                const SizedBox(height: 14),
                Center(
                  child: GestureDetector(
                    onTap: () => Navigator.of(context).pop(),
                    child: RichText(
                      text: const TextSpan(
                        style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
                        children: [
                          TextSpan(text: 'Já tem conta? '),
                          TextSpan(
                            text: 'Entrar',
                            style: TextStyle(
                              color: AppColors.textPrimary,
                              fontWeight: FontWeight.w700,
                              decoration: TextDecoration.underline,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Field extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final IconData icon;
  final bool obscureText;
  final TextInputType? keyboardType;
  final String? Function(String?)? validator;
  final Widget? suffixIcon;

  const _Field({
    required this.controller,
    required this.label,
    required this.icon,
    this.obscureText = false,
    this.keyboardType,
    this.validator,
    this.suffixIcon,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      obscureText: obscureText,
      keyboardType: keyboardType,
      validator: validator,
      style: const TextStyle(color: AppColors.textPrimary, fontSize: 14.5),
      cursorColor: AppColors.accentLight,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: AppColors.textSecondary, fontSize: 13.5),
        prefixIcon: Icon(icon, color: AppColors.textSecondary, size: 20),
        suffixIcon: suffixIcon,
        filled: true,
        fillColor: AppColors.surfaceElevated,
        contentPadding: const EdgeInsets.symmetric(vertical: 14, horizontal: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: AppColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.accentLight, width: 1.4),
        ),
        errorStyle: const TextStyle(color: AppColors.danger, fontSize: 11),
      ),
    );
  }
}