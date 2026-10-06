import 'package:flutter/material.dart';
import '../core/theme/app_colors.dart';

/// Cenário de fundo "atmosférico": camadas de luz desfocada na paleta
/// da marca, ocupando a tela inteira. Usado na tela de login e na
/// splash screen, pra manter a mesma entrada visual em todo o fluxo
/// de autenticação.
class AtmosphericBackground extends StatelessWidget {
  const AtmosphericBackground({super.key});

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