import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/transaction.dart';

/// Erro com mensagem já pronta para o usuário.
class LedgerException implements Exception {
  final String message;
  const LedgerException(this.message);

  @override
  String toString() => message;
}

/// Acesso ao livro-razão no Supabase.
///
/// Regras: o saldo é lido da view `account_balances` (soma do livro-razão)
/// e nunca editado. Toda escrita passa pelas funções do banco
/// (`pix_transfer`, `simulate_deposit`), que validam saldo e chave.
class LedgerRepository {
  final SupabaseClient? _injected;

  LedgerRepository([this._injected]);

  SupabaseClient get _client => _injected ?? Supabase.instance.client;

  Future<int> fetchBalanceCents() => _run(() async {
        final row = await _client
            .from('account_balances')
            .select('balance_cents')
            .maybeSingle();
        return row == null ? 0 : (row['balance_cents'] as num).toInt();
      });

  Future<List<Transaction>> fetchStatement({int limit = 100}) => _run(() async {
        final rows = await _client
            .from('ledger_entries')
            .select()
            .order('created_at', ascending: false)
            .limit(limit);
        return rows.map((r) => toTransaction(Map<String, dynamic>.from(r))).toList();
      });

  Future<void> sendPix({
    required String keyValue,
    required int amountCents,
    String? description,
  }) =>
      _run(() async {
        await _client.rpc('pix_transfer', params: {
          'p_key_value': keyValue,
          'p_amount_cents': amountCents,
          'p_description': description,
        });
      });

  Future<void> simulateDeposit({required int amountCents, String? description}) =>
      _run(() async {
        await _client.rpc('simulate_deposit', params: {
          'p_amount_cents': amountCents,
          'p_description': description,
        });
      });

  /// Converte uma linha de `ledger_entries` no modelo que as telas usam.
  /// Amount sempre positivo; o tipo define se é entrada ou saída.
  static Transaction toTransaction(Map<String, dynamic> row) {
    final kind = row['kind'] as String;
    final cents = (row['amount_cents'] as num).toInt();
    final description = (row['description'] as String?)?.trim() ?? '';
    final date = DateTime.tryParse(row['created_at'] as String? ?? '') ?? DateTime.now();

    TransactionType type;
    String title;
    switch (kind) {
      case 'pix_in':
        type = TransactionType.pixReceived;
        title = 'Pix recebido';
      case 'pix_out':
        type = TransactionType.pixSent;
        title = 'Pix enviado';
      case 'deposit':
        type = TransactionType.pixReceived;
        title = 'Depósito';
      case 'transfer_in':
        type = TransactionType.pixReceived;
        title = 'Transferência recebida';
      case 'transfer_out':
        type = TransactionType.pixSent;
        title = 'Transferência enviada';
      case 'withdrawal':
        type = TransactionType.pixSent;
        title = 'Saque';
      case 'fee':
        type = TransactionType.pixSent;
        title = 'Tarifa';
      default:
        type = cents >= 0 ? TransactionType.pixReceived : TransactionType.pixSent;
        title = 'Ajuste';
    }

    return Transaction(
      id: row['id'] as String,
      type: type,
      title: title,
      subtitle: description.isEmpty ? title : description,
      amount: cents.abs() / 100,
      date: date,
    );
  }

  /// Executa uma operação do banco e traduz erros para o usuário.
  Future<T> _run<T>(Future<T> Function() op) async {
    try {
      return await op();
    } on PostgrestException catch (e) {
      throw LedgerException(_friendly(e.message));
    } catch (_) {
      throw const LedgerException('Sem conexão com o servidor. Tente de novo');
    }
  }

  static String _friendly(String message) {
    final m = message.toLowerCase();
    if (m.contains('saldo insuficiente')) return 'Saldo insuficiente';
    if (m.contains('chave pix não encontrada')) return 'Chave Pix não encontrada';
    if (m.contains('própria conta')) return 'Não é possível enviar para a própria conta';
    if (m.contains('valor inválido')) return 'Valor inválido';
    if (m.contains('conta não encontrada')) return 'Conta não encontrada';
    return 'Não foi possível concluir a operação';
  }
}
