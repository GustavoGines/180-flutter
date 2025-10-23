import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:go_router/go_router.dart';
import 'package:pasteleria_180_flutter/feature/orders/home_page.dart';

import '../../core/models/order.dart';
import '../auth/auth_state.dart';
import 'orders_repository.dart';

// Provider que busca un solo pedido por su ID
final orderByIdProvider = FutureProvider.autoDispose.family<Order, int>((
  ref,
  orderId,
) {
  final repository = ref.watch(ordersRepoProvider);
  return repository.getOrderById(orderId);
});

class OrderDetailPage extends ConsumerWidget {
  final int orderId;
  const OrderDetailPage({super.key, required this.orderId});

  // ======= Paleta Pastel y Traducciones =======
  static const _kPastelRose = Color(0xFFFFE3E8);
  static const _kPastelLavender = Color(0xFFEDE7FF);
  static const _kInkRose = Color(0xFFF3A9B9);
  static const _kInkLavender = Color(0xFFB4A6FF);
  static const _kInkBabyBlue = Color(0xFF8CC5F5);
  static const _kInkMint = Color(0xFF83D1B9);

  static const Map<String, String> statusTranslations = {
    'confirmed': 'Confirmado',
    'ready': 'Listo',
    'delivered': 'Entregado',
    'canceled': 'Cancelado',
  };
  static const Map<String, Color> _statusPastelBg = {
    'confirmed': Color(0xFFD8F6EC),
    'ready': Color(0xFFFFE6EF),
    'delivered': Color(0xFFDFF1FF),
    'canceled': Color(0xFFFFE0E0),
  };
  static const Map<String, Color> _statusInk = {
    'confirmed': _kInkMint,
    'ready': _kInkRose,
    'delivered': _kInkBabyBlue,
    'canceled': Color(0xFFE57373),
  };
  static const Color darkBrown = Color(0xFF7A4A4A);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final orderAsyncValue = ref.watch(orderByIdProvider(orderId));

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text(
          'Detalle del Pedido',
          style: TextStyle(color: darkBrown),
        ),
        backgroundColor: Colors.white,
        elevation: 1,
        iconTheme: const IconThemeData(color: darkBrown),
      ),
      floatingActionButton: orderAsyncValue.whenOrNull(
        data: (order) {
          final userRole = ref.watch(authStateProvider).user?.role;
          if (userRole == 'admin' || userRole == 'staff') {
            return FloatingActionButton(
              child: const Icon(Icons.edit_note),
              onPressed: () => _showActionsModal(context, ref, order),
            );
          }
          return null;
        },
      ),
      body: orderAsyncValue.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(
          child: Text(
            'No se pudo cargar el pedido:\n$err',
            textAlign: TextAlign.center,
          ),
        ),
        data: (order) {
          // --- NUEVA PREPARACIÓN DE DATOS (COMBINADOS) ---
          final total = order.total ?? 0.0;
          final deposit = order.deposit ?? 0.0;
          final balance = total - deposit;
          final currencyFormat = NumberFormat("'\$' #,##0.00", 'es_AR');

          // Juntamos todas las URLs de todos los items en una sola lista
          final allPhotoUrls = order.items
              .where((item) => item.customizationJson?['photo_urls'] != null)
              .expand(
                (item) =>
                    (item.customizationJson!['photo_urls'] as List<dynamic>),
              )
              .cast<String>()
              .toList();

          // Juntamos todos los rellenos y eliminamos duplicados
          final allFillings = order.items
              .where((item) => item.customizationJson?['fillings'] != null)
              .expand(
                (item) =>
                    (item.customizationJson!['fillings'] as List<dynamic>),
              )
              .cast<String>()
              .toSet()
              .join(', ');

          final ink = _statusInk[order.status] ?? Colors.grey.shade600;
          final bg = _statusPastelBg[order.status] ?? _kPastelRose;

          return SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildInfoCard(
                  title: 'Evento y Cliente',
                  backgroundColor: bg,
                  borderColor: ink.withAlpha(89),
                  children: [
                    _buildInfoTile(
                      Icons.person,
                      'Cliente',
                      order.client?.name ?? 'Sin nombre',
                    ),
                    _buildInfoTile(
                      Icons.calendar_today,
                      'Fecha',
                      DateFormat(
                        'EEEE d \'de\' MMMM, y',
                        'es_AR',
                      ).format(order.eventDate),
                    ),
                    _buildInfoTile(
                      Icons.access_time,
                      'Horario',
                      '${DateFormat.Hm().format(order.startTime)} - ${DateFormat.Hm().format(order.endTime)}',
                    ),
                    ListTile(
                      leading: Icon(Icons.flag, color: ink, size: 28),
                      title: const Text(
                        'Estado',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      trailing: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: ink.withAlpha(31),
                          borderRadius: BorderRadius.circular(99),
                          border: Border.all(color: ink.withAlpha(89)),
                        ),
                        child: Text(
                          (statusTranslations[order.status] ?? order.status)
                              .toUpperCase(),
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            letterSpacing: .3,
                            color: ink.withAlpha(242),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),

                if (allPhotoUrls.isNotEmpty)
                  _buildInfoCard(
                    title: 'Modelos',
                    backgroundColor: _kPastelLavender,
                    borderColor: _kInkLavender.withAlpha(89),
                    children: [
                      SizedBox(
                        height: 250,
                        child: ListView.builder(
                          scrollDirection: Axis.horizontal,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                          itemCount: allPhotoUrls.length,
                          itemBuilder: (context, index) {
                            final url = allPhotoUrls[index];
                            return Padding(
                              padding: const EdgeInsets.only(right: 10),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(12.0),
                                child: Image.network(
                                  url,
                                  width: 250,
                                  fit: BoxFit.cover,
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),

                _buildInfoCard(
                  title: 'Detalles de Productos',
                  backgroundColor: _kPastelRose,
                  borderColor: _kInkRose.withAlpha(89),
                  children: [
                    ...order.items.map(
                      (item) => ListTile(
                        leading: const Icon(
                          Icons.cake_outlined,
                          color: darkBrown,
                        ),
                        title: Text('${item.name} (x${item.qty})'),
                        trailing: Text(
                          currencyFormat.format(item.qty * item.unitPrice),
                        ),
                      ),
                    ),
                    if (allFillings.isNotEmpty)
                      const Divider(indent: 16, endIndent: 16),
                    if (allFillings.isNotEmpty)
                      _buildInfoTile(Icons.layers, 'Rellenos', allFillings),
                  ],
                ),

                _buildInfoCard(
                  title: 'Información Financiera',
                  backgroundColor: _kPastelRose,
                  borderColor: _kInkRose.withAlpha(89),
                  children: [
                    _buildInfoTile(
                      Icons.receipt_long,
                      'Total del Pedido',
                      currencyFormat.format(total),
                    ),
                    _buildInfoTile(
                      Icons.payment,
                      'Seña Pagada',
                      currencyFormat.format(deposit),
                    ),
                    const Divider(indent: 16, endIndent: 16, height: 1),
                    ListTile(
                      leading: Icon(
                        Icons.account_balance_wallet,
                        color: Colors.green.shade700,
                      ),
                      title: Text(
                        'Saldo Pendiente',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.green.shade700,
                          fontSize: 18,
                        ),
                      ),
                      trailing: Text(
                        currencyFormat.format(balance),
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.green.shade700,
                          fontSize: 18,
                        ),
                      ),
                    ),
                  ],
                ),

                if (order.notes != null && order.notes!.isNotEmpty)
                  _buildInfoCard(
                    title: 'Notas Adicionales',
                    backgroundColor: _kPastelRose,
                    borderColor: _kInkRose.withAlpha(89),
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16.0,
                          vertical: 12.0,
                        ),
                        child: Text(
                          order.notes!,
                          style: const TextStyle(fontSize: 16, height: 1.5),
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  // ====== Acciones ======
  void _showActionsModal(BuildContext context, WidgetRef ref, Order order) {
    final isPaid =
        order.total != null &&
        order.deposit != null &&
        order.deposit! >= order.total!;
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return SafeArea(
          child: Wrap(
            children: <Widget>[
              ListTile(
                leading: const Icon(Icons.flag_circle_outlined),
                title: const Text('Cambiar Estado'),
                onTap: () {
                  Navigator.pop(context);
                  _showStatusDialog(context, ref, order);
                },
              ),
              if (!isPaid)
                ListTile(
                  leading: const Icon(Icons.price_check, color: Colors.green),
                  title: const Text(
                    'Marcar como Pagado',
                    style: TextStyle(color: Colors.green),
                  ),
                  onTap: () async {
                    Navigator.pop(context);
                    await ref.read(ordersRepoProvider).markAsPaid(order.id);
                    ref.invalidate(orderByIdProvider(order.id));
                  },
                ),
              ListTile(
                title: const Text('Modificar Pedido Completo'),
                onTap: () {
                  Navigator.pop(context);
                  // Navega a la ruta de edición con el ID
                  context.push('/order/${order.id}/edit');
                },
              ),

              ListTile(
                leading: const Icon(Icons.delete_outline, color: Colors.red),
                title: const Text(
                  'Eliminar Pedido',
                  style: TextStyle(color: Colors.red),
                ),
                onTap: () {
                  Navigator.pop(context); // Cierra el modal de acciones
                  _showDeleteConfirmationDialog(
                    context,
                    ref,
                    order,
                  ); // Abre el diálogo de confirmación
                },
              ),
            ],
          ),
        );
      },
    );
  }

  void _showStatusDialog(BuildContext context, WidgetRef ref, Order order) {
    String selectedStatus = order.status;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Cambiar Estado del Pedido'),
              content: DropdownButton<String>(
                value: selectedStatus,
                isExpanded: true,
                items: statusTranslations.keys.map((String value) {
                  return DropdownMenuItem<String>(
                    value: value,
                    child: Text(statusTranslations[value]!),
                  );
                }).toList(),
                onChanged: (String? newValue) {
                  if (newValue != null) {
                    setDialogState(() => selectedStatus = newValue);
                  }
                },
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancelar'),
                ),
                FilledButton(
                  child: const Text('Guardar'),
                  onPressed: () async {
                    Navigator.pop(context);
                    await ref
                        .read(ordersRepoProvider)
                        .updateStatus(order.id, selectedStatus);
                    ref.invalidate(orderByIdProvider(order.id));
                  },
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showDeleteConfirmationDialog(
    BuildContext context,
    WidgetRef ref,
    Order order,
  ) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Confirmar Eliminación'),
          content: const Text(
            '¿Estás seguro de que quieres eliminar este pedido de forma permanente? Esta acción no se puede deshacer.',
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('Cancelar'),
              onPressed: () {
                Navigator.of(context).pop(); // Cierra el diálogo
              },
            ),
            FilledButton.icon(
              icon: const Icon(Icons.warning_amber),
              label: const Text('Eliminar'),
              style: FilledButton.styleFrom(
                backgroundColor: Colors.red.shade700,
              ),
              onPressed: () async {
                // Llama al repositorio para borrar el pedido
                await ref.read(ordersRepoProvider).deleteOrder(order.id);

                if (context.mounted) {
                  Navigator.of(
                    context,
                  ).pop(); // Cierra el diálogo de confirmación

                  // Muestra un mensaje de éxito
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Pedido eliminado con éxito.'),
                      backgroundColor: Colors.green,
                    ),
                  );

                  // Invalida la lista de pedidos para que se refresque
                  ref.invalidate(ordersByFilterProvider);

                  // Vuelve a la página principal
                  context.go('/');
                }
              },
            ),
          ],
        );
      },
    );
  }

  // ====== Helpers de UI ======
  Widget _buildInfoCard({
    String? title,
    required List<Widget> children,
    Color? backgroundColor,
    Color? borderColor,
  }) {
    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 16),
      color: backgroundColor ?? Colors.white,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(15),
        side: BorderSide(color: borderColor ?? Colors.black12, width: 1.2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (title != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Text(
                title,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: darkBrown,
                ),
              ),
            ),
          if (title != null)
            const Divider(indent: 16, endIndent: 16, thickness: 0.5, height: 1),
          ...children,
        ],
      ),
    );
  }

  Widget _buildInfoTile(IconData icon, String title, String subtitle) {
    return ListTile(
      leading: Icon(icon, color: darkBrown, size: 28),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
      subtitle: Text(subtitle, style: const TextStyle(fontSize: 16)),
    );
  }
}
