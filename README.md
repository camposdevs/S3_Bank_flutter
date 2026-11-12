<div align="center">

<img src="https://capsule-render.vercel.app/api?type=waving&color=0:0B0B12,100:6A4CE0&height=200&section=header&text=S3%20Bank&fontSize=56&fontColor=ffffff&fontAlignY=38&desc=Conta%20digital%20gamificada%20com%20n%C3%ADveis%20atrelados%20ao%20CDI&descAlignY=58&descSize=18&descColor=B98CFF" width="100%" />

![Flutter](https://img.shields.io/badge/Flutter-02569B?style=for-the-badge&logo=flutter&logoColor=white)
![Dart](https://img.shields.io/badge/Dart-0175C2?style=for-the-badge&logo=dart&logoColor=white)
![Provider](https://img.shields.io/badge/State-Provider-6A4CE0?style=for-the-badge)
![Material 3](https://img.shields.io/badge/Material_3-Dark-0B0B12?style=for-the-badge&logo=materialdesign&logoColor=B98CFF)
![Status](https://img.shields.io/badge/Status-Protótipo_local-3355D3?style=for-the-badge)
[![CI](https://github.com/camposdevs/S3_Bank_flutter/actions/workflows/flutter.yml/badge.svg)](https://github.com/camposdevs/S3_Bank_flutter/actions/workflows/flutter.yml)

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
| **Acesso** | Login, cadastro e recuperação de senha em 3 etapas (código → nova senha → confirmação), com contas salvas no aparelho |
| **Início** | Saldo com opção de ocultar, nível atual, barra de progresso até o próximo nível e extrato |
| **Pix** | Pagar, receber (QR Code + Pix Copia e Cola no padrão BR Code com CRC16) e gerenciar chaves |
| **Guardar Dinheiro** | Caixinhas com metas, aportes, resgates e rendimento calculado sobre o CDI do nível |
| **Cartão digital** | Cartão com visual do nível e dados mascarados (número e CVV só aparecem ao tocar em "Mostrar dados") |
| **Perfil** | Nome, nível e saída da conta (abre ao tocar no avatar do início) |
| **Extrato** | Todas as movimentações (Pix e caixinhas), aberto por "Ver tudo" no início |

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

**Pré-requisitos:** Flutter `>=3.35` (Dart `>=3.9`).

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

> **Para entrar no app:** crie sua conta em **"Abra sua conta"**. Ela começa zerada.
> A sessão fica salva no aparelho, então ao reabrir o app você continua logado. Os dados ficam no banco (Supabase).

---

## Arquitetura

Organização por **telas + camada de dados simples** (`models` e `providers`).
Gerenciador de estado: [`provider`](https://pub.dev/packages/provider) (`ChangeNotifier`).

```text
lib/
├── animations/                   # FadeSlideIn, AnimatedCounter, AnimatedProgressBar, TapScale, transições de página
├── core/
│   ├── theme/                    # AppColors e ThemeData (Material 3, dark)
│   └── pix_payload_generator.dart # BR Code do Pix (EMV + CRC16)
├── models/                       # UserTier, Transaction, SavingsGoal, CardModel
├── services/                     # armazenamento local e sincronia dos dados por conta
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
│   ├── statement/                # extrato completo
│   ├── auth_gate.dart            # alterna login ↔ app conforme a sessão
│   ├── splash_screen.dart
│   └── main_navigation_screen.dart # navegação inferior entre as abas
└── main.dart                     # MultiProvider + MaterialApp
test/                             # testes automatizados
```

---

## Animações

Ficam em `lib/animations/` (Flutter puro, sem pacotes extras), seguindo o
[guia oficial de animações](https://docs.flutter.dev/ui/animations):

| Animação | Onde aparece |
|----------|--------------|
| `FadeSlideIn` (entrada em cascata) | Início, Guardar Dinheiro, extrato, login e cadastro |
| `AnimatedCounter` | Saldo, total guardado e rendimento (o valor "rola" até o número) |
| `AnimatedProgressBar` | Progresso de nível e das caixinhas |
| `TapScale` | Botões, atalhos, chips e itens do perfil afundam levemente ao toque |
| `MorphButton` + `LoadingDots` | Botão ENTRAR encolhe numa pílula com três pontinhos pulsando ao entrar |
| `Hero` | Avatar do início → perfil |
| `fadeSlideRoute` / `fadeRoute` | Navegação entre telas e da abertura para o app |
| `AnimatedSwitcher` / `AnimatedContainer` / `AnimatedSize` | Troca login ↔ app, ocultar saldo e dados do cartão, avisos de erro, seleção de ícone |
| Fade entre abas | Navegação inferior (o estado de cada aba é preservado) |

---

## Testes

```bash
flutter test
```

Os testes cobrem as regras que não podem quebrar sem ninguém perceber:

| Arquivo | O que garante |
|---------|---------------|
| `user_tier_test.dart` | Percentuais do CDI, ordem dos níveis, pontos de constância, subida de nível (inclusive vários de uma vez) |
| `pix_payload_generator_test.dart` | Estrutura do BR Code, tamanhos dos campos, CRC16 conferido por uma implementação independente, limpeza de acentos |
| `wallet_provider_test.dart` | Envio e recebimento de Pix, saldo insuficiente, valores inválidos, arredondamento de centavos |
| `savings_and_pix_keys_test.dart` | Rendimento por nível, caixinhas, validação de CPF/e-mail/celular/chave aleatória |
| `auth_provider_test.dart` | Login, cadastro, contas duplicadas, senha com hash, sessão salva e recuperação de senha |
| `account_data_test.dart` | Dados salvos por conta, isolamento entre contas e persistência ao reabrir o app |
| `animations_test.dart` | Formatação em R$, animações terminando no estado certo, `TapScale` sem bloquear botões e arredondamento de centavos nas caixinhas |

A cada push, o GitHub Actions roda `flutter analyze` e `flutter test`
(`.github/workflows/flutter.yml`).

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

## Segurança (protótipo)

Este projeto é um **protótipo sem servidor**, e isso define o que ele garante:

- **Senhas:** nunca são guardadas em texto puro. Cada conta recebe um *salt* aleatório
  (`Random.secure`) e a senha é guardada como hash SHA-256 desse salt com a senha.
- **Sessão e contas:** ficam no aparelho (`shared_preferences`), isoladas por conta.
- **Recuperação de senha:** o código é gerado localmente e exibido na própria tela
  (modo demonstração), porque não há envio de e-mail ou SMS.

**Para produção**, isto precisaria mudar: autenticação no servidor, um algoritmo lento
de senha (PBKDF2, scrypt ou Argon2 em vez de um SHA-256 simples), código enviado por
canal real e comunicação protegida por HTTPS. Os pontos estão listados em
*Onde plugar um backend*.

---

## Roadmap

- [x] Login, cadastro e recuperação de senha (contas locais, senha com hash)
- [x] Persistência local por conta (`shared_preferences`)
- [x] Níveis, pontos de constância e cartão que acompanha o nível
- [x] Pix com QR Code e Copia e Cola
- [ ] Camada de repositório entre providers e API
- [ ] Autenticação e backend reais (hoje tudo é local, sem servidor)
- [x] Testes automatizados e CI no GitHub Actions
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