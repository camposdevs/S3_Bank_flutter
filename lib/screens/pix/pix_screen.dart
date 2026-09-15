import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../../core/pix_payload_generator.dart';
import '../../core/theme/app_colors.dart';
import '../../providers/pix_keys_provider.dart';
import '../../providers/wallet_provider.dart';
import '../../widgets/transaction_tile.dart';
import '../../models/transaction.dart';

class PixScreen extends StatelessWidget {
  const PixScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final wallet = context.watch<WalletProvider>();
    final pixTransactions = wallet.transactions
        .where((t) =>
            t.type == TransactionType.pixSent || t.type == TransactionType.pixReceived)
        .toList();

    return Scaffold(
      appBar: AppBar(title: const Text('Área Pix')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
          children: [
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 1.7,
              children: [
                _PixActionCard(
                  icon: Icons.arrow_upward,
                  title: 'Pagar / Transferir',
                  subtitle: 'Chave, Copia e Cola ou QR Code',
                  onTap: () => _showPayModal(context),
                ),
                _PixActionCard(
                  icon: Icons.arrow_downward,
                  title: 'Receber / Cobrar',
                  subtitle: 'Gerar QR Code ou chave',
                  onTap: () => _showReceiveModal(context),
                ),
                _PixActionCard(
                  icon: Icons.vpn_key_outlined,
                  title: 'Minhas Chaves',
                  subtitle: 'Gerenciar chaves Pix',
                  onTap: () => _showKeysModal(context),
                ),
                _PixActionCard(
                  icon: Icons.qr_code_scanner,
                  title: 'QR Code',
                  subtitle: 'Escanear para pagar',
                  onTap: () => _showPayModal(context, prefillQr: true),
                ),
              ],
            ),
            const SizedBox(height: 28),
            const Text(
              'Histórico Pix',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
            ),
            const SizedBox(height: 8),
            if (pixTransactions.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Text(
                  'Nenhuma transação Pix ainda.',
                  style: TextStyle(color: AppColors.textSecondary),
                ),
              )
            else
              ...pixTransactions.map((t) => TransactionTile(transaction: t)),
          ],
        ),
      ),
    );
  }

  void _showPayModal(BuildContext context, {bool prefillQr = false}) {
    final wallet = context.read<WalletProvider>();
    final recipientController = TextEditingController(
      text: prefillQr ? 'QR Code • Loja Exemplo' : '',
    );
    final amountController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 20,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
          ),
          child: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Pagar / Transferir',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18)),
                const SizedBox(height: 16),
                TextFormField(
                  controller: recipientController,
                  decoration: const InputDecoration(
                    labelText: 'Chave Pix, e-mail ou "Copia e Cola"',
                  ),
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? 'Informe o destinatário' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: amountController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(labelText: 'Valor (R\$)'),
                  validator: (v) {
                    final value = double.tryParse((v ?? '').replaceAll(',', '.'));
                    if (value == null || value <= 0) return 'Valor inválido';
                    if (value > wallet.balance) return 'Saldo insuficiente';
                    return null;
                  },
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      if (!formKey.currentState!.validate()) return;
                      final amount =
                          double.parse(amountController.text.replaceAll(',', '.'));
                      wallet.sendPix(amount, recipient: recipientController.text.trim());
                      Navigator.of(ctx).pop();
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Pix enviado com sucesso!')),
                      );
                    },
                    child: const Text('Confirmar pagamento'),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showReceiveModal(BuildContext context) {
    final wallet = context.read<WalletProvider>();
    final senderController = TextEditingController();
    final amountController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        // O payload só existe depois que a cobrança é "gerada" — antes
        // disso mostramos o formulário; depois, o QR Code real.
        String? generatedPayload;

        return StatefulBuilder(
          builder: (ctx, setState) {
            return Padding(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 20,
                bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
              ),
              child: generatedPayload == null
                  ? _buildChargeForm(
                      ctx: ctx,
                      formKey: formKey,
                      senderController: senderController,
                      amountController: amountController,
                      onGenerate: () {
                        if (!formKey.currentState!.validate()) return;
                        final amount =
                            double.parse(amountController.text.replaceAll(',', '.'));
                        final payload = PixPayloadGenerator.generate(
                          pixKey: 'rafaela@email.com',
                          merchantName: 'Rafaela Souza',
                          merchantCity: 'SAO PAULO',
                          amount: amount,
                          description: senderController.text.trim().isEmpty
                              ? null
                              : 'Cobranca de ${senderController.text.trim()}',
                        );
                        setState(() => generatedPayload = payload);
                      },
                    )
                  : _buildQrResult(
                      ctx: ctx,
                      payload: generatedPayload!,
                      amount: double.parse(amountController.text.replaceAll(',', '.')),
                      onSimulatePayment: () {
                        final amount =
                            double.parse(amountController.text.replaceAll(',', '.'));
                        final sender = senderController.text.trim().isEmpty
                            ? 'Recebimento Pix'
                            : senderController.text.trim();
                        wallet.receivePix(amount, sender: sender);
                        Navigator.of(ctx).pop();
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Pagamento simulado com sucesso!')),
                        );
                      },
                    ),
            );
          },
        );
      },
    );
  }

  Widget _buildChargeForm({
    required BuildContext ctx,
    required GlobalKey<FormState> formKey,
    required TextEditingController senderController,
    required TextEditingController amountController,
    required VoidCallback onGenerate,
  }) {
    return Form(
      key: formKey,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Receber / Cobrar',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18)),
          const SizedBox(height: 16),
          TextFormField(
            controller: senderController,
            decoration: const InputDecoration(labelText: 'De quem (opcional)'),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: amountController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(labelText: 'Valor a cobrar (R\$)'),
            validator: (v) {
              final value = double.tryParse((v ?? '').replaceAll(',', '.'));
              if (value == null || value <= 0) return 'Valor inválido';
              return null;
            },
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: onGenerate,
              child: const Text('Gerar QR Code'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQrResult({
    required BuildContext ctx,
    required String payload,
    required double amount,
    required VoidCallback onSimulatePayment,
  }) {
    final currencyFmt = NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$');

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        const Text('Cobrança Pix gerada',
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18)),
        const SizedBox(height: 4),
        Text(
          currencyFmt.format(amount),
          style: const TextStyle(
            color: AppColors.accentLight,
            fontWeight: FontWeight.w800,
            fontSize: 20,
          ),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
          ),
          child: QrImageView(
            data: payload,
            version: QrVersions.auto,
            size: 220,
            backgroundColor: Colors.white,
          ),
        ),
        const SizedBox(height: 16),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.surfaceElevated,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  payload,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 11,
                    fontFamily: 'monospace',
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.copy_outlined, size: 18, color: AppColors.accentLight),
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: payload));
                  ScaffoldMessenger.of(ctx).showSnackBar(
                    const SnackBar(content: Text('Código Pix copiado.')),
                  );
                },
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'Peça para quem vai te pagar escanear o QR Code ou colar o\n'
          'código "copia e cola" no app do banco dele.',
          textAlign: TextAlign.center,
          style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
        ),
        const SizedBox(height: 20),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton(
            onPressed: onSimulatePayment,
            child: const Text('Simular pagamento recebido'),
          ),
        ),
      ],
    );
  }

  void _showKeysModal(BuildContext context) {
    final keysProvider = context.read<PixKeysProvider>();

    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return AnimatedBuilder(
          animation: keysProvider,
          builder: (ctx, _) {
            return Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Minhas Chaves Pix',
                      style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18)),
                  const SizedBox(height: 12),
                  if (keysProvider.keys.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 12),
                      child: Text(
                        'Nenhuma chave cadastrada ainda.',
                        style: TextStyle(color: AppColors.textSecondary),
                      ),
                    )
                  else
                    ...keysProvider.keys.map(
                      (k) => ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading:
                            const Icon(Icons.vpn_key_outlined, color: AppColors.accentLight),
                        title: Text(k.type.label),
                        subtitle:
                            Text(k.value, style: const TextStyle(color: AppColors.textSecondary)),
                        trailing: IconButton(
                          icon: const Icon(Icons.delete_outline,
                              size: 20, color: AppColors.textSecondary),
                          onPressed: () => keysProvider.removeKey(k.id),
                        ),
                      ),
                    ),
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    onPressed: () => _showAddKeyModal(context, keysProvider),
                    icon: const Icon(Icons.add),
                    label: const Text('Cadastrar nova chave'),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _showAddKeyModal(BuildContext context, PixKeysProvider keysProvider) {
    final valueController = TextEditingController();
    final formKey = GlobalKey<FormState>();
    PixKeyType selectedType = PixKeyType.email;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setState) {
            return Padding(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 20,
                bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
              ),
              child: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Nova chave Pix',
                        style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18)),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<PixKeyType>(
                      value: selectedType,
                      items: PixKeyType.values
                          .map((t) => DropdownMenuItem(value: t, child: Text(t.label)))
                          .toList(),
                      onChanged: (v) => setState(() => selectedType = v ?? PixKeyType.email),
                      decoration: const InputDecoration(labelText: 'Tipo de chave'),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: valueController,
                      decoration: const InputDecoration(labelText: 'Valor da chave'),
                      validator: (v) =>
                          (v == null || v.trim().isEmpty) ? 'Informe o valor da chave' : null,
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () {
                          if (!formKey.currentState!.validate()) return;
                          keysProvider.addKey(
                            type: selectedType,
                            value: valueController.text.trim(),
                          );
                          Navigator.of(ctx).pop();
                        },
                        child: const Text('Salvar chave'),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class _PixActionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _PixActionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: AppColors.accentLight, size: 22),
            const Spacer(),
            Text(title,
                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5)),
            const SizedBox(height: 2),
            Text(
              subtitle,
              style: const TextStyle(color: AppColors.textSecondary, fontSize: 11),
            ),
          ],
        ),
      ),
    );
  }
}
