import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'core/theme/app_theme.dart';
import 'models/user_tier.dart';
import 'providers/auth_provider.dart';
import 'providers/card_provider.dart';
import 'providers/pix_keys_provider.dart';
import 'providers/savings_provider.dart';
import 'providers/user_provider.dart';
import 'providers/wallet_provider.dart';
import 'screens/splash_screen.dart';
import 'services/account_data_coordinator.dart';
import 'services/local_store.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final store = await LocalStore.create();

  final auth = AuthProvider(store);
  final user = UserProvider();
  final wallet = WalletProvider();
  final savings = SavingsProvider();
  final pixKeys = PixKeysProvider();
  final card = CardProvider(
    holderName: 'Rafaela Souza',
    initialTier: UserTier.bronze,
  );

  // Carrega/salva os dados da conta logada nos providers acima.
  final coordinator = AccountDataCoordinator(
    store: store,
    auth: auth,
    user: user,
    wallet: wallet,
    savings: savings,
    pixKeys: pixKeys,
    card: card,
  );

  runApp(S3BankApp(
    coordinator: coordinator,
    auth: auth,
    user: user,
    wallet: wallet,
    savings: savings,
    pixKeys: pixKeys,
    card: card,
  ));
}

class S3BankApp extends StatelessWidget {
  // Mantém o coordenador vivo durante toda a execução do app.
  final AccountDataCoordinator coordinator;
  final AuthProvider auth;
  final UserProvider user;
  final WalletProvider wallet;
  final SavingsProvider savings;
  final PixKeysProvider pixKeys;
  final CardProvider card;

  const S3BankApp({
    super.key,
    required this.coordinator,
    required this.auth,
    required this.user,
    required this.wallet,
    required this.savings,
    required this.pixKeys,
    required this.card,
  });

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<AuthProvider>.value(value: auth),
        ChangeNotifierProvider<UserProvider>.value(value: user),
        ChangeNotifierProvider<WalletProvider>.value(value: wallet),
        ChangeNotifierProvider<SavingsProvider>.value(value: savings),
        ChangeNotifierProvider<PixKeysProvider>.value(value: pixKeys),
        ChangeNotifierProvider<CardProvider>.value(value: card),
      ],
      child: MaterialApp(
        title: 'S3 Bank',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.dark,
        home: const SplashScreen(),
      ),
    );
  }
}
