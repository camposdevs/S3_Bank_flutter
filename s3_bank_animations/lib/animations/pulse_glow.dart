import 'package:flutter/material.dart';

/// Brilho pulsante, ideal para o nível atual na trilha (TierNode).
class PulseGlow extends StatefulWidget {
  const PulseGlow({
    super.key,
    required this.child,
    required this.color,
    this.enabled = true,
    this.maxBlur = 18,
    this.shape = BoxShape.circle,
    this.borderRadius,
  });

  final Widget child;
  final Color color;
  final bool enabled;
  final double maxBlur;
  final BoxShape shape;
  final BorderRadius? borderRadius;

  @override
  State<PulseGlow> createState() => _PulseGlowState();
}

class _PulseGlowState extends State<PulseGlow>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 1400));

  @override
  void initState() {
    super.initState();
    if (widget.enabled) _c.repeat(reverse: true);
  }

  @override
  void didUpdateWidget(PulseGlow old) {
    super.didUpdateWidget(old);
    if (widget.enabled && !_c.isAnimating) {
      _c.repeat(reverse: true);
    } else if (!widget.enabled && _c.isAnimating) {
      _c.stop();
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      child: widget.child,
      builder: (context, child) {
        final t = widget.enabled ? Curves.easeInOut.transform(_c.value) : 0.0;
        return DecoratedBox(
          decoration: BoxDecoration(
            shape: widget.shape,
            borderRadius:
                widget.shape == BoxShape.circle ? null : widget.borderRadius,
            boxShadow: [
              BoxShadow(
                color: widget.color.withAlpha((40 + 110 * t).round()),
                blurRadius: 6 + widget.maxBlur * t,
                spreadRadius: 1 + 3 * t,
              ),
            ],
          ),
          child: child,
        );
      },
    );
  }
}
