import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_colors.dart';
import '../../models/savings_goal.dart';
import '../../models/user_tier.dart';
import '../../providers/savings_provider.dart';
import '../../providers/user_provider.dart';
import '../../providers/wallet_provider.dart';

class SavingsScreen extends StatelessWidget {
  const SavingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final savings = context.watch<SavingsProvider>();
    final user = context.watch<UserProvider>();
    final currencyFmt = NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$');

    return Scaffold(
      appBar: AppBar(title: const Text('Guardar Dinheiro')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showCreateGoalModal(context),
        icon: const Icon(Icons.add),
        label: const Text('Nova caixinha'),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 100),
          children: [
            // Gamificação integrada: mostra o rendimento atual com base no nível.
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                gradient: AppColors.accentGradient,
                borderRadius: BorderRadius.circular(18),
              ),
              child: Row(
                children: [
                  Icon(user.tier.icon, color: Colors.white, size: 28),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Seu dinheiro está rendendo ${user.tier.cdiLabel} no nível ${user.tier.displayName}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: _SummaryTile(
                    label: 'Total guardado',
                    value: currencyFmt.format(savings.totalSaved),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _SummaryTile(
                    label: 'Rendimento do mês',
                    value:
                        '+ ${currencyFmt.format(savings.monthlyYieldEstimate(user.tier))}',
                    valueColor: AppColors.success,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            const Text(
              'Suas caixinhas',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
            ),
            const SizedBox(height: 12),
            if (savings.goals.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Text(
                  'Você ainda não criou nenhuma caixinha.',
                  style: TextStyle(color: AppColors.textSecondary),
                ),
              )
            else
              ...savings.goals.map(
                (goal) => _GoalCard(goal: goal),
              ),
          ],
        ),
      ),
    );
  }

