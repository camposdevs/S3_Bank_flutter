import 'package:flutter_test/flutter_test.dart';
import 'package:s3_bank/providers/auth_provider.dart';

// Os fluxos que chamam o Supabase precisam de um projeto real (ou de um
// mock do GoTrueClient) para serem testados de ponta a ponta. Aqui ficam
// as regras puras, que não dependem de rede.
void main() {
  group('validação de e-mail', () {
    test('aceita e-mails válidos', () {
      expect(AuthProvider.isValidEmail('nome@email.com'), isTrue);
      expect(AuthProvider.isValidEmail('  a.b@dominio.com.br '), isTrue);
    });

    test('rejeita CPF e textos sem formato de e-mail', () {
      expect(AuthProvider.isValidEmail('52998224725'), isFalse);
      expect(AuthProvider.isValidEmail('sem-arroba'), isFalse);
      expect(AuthProvider.isValidEmail(''), isFalse);
    });

    test('normaliza para minúsculas e sem espaços', () {
      expect(AuthProvider.normalizeEmail('  Nome@Email.COM '), 'nome@email.com');
    });
  });

  group('constantes da conta demo', () {
    test('senha demo respeita o mínimo do Supabase (6 caracteres)', () {
      expect(AuthProvider.demoPassword.length, greaterThanOrEqualTo(6));
      expect(AuthProvider.isValidEmail(AuthProvider.demoIdentifier), isTrue);
    });
  });
}
