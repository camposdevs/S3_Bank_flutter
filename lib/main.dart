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
import 'screens/auth_gate.dart';

void main() {
  runApp(const S3BankApp());
}

class S3BankApp extends StatelessWidget {
  const S3BankApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => UserProvider()),
        ChangeNotifierProvider(create: (_) => WalletProvider()),
        ChangeNotifierProvider(create: (_) => SavingsProvider()),
        ChangeNotifierProvider(create: (_) => PixKeysProvider()),
        ChangeNotifierProvider(
          create: (_) => CardProvider(
            holderName: 'Rafaela Souza',
            initialTier: UserTier.bronze,
          ),
        ),
      ],
      child: MaterialApp(
        title: 'S3 Bank',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.dark,
        home: const AuthGate(),
      ),
    );
  }
}
