import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Testes de integração contra o Supabase REAL: cadastro (trigger), saldo
/// pelo livro-razão, Pix, caixinhas, chaves Pix e RLS.
///
/// Só rodam quando as credenciais são passadas por --dart-define. No CI
/// (sem as variáveis) ficam pulados.
///
/// Pré-requisitos no painel do Supabase:
///   - Migrações 0001 e 0002 executadas (SQL Editor).
///   - Authentication > Providers > Email > desligar "Confirm email".
///
/// Como rodar:
///   flutter test test/integration --dart-define=SUPABASE_URL=... --dart-define=SUPABASE_ANON_KEY=...
const _url = String.fromEnvironment('SUPABASE_URL');
const _anonKey = String.fromEnvironment('SUPABASE_ANON_KEY');
final _enabled = _url.isNotEmpty && _anonKey.isNotEmpty;

/// Cliente isolado (sessão própria) para cada usuário de teste. O fluxo
/// implícito não exige armazenamento assíncrono, que o teste não configura.
SupabaseClient _newClient() => SupabaseClient(
      _url,
      _anonKey,
      authOptions: const AuthClientOptions(
        authFlowType: AuthFlowType.implicit,
        autoRefreshToken: false,
      ),
    );

/// Cadastra um usuário único e devolve o cliente já logado.
Future<({SupabaseClient client, String uid, String email})> _signUpUser(
  String label,
) async {
  final client = _newClient();
  final stamp = DateTime.now().microsecondsSinceEpoch;
  final email = 'teste.$label.$stamp@example.com';
  final res = await client.auth.signUp(
    email: email,
    password: '123456',
    data: {'full_name': 'Usuário $label', 'cpf': ''},
  );
  if (res.session == null) {
    throw StateError(
      'Cadastro não devolveu sessão. Desligue "Confirm email" em '
      'Authentication > Providers > Email no painel do Supabase.',
    );
  }
  return (client: client, uid: res.user!.id, email: email);
}

/// Id da conta do usuário logado (RLS: só enxerga a própria).
Future<String> _myAccountId(SupabaseClient client, String uid) async {
  final row = await client.from('accounts').select('id').eq('owner_id', uid).single();
  return row['id'] as String;
}

/// Saldo calculado pelo livro-razão (view account_balances).
Future<int> _balanceCents(SupabaseClient client, String accountId) async {
  final row = await client
      .from('account_balances')
      .select('balance_cents')
      .eq('account_id', accountId)
      .single();
  return (row['balance_cents'] as num).toInt();
}

/// Id da única caixinha do usuário logado.
Future<String> _onlyGoalId(SupabaseClient client) async {
  final row = await client.from('savings_goal_balances').select('goal_id').single();
  return row['goal_id'] as String;
}

