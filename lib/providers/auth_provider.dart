import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import '../services/local_store.dart';

/// Conta cadastrada no aparelho. A senha nunca é guardada em texto puro:
/// só o hash (SHA-256) combinado com um "sal" aleatório.
class Account {
  final String id;
  final String name;
  final String identifier;
  final String salt;
  final String passwordHash;
  final bool isDemo;

  const Account({
    required this.id,
    required this.name,
    required this.identifier,
    required this.salt,
    required this.passwordHash,
    this.isDemo = false,
  });

  Account withPassword(String salt, String passwordHash) => Account(
        id: id,
        name: name,
        identifier: identifier,
        salt: salt,
        passwordHash: passwordHash,
        isDemo: isDemo,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'identifier': identifier,
        'salt': salt,
        'passwordHash': passwordHash,
        'isDemo': isDemo,
      };

  factory Account.fromJson(Map<String, dynamic> json) => Account(
        id: json['id'] as String,
        name: json['name'] as String,
        identifier: json['identifier'] as String,
        salt: json['salt'] as String,
        passwordHash: json['passwordHash'] as String,
        isDemo: json['isDemo'] as bool? ?? false,
      );
}

/// Autenticação local: contas e sessão ficam salvas no aparelho
/// (via [LocalStore]), então o usuário continua logado ao reabrir o app.
///
/// Não há servidor: o "hash" protege contra leitura casual do
/// armazenamento, mas NÃO substitui autenticação de verdade.
///
/// TODO(integração-backend): trocar o corpo de [signIn], [signUp],
/// [signOut] e do fluxo de recuperação por chamadas à API. As
/// assinaturas podem continuar iguais, então nenhuma tela muda.
class AuthProvider extends ChangeNotifier {
  /// Conta de demonstração, criada automaticamente na primeira execução.
  static const demoIdentifier = 'demo@s3bank.com';
  static const demoPassword = '1234';
  static const demoName = 'Rafaela Souza';

  static const _accountsKey = 'accounts';
  static const _sessionKey = 'session';

  final LocalStore _store;
  final Map<String, Account> _accounts = {};
  String? _currentId;

  // Estado temporário da recuperação de senha (nunca vai para o disco).
  String? _resetAccountId;
  String? _resetCode;
  bool _resetVerified = false;

  AuthProvider(this._store) {
    _loadFromDisk();
  }

  bool get isLoggedIn => _currentId != null;
  Account? get currentAccount => _currentId == null ? null : _accounts[_currentId];
  String? get loginIdentifier => currentAccount?.identifier;

  /// Código da recuperação de senha. Como não há e-mail/SMS de verdade,
  /// a tela de recuperação mostra o código (modo demonstração).
  String? get demoResetCode => _resetCode;

  // ------------------------------------------------------------ helpers

  /// E-mail em minúsculas ou CPF só com dígitos, para comparar contas.
  static String normalizeIdentifier(String raw) {
    final v = raw.trim().toLowerCase();
    if (v.contains('@')) return v;
    final digits = v.replaceAll(RegExp(r'\D'), '');
    return digits.isNotEmpty ? digits : v;
  }

  static final _emailRegex = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

  static bool _isValidIdentifier(String normalized) {
    if (normalized.contains('@')) return _emailRegex.hasMatch(normalized);
    return RegExp(r'^\d{11}$').hasMatch(normalized);
  }

  static String _newSalt() {
    final random = Random.secure();
    final bytes = List<int>.generate(16, (_) => random.nextInt(256));
    return base64UrlEncode(bytes);
  }

  static String _hash(String salt, String password) =>
      sha256.convert(utf8.encode('$salt:$password')).toString();

