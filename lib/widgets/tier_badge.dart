import 'package:flutter/material.dart';
import '../models/user_tier.dart';

/// Badge compacto exibido no header do Dashboard com o nível atual.
class TierBadge extends StatelessWidget {
  final UserTier tier;
  final bool large;

  const TierBadge({super.key, required this.tier, this.large = false});

  @override
  Widget build(BuildContext context) {
    final color = tier.primaryColor;
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: large ? 14 : 10,
        vertical: large ? 8 : 5,
      ),
      decoration: BoxDecoration(
        color: color.withOpacity(0.16),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withOpacity(0.5)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(tier.icon, size: large ? 18 : 14, color: color),
          const SizedBox(width: 6),
          Text(
            tier.displayName,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w700,
              fontSize: large ? 14 : 12,
            ),
          ),
        ],
      ),
    );
  }
}
