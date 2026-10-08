import 'package:flutter_test/flutter_test.dart';
import 'package:s3_bank/providers/auth_provider.dart';
import 'package:s3_bank/services/local_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<AuthProvider> newAuth() async => AuthProvider(await LocalStore.create());

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('normalizeIdentifier', () {
    test('e-mail: minúsculas e sem espaços', () {
      expect(AuthProvider.normalizeIdentifier('  Nome@Email.COM '), 'nome@email.com');
    });

    test('CPF: só dígitos, com ou sem máscara', () {
      expect(AuthProvider.normalizeIdentifier('529.982.247-25'), '52998224725');
      expect(AuthProvider.normalizeIdentifier('52998224725'), '52998224725');
    });
  });

  group('login', () {
    test('a conta de demonstração existe desde a primeira execução', () async {
      final auth = await newAuth();
      expect(auth.isLoggedIn, isFalse);

      final error = await auth.signIn(
        identifier: AuthProvider.demoIdentifier,
        password: AuthProvider.demoPassword,
      );
      expect(error, isNull);
      expect(auth.isLoggedIn, isTrue);
      expect(auth.currentAccount!.isDemo, isTrue);
      expect(auth.currentAccount!.name, AuthProvider.demoName);
    });

    test('senha errada ou conta inexistente dão o mesmo erro', () async {
      final auth = await newAuth();
      final wrongPassword = await auth.signIn(
        identifier: AuthProvider.demoIdentifier,
        password: 'errada',
      );
      final unknownAccount = await auth.signIn(
        identifier: 'ninguem@email.com',
        password: '1234',
      );
      expect(wrongPassword, 'CPF/e-mail ou senha incorretos');
      expect(unknownAccount, wrongPassword);
      expect(auth.isLoggedIn, isFalse);
    });

    test('valida campos vazios e senha curta antes de procurar a conta', () async {
      final auth = await newAuth();
      expect(await auth.signIn(identifier: ' ', password: '1234'), isNotNull);
      expect(await auth.signIn(identifier: 'a@b.com', password: '12'), 'Senha muito curta');
    });
  });

  group('cadastro', () {
    test('cria a conta e já entra nela', () async {
      final auth = await newAuth();
      final error = await auth.signUp(
        name: 'Maria Teste',
        identifier: 'maria@email.com',
        password: 'abcd',
      );
      expect(error, isNull);
      expect(auth.isLoggedIn, isTrue);
      expect(auth.currentAccount!.name, 'Maria Teste');
      expect(auth.currentAccount!.isDemo, isFalse);
    });

    test('não permite cadastrar o mesmo e-mail duas vezes', () async {
      final auth = await newAuth();
      await auth.signUp(name: 'Maria', identifier: 'maria@email.com', password: 'abcd');
      auth.signOut();

      final error = await auth.signUp(
        name: 'Outra Maria',
        identifier: 'MARIA@email.com',
        password: 'efgh',
      );
      expect(error, 'Já existe uma conta com esse CPF ou e-mail');
    });

    test('recusa identificador que não é e-mail nem CPF de 11 dígitos', () async {
      final auth = await newAuth();
      final error = await auth.signUp(name: 'Maria', identifier: 'maria', password: 'abcd');
      expect(error, isNotNull);
      expect(auth.isLoggedIn, isFalse);
    });

    test('CPF com máscara e sem máscara são a mesma conta', () async {
      final auth = await newAuth();
      await auth.signUp(name: 'Maria', identifier: '529.982.247-25', password: 'abcd');
      auth.signOut();

      final error = await auth.signIn(identifier: '52998224725', password: 'abcd');
      expect(error, isNull);
    });

    test('a senha nunca fica salva em texto puro', () async {
      final auth = await newAuth();
      await auth.signUp(name: 'Maria', identifier: 'maria@email.com', password: 'senha-secreta');
      final account = auth.currentAccount!;
      expect(account.passwordHash.contains('senha-secreta'), isFalse);
      expect(account.passwordHash.length, 64); // SHA-256 em hexadecimal

      final prefs = await SharedPreferences.getInstance();
      final everything = prefs.getKeys().map((k) => prefs.get(k).toString()).join();
      expect(everything.contains('senha-secreta'), isFalse);
    });
  });

  group('sessão', () {
    test('continua logado ao "reabrir o app"', () async {
      final first = await newAuth();
      await first.signUp(name: 'Maria', identifier: 'maria@email.com', password: 'abcd');

      final reopened = await newAuth(); // novo AuthProvider, mesmo armazenamento
      expect(reopened.isLoggedIn, isTrue);
      expect(reopened.currentAccount!.identifier, 'maria@email.com');
    });

    test('sair encerra a sessão salva', () async {
      final first = await newAuth();
      await first.signUp(name: 'Maria', identifier: 'maria@email.com', password: 'abcd');
      first.signOut();
      expect(first.isLoggedIn, isFalse);

      final reopened = await newAuth();
      expect(reopened.isLoggedIn, isFalse);
    });
  });

  group('recuperação de senha', () {
    test('conta inexistente não gera código', () async {
      final auth = await newAuth();
      final error = await auth.requestPasswordReset('ninguem@email.com');
      expect(error, 'Não encontramos uma conta com esses dados');
      expect(auth.demoResetCode, isNull);
    });

    test('fluxo completo troca a senha', () async {
      final auth = await newAuth();
      await auth.signUp(name: 'Maria', identifier: 'maria@email.com', password: 'antiga');
      auth.signOut();

      expect(await auth.requestPasswordReset('maria@email.com'), isNull);
      final code = auth.demoResetCode!;
      expect(code.length, 6);

      expect(await auth.verifyResetCode('000000x'), 'Código incorreto');
      expect(await auth.verifyResetCode(code), isNull);
      expect(await auth.resetPassword('nova123'), isNull);

      expect(
        await auth.signIn(identifier: 'maria@email.com', password: 'antiga'),
        isNotNull,
      );
      expect(
        await auth.signIn(identifier: 'maria@email.com', password: 'nova123'),
        isNull,
      );
    });

    test('não troca a senha sem validar o código antes', () async {
      final auth = await newAuth();
      await auth.requestPasswordReset(AuthProvider.demoIdentifier);
      final error = await auth.resetPassword('qualquer');
      expect(error, isNotNull);

      // A senha antiga da demo continua valendo.
      expect(
        await auth.signIn(
          identifier: AuthProvider.demoIdentifier,
          password: AuthProvider.demoPassword,
        ),
        isNull,
      );
    });
  });
}
