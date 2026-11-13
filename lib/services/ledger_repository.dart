import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/transaction.dart';

/// Erro com mensagem já pronta para o usuário.
class LedgerException implements Exception {
  final String message;
  const LedgerException(this.message);

  @override
  String toString() => message;
}

/// Acesso ao banco (Supabase).
///
/// Regras: saldos são lidos de views (somas do livro-razão) e nunca
/// editados. Toda escrita financeira passa por funções do banco, que
/// validam saldo e regras. As chaves Pix são gravadas na tabela `pix_keys`
/// (com RLS), que é a única escrita direta permitida.
class LedgerRepository {
  final SupabaseClient? _injected;

  LedgerRepository([this._injected]);

  SupabaseClient get _client => _injected ?? Supabase.instance.client;

  // ------------------------------------------------------------ saldo e extrato

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

  // ------------------------------------------------------------ caixinhas

  /// Linhas da view savings_goal_balances: goal_id, name, target_cents,
  /// saved_cents, created_at.
  Future<List<Map<String, dynamic>>> fetchGoals() => _run(() async {
        final rows = await _client
            .from('savings_goal_balances')
            .select()
            .order('created_at', ascending: true);
        return rows.map((r) => Map<String, dynamic>.from(r)).toList();
      });

  Future<void> createGoal({required String name, required int targetCents}) =>
      _run(() async {
        await _client.rpc('create_savings_goal', params: {
          'p_name': name,
          'p_target_cents': targetCents,
        });
      });

  /// direction: 'in' guarda (sai da conta), 'out' resgata (volta para a conta).
  Future<void> moveSavings({
    required String goalId,
    required int amountCents,
    required String direction,
  }) =>
      _run(() async {
        await _client.rpc('savings_move', params: {
          'p_goal_id': goalId,
          'p_amount_cents': amountCents,
          'p_direction': direction,
        });
      });

  // ------------------------------------------------------------ chaves Pix

  Future<List<Map<String, dynamic>>> fetchPixKeys() => _run(() async {
        final rows = await _client
            .from('pix_keys')
            .select('id, key_type, key_value')
            .order('created_at', ascending: true);
        return rows.map((r) => Map<String, dynamic>.from(r)).toList();
      });

  /// Cadastro pela função `register_pix_key` (migração 0003).
  Future<void> insertPixKey({required String keyType, required String keyValue}) =>
      _run(() async {
        await _client.rpc('register_pix_key', params: {
          'p_key_type': keyType,
          'p_key_value': keyValue,
        });
      });

  Future<void> deletePixKey(String id) => _run(() async {
        await _client.from('pix_keys').delete().eq('id', id);
      });

  /// Progresso de gamificação da conta (nível, pontos, constância), ou null.
  Future<Map<String, dynamic>?> fetchProgress() => _run(() async {
        final row = await _client
            .from('user_progress')
            .select('tier, points, streak_months')
            .maybeSingle();
        return row == null ? null : Map<String, dynamic>.from(row);
      });

  // ------------------------------------------------------------ mapeamento

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
      case 'savings_in':
        type = TransactionType.savingsDeposit;
        title = 'Guardado em caixinha';
      case 'savings_out':
        type = TransactionType.savingsWithdraw;
        title = 'Resgatado da caixinha';
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

  // ------------------------------------------------------------ erros

  /// Executa uma operação do banco e traduz erros para o usuário.
  Future<T> _run<T>(Future<T> Function() op) async {
    try {
      return await op();
    } on PostgrestException catch (e) {
      // Aparece no console (flutter run) para diagnosticar a causa real.
      debugPrint('[banco] ${e.code}: ${e.message} ${e.details ?? ''}');
      throw LedgerException(_friendly(e.message));
    } catch (e) {
      debugPrint('[banco] erro de conexão: $e');
      throw const LedgerException('Sem conexão com o servidor. Tente de novo');
    }
  }

  static String _friendly(String message) {
    final m = message.toLowerCase();
    if (m.contains('saldo insuficiente')) return 'Saldo insuficiente';
    if (m.contains('chave pix não encontrada')) return 'Chave Pix não encontrada';
    if (m.contains('própria conta')) return 'Não é possível enviar para a própria conta';
    if (m.contains('valor inválido')) return 'Valor inválido';
    if (m.contains('valor maior que o guardado')) return 'Valor maior que o guardado';
    if (m.contains('caixinha não encontrada')) return 'Caixinha não encontrada';
    if (m.contains('nome inválido')) return 'Informe um nome para a caixinha';
    if (m.contains('conta não encontrada')) return 'Conta não encontrada';
    // Chave duplicada ou de outra pessoa: mensagem genérica, para não
    // revelar se uma chave existe em outra conta.
    if (m.contains('chave já em uso') || m.contains('duplicate key')) {
      return 'Esta chave já está em uso';
    }
    if (m.contains('tipo inválido')) return 'Tipo de chave inválido';
    if (m.contains('could not find the function') || m.contains('schema cache')) {
      return 'Banco desatualizado: execute a migração 0003 no Supabase';
    }
    if (m.contains('row-level security')) {
      return 'Não foi possível cadastrar esta chave';
    }
    return 'Não foi possível concluir a operação';
  }
}
