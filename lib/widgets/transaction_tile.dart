import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../core/theme/app_colors.dart';
import '../models/transaction.dart';

class TransactionTile extends StatelessWidget {
  final Transaction transaction;

  const TransactionTile({super.key, required this.transaction});

  IconData get _icon {
    switch (transaction.type) {
      case TransactionType.pixSent:
        return Icons.arrow_upward;
      case TransactionType.pixReceived:
        return Icons.arrow_downward;
      case TransactionType.savingsDeposit:
        return Icons.savings_outlined;
      case TransactionType.savingsWithdraw:
        return Icons.account_balance_wallet_outlined;
    }
  }

  @override
  Widget build(BuildContext context) {
    final formatter = NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$');
    final dateFormatter = DateFormat('dd/MM • HH:mm');
    final color = transaction.isCredit ? AppColors.success : AppColors.textPrimary;
    final sign = transaction.isCredit ? '+ ' : '- ';

    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Container(
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          color: AppColors.surfaceElevated,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(_icon, color: AppColors.textSecondary, size: 20),
      ),
      title: Text(
        transaction.title,
        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
      ),
      subtitle: Text(
        '${transaction.subtitle} • ${dateFormatter.format(transaction.date)}',
        style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
      ),
      trailing: Text(
        '$sign${formatter.format(transaction.amount)}',
        style: TextStyle(color: color, fontWeight: FontWeight.w700, fontSize: 13.5),
      ),
    );
  }
}
