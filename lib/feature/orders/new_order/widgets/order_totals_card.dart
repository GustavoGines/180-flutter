import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../new_order_controller.dart';

class OrderTotalsCard extends ConsumerStatefulWidget {
  final VoidCallback? onSubmit;

  const OrderTotalsCard({super.key, required this.onSubmit});

  @override
  ConsumerState<OrderTotalsCard> createState() => _OrderTotalsCardState();
}

class _OrderTotalsCardState extends ConsumerState<OrderTotalsCard> {
  late TextEditingController _depositController;
  late TextEditingController _deliveryCostController;

  @override
  void initState() {
    super.initState();
    _depositController = TextEditingController();
    _deliveryCostController = TextEditingController();
    
    // Al inicializar, pre-llenar los controladores si hay valores iniciales en el state.
    // Esto es útil para el modo edición.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final state = ref.read(newOrderControllerProvider);
      if (state.deposit > 0) {
        _depositController.text = state.deposit.toStringAsFixed(0);
      }
      if (state.deliveryCost > 0) {
        _deliveryCostController.text = state.deliveryCost.toStringAsFixed(0);
      }
    });
  }

  @override
  void dispose() {
    _depositController.dispose();
    _deliveryCostController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(newOrderControllerProvider);
    final controller = ref.read(newOrderControllerProvider.notifier);

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
                    controller: _depositController,
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
                    onChanged: (val) {
                      final amount = double.tryParse(val) ?? 0.0;
                      controller.updateDeposit(amount);
                    },
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  flex: 3,
                  child: TextFormField(
                    controller: _deliveryCostController,
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
                    onChanged: (val) {
                      final amount = double.tryParse(val) ?? 0.0;
                      controller.updateDeliveryCost(amount);
                    },
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
                          value: state.isPaid,
                          activeThumbColor: Colors.green,
                          onChanged: (val) => controller.updateIsPaid(val),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 8),
            _buildSummaryRow(context, 'Subtotal Productos:', state.itemsTotal),
            if (state.deliveryCost > 0)
              _buildSummaryRow(context, 'Costo Envío:', state.deliveryCost),
            _buildSummaryRow(context, 'TOTAL PEDIDO:', state.grandTotal, isTotal: true),
            if (state.deposit > 0)
              _buildSummaryRow(context, 'Seña Recibida:', -state.deposit),
            if (state.grandTotal > 0)
              _buildSummaryRow(
                context,
                'Saldo Pendiente:',
                state.balance,
                isTotal: true,
                highlight: state.balance > 0,
              ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: state.isLoading ? null : widget.onSubmit,
                icon: state.isLoading
                    ? SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Theme.of(context).colorScheme.onPrimary,
                        ),
                      )
                    : const Icon(Icons.save),
                label: Text(state.isEditMode ? 'Guardar Cambios' : 'Guardar Pedido'),
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
