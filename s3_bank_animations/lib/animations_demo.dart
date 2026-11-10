import 'package:flutter/material.dart';
import 'animations/animations.dart';

/// Tela de demonstração. Rode com:  home: const AnimationsDemo()
class AnimationsDemo extends StatefulWidget {
  const AnimationsDemo({super.key});

  @override
  State<AnimationsDemo> createState() => _AnimationsDemoState();
}

class _AnimationsDemoState extends State<AnimationsDemo> {
  double _saldo = 2450.75;
  double _meta = 0.65;

  @override
  Widget build(BuildContext context) {
    const accent = Color(0xFF8A05BE);
    return Scaffold(
      appBar: AppBar(title: const Text('Kit de animações')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          StaggeredColumn(children: [
            const Text('Saldo'),
            AnimatedCounter(
              value: _saldo,
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 24),
            Center(
              child: AnimatedProgressRing(
                progress: _meta,
                color: accent,
                size: 120,
                child: Text('${(_meta * 100).round()}%'),
              ),
            ),
            const SizedBox(height: 24),
            Center(
              child: PulseGlow(
                color: accent,
                child: const CircleAvatar(radius: 28, child: Icon(Icons.star)),
              ),
            ),
            const SizedBox(height: 24),
            TapScale(
              onTap: () => setState(() {
                _saldo += 500;
                _meta = (_meta + 0.1).clamp(0.0, 1.0);
              }),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: accent,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Center(
                  child: Text('Guardar R\$ 500',
                      style: TextStyle(color: Colors.white)),
                ),
              ),
            ),
          ]),
        ],
      ),
    );
  }
}
