import 'package:flutter/material.dart';
import '../models/transaction.dart';

/// Gerencia o saldo da conta corrente e o histórico geral de transações
/// (Pix + movimentações de caixinhas refletidas na conta).
/// TODO(integração-backend): substituir por chamadas reais a uma API
/// de extrato/saldo (ex: GET /account/balance, GET /account/statement).
class WalletProvider extends ChangeNotifier {
  double _balance;
  bool _balanceVisible = true;
  final List<Transaction> _transactions;

  WalletProvider({double initialBalance = 3482.17})
      : _balance = initialBalance,
        _transactions = _seedTransactions();

  double get balance => _balance;
  bool get balanceVisible => _balanceVisible;
  List<Transaction> get transactions => List.unmodifiable(_transactions);

  void toggleBalanceVisibility() {
    _balanceVisible = !_balanceVisible;
    notifyListeners();
  }

  bool sendPix(double amount, {required String recipient}) {
    if (amount <= 0 || amount > _balance) return false;
    _balance -= amount;
    _transactions.insert(
      0,
      Transaction(
        id: DateTime.now().microsecondsSinceEpoch.toString(),
        type: TransactionType.pixSent,
        title: 'Pix enviado',
        subtitle: recipient,
        amount: amount,
        date: DateTime.now(),
      ),
    );
    notifyListeners();
    return true;
  }

  void receivePix(double amount, {required String sender}) {
    _balance += amount;
    _transactions.insert(
      0,
      Transaction(
        id: DateTime.now().microsecondsSinceEpoch.toString(),
        type: TransactionType.pixReceived,
        title: 'Pix recebido',
        subtitle: sender,
        amount: amount,
        date: DateTime.now(),
      ),
    );
    notifyListeners();
  }

  /// Usado pela área "Guardar Dinheiro" para debitar da conta corrente
  /// quando o usuário faz um aporte em uma caixinha.
  bool debitForSavings(double amount, {required String goalName}) {
    if (amount <= 0 || amount > _balance) return false;
    _balance -= amount;
    _transactions.insert(
      0,
      Transaction(
        id: DateTime.now().microsecondsSinceEpoch.toString(),
        type: TransactionType.savingsDeposit,
        title: 'Guardado em $goalName',
        subtitle: 'Guardar Dinheiro',
        amount: amount,
        date: DateTime.now(),
      ),
    );
    notifyListeners();
    return true;
  }

  /// Usado quando o usuário resgata uma caixinha de volta para a conta.
  void creditFromSavings(double amount, {required String goalName}) {
    _balance += amount;
    _transactions.insert(
      0,
      Transaction(
        id: DateTime.now().microsecondsSinceEpoch.toString(),
        type: TransactionType.savingsWithdraw,
        title: 'Resgatado de $goalName',
        subtitle: 'Guardar Dinheiro',
        amount: amount,
        date: DateTime.now(),
      ),
    );
    notifyListeners();
  }

  static List<Transaction> _seedTransactions() {
    final now = DateTime.now();
    return [
      Transaction(
        id: '1',
        type: TransactionType.pixReceived,
        title: 'Pix recebido',
        subtitle: 'João Pedro',
        amount: 250,
        date: now.subtract(const Duration(hours: 3)),
      ),
      Transaction(
        id: '2',
        type: TransactionType.savingsDeposit,
        title: 'Guardado em Reserva de Emergência',
        subtitle: 'Guardar Dinheiro',
        amount: 100,
        date: now.subtract(const Duration(days: 1)),
      ),
      Transaction(
        id: '3',
        type: TransactionType.pixSent,
        title: 'Pix enviado',
        subtitle: 'Mercado Bom Preço',
        amount: 68.9,
        date: now.subtract(const Duration(days: 2)),
      ),
    ];
  }
}
