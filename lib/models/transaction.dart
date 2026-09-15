enum TransactionType { pixSent, pixReceived, savingsDeposit, savingsWithdraw }

class Transaction {
  final String id;
  final TransactionType type;
  final String title;
  final String subtitle;
  final double amount;
  final DateTime date;

  const Transaction({
    required this.id,
    required this.type,
    required this.title,
    required this.subtitle,
    required this.amount,
    required this.date,
  });

  /// Indica se o valor deve ser exibido como entrada (verde) ou saída (padrão).
  bool get isCredit =>
      type == TransactionType.pixReceived || type == TransactionType.savingsWithdraw;
}
