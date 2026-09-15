import 'package:flutter/material.dart';

enum PixKeyType { cpf, email, phone, random }

extension PixKeyTypeX on PixKeyType {
  String get label {
    switch (this) {
      case PixKeyType.cpf:
        return 'CPF';
      case PixKeyType.email:
        return 'E-mail';
      case PixKeyType.phone:
        return 'Celular';
      case PixKeyType.random:
        return 'Chave aleatória';
    }
  }
}

class PixKey {
  final String id;
  final PixKeyType type;
  final String value;

  const PixKey({required this.id, required this.type, required this.value});
}

/// Gerencia as chaves Pix do usuário, 100% em memória.
/// TODO(integração-backend): cadastro/remoção de chave Pix precisa,
/// em produção, ser validado e registrado junto ao DICT (Diretório de
/// Identificadores de Contas Transacionais) do Banco Central — algo
/// que só uma instituição autorizada pelo BC pode fazer.
class PixKeysProvider extends ChangeNotifier {
  final List<PixKey> _keys;

  PixKeysProvider() : _keys = _seedKeys();

  List<PixKey> get keys => List.unmodifiable(_keys);

  void addKey({required PixKeyType type, required String value}) {
    _keys.add(
      PixKey(
        id: DateTime.now().microsecondsSinceEpoch.toString(),
        type: type,
        value: value,
      ),
    );
    notifyListeners();
  }

  void removeKey(String id) {
    _keys.removeWhere((k) => k.id == id);
    notifyListeners();
  }

  static List<PixKey> _seedKeys() {
    return [
      const PixKey(id: 'k1', type: PixKeyType.email, value: 'rafaela@email.com'),
      const PixKey(id: 'k2', type: PixKeyType.cpf, value: '•••.•••.•••-00'),
    ];
  }
}