void main() {
  final skip = _enabled
      ? null
      : 'Defina SUPABASE_URL e SUPABASE_ANON_KEY com --dart-define para rodar';

  group('Supabase real', () {
    // ------------------------------------------------------------ cadastro e saldo

    test('cadastro cria perfil e conta automaticamente (trigger)', () async {
      final a = await _signUpUser('perfil');
      final profile = await a.client
          .from('profiles')
          .select('full_name')
          .eq('id', a.uid)
          .single();
      expect(profile['full_name'], 'Usuário perfil');
      expect(await _myAccountId(a.client, a.uid), isNotEmpty);
    });

    test('conta nova começa com saldo zero', () async {
      final a = await _signUpUser('zero');
      final accountId = await _myAccountId(a.client, a.uid);
      expect(await _balanceCents(a.client, accountId), 0);
    });

    test('depósito simulado aparece no saldo', () async {
      final a = await _signUpUser('deposito');
      final accountId = await _myAccountId(a.client, a.uid);
      await a.client.rpc('simulate_deposit', params: {
        'p_amount_cents': 100000,
        'p_description': 'teste',
      });
      expect(await _balanceCents(a.client, accountId), 100000);
    });

    // ------------------------------------------------------------ Pix

    test('Pix entre dois usuários move o saldo nas duas pontas', () async {
      final a = await _signUpUser('pixA');
      final b = await _signUpUser('pixB');
      final accA = await _myAccountId(a.client, a.uid);
      final accB = await _myAccountId(b.client, b.uid);

      await b.client.from('pix_keys').insert({
        'account_id': accB,
        'key_type': 'email',
        'key_value': b.email,
      });
      await a.client.rpc('simulate_deposit', params: {
        'p_amount_cents': 10000,
        'p_description': 'saldo inicial',
      });
      await a.client.rpc('pix_transfer', params: {
        'p_key_value': b.email,
        'p_amount_cents': 2500,
        'p_description': 'teste pix',
      });

      expect(await _balanceCents(a.client, accA), 7500);
      expect(await _balanceCents(b.client, accB), 2500);
    });

    test('Pix sem saldo é recusado pelo banco', () async {
      final a = await _signUpUser('semSaldo');
      final b = await _signUpUser('semSaldoDest');
      final accB = await _myAccountId(b.client, b.uid);
      await b.client.from('pix_keys').insert({
        'account_id': accB,
        'key_type': 'email',
        'key_value': b.email,
      });

      await expectLater(
        Future(() async => a.client.rpc('pix_transfer', params: {
              'p_key_value': b.email,
              'p_amount_cents': 999999999,
            })),
        throwsA(isA<PostgrestException>().having(
          (e) => e.message,
          'message',
          contains('saldo insuficiente'),
        )),
      );
    });

    // ------------------------------------------------------------ RLS (livro-razão)

    test('RLS: um usuário não enxerga o livro-razão de outro', () async {
      final a = await _signUpUser('rlsA');
      final b = await _signUpUser('rlsB');
      final accA = await _myAccountId(a.client, a.uid);
      await a.client.rpc('simulate_deposit', params: {
        'p_amount_cents': 5000,
        'p_description': 'privado',
      });

      final visivel = await b.client
          .from('ledger_entries')
          .select('id')
          .eq('account_id', accA);
      expect(visivel, isEmpty);
    });

    test('RLS: escrita direta no livro-razão é bloqueada', () async {
      final a = await _signUpUser('escrita');
      final accountId = await _myAccountId(a.client, a.uid);

      await expectLater(
        Future(() async => a.client.from('ledger_entries').insert({
              'account_id': accountId,
              'amount_cents': 999999,
              'kind': 'deposit',
            })),
        throwsA(isA<PostgrestException>()),
      );
    });

    test('RLS: não é possível alterar lançamentos existentes', () async {
      final a = await _signUpUser('edicao');
      final accountId = await _myAccountId(a.client, a.uid);
      await a.client.rpc('simulate_deposit', params: {
        'p_amount_cents': 5000,
        'p_description': 'original',
      });

      // Sem permissão de UPDATE, o banco recusa ou não altera nenhuma linha.
      try {
        final changed = await a.client
            .from('ledger_entries')
            .update({'amount_cents': 1})
            .eq('account_id', accountId)
            .select();
        expect(changed, isEmpty);
      } on PostgrestException {
        // recusado pelo banco: também é o comportamento esperado
      }
      expect(await _balanceCents(a.client, accountId), 5000);
    });

    // ------------------------------------------------------------ caixinhas

    test('caixinha: criar, guardar e resgatar movem o saldo certo', () async {
      final a = await _signUpUser('caixa');
      final accId = await _myAccountId(a.client, a.uid);
      await a.client.rpc('simulate_deposit', params: {
        'p_amount_cents': 10000,
        'p_description': 'saldo inicial',
      });

      await a.client.rpc('create_savings_goal', params: {
        'p_name': 'Viagem',
        'p_target_cents': 50000,
      });
      final goalId = await _onlyGoalId(a.client);

      await a.client.rpc('savings_move', params: {
        'p_goal_id': goalId,
        'p_amount_cents': 3000,
        'p_direction': 'in',
      });
      expect(await _balanceCents(a.client, accId), 7000);
      final afterIn = await a.client
          .from('savings_goal_balances')
          .select('saved_cents')
          .eq('goal_id', goalId)
          .single();
      expect((afterIn['saved_cents'] as num).toInt(), 3000);

      await a.client.rpc('savings_move', params: {
        'p_goal_id': goalId,
        'p_amount_cents': 1000,
        'p_direction': 'out',
      });
      expect(await _balanceCents(a.client, accId), 8000);
      final afterOut = await a.client
          .from('savings_goal_balances')
          .select('saved_cents')
          .eq('goal_id', goalId)
          .single();
      expect((afterOut['saved_cents'] as num).toInt(), 2000);
    });

    test('caixinha: guardar sem saldo é recusado', () async {
      final a = await _signUpUser('caixaSemSaldo');
      await a.client.rpc('create_savings_goal', params: {
        'p_name': 'Reserva',
        'p_target_cents': 10000,
      });
      final goalId = await _onlyGoalId(a.client);

      await expectLater(
        Future(() async => a.client.rpc('savings_move', params: {
              'p_goal_id': goalId,
              'p_amount_cents': 500,
              'p_direction': 'in',
            })),
        throwsA(isA<PostgrestException>().having(
          (e) => e.message,
          'message',
          contains('saldo insuficiente'),
        )),
      );
    });

    test('caixinha: resgatar mais do que o guardado é recusado', () async {
      final a = await _signUpUser('caixaResgate');
      await a.client.rpc('simulate_deposit', params: {
        'p_amount_cents': 5000,
        'p_description': 'saldo',
      });
      await a.client.rpc('create_savings_goal', params: {
        'p_name': 'Reserva',
        'p_target_cents': 10000,
      });
      final goalId = await _onlyGoalId(a.client);
      await a.client.rpc('savings_move', params: {
        'p_goal_id': goalId,
        'p_amount_cents': 1000,
        'p_direction': 'in',
      });

      await expectLater(
        Future(() async => a.client.rpc('savings_move', params: {
              'p_goal_id': goalId,
              'p_amount_cents': 2000,
              'p_direction': 'out',
            })),
        throwsA(isA<PostgrestException>().having(
          (e) => e.message,
          'message',
          contains('valor maior que o guardado'),
        )),
      );
    });

    test('caixinha: outro usuário não vê nem movimenta a caixinha', () async {
      final a = await _signUpUser('caixaA');
      final b = await _signUpUser('caixaB');
      await a.client.rpc('create_savings_goal', params: {
        'p_name': 'Privada',
        'p_target_cents': 10000,
      });
      final goalId = await _onlyGoalId(a.client);

      final visivel = await b.client.from('savings_goal_balances').select();
      expect(visivel, isEmpty);

      await expectLater(
        Future(() async => b.client.rpc('savings_move', params: {
              'p_goal_id': goalId,
              'p_amount_cents': 100,
              'p_direction': 'in',
            })),
        throwsA(isA<PostgrestException>().having(
          (e) => e.message,
          'message',
          contains('caixinha não encontrada'),
        )),
      );
    });

    // ------------------------------------------------------------ chaves Pix

    test('chave Pix: cadastrar, listar e remover pela própria conta', () async {
      final a = await _signUpUser('pixKey');
      final accId = await _myAccountId(a.client, a.uid);

      await a.client.from('pix_keys').insert({
        'account_id': accId,
        'key_type': 'email',
        'key_value': a.email,
      });
      final listed = await a.client.from('pix_keys').select('id').eq('key_value', a.email);
      expect(listed.length, 1);

      await a.client.from('pix_keys').delete().eq('key_value', a.email);
      final depois = await a.client.from('pix_keys').select('id').eq('key_value', a.email);
      expect(depois, isEmpty);
    });

    test('chave Pix: outro usuário não consegue cadastrar a mesma chave', () async {
      final a = await _signUpUser('pixDonoA');
      final b = await _signUpUser('pixDonoB');
      final accA = await _myAccountId(a.client, a.uid);
      final accB = await _myAccountId(b.client, b.uid);

      await a.client.from('pix_keys').insert({
        'account_id': accA,
        'key_type': 'email',
        'key_value': a.email,
      });

      await expectLater(
        Future(() async => b.client.from('pix_keys').insert({
              'account_id': accB,
              'key_type': 'email',
              'key_value': a.email,
            })),
        throwsA(isA<PostgrestException>()),
      );
    });

    test('chave Pix: cadastro pela função register_pix_key', () async {
      final a = await _signUpUser('regKey');
      final id = await a.client.rpc('register_pix_key', params: {
        'p_key_type': 'email',
        'p_key_value': a.email,
      });
      expect(id, isNotNull);

      final listed = await a.client.from('pix_keys').select('id').eq('key_value', a.email);
      expect(listed.length, 1);
    });

    test('chave Pix: chave já usada por outra conta é recusada com mensagem clara', () async {
      final a = await _signUpUser('regDupA');
      final b = await _signUpUser('regDupB');
      await a.client.rpc('register_pix_key', params: {
        'p_key_type': 'email',
        'p_key_value': a.email,
      });

      await expectLater(
        Future(() async => b.client.rpc('register_pix_key', params: {
              'p_key_type': 'email',
              'p_key_value': a.email,
            })),
        throwsA(isA<PostgrestException>().having(
          (e) => e.message,
          'message',
          contains('chave já em uso'),
        )),
      );
    });

    // ------------------------------------------------------------ gamificação

    test('gamificação: aporte em caixinha gera pontos no servidor', () async {
      final a = await _signUpUser('gamif');
      final accId = await _myAccountId(a.client, a.uid);
      await a.client.rpc('simulate_deposit', params: {
        'p_amount_cents': 10000,
        'p_description': 'saldo',
      });
      await a.client.rpc('create_savings_goal', params: {
        'p_name': 'Reserva',
        'p_target_cents': 50000,
      });
      final goalId = await _onlyGoalId(a.client);
      await a.client.rpc('savings_move', params: {
        'p_goal_id': goalId,
        'p_amount_cents': 10000,
        'p_direction': 'in',
      });

      // R$ 100 -> 15 + 100/10 = 25 pontos, primeiro mês (sem bônus).
      final row = await a.client
          .from('user_progress')
          .select('tier, points, streak_months')
          .eq('account_id', accId)
          .single();
      expect(row['tier'], 'bronze');
      expect((row['points'] as num).toInt(), 25);
      expect((row['streak_months'] as num).toInt(), 1);
    });

    test('gamificação: resgatar não gera pontos', () async {
      final a = await _signUpUser('gamifResgate');
      final accId = await _myAccountId(a.client, a.uid);
      await a.client.rpc('simulate_deposit', params: {
        'p_amount_cents': 10000,
        'p_description': 'saldo',
      });
      await a.client.rpc('create_savings_goal', params: {
        'p_name': 'Reserva',
        'p_target_cents': 50000,
      });
      final goalId = await _onlyGoalId(a.client);
      await a.client.rpc('savings_move', params: {
        'p_goal_id': goalId,
        'p_amount_cents': 10000,
        'p_direction': 'in',
      });
      final antes = await a.client
          .from('user_progress')
          .select('points')
          .eq('account_id', accId)
          .single();

      await a.client.rpc('savings_move', params: {
        'p_goal_id': goalId,
        'p_amount_cents': 5000,
        'p_direction': 'out',
      });
      final depois = await a.client
          .from('user_progress')
          .select('points')
          .eq('account_id', accId)
          .single();
      expect(depois['points'], antes['points']);
    });

    test('gamificação: progresso de outro usuário não é visível', () async {
      final a = await _signUpUser('gamifA');
      final b = await _signUpUser('gamifB');
      final accA = await _myAccountId(a.client, a.uid);
      await a.client.rpc('simulate_deposit', params: {
        'p_amount_cents': 10000,
        'p_description': 'saldo',
      });
      await a.client.rpc('create_savings_goal', params: {
        'p_name': 'Reserva',
        'p_target_cents': 50000,
      });
      final goalId = await _onlyGoalId(a.client);
      await a.client.rpc('savings_move', params: {
        'p_goal_id': goalId,
        'p_amount_cents': 10000,
        'p_direction': 'in',
      });
      expect(await a.client.from('user_progress').select().eq('account_id', accA), isNotEmpty);

      final visivel = await b.client.from('user_progress').select().eq('account_id', accA);
      expect(visivel, isEmpty);
    });

    test('gamificação: usuário não consegue alterar os próprios pontos', () async {
      final a = await _signUpUser('gamifEdit');
      final accId = await _myAccountId(a.client, a.uid);
      await a.client.rpc('simulate_deposit', params: {
        'p_amount_cents': 1000,
        'p_description': 'saldo',
      });
      await a.client.rpc('create_savings_goal', params: {
        'p_name': 'Reserva',
        'p_target_cents': 50000,
      });
      final goalId = await _onlyGoalId(a.client);
      await a.client.rpc('savings_move', params: {
        'p_goal_id': goalId,
        'p_amount_cents': 1000,
        'p_direction': 'in',
      });

      try {
        final changed = await a.client
            .from('user_progress')
            .update({'points': 999999})
            .eq('account_id', accId)
            .select();
        expect(changed, isEmpty);
      } on PostgrestException {
        // recusado pelo banco: também é o comportamento esperado
      }
      final row = await a.client
          .from('user_progress')
          .select('points')
          .eq('account_id', accId)
          .single();
      // R$ 10 -> 15 + 10/10 = 16 pontos; o valor real continua o do servidor.
      expect((row['points'] as num).toInt(), 16);
    });
  }, skip: skip);
}
