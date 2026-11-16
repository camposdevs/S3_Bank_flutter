import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/card_format.dart';
import '../../core/format.dart';
import '../../core/statement_filter.dart';
import '../../core/theme/app_colors.dart';
import '../../models/card_summary.dart';
import '../../providers/credit_card_provider.dart';
import '../../providers/wallet_provider.dart';
import '../../services/ledger_repository.dart';
import '../../widgets/state_view.dart';

/// Cartão de crédito: limite, fatura do mês, cartão virtual e compras.
/// O provider nasce com a tela e morre com ela.
class CreditCardScreen extends StatelessWidget {
  const CreditCardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => CreditCardProvider(LedgerRepository())..refresh(),
      child: const _CreditCardView(),
    );
  }
}

class _CreditCardView extends StatelessWidget {
  const _CreditCardView();

  @override
  Widget build(BuildContext context) {
    final cc = context.watch<CreditCardProvider>();
    final s = cc.summary;

    return Scaffold(
      appBar: AppBar(title: const Text('Cartão de crédito')),
      body: SafeArea(
        child: s == null
            ? (cc.error != null
                ? StateView.error(message: cc.error!, onAction: cc.refresh)
                : StateView.loading())
            : RefreshIndicator(
                onRefresh: cc.refresh,
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
                  children: [
                    _LimitCard(summary: s),
                    const SizedBox(height: 14),
                    _InvoiceCard(summary: s),
                    const SizedBox(height: 14),
                    _VirtualCardSection(summary: s),
                    const SizedBox(height: 22),
                    _PurchasesSection(purchases: cc.purchases, canBuy: s.hasCard),
                  ],
                ),
              ),
      ),
    );
  }
}

String _dateBr(DateTime d) =>
    '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

/// "1.500,00" ou "1500" -> 1500.0. Null se não for um valor positivo.
double? _parseMoney(String text) {
  final v = double.tryParse(text.trim().replaceAll('.', '').replaceAll(',', '.'));
  return (v == null || v <= 0) ? null : v;
}

class _Panel extends StatelessWidget {
  final Widget child;

  const _Panel({required this.child});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
        ),
        child: child,
      );
}

class _LimitCard extends StatelessWidget {
  final CardSummary summary;

  const _LimitCard({required this.summary});

  @override
  Widget build(BuildContext context) {
    final ratio = summary.limitCents == 0
        ? 0.0
        : (summary.usedCents / summary.limitCents).clamp(0.0, 1.0);
    return _Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Limite disponível',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
          const SizedBox(height: 4),
          Text(
            brl(summary.availableCents / 100),
            style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 12),
          LinearProgressIndicator(value: ratio, minHeight: 8),
          const SizedBox(height: 6),
          Text(
            'Usado ${brl(summary.usedCents / 100)} de ${brl(summary.limitCents / 100)}',
            style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
          ),
        ],
      ),
    );
  }
}

class _InvoiceCard extends StatelessWidget {
  final CardSummary summary;

  const _InvoiceCard({required this.summary});

  Future<void> _pay(BuildContext context) async {
    final cc = context.read<CreditCardProvider>();
    final wallet = context.read<WalletProvider>();
    final messenger = ScaffoldMessenger.of(context);
    final total = summary.invoiceTotalCents / 100;

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Pagar fatura'),
        content: Text('Pagar ${brl(total)} agora? O valor sai da sua conta.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Pagar'),
          ),
        ],
      ),
    );
    if (ok != true) return;

    final error = await cc.payInvoice();
    if (error == null) await wallet.refreshFromServer();
    messenger.showSnackBar(SnackBar(content: Text(error ?? 'Fatura paga com sucesso.')));
  }

  @override
  Widget build(BuildContext context) {
    final m = summary.invoiceMonth;
    final open = summary.invoiceTotalCents > 0;
    return _Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Fatura de ${monthNamePt(m.month)}/${m.year}',
            style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
          ),
          const SizedBox(height: 4),
          Text(
            brl(summary.invoiceTotalCents / 100),
            style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 4),
          Text(
            'Vence em ${_dateBr(summary.invoiceDue)}',
            style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
          ),
          const SizedBox(height: 14),
          if (open)
            FilledButton(
              onPressed: () => _pay(context),
              child: const Text('Pagar fatura'),
            )
          else
            const Text(
              'Nenhuma compra nesta fatura.',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
            ),
        ],
      ),
    );
  }
}

class _VirtualCardSection extends StatelessWidget {
  final CardSummary summary;

  const _VirtualCardSection({required this.summary});

  static String _grouped(String number) => [
        for (var i = 0; i < number.length; i += 4)
          number.substring(i, i + 4 > number.length ? number.length : i + 4),
      ].join(' ');

