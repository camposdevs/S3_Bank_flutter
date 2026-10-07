<div align="center">

<img src="https://capsule-render.vercel.app/api?type=waving&color=0:0B0B12,100:6A4CE0&height=200&section=header&text=S3%20Bank&fontSize=56&fontColor=ffffff&fontAlignY=38&desc=Conta%20digital%20gamificada%20com%20n%C3%ADveis%20atrelados%20ao%20CDI&descAlignY=58&descSize=18&descColor=B98CFF" width="100%" />

![Flutter](https://img.shields.io/badge/Flutter-02569B?style=for-the-badge&logo=flutter&logoColor=white)
![Dart](https://img.shields.io/badge/Dart-0175C2?style=for-the-badge&logo=dart&logoColor=white)
![Provider](https://img.shields.io/badge/State-Provider-6A4CE0?style=for-the-badge)
![Material 3](https://img.shields.io/badge/Material_3-Dark-0B0B12?style=for-the-badge&logo=materialdesign&logoColor=B98CFF)
![Status](https://img.shields.io/badge/Status-Protótipo_local-3355D3?style=for-the-badge)

</div>

---

<div align="center">

Um app bancário onde **quanto mais constante você é, mais seu dinheiro rende**.
A cada aporte em "Guardar Dinheiro" você ganha pontos de constância, sobe de nível
e desbloqueia um percentual maior do CDI, com um cartão digital que muda de visual junto com você.

Roda **100% localmente**, com dados mockados em memória. Nenhum backend necessário.

</div>

---

## Funcionalidades

| Área | O que tem |
|------|-----------|
| **Acesso** | Login, cadastro e recuperação de senha em 3 etapas (código → nova senha → confirmação) |
| **Início** | Saldo com opção de ocultar, nível atual, barra de progresso até o próximo nível e extrato |
| **Pix** | Pagar, receber (QR Code + Pix Copia e Cola no padrão BR Code com CRC16) e gerenciar chaves |
| **Guardar Dinheiro** | Caixinhas com metas, aportes, resgates e rendimento calculado sobre o CDI do nível |
| **Cartão digital** | Cartão com visual do nível, dados mascarados e opção de bloquear |
| **Perfil** | Nome, nível e saída da conta |

---

## Sistema de níveis

Definido em `models/user_tier.dart` (`enum UserTier` + extension com as regras de negócio).

| Nível | Rendimento |
|-------|------------|
| Bronze | 100% do CDI |
| Prata | 115% do CDI |
| Ouro | 130% do CDI |
| Diamante | 140% do CDI |

- A evolução é medida em **pontos de constância** (`UserProvider.consistencyPoints`),
  acumulados a cada aporte (`UserProvider.registerDeposit`). Um aporte vale pontos fixos
  mais uma fração do valor, para premiar o hábito e não só o volume.
- Ao passar do limite, o excedente de pontos é aproveitado no nível seguinte.
- O cartão digital é sincronizado com o nível via `CardProvider.syncTier`,
  então a "skin" muda sozinha quando o usuário sobe de nível.

---

## Como rodar

**Pré-requisitos:** Flutter com Dart `>=3.3.0` (Flutter 3.19 ou superior).

```bash
git clone https://github.com/camposdevs/S3_Bank_flutter.git
cd S3_Bank_flutter
flutter pub get
flutter run
```

Para rodar no navegador:

```bash
flutter run -d chrome
```

> **Para entrar no app:** use qualquer CPF ou e-mail e uma senha com 4 ou mais caracteres.
> A autenticação é simulada e a sessão dura só enquanto o app está aberto.

---

## Arquitetura

Organização por **telas + camada de dados simples** (`models` e `providers`).
Gerenciador de estado: [`provider`](https://pub.dev/packages/provider) (`ChangeNotifier`).

```text
lib/
├── core/
│   ├── theme/                    # AppColors e ThemeData (Material 3, dark)
│   └── pix_payload_generator.dart # BR Code do Pix (EMV + CRC16)
├── models/                       # UserTier, Transaction, SavingsGoal, CardModel
├── providers/                    # Auth, User, Wallet, Savings, PixKeys, Card
├── widgets/                      # cartão, saldo, badges, botão com gradiente,
│                                 # fundo e campos das telas de acesso...
├── screens/
│   ├── auth/                     # login, cadastro, esqueci minha senha
│   ├── dashboard/                # início
│   ├── pix/                      # área Pix
│   ├── savings/                  # guardar dinheiro
│   ├── card/                     # cartão digital
│   ├── profile/                  # perfil
│   ├── auth_gate.dart            # alterna login ↔ app conforme a sessão
│   ├── splash_screen.dart
│   └── main_navigation_screen.dart # navegação inferior entre as abas
└── main.dart                     # MultiProvider + MaterialApp
```

---

## Onde plugar um backend

Todo o estado vive nos `ChangeNotifier` de `lib/providers/`, com dados de exemplo criados na hora.
Para integrar uma API, o caminho é sempre o mesmo: **trocar o corpo dos métodos públicos
de cada provider** (`sendPix`, `deposit`, `createGoal`, `signIn`...) por uma chamada de rede,
mantendo a mesma assinatura. As telas não precisam mudar.

Os pontos estão marcados no código com `TODO(integração-backend)`:

| Onde | O que deveria vir de uma fonte real |
|------|-------------------------------------|
| `AuthProvider` | Login, cadastro e sessão de verdade |
| `ForgotPasswordScreen` | Envio e validação do código, e gravação da nova senha |
| `UserProvider` | Regra de constância (frequência e regularidade, como streak semanal) vinda de uma API de gamificação |
| `SavingsProvider` | Taxa CDI vinda de uma API financeira e metas persistidas |
| `WalletProvider` | Saldo e extrato (`GET /account/balance`, `GET /account/statement`) |
| `PixKeysProvider` | Cadastro e remoção de chaves Pix |
| `CardProvider` | Número, validade e CVV vindos de um endpoint seguro, nunca fixos no código |
| `PixPayloadGenerator` | Cobranças dinâmicas, que exigem um PSP autorizado pelo Banco Central |

> **Aviso sobre o Pix:** o QR Code gerado é estático e estruturalmente válido.
> Se a chave informada existir de verdade, qualquer banco consegue pagar nela.
> Em demonstrações, use sempre uma chave fictícia.

---

## Roadmap

- [x] Login, cadastro e recuperação de senha (simulados)
- [x] Níveis, pontos de constância e cartão que acompanha o nível
- [x] Pix com QR Code e Copia e Cola
- [ ] Persistência local (hoje todo o estado se perde ao fechar o app)
- [ ] Novo usuário começar do zero (hoje herda saldo, metas e pontos de exemplo)
- [ ] Camada de repositório entre providers e API
- [ ] Autenticação e backend reais
- [ ] Testes automatizados
- [ ] Telas de Dados pessoais, Segurança e Ajuda no perfil

<!--
Quando tiver prints do app, adicione aqui uma seção "Telas" com uma tabela de imagens:
| Login | Início | Pix | Cartão |
|:-:|:-:|:-:|:-:|
| <img src="docs/login.png" width="200"> | ... |
-->

---

<div align="center">

### Feito por Pedro Campos

[![Portfolio](https://img.shields.io/badge/🌐_Portfólio-0f172a?style=for-the-badge)](https://portfoliodevcampos.netlify.app/)
[![LinkedIn](https://img.shields.io/badge/LinkedIn-0077B5?style=for-the-badge&logo=linkedin&logoColor=white)](https://www.linkedin.com/in/pedro-campos-leitao/)
[![Gmail](https://img.shields.io/badge/Email-D14836?style=for-the-badge&logo=gmail&logoColor=white)](mailto:devcampos2007@gmail.com)

<img src="https://capsule-render.vercel.app/api?type=waving&color=0:6A4CE0,100:0B0B12&height=100&section=footer" width="100%" />

</div>