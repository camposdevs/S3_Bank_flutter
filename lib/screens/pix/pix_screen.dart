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

// Dados fixos usados na geração da cobrança (ideal: vir do usuário logado).
// A chave Pix agora vem de "Minhas Chaves" (PixKeysProvider.primaryKey).
const _kMerchantName = 'Rafaela Souza';
const _kMerchantCity = 'SAO PAULO';

final _currencyFmt = NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$');

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
              // 1.45 (antes 1.7) evita overflow do texto em telas estreitas.
              childAspectRatio: 1.45,
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
        return SafeArea(
          top: false,
          child: SingleChildScrollView(
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
                    inputFormatters: [_BrlAmountFormatter()],
                    decoration: const InputDecoration(labelText: 'Valor (R\$)'),
                    validator: (v) {
                      final value = _parseAmount(v);
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
                        final amount = _parseAmount(amountController.text)!;
                        final ok = wallet.sendPix(
                          amount,
                          recipient: recipientController.text.trim(),
                        );
                        Navigator.of(ctx).pop();
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(ok
                                ? 'Pix enviado com sucesso!'
                                : 'Não foi possível enviar o Pix.'),
                          ),
                        );
                      },
                      child: const Text('Confirmar pagamento'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  void _showReceiveModal(BuildContext context) {
    final wallet = context.read<WalletProvider>();
    final receiveKey = context.read<PixKeysProvider>().primaryKey;
    if (receiveKey == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Cadastre uma chave Pix em "Minhas Chaves" para receber.'),
        ),
      );
      return;
    }
    final senderController = TextEditingController();
    final amountController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    // O payload só existe depois que a cobrança é "gerada" — antes
    // disso mostramos o formulário; depois, o QR Code real.
    // Fica FORA do builder para não resetar se o builder for reconstruído
    // (ex.: teclado fechando ao trocar de formulário para o QR).
    String? generatedPayload;

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
            return SafeArea(
              top: false,
              child: SingleChildScrollView(
                padding: EdgeInsets.only(
                  left: 20,
                  right: 20,
                  top: 20,
                  bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
                ),
                child: generatedPayload == null
                    ? _buildChargeForm(
                        formKey: formKey,
                        senderController: senderController,
                        amountController: amountController,
                        onGenerate: () {
                          if (!formKey.currentState!.validate()) return;
                          final amount = _parseAmount(amountController.text)!;
                          final sender = senderController.text.trim();
                          final payload = PixPayloadGenerator.generate(
                            pixKey: receiveKey.payloadValue,
                            merchantName: _kMerchantName,
                            merchantCity: _kMerchantCity,
                            amount: amount,
                            description: sender.isEmpty ? null : 'Cobranca de $sender',
                          );
                          setState(() => generatedPayload = payload);
                        },
                      )
                    : _buildQrResult(
                        payload: generatedPayload!,
                        amount: _parseAmount(amountController.text)!,
                        onSimulatePayment: () {
                          final amount = _parseAmount(amountController.text)!;
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
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildChargeForm({
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
            inputFormatters: [_BrlAmountFormatter()],
            decoration: const InputDecoration(labelText: 'Valor a cobrar (R\$)'),
            validator: (v) {
              final value = _parseAmount(v);
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
    required String payload,
    required double amount,
    required VoidCallback onSimulatePayment,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        const Text('Cobrança Pix gerada',
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18)),
        const SizedBox(height: 4),
        Text(
          _currencyFmt.format(amount),
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
              _CopyIconButton(text: payload),
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
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return ListenableBuilder(
          listenable: keysProvider,
          builder: (ctx, _) {
            return SafeArea(
              top: false,
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
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
                          leading: const Icon(Icons.vpn_key_outlined,
                              color: AppColors.accentLight),
                          title: Text(k.type.label),
                          subtitle: Text(k.displayValue,
                              style: const TextStyle(color: AppColors.textSecondary)),
                          trailing: IconButton(
                            tooltip: 'Remover chave',
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
            return SafeArea(
              top: false,
              child: SingleChildScrollView(
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
                        onChanged: (v) {
                          setState(() => selectedType = v ?? PixKeyType.email);
                          valueController.clear();
                          formKey.currentState?.reset();
                        },
                        decoration: const InputDecoration(labelText: 'Tipo de chave'),
                      ),
                      const SizedBox(height: 12),
                      if (selectedType == PixKeyType.random)
                        const Text(
                          'Uma chave aleatória será gerada automaticamente ao salvar.',
                          style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
                        )
                      else
                        TextFormField(
                          controller: valueController,
                          keyboardType: selectedType.keyboardType,
                          decoration: InputDecoration(
                            labelText: 'Valor da chave',
                            hintText: selectedType.hint,
                          ),
                          validator: (v) =>
                              keysProvider.validateInput(selectedType, v ?? ''),
                        ),
                      const SizedBox(height: 20),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: () {
                            if (!formKey.currentState!.validate()) return;
                            if (selectedType == PixKeyType.random) {
                              keysProvider.addRandomKey();
                            } else {
                              keysProvider.addKey(
                                type: selectedType,
                                value: valueController.text.trim(),
                              );
                            }
                            Navigator.of(ctx).pop();
                          },
                          child: const Text('Salvar chave'),
                        ),
                      ),
                    ],
                  ),
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
    // Material + InkWell: o efeito de toque (ripple) fica visível.
    // Com Container decorado dentro do InkWell, a cor cobria o ripple.
    return Material(
      color: AppColors.surface,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: AppColors.border),
      ),
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: AppColors.accentLight, size: 22),
              const Spacer(),
              Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: AppColors.textSecondary, fontSize: 11),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Botão de copiar com feedback visual. Antes usava SnackBar, mas ele
/// aparecia ATRÁS do bottom sheet e o usuário não via nada.
class _CopyIconButton extends StatefulWidget {
  final String text;
  const _CopyIconButton({required this.text});

  @override
  State<_CopyIconButton> createState() => _CopyIconButtonState();
}

class _CopyIconButtonState extends State<_CopyIconButton> {
  bool _copied = false;

  Future<void> _copy() async {
    await Clipboard.setData(ClipboardData(text: widget.text));
    if (!mounted) return;
    setState(() => _copied = true);
    await Future.delayed(const Duration(seconds: 2));
    if (!mounted) return;
    setState(() => _copied = false);
  }

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: _copied ? 'Copiado!' : 'Copiar código Pix',
      icon: Icon(
        _copied ? Icons.check : Icons.copy_outlined,
        size: 18,
        color: AppColors.accentLight,
      ),
      onPressed: _copy,
    );
  }
}

/// Formata valores em reais enquanto digita: 5000 -> 5.000 | 5000,5 -> 5.000,5
class _BrlAmountFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    var text = newValue.text;

    // Se o teclado mandou "." como separador decimal, trata como vírgula.
    if (text.endsWith('.') && !text.contains(',')) {
      text = '${text.substring(0, text.length - 1)},';
    }

    // Os pontos que existem no texto são só de formatação; removemos.
    text = text.replaceAll('.', '');

    final commaIndex = text.indexOf(',');
    final hasComma = commaIndex != -1;

    var intPart = hasComma ? text.substring(0, commaIndex) : text;
    var decPart = hasComma ? text.substring(commaIndex + 1) : '';

    intPart = intPart.replaceAll(RegExp(r'\D'), '');
    decPart = decPart.replaceAll(RegExp(r'\D'), '');
    if (decPart.length > 2) decPart = decPart.substring(0, 2);

    if (intPart.isEmpty && !hasComma) {
      return const TextEditingValue(text: '');
    }
    if (intPart.isEmpty) intPart = '0';

    // Remove zeros à esquerda (007 -> 7)
    intPart = intPart.replaceFirst(RegExp(r'^0+(?=\d)'), '');

    // O campo de valor do Pix aceita no máximo 13 caracteres (9999999999.99),
    // então limitamos a parte inteira a 10 dígitos.
    if (intPart.length > 10) return oldValue;

    // Agrupa de 3 em 3 com ponto
    final grouped = intPart.replaceAllMapped(
      RegExp(r'\B(?=(\d{3})+(?!\d))'),
      (_) => '.',
    );

    final formatted = hasComma ? '$grouped,$decPart' : grouped;

    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}

/// Converte "5.000,50" -> 5000.5 (arredondado para centavos).
double? _parseAmount(String? v) {
  if (v == null) return null;
  var s = v.trim().replaceAll('.', '').replaceAll(',', '.');
  if (s.isEmpty) return null;
  if (s.endsWith('.')) s = '${s}0'; // "5," -> "5.0"
  final parsed = double.tryParse(s);
  if (parsed == null) return null;
  return (parsed * 100).round() / 100;
}