  Future<void> _create(BuildContext context) async {
    final cc = context.read<CreditCardProvider>();
    final messenger = ScaffoldMessenger.of(context);
    try {
      final card = await cc.createVirtualCard();
      if (!context.mounted) return;
      await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Seu cartão virtual'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SelectableText(
                _grouped(card.number),
                style: const TextStyle(fontFamily: 'monospace', fontSize: 16),
              ),
              const SizedBox(height: 8),
              Text('Validade ${card.expiry}'),
              const SizedBox(height: 4),
              Text('CVV ${card.cvv}',
                  style: const TextStyle(fontWeight: FontWeight.w700)),
              const SizedBox(height: 12),
              const Text(
                'Anote o CVV agora. Ele não será mostrado de novo.',
                style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
              ),
            ],
          ),
          actions: [
            FilledButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Entendi'),
            ),
          ],
        ),
      );
    } on LedgerException catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (summary.hasCard) {
      return _Panel(
        child: Row(
          children: [
            const Icon(Icons.credit_card, size: 30),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(maskedCard(summary.last4),
                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                  const SizedBox(height: 2),
                  Text('Validade ${summary.expiry}',
                      style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                ],
              ),
            ),
          ],
        ),
      );
    }
    return _Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Cartão virtual',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
          const SizedBox(height: 4),
          const Text(
            'Crie um cartão para registrar compras no crédito.',
            style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: () => _create(context),
            icon: const Icon(Icons.add_card_outlined),
            label: const Text('Criar cartão virtual'),
          ),
        ],
      ),
    );
  }
}

class _PurchasesSection extends StatelessWidget {
  final List<CardPurchase> purchases;
  final bool canBuy;

  const _PurchasesSection({required this.purchases, required this.canBuy});

  Future<void> _newPurchase(BuildContext context) async {
    final cc = context.read<CreditCardProvider>();
    final messenger = ScaffoldMessenger.of(context);
    final merchantCtrl = TextEditingController();
    final amountCtrl = TextEditingController();
    var category = 'outros';

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialog) => AlertDialog(
          title: const Text('Nova compra'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: merchantCtrl,
                decoration: const InputDecoration(labelText: 'Onde foi a compra'),
              ),
              TextField(
                controller: amountCtrl,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(labelText: 'Valor (R\$)'),
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                value: category,
                decoration: const InputDecoration(labelText: 'Categoria'),
                items: [
                  for (final e in kTxCategories.entries)
                    DropdownMenuItem(value: e.key, child: Text(e.value)),
                ],
                onChanged: (v) => setDialog(() => category = v ?? category),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('Registrar'),
            ),
          ],
        ),
      ),
    );
    if (ok != true) return;

    final amount = _parseMoney(amountCtrl.text);
    if (amount == null) {
      messenger.showSnackBar(const SnackBar(content: Text('Informe um valor válido.')));
      return;
    }
    final error = await cc.purchase(
      merchant: merchantCtrl.text,
      amountCents: (amount * 100).round(),
      category: category,
    );
    messenger.showSnackBar(SnackBar(
      content: Text(error ?? 'Compra de ${brl(amount)} registrada na fatura.'),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Expanded(
              child: Text('Compras',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
            ),
            TextButton.icon(
              onPressed: canBuy ? () => _newPurchase(context) : null,
              icon: const Icon(Icons.add),
              label: const Text('Nova compra'),
            ),
          ],
        ),
        if (!canBuy)
          const Padding(
            padding: EdgeInsets.only(top: 8),
            child: Text(
              'Crie seu cartão virtual para registrar compras.',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
            ),
          )
        else if (purchases.isEmpty)
          StateView.empty(
            icon: Icons.shopping_bag_outlined,
            title: 'Nenhuma compra ainda',
            message: 'As compras aparecem aqui e entram na fatura do mês.',
          )
        else
          for (final p in purchases) _PurchaseTile(purchase: p),
      ],
    );
  }
}

class _PurchaseTile extends StatelessWidget {
  final CardPurchase purchase;

  const _PurchaseTile({required this.purchase});

  @override
  Widget build(BuildContext context) {
    final category = kTxCategories[purchase.category] ?? kSemCategoria;
    final d = purchase.purchasedAt;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(purchase.merchant,
                    style: const TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(height: 2),
                Text(
                  '$category · ${_dateBr(d)}',
                  style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(brl(purchase.amountCents / 100),
                  style: const TextStyle(fontWeight: FontWeight.w700)),
              const SizedBox(height: 2),
              Text(
                purchase.paid ? 'Paga' : 'Na fatura',
                style: TextStyle(
                  color: purchase.paid ? AppColors.success : AppColors.textSecondary,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
