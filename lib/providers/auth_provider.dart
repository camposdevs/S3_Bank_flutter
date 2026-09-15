import 'package:flutter/material.dart';

/// Autenticação puramente local e EM MEMÓRIA — sem storage, sem
/// SharedPreferences, sem banco de dados de nenhum tipo. A sessão dura
/// só enquanto o app está aberto; fechar e abrir de novo pede login
/// outra vez. É o suficiente pra fechar o fluxo do app enquanto você
/// não decide como (e se) vai persistir isso.
///
/// TODO(autenticação real): quando for integrar login de verdade
/// (com ou sem backend), troque só o corpo de [signIn]/[signOut] —
/// a assinatura pode continuar igual, então nenhuma tela muda.
class AuthProvider extends ChangeNotifier {
  bool _isLoggedIn = false;
  String? _loginIdentifier;

  bool get isLoggedIn => _isLoggedIn;
  String? get loginIdentifier => _loginIdentifier;

  /// Validação simples só de formato — não checa senha "real"
  /// nenhuma, já que não há onde ela estaria cadastrada sem backend.
  Future<String?> signIn({required String identifier, required String password}) async {
    if (identifier.trim().isEmpty) return 'Informe seu CPF ou e-mail';
    if (password.length < 4) return 'Senha muito curta';

    // Simula uma latência de rede pra a UI de loading fazer sentido.
    await Future.delayed(const Duration(milliseconds: 700));

    _isLoggedIn = true;
    _loginIdentifier = identifier.trim();
    notifyListeners();
    return null; // null = sucesso
  }

  void signOut() {
    _isLoggedIn = false;
    _loginIdentifier = null;
    notifyListeners();
  }
}
