# Kit de animações — S3 Bank (Flutter)

Widgets sem dependências externas. Copie `lib/animations/` para o projeto e importe:

```dart
import 'package:seu_app/animations/animations.dart';
```

| Widget | Onde usar no S3 Bank |
|---|---|
| `FadeSlideIn` / `StaggeredColumn` | Entrada dos blocos da Home e listas de cofrinhos |
| `AnimatedCounter` | Saldo e valores guardados (rola até o valor, formato R$ pt-BR) |
| `AnimatedProgressRing` | Progresso das metas (no lugar/ao redor do `GoalProgressRing`) |
| `PulseGlow` | Nível atual na trilha (`TierNode`) |
| `TapScale` | Cards, botões e itens clicáveis |
| `fadeSlideRoute` | `Navigator.push(context, fadeSlideRoute(const Tela()))` |

**Hero** (lista de cofrinhos → detalhe): envolva o card e o topo do detalhe com
`Hero(tag: 'cofrinho-${id}', child: ...)`, usando a mesma tag nos dois lados.

`lib/animations_demo.dart` é uma tela de exemplo para testar tudo.

## Botões Guardar valor / Resgatar (borda branca)

```dart
final botaoBorda = OutlinedButton.styleFrom(
  foregroundColor: const Color(0xFFA78BFA), // roxo mais claro: melhor contraste no fundo escuro
  side: const BorderSide(color: Colors.white, width: 1),
  minimumSize: const Size.fromHeight(48),
  shape: const StadiumBorder(),
);

Row(
  children: [
    Expanded(
      child: TapScale(
        child: OutlinedButton(
          style: botaoBorda,
          onPressed: onGuardar,
          child: const Text('Guardar valor'),
        ),
      ),
    ),
    const SizedBox(width: 12),
    Expanded(
      child: TapScale(
        child: OutlinedButton(
          style: botaoBorda,
          onPressed: onResgatar,
          child: const Text('Resgatar'),
        ),
      ),
    ),
  ],
)
```
