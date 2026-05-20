import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class OrderTotalsCard extends StatelessWidget {
  final TextEditingController depositController;
  final TextEditingController deliveryCostController;
  final bool isPaid;
  final ValueChanged<bool> onPaidChanged;
  final VoidCallback onTotalsChanged;
  final double itemsSubtotal;
  final double deliveryCost;
  final double grandTotal;
  final double depositAmount;
  final double remainingBalance;
  final bool isLoading;
  final bool isEditMode;
  final VoidCallback? onSubmit;

  const OrderTotalsCard({
    super.key,
    required this.depositController,
    required this.deliveryCostController,
    required this.isPaid,
    required this.onPaidChanged,
    required this.onTotalsChanged,
    required this.itemsSubtotal,
    required this.deliveryCost,
    required this.grandTotal,
    required this.depositAmount,
    required this.remainingBalance,
    required this.isLoading,
    required this.isEditMode,
    required this.onSubmit,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      elevation: 8.0,
      color: Theme.of(context).colorScheme.surface,
      shape: Border(
        top: BorderSide(
          color: Theme.of(context).colorScheme.outlineVariant,
          width: 0.5,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  flex: 3,
                  child: TextFormField(
                    controller: depositController,
                    decoration: const InputDecoration(
                      labelText: 'Seña Recibida (\$)',
                      prefixText: '\$',
                      border: OutlineInputBorder(),
                      isDense: true,
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 12,
                      ),
                    ),
                    keyboardType: const TextInputType.numberWithOptions(decimal: false),
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    onChanged: (_) => onTotalsChanged(),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  flex: 3,
                  child: TextFormField(
                    controller: deliveryCostController,
                    decoration: const InputDecoration(
                      labelText: 'Envío (\$)',
                      prefixText: '\$',
                      border: OutlineInputBorder(),
                      isDense: true,
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 12,
                      ),
                    ),
                    keyboardType: const TextInputType.numberWithOptions(decimal: false),
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    onChanged: (_) => onTotalsChanged(),
                  ),
                ),
                const SizedBox(width: 8),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Pagado?',
                      style: TextStyle(
                        fontSize: 10,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                    SizedBox(
                      height: 30,
                      child: Transform.scale(
                        scale: 0.8,
                        child: Switch(
                          value: isPaid,
                          activeThumbColor: Colors.green,
                          onChanged: (val) {
                            onPaidChanged(val);
                            // It's up to the parent to trigger recalculateTotals
                          },
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 8),
            _buildSummaryRow(context, 'Subtotal Productos:', itemsSubtotal),
            if (deliveryCost > 0)
              _buildSummaryRow(context, 'Costo Envío:', deliveryCost),
            _buildSummaryRow(context, 'TOTAL PEDIDO:', grandTotal, isTotal: true),
            if (depositAmount > 0)
              _buildSummaryRow(context, 'Seña Recibida:', -depositAmount),
            if (grandTotal > 0)
              _buildSummaryRow(
                context,
                'Saldo Pendiente:',
                remainingBalance,
                isTotal: true,
                highlight: remainingBalance > 0,
              ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: isLoading ? null : onSubmit,
                icon: isLoading
                    ? SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Theme.of(context).colorScheme.onPrimary,
                        ),
                      )
                    : const Icon(Icons.save),
                label: Text(isEditMode ? 'Guardar Cambios' : 'Guardar Pedido'),
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  textStyle: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryRow(
    BuildContext context,
    String label,
    double amount, {
    bool isTotal = false,
    bool highlight = false,
  }) {
    final style = TextStyle(
      fontSize: isTotal ? 16 : 14,
      fontWeight: isTotal ? FontWeight.bold : FontWeight.normal,
      color: highlight
          ? Theme.of(context).colorScheme.error
          : (isTotal
              ? Theme.of(context).colorScheme.primary
              : Theme.of(context).colorScheme.onSurface),
    );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: style),
          Text('\$${amount.toStringAsFixed(0)}', style: style),
        ],
      ),
    );
  }
}
