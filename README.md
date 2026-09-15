# S3 Bank — Protótipo Flutter (local, sem backend)

Conta digital gamificada com progressão de níveis atrelada ao CDI.
Roda 100% localmente, com dados mockados em memória — sem depender
de nenhum backend por enquanto.

## Como rodar

```bash
flutter pub get
flutter run
```

## Arquitetura

Organização por **features + camada de dados simples** (models/providers).

```
lib/
  core/theme/          # cores e ThemeData (Material 3, dark)
  models/               # UserTier, Transaction, SavingsGoal, CardModel
  providers/             # ChangeNotifier: User, Wallet, Savings, Card
  widgets/               # componentes reutilizáveis (cartão, saldo, badges...)
  screens/
    dashboard/           # Home
    pix/                 # Área Pix (pagar, receber, chaves)
    savings/              # Guardar Dinheiro (caixinhas)
    card/                 # Gestão do Cartão Digital
    main_navigation_screen.dart  # bottom nav que une as 4 abas
  main.dart               # MultiProvider + MaterialApp
```

**Gerenciador de estado:** `provider` (ChangeNotifier).

## Sistema de Níveis (Tier System)

Definido em `models/user_tier.dart` (`enum UserTier` + extension):

| Nível     | % do CDI |
|-----------|----------|
| Bronze    | 100%     |
| Prata     | 115%     |
| Ouro      | 130%     |
| Diamante  | 140%     |

- A evolução de nível é modelada como **pontos de constância**
  (`UserProvider.consistencyPoints`), acumulados a cada aporte feito em
  "Guardar Dinheiro" (`UserProvider.registerDeposit`).
- O cartão digital (`CardProvider`) é sincronizado com o nível do
  usuário via `CardProvider.syncTier`, chamado no `DashboardScreen` a
  cada rebuild — então a skin do cartão muda sozinha ao subir de nível.

## Onde plugar um backend depois

Todo estado hoje vive dentro dos `ChangeNotifier` em `lib/providers/`,
com dados mockados criados na hora (`_seedTransactions`,
`_seedGoals`, etc). Quando for integrar um backend, o ponto de entrada é sempre o mesmo: trocar o corpo dos
métodos públicos de cada provider (`sendPix`, `deposit`, `createGoal`,
`toggleBlocked`...) por uma chamada de API/RPC, mantendo a mesma
assinatura — as telas não precisam mudar.

Os trechos marcados com `TODO(integração-backend)` no código indicam
exatamente onde cada regra hoje mockada deveria vir de uma fonte real:

- `UserProvider` — regra de constância/streak vinda de uma API de
  gamificação, em vez do contador local.
- `SavingsProvider` — taxa CDI mockada (`mockAnnualCdiRate`) vinda de
  uma API financeira/BACEN; saldo e metas persistidos em backend.
- `WalletProvider` — saldo e extrato vindos de
  `GET /account/balance` e `GET /account/statement`.
- `CardProvider` — número, validade e CVV reais vindos de um endpoint
  seguro (`GET /card/details`), nunca hardcoded como hoje.

## O que falta para produção

- Persistência real (hoje todo estado é perdido ao fechar o app).
- Autenticação/login.
- Camada de repositório entre providers e API.
- Testes automatizados.
"# S3_Bank_flutter" 
