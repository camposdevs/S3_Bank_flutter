import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Conta do usuário logado. O [id] é o UUID do Supabase Auth, que é a
/// mesma chave usada no banco (profiles, accounts, ledger_entries).
class Account {
  final String id;
  final String name;
  final String identifier;

  const Account({
    required this.id,
    required this.name,
    required this.identifier,
  });
}

/// Autenticação via Supabase Auth.
///
/// A sessão é persistida pelo próprio supabase_flutter, então o usuário
/// continua logado ao reabrir o app. A API pública (signIn, signUp,
/// signOut, recuperação de senha) não mudou, então as telas continuam
/// iguais.
///
/// Login é feito por e-mail: o Supabase Auth exige e-mail, e aceitar CPF
/// exigiria um endpoint público que converte CPF em e-mail (vazamento).
class AuthProvider extends ChangeNotifier {
  static const _networkError = 'Sem conexão com o servidor. Tente de novo';
  static const _genericError = 'Não foi possível concluir. Tente de novo';

  StreamSubscription<AuthState>? _sub;
  Account? _account;

  // Estado temporário da recuperação de senha (só em memória).
  String? _resetEmail;
  bool _resetVerified = false;

  /// [connect] = false cria o provider sem tocar no Supabase (usado nos
  /// testes de widget e de dados locais). Nesse modo ele começa deslogado.
  AuthProvider({bool connect = true}) {
    if (!connect) return;
    _sub = _auth.onAuthStateChange.listen((state) => _onSession(state.session));
    _onSession(_auth.currentSession);
  }

  GoTrueClient get _auth => Supabase.instance.client.auth;

  bool get isLoggedIn => _account != null;
  Account? get currentAccount => _account;
  String? get loginIdentifier => _account?.identifier;

  // ------------------------------------------------------------ helpers

  static final _emailRegex = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

  static bool isValidEmail(String raw) => _emailRegex.hasMatch(raw.trim());

  static String normalizeEmail(String raw) => raw.trim().toLowerCase();

  static String _mapError(AuthException e) {
    final m = e.message.toLowerCase();
    if (m.contains('invalid login')) return 'E-mail ou senha incorretos';
    if (m.contains('already registered') || m.contains('already exists')) {
      return 'Já existe uma conta com esse e-mail';
    }
    if (m.contains('not confirmed')) {
      return 'Confirme seu e-mail antes de entrar';
    }
    if (m.contains('rate limit') || m.contains('too many')) {
      return 'Muitas tentativas. Aguarde um pouco';
    }
    if (m.contains('token') || m.contains('otp')) {
      return 'Código incorreto ou expirado';
    }
    return _genericError;
  }

  // ------------------------------------------------------------ sessão

  Future<void> _onSession(Session? session) async {
    final user = session?.user;
    if (user == null) {
      if (_account != null) {
        _account = null;
        notifyListeners();
      }
      return;
    }
    if (_account?.id == user.id) return;

    final name = await _loadName(user);
    // Se a sessão mudou enquanto o nome carregava, descarta o resultado.
    if (_auth.currentUser?.id != user.id) return;

    _account = Account(
      id: user.id,
      name: name,
      identifier: user.email ?? '',
    );
    notifyListeners();
  }

  Future<String> _loadName(User user) async {
    final fallback = (user.userMetadata?['full_name'] as String?) ?? 'Cliente';
    try {
      final row = await Supabase.instance.client
          .from('profiles')
          .select('full_name')
          .eq('id', user.id)
          .maybeSingle();
      return (row?['full_name'] as String?) ?? fallback;
    } catch (_) {
      return fallback;
    }
  }

  // ------------------------------------------------------------ login

  Future<String?> signIn({required String identifier, required String password}) async {
    final email = normalizeEmail(identifier);
    if (email.isEmpty) return 'Informe seu e-mail';
    if (!isValidEmail(email)) return 'Informe um e-mail válido';
    if (password.length < 6) return 'A senha precisa ter pelo menos 6 caracteres';

    try {
      await _auth.signInWithPassword(email: email, password: password);
      return null; // a sessão chega pelo onAuthStateChange
    } on AuthException catch (e) {
      return _mapError(e);
    } catch (_) {
      return _networkError;
    }
  }

  /// Cria a conta. Se o projeto exigir confirmação por e-mail, o usuário
  /// precisa confirmar antes de entrar.
  Future<String?> signUp({
    required String name,
    required String identifier,
    required String password,
  }) async {
    if (name.trim().length < 2) return 'Informe seu nome completo';
    final email = normalizeEmail(identifier);
    if (!isValidEmail(email)) return 'Informe um e-mail válido';
    if (password.length < 6) return 'A senha precisa ter pelo menos 6 caracteres';

    try {
      final res = await _auth.signUp(
        email: email,
        password: password,
        data: {'full_name': name.trim()},
      );
      if (res.session == null) {
        return 'Confirme seu e-mail pelo link que enviamos e depois entre';
      }
      return null;
    } on AuthException catch (e) {
      return _mapError(e);
    } catch (_) {
      return _networkError;
    }
  }

  void signOut() {
    // Zera a conta já, para o coordenador salvar os dados desta conta.
    _account = null;
    notifyListeners();
    try {
      _auth.signOut().catchError((_) {});
    } catch (_) {
      // Supabase não inicializado (testes): nada a encerrar no servidor.
    }
  }

  /// Só para testes: entra com uma conta fabricada, sem falar com o Supabase.
  @visibleForTesting
  void debugLogin(Account account) {
    _account = account;
    notifyListeners();
  }

  // ------------------------------------------------- recuperar a senha

  /// Etapa 1: envia o código por e-mail (template com {{ .Token }}).
  Future<String?> requestPasswordReset(String identifier) async {
    final email = normalizeEmail(identifier);
    if (!isValidEmail(email)) return 'Informe um e-mail válido';

    try {
      await _auth.resetPasswordForEmail(email);
      _resetEmail = email;
      _resetVerified = false;
      return null;
    } on AuthException catch (e) {
      return _mapError(e);
    } catch (_) {
      return _networkError;
    }
  }

  /// Etapa 2: confere o código de 6 dígitos. Isso também abre uma sessão
  /// temporária, necessária para trocar a senha na etapa 3.
  Future<String?> verifyResetCode(String code) async {
    final email = _resetEmail;
    if (email == null) return 'Solicite um novo código';

    try {
      await _auth.verifyOTP(
        type: OtpType.recovery,
        email: email,
        token: code.trim(),
      );
      _resetVerified = true;
      return null;
    } on AuthException catch (e) {
      return _mapError(e);
    } catch (_) {
      return _networkError;
    }
  }

  /// Etapa 3: grava a nova senha.
  Future<String?> resetPassword(String newPassword) async {
    if (!_resetVerified || _auth.currentSession == null) {
      return 'A recuperação expirou. Comece de novo.';
    }
    if (newPassword.length < 6) return 'A senha precisa ter pelo menos 6 caracteres';

    try {
      await _auth.updateUser(UserAttributes(password: newPassword));
      _resetEmail = null;
      _resetVerified = false;
      return null;
    } on AuthException catch (e) {
      return _mapError(e);
    } catch (_) {
      return _networkError;
    }
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}