  void _showCreateGoalModal(BuildContext context) {
    final savings = context.read<SavingsProvider>();
    final nameController = TextEditingController();
    final targetController = TextEditingController();
    final formKey = GlobalKey<FormState>();
    IconData selectedIcon = Icons.savings_outlined;

    final iconOptions = const [
      Icons.savings_outlined,
      Icons.flight_takeoff,
      Icons.shield_outlined,
      Icons.directions_car_outlined,
      Icons.home_outlined,
      Icons.school_outlined,
    ];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setState) {
            return Padding(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 20,
                bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
              ),
              child: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Nova caixinha',
                        style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18)),
                    const SizedBox(height: 16),
                    Wrap(
                      spacing: 10,
                      children: iconOptions.map((icon) {
                        final selected = icon == selectedIcon;
                        return GestureDetector(
                          onTap: () => setState(() => selectedIcon = icon),
                          child: CircleAvatar(
                            radius: 22,
                            backgroundColor: selected
                                ? AppColors.accent
                                : AppColors.surfaceElevated,
                            child: Icon(icon, color: Colors.white, size: 20),
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: nameController,
                      decoration: const InputDecoration(labelText: 'Nome do objetivo'),
                      validator: (v) =>
                          (v == null || v.trim().isEmpty) ? 'Informe um nome' : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: targetController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(labelText: 'Valor alvo (R\$)'),
                      validator: (v) {
                        final value = double.tryParse((v ?? '').replaceAll(',', '.'));
                        if (value == null || value <= 0) return 'Valor inválido';
                        return null;
                      },
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () {
                          if (!formKey.currentState!.validate()) return;
                          savings.createGoal(
                            name: nameController.text.trim(),
                            icon: selectedIcon,
                            targetAmount:
                                double.parse(targetController.text.replaceAll(',', '.')),
                          );
                          Navigator.of(ctx).pop();
                        },
                        child: const Text('Criar caixinha'),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class _SummaryTile extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColor;

  const _SummaryTile({required this.label, required this.value, this.valueColor});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 16,
              color: valueColor ?? AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}

class _GoalCard extends StatelessWidget {
  final SavingsGoal goal;

  const _GoalCard({required this.goal});

  @override
  Widget build(BuildContext context) {
    final currencyFmt = NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$');

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: AppColors.surfaceElevated,
                child: Icon(goal.icon, color: AppColors.accentLight, size: 18),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(goal.name,
                        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                    Text(
                      '${currencyFmt.format(goal.currentAmount)} de ${currencyFmt.format(goal.targetAmount)}',
                      style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: goal.progress,
              minHeight: 8,
              backgroundColor: AppColors.surfaceElevated,
              valueColor: const AlwaysStoppedAnimation(AppColors.accentLight),
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: Wrap(
                  spacing: 8,
                  children: [10, 50, 100].map((v) {
                    return _QuickChip(
                      label: 'R\$ $v',
                      onTap: () => _deposit(context, goal, v.toDouble()),
                    );
                  }).toList(),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => _showCustomDepositModal(context, goal),
                  child: const Text('Guardar valor'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: TextButton(
                  onPressed: goal.currentAmount <= 0
                      ? null
                      : () => _showWithdrawModal(context, goal),
                  child: const Text('Resgatar'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _deposit(BuildContext context, SavingsGoal goal, double amount) {
    final wallet = context.read<WalletProvider>();
    final savings = context.read<SavingsProvider>();
    final user = context.read<UserProvider>();

    final debited = wallet.debitForSavings(amount, goalName: goal.name);
    if (!debited) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Saldo insuficiente na conta corrente.')),
      );
      return;
    }
    savings.deposit(goal.id, amount);
    // Cada aporte alimenta a pontuação de constância que impulsiona o
    // usuário rumo ao próximo nível de rendimento.
    user.registerDeposit(amount);
  }

  void _showCustomDepositModal(BuildContext context, SavingsGoal goal) {
    final controller = TextEditingController();
    final formKey = GlobalKey<FormState>();
    final wallet = context.read<WalletProvider>();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 20,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
          ),
          child: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Guardar em "${goal.name}"',
                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 18)),
                const SizedBox(height: 16),
                TextFormField(
                  controller: controller,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(labelText: 'Valor (R\$)'),
                  validator: (v) {
                    final value = double.tryParse((v ?? '').replaceAll(',', '.'));
                    if (value == null || value <= 0) return 'Valor inválido';
                    if (value > wallet.balance) return 'Saldo insuficiente';
                    return null;
                  },
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      if (!formKey.currentState!.validate()) return;
                      final amount = double.parse(controller.text.replaceAll(',', '.'));
                      Navigator.of(ctx).pop();
                      _deposit(context, goal, amount);
                    },
                    child: const Text('Confirmar'),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showWithdrawModal(BuildContext context, SavingsGoal goal) {
    final controller = TextEditingController();
    final formKey = GlobalKey<FormState>();
    final savings = context.read<SavingsProvider>();
    final wallet = context.read<WalletProvider>();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 20,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
          ),
          child: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Resgatar de "${goal.name}"',
                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 18)),
                const SizedBox(height: 16),
                TextFormField(
                  controller: controller,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(labelText: 'Valor (R\$)'),
                  validator: (v) {
                    final value = double.tryParse((v ?? '').replaceAll(',', '.'));
                    if (value == null || value <= 0) return 'Valor inválido';
                    if (value > goal.currentAmount) return 'Valor maior que o guardado';
                    return null;
                  },
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      if (!formKey.currentState!.validate()) return;
                      final amount = double.parse(controller.text.replaceAll(',', '.'));
                      final actual = savings.withdraw(goal.id, amount);
                      wallet.creditFromSavings(actual, goalName: goal.name);
                      Navigator.of(ctx).pop();
                    },
                    child: const Text('Confirmar resgate'),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _QuickChip extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _QuickChip({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return ActionChip(
      label: Text(label),
      backgroundColor: AppColors.surfaceElevated,
      labelStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
      onPressed: onTap,
    );
  }
}
