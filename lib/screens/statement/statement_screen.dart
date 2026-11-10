import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../animations/animations.dart';
import '../../core/theme/app_colors.dart';
import '../../providers/wallet_provider.dart';
import '../../widgets/transaction_tile.dart';

/// Extrato completo da conta: Pix e movimentações de caixinhas.
/// (A aba Pix mostra só os Pix; "Ver tudo" no início abre esta tela.)
class StatementScreen extends StatelessWidget {
  const StatementScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final transactions = context.watch<WalletProvider>().transactions;

    return Scaffold(
      appBar: AppBar(title: const Text('Extrato')),
      body: SafeArea(
        child: transactions.isEmpty
            ? const Center(
                child: Text(
                  'Nenhuma movimentação ainda.',
                  style: TextStyle(color: AppColors.textSecondary),
                ),
              )
            : ListView.builder(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
                itemCount: transactions.length,
                itemBuilder: (context, i) {
                  final t = transactions[i];
                  return FadeSlideIn(
                    key: ValueKey(t.id),
                    delay: Duration(milliseconds: 40 * (i < 8 ? i : 8)),
                    child: TransactionTile(transaction: t),
                  );
                },
              ),
      ),
    );
  }
}
