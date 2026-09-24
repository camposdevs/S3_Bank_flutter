import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_colors.dart';
import '../../providers/auth_provider.dart';

/// Tela de login inspirada na estrutura do app do C6 Bank: um cenário
/// de fundo em tela cheia (lá é uma foto; aqui, um "cenário atmosférico"
/// feito só com o degradê da marca, já que não temos uma foto real) com
/// a marca em destaque no topo, e uma ficha de acesso ancorada na parte
/// de baixo da tela (cantos arredondados só em cima, sem flutuar como
/// cartão) com efeito de vidro fosco sobre o cenário.
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _loginController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;
  bool _loading = false;
  String? _errorMessage;

  @override
  void dispose() {
    _loginController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _loading = true;
      _errorMessage = null;
    });

    final error = await context.read<AuthProvider>().signIn(
          identifier: _loginController.text,
          password: _passwordController.text,
        );

    if (!mounted) return;
    setState(() {
      _loading = false;
      _errorMessage = error;
    });
    // Em caso de sucesso, o AuthGate reage sozinho (via Provider) e
    // troca a tela — não precisa navegar manualmente daqui.
  }

  void _toggleObscurePassword() {
    setState(() => _obscurePassword = !_obscurePassword);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        fit: StackFit.expand,
        children: [
          const _AtmosphericBackground(),
          SafeArea(
            bottom: false,
            child: Column(
              children: [
                const Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(top: 48),
                    child: _BrandHeader(),
                  ),
                ),
                _AccessSheet(
                  formKey: _formKey,
                  loginController: _loginController,
                  passwordController: _passwordController,
                  obscurePassword: _obscurePassword,
                  loading: _loading,
                  errorMessage: _errorMessage,
                  onToggleObscurePassword: _toggleObscurePassword,
                  onSubmit: _submit,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Cenário de fundo "atmosférico": camadas de luz desfocada na paleta
/// da marca, ocupando a tela inteira — faz o papel que uma foto faria
/// no app do C6, mas 100% construído com o degradê do S3 Bank.
class _AtmosphericBackground extends StatelessWidget {
  const _AtmosphericBackground();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.background,
      child: Stack(
        children: [
          Positioned(
            top: -120,
            left: -80,
            child: _glowCircle(420, AppColors.loginPurpleTop.withOpacity(0.55)),
          ),
          Positioned(
            top: 140,
            right: -140,
            child: _glowCircle(380, AppColors.loginBlueMid.withOpacity(0.45)),
          ),
          Positioned(
            bottom: 180,
            left: -100,
            child: _glowCircle(360, AppColors.loginBlueDark.withOpacity(0.55)),
          ),
          Positioned(
            bottom: -60,
            right: -60,
            child: _glowCircle(300, AppColors.accentLight.withOpacity(0.3)),
          ),
        ],
      ),
    );
  }

  Widget _glowCircle(double size, Color color) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(colors: [color, Colors.transparent]),
      ),
    );
  }
}

/// Marca centralizada na parte de cima do cenário — mesma posição que
/// o logo do C6 ocupa sobre a foto.
class _BrandHeader extends StatelessWidget {
  const _BrandHeader();

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.start,
      children: [
        Image.asset(
          'assets/images/logo.png',
          width: 190,
          fit: BoxFit.contain,
        ),
        const SizedBox(height: 10),
        const Text(
          'Sua conta, seu ritmo.',
          style: TextStyle(color: Colors.white70, fontSize: 13),
        ),
      ],
    );
  }
}

/// Ficha de acesso ancorada na base da tela, com efeito de vidro fosco
/// desfocando o cenário atrás dela — mesma lógica do painel do C6, só
/// que aqui sobre o degradê em vez de uma foto.
class _AccessSheet extends StatelessWidget {
  final GlobalKey<FormState> formKey;
  final TextEditingController loginController;
  final TextEditingController passwordController;
  final bool obscurePassword;
  final bool loading;
  final String? errorMessage;
  final VoidCallback onToggleObscurePassword;
  final VoidCallback onSubmit;

  const _AccessSheet({
    required this.formKey,
    required this.loginController,
    required this.passwordController,
    required this.obscurePassword,
    required this.loading,
    required this.errorMessage,
    required this.onToggleObscurePassword,
    required this.onSubmit,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
        child: Container(
          width: double.infinity,
          padding: EdgeInsets.fromLTRB(
            24,
            20,
            24,
            MediaQuery.of(context).viewInsets.bottom > 0
                ? 20
                : MediaQuery.of(context).padding.bottom + 24,
          ),
          decoration: BoxDecoration(
            color: AppColors.surface.withOpacity(0.82),
            border: Border(
              top: BorderSide(color: Colors.white.withOpacity(0.08)),
            ),
          ),
          child: SingleChildScrollView(
            child: Form(
              key: formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      margin: const EdgeInsets.only(bottom: 18),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                  ),
                  const Text(
                    'Acesse sua conta',
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 19,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 18),
                  _AccessField(
                    controller: loginController,
                    label: 'CPF ou e-mail',
                    icon: Icons.person_outline,
                    keyboardType: TextInputType.emailAddress,
                    validator: (v) => (v == null || v.trim().isEmpty)
                        ? 'Informe seu CPF ou e-mail'
                        : null,
                  ),
                  const SizedBox(height: 12),
                  _AccessField(
                    controller: passwordController,
                    label: 'Senha',
                    icon: Icons.lock_outline,
                    obscureText: obscurePassword,
                    validator: (v) =>
                        (v == null || v.length < 4) ? 'Senha muito curta' : null,
                    suffixIcon: IconButton(
                      icon: Icon(
                        obscurePassword
                            ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined,
                        color: AppColors.textSecondary,
                        size: 20,
                      ),
                      onPressed: onToggleObscurePassword,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: () {},
                      style: TextButton.styleFrom(
                        foregroundColor: AppColors.accentLight,
                        padding: EdgeInsets.zero,
                        minimumSize: const Size(0, 32),
                      ),
                      child: const Text(
                        'Esqueci minha senha',
                        style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600),
                      ),
                    ),
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
                  Container(
                    height: 52,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(14),
                      gradient: AppColors.loginGradient,
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.loginBlueMid.withOpacity(0.45),
                          blurRadius: 18,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(14),
                        onTap: loading ? null : onSubmit,
                        child: Center(
                          child: loading
                              ? const SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2.4,
                                    color: Colors.white,
                                  ),
                                )
                              : const Text(
                                  'ENTRAR',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Center(
                    child: RichText(
                      text: TextSpan(
                        style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
                        children: [
                          const TextSpan(text: 'Ainda não é cliente? '),
                          TextSpan(
                            text: 'Abra sua conta',
                            style: const TextStyle(
                              color: AppColors.textPrimary,
                              fontWeight: FontWeight.w700,
                              decoration: TextDecoration.underline,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Campo de texto no estilo padrão do app (superfície escura elevada),
/// já que agora a ficha fica sobre o painel de vidro, não sobre um
/// cartão colorido.
class _AccessField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final IconData icon;
  final bool obscureText;
  final TextInputType? keyboardType;
  final String? Function(String?)? validator;
  final Widget? suffixIcon;

  const _AccessField({
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