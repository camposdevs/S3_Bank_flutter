import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Testes de integração contra o Supabase REAL: cadastro (trigger), saldo
/// pelo livro-razão, Pix entre usuários e RLS.
///
/// Só rodam quando as credenciais são passadas por --dart-define. No CI
/// (sem as variáveis) ficam pulados.
///
/// Pré-requisito no painel do Supabase:
///   Authentication > Providers > Email > desligar "Confirm email"
///   (senão o cadastro não devolve sessão e o teste avisa).
///
/// Como rodar:
///   flutter test test/integration --dart-define=SUPABASE_URL=... --dart-define=SUPABASE_ANON_KEY=...
const _url = String.fromEnvironment('SUPABASE_URL');
const _anonKey = String.fromEnvironment('SUPABASE_ANON_KEY');
final _enabled = _url.isNotEmpty && _anonKey.isNotEmpty;

/// Cria um cliente isolado (sessão própria) para cada usuário de teste.
SupabaseClient _newClient() => SupabaseClient(
      _url,
      _anonKey,
      // PKCE exige armazenamento assíncrono, que o teste (sem Flutter) não
      // configura. O fluxo implícito funciona sem ele.
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
    password: 'senha-teste-123',
    data: {'full_name': 'Usuário $label', 'cpf': ''},
  );
  final session = res.session;
  if (session == null) {
    throw StateError(
      'Cadastro não devolveu sessão. Desligue "Confirm email" em '
      'Authentication > Providers > Email no painel do Supabase.',
    );
  }
  return (client: client, uid: res.user!.id, email: email);
}

/// Id da conta do usuário logado (RLS: só enxerga a própria).
Future<String> _myAccountId(SupabaseClient client, String uid) async {
  final row = await client
      .from('accounts')
      .select('id')
      .eq('owner_id', uid)
      .single();
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

void main() {
  final skip = _enabled
      ? null
      : 'Defina SUPABASE_URL e SUPABASE_ANON_KEY com --dart-define para rodar';

  group('Supabase real', () {
    test('cadastro cria perfil e conta automaticamente (trigger)', () async {
      final a = await _signUpUser('perfil');
      final profile = await a.client
          .from('profiles')
          .select('full_name')
          .eq('id', a.uid)
          .single();
      expect(profile['full_name'], 'Usuário perfil');

      final accountId = await _myAccountId(a.client, a.uid);
      expect(accountId, isNotEmpty);
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

    test('Pix entre dois usuários move o saldo nas duas pontas', () async {
      final a = await _signUpUser('pixA');
      final b = await _signUpUser('pixB');
      final accA = await _myAccountId(a.client, a.uid);
      final accB = await _myAccountId(b.client, b.uid);

      // B cadastra a própria chave Pix (RLS permite só na própria conta).
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
  }, skip: skip);
}