  void _loadFromDisk() {
    final raw = _store.getString(_accountsKey);
    if (raw != null) {
      try {
        final list = jsonDecode(raw) as List;
        for (final item in list) {
          final account = Account.fromJson(Map<String, dynamic>.from(item as Map));
          _accounts[account.id] = account;
        }
      } catch (_) {
        _accounts.clear(); // dado corrompido: começa limpo
      }
    }

    final demoId = normalizeIdentifier(demoIdentifier);
    if (!_accounts.containsKey(demoId)) {
      final salt = _newSalt();
      _accounts[demoId] = Account(
        id: demoId,
        name: demoName,
        identifier: demoIdentifier,
        salt: salt,
        passwordHash: _hash(salt, demoPassword),
        isDemo: true,
      );
      _saveAccounts();
    }

    final session = _store.getString(_sessionKey);
    if (session != null && _accounts.containsKey(session)) {
      _currentId = session;
    }
  }

  void _saveAccounts() {
    _store.setString(
      _accountsKey,
      jsonEncode(_accounts.values.map((a) => a.toJson()).toList()),
    );
  }

  void _startSession(String id) {
    _currentId = id;
    _store.setString(_sessionKey, id);
    notifyListeners();
  }

  // ------------------------------------------------------------ login

  Future<String?> signIn({required String identifier, required String password}) async {
    if (identifier.trim().isEmpty) return 'Informe seu CPF ou e-mail';
    if (password.length < 4) return 'Senha muito curta';

    await Future.delayed(const Duration(milliseconds: 700));

    final account = _accounts[normalizeIdentifier(identifier)];
    if (account == null || account.passwordHash != _hash(account.salt, password)) {
      return 'CPF/e-mail ou senha incorretos';
    }

    _startSession(account.id);
    return null; // null = sucesso
  }

  /// Cria a conta e já loga o usuário.
  Future<String?> signUp({
    required String name,
    required String identifier,
    required String password,
  }) async {
    if (name.trim().isEmpty) return 'Informe seu nome completo';
    if (identifier.trim().isEmpty) return 'Informe seu CPF ou e-mail';
    if (password.length < 4) return 'Senha muito curta';

    final id = normalizeIdentifier(identifier);
    if (!_isValidIdentifier(id)) return 'Informe um e-mail válido ou um CPF com 11 dígitos';

    await Future.delayed(const Duration(milliseconds: 900));

    if (_accounts.containsKey(id)) {
      return 'Já existe uma conta com esse CPF ou e-mail';
    }

    final salt = _newSalt();
    _accounts[id] = Account(
      id: id,
      name: name.trim(),
      identifier: identifier.trim(),
      salt: salt,
      passwordHash: _hash(salt, password),
    );
    _saveAccounts();

    _startSession(id);
    return null;
  }

  void signOut() {
    _currentId = null;
    _store.remove(_sessionKey);
    notifyListeners();
  }

  // ------------------------------------------------- recuperar a senha

  /// Etapa 1: confere se a conta existe e gera o código.
  Future<String?> requestPasswordReset(String identifier) async {
    if (identifier.trim().isEmpty) return 'Informe seu CPF ou e-mail';

    await Future.delayed(const Duration(milliseconds: 900));

    final id = normalizeIdentifier(identifier);
    if (!_accounts.containsKey(id)) {
      return 'Não encontramos uma conta com esses dados';
    }

    _resetAccountId = id;
    _resetCode = (Random.secure().nextInt(900000) + 100000).toString();
    _resetVerified = false;
    return null;
  }

  /// Etapa 2: confere o código digitado.
  Future<String?> verifyResetCode(String code) async {
    await Future.delayed(const Duration(milliseconds: 600));

    if (_resetCode == null) return 'Solicite um novo código';
    if (code.trim() != _resetCode) return 'Código incorreto';

    _resetVerified = true;
    return null;
  }

  /// Etapa 3: grava a nova senha da conta.
  Future<String?> resetPassword(String newPassword) async {
    final id = _resetAccountId;
    final account = id == null ? null : _accounts[id];
    if (!_resetVerified || account == null) {
      return 'A recuperação expirou. Comece de novo.';
    }
    if (newPassword.length < 4) return 'Senha muito curta';

    await Future.delayed(const Duration(milliseconds: 900));

    final salt = _newSalt();
    _accounts[account.id] = account.withPassword(salt, _hash(salt, newPassword));
    _saveAccounts();

    _resetAccountId = null;
    _resetCode = null;
    _resetVerified = false;
    return null;
  }
}
