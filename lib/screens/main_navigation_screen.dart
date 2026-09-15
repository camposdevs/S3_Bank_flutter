import 'package:flutter/material.dart';
import '../core/theme/app_colors.dart';
import 'card/card_screen.dart';
import 'dashboard/dashboard_screen.dart';
import 'pix/pix_screen.dart';
import 'savings/savings_screen.dart';

/// Casca principal do app com navegação por abas. O Dashboard é a home;
/// as demais abas reaproveitam as telas de feature já existentes.
class MainNavigationScreen extends StatefulWidget {
  const MainNavigationScreen({super.key});

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  int _currentIndex = 0;

  void _goToTab(int index) => setState(() => _currentIndex = index);

  @override
  Widget build(BuildContext context) {
    final screens = [
      DashboardScreen(onNavigateToTab: _goToTab),
      const PixScreen(),
      const SavingsScreen(),
      const CardScreen(),
    ];

    return Scaffold(
      body: IndexedStack(index: _currentIndex, children: screens),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: _goToTab,
        backgroundColor: AppColors.surface,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home_outlined), label: 'Início'),
          BottomNavigationBarItem(icon: Icon(Icons.qr_code), label: 'Pix'),
          BottomNavigationBarItem(icon: Icon(Icons.savings_outlined), label: 'Guardar'),
          BottomNavigationBarItem(icon: Icon(Icons.credit_card), label: 'Cartão'),
        ],
      ),
    );
  }
}
