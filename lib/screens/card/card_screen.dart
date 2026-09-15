import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_colors.dart';
import '../../providers/card_provider.dart';
import '../../widgets/digital_card_widget.dart';

class CardScreen extends StatefulWidget {
  const CardScreen({super.key});

  @override
  State<CardScreen> createState() => _CardScreenState();
}

class _CardScreenState extends State<CardScreen> {
  bool _showDetails = false;

  @override
  Widget build(BuildContext context) {
    final cardProvider = context.watch<CardProvider>();
    final card = cardProvider.card;

    return Scaffold(
      appBar: AppBar(title: const Text('Cartão Digital')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
          children: [
            DigitalCardWidget(card: card, showDetails: _showDetails),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                TextButton.icon(
                  onPressed: () => setState(() => _showDetails = !_showDetails),
                  icon: Icon(
                    _showDetails ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                    size: 18,
                  ),
                  label: Text(_showDetails ? 'Ocultar dados' : 'Mostrar dados'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                children: [
                  _CopyRow(
                    label: 'Número do cartão',
                    value: card.groupedNumber,
                    onCopy: () => _copyToClipboard(context, card.groupedNumber, 'Número'),
                  ),
                  const Divider(height: 1),
                  _CopyRow(
                    label: 'Validade',
                    value: card.expiry,
                    onCopy: () => _copyToClipboard(context, card.expiry, 'Validade'),
                  ),
                  const Divider(height: 1),
                  _CopyRow(
                    label: 'CVV',
                    value: card.cvv,
                    onCopy: () => _copyToClipboard(context, card.cvv, 'CVV'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.border),
              ),
              child: SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Bloquear cartão temporariamente',
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                subtitle: Text(
                  card.isBlocked
                      ? 'Cartão bloqueado — nenhuma compra será autorizada.'
                      : 'Cartão ativo para uso.',
                  style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
                ),
                value: card.isBlocked,
                activeColor: AppColors.danger,
                onChanged: (_) => cardProvider.toggleBlocked(),
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.surfaceElevated,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline, color: AppColors.textSecondary, size: 18),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Text(
                      'Função: Apenas Débito. O visual do cartão é atualizado automaticamente conforme seu nível de rendimento evolui.',
                      style: TextStyle(color: AppColors.textSecondary, fontSize: 12.5),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _copyToClipboard(BuildContext context, String value, String label) {
    Clipboard.setData(ClipboardData(text: value.replaceAll(' ', '')));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$label copiado.')),
    );
  }
}

class _CopyRow extends StatelessWidget {
  final String label;
  final String value;
  final VoidCallback onCopy;

  const _CopyRow({required this.label, required this.value, required this.onCopy});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      title: Text(label, style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
      subtitle: Text(value, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
      trailing: IconButton(
        icon: const Icon(Icons.copy_outlined, size: 18, color: AppColors.accentLight),
        onPressed: onCopy,
      ),
    );
  }
}
