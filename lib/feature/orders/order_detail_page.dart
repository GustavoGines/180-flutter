// lib/feature/orders/order_detail_page.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

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

  // ======= Paleta Pastel =======
  static const _kPastelRose = Color(
    0xFFFFE3E8,
  ); // rosa pastel (para todas las cards)
  static const _kPastelLavender = Color(
    0xFFEDE7FF,
  ); // lila pastel (solo Modelos)
  static const _kInkRose = Color(0xFFF3A9B9);
  static const _kInkLavender = Color(0xFFB4A6FF);
  static const _kInkBabyBlue = Color(0xFF8CC5F5);
  static const _kInkMint = Color(0xFF83D1B9);
  static const _kInkSand = Color(0xFFC9B99A);

  // Traducciones visibles
  static const Map<String, String> statusTranslations = {
    'confirmed': 'Confirmado',
    'ready': 'Listo',
    'delivered': 'Entregado',
    'canceled': 'Cancelado',
  };

  // Fondo pastel por estado (igual que en Home)
  static const Map<String, Color> _statusPastelBg = {
    'confirmed': Color(0xFFD8F6EC), // menta pastel
    'ready': Color(0xFFFFE6EF), // rosa pastel
    'delivered': Color(0xFFDFF1FF), // celeste pastel
    'canceled': Color(0xFFFFE0E0), // rojo pastel suave
  };

  // Acento/borde por estado (para el chip de Estado)
  static const Map<String, Color> _statusInk = {
    'confirmed': _kInkMint,
    'ready': _kInkRose,
    'delivered': _kInkBabyBlue,
    'canceled': Color(0xFFE57373), // rojo pastel suave
  };

  // Color de acento general para títulos/íconos secundarios
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
      // FAB solo para admin/staff
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
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Text(
              'No se pudo cargar el pedido:\n$err',
              textAlign: TextAlign.center,
            ),
          ),
        ),
        data: (order) {
          final total = order.total ?? 0.0;
          final deposit = order.deposit ?? 0.0;
          final balance = total - deposit;
          final currencyFormat = NumberFormat("'\$' #,##0.00", 'es_AR');

          final firstItem = order.items.isNotEmpty ? order.items.first : null;
          final photoUrls =
              (firstItem?.customizationJson?['photo_urls'] as List<dynamic>?);
          final fillings =
              (firstItem?.customizationJson?['fillings'] as List<dynamic>?)
                  ?.join(', ');

          // Color de tinta según estado (para el chip)
          final ink = _statusInk[order.status] ?? _kInkSand;
          final bg =
              _statusPastelBg[order.status] ??
              _kPastelRose; // 👈 fondo según estado

          return SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ====== Card 1: Evento y Cliente (Rosa pastel) ======
                _buildInfoCard(
                  title: 'Evento y Cliente',
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
                          color: ink.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(99),
                          border: Border.all(
                            color: ink.withValues(alpha: 0.35),
                          ),
                        ),
                        child: Text(
                          (statusTranslations[order.status] ?? order.status)
                              .toUpperCase(),
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            letterSpacing: .3,
                            color: ink.withValues(alpha: 0.95),
                          ),
                        ),
                      ),
                    ),
                  ],
                  background: bg, // 👈 fondo por estado
                  borderColor: ink.withValues(alpha: 0.35),
                ),

                // ====== Card 2: Modelos de Torta (Lila pastel) ======
                if (photoUrls != null && photoUrls.isNotEmpty)
                  _buildInfoCard(
                    title: 'Modelos de Torta',
                    children: [
                      SizedBox(
                        height: 250,
                        child: ListView.builder(
                          scrollDirection: Axis.horizontal,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                          itemCount: photoUrls.length,
                          itemBuilder: (context, index) {
                            final url = photoUrls[index] as String;
                            return Padding(
                              padding: const EdgeInsets.only(right: 10),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(12.0),
                                child: Image.network(
                                  url,
                                  width: 250,
                                  fit: BoxFit.cover,
                                  loadingBuilder: (context, child, progress) =>
                                      progress == null
                                      ? child
                                      : const Center(
                                          child: CircularProgressIndicator(),
                                        ),
                                  errorBuilder: (context, error, stack) =>
                                      const Center(
                                        child: Icon(
                                          Icons.broken_image,
                                          size: 50,
                                          color: Colors.grey,
                                        ),
                                      ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                    background: _kPastelLavender,
                    borderColor: _kInkLavender.withValues(alpha: 0.35),
                  ),

                // ====== Card 3: Detalles del Producto (Rosa pastel) ======
                if (firstItem != null)
                  _buildInfoCard(
                    title: 'Detalles del Producto',
                    children: [
                      _buildInfoTile(
                        Icons.cake,
                        'Producto',
                        '${firstItem.name} (x${firstItem.qty})',
                      ),
                      if (fillings != null && fillings.isNotEmpty)
                        _buildInfoTile(Icons.layers, 'Rellenos', fillings),
                    ],
                    background: _kPastelRose,
                    borderColor: _kInkRose.withValues(alpha: 0.35),
                  ),

                // ====== Card 4: Información Financiera (Rosa pastel) ======
                _buildInfoCard(
                  title: 'Información Financiera',
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
                  background: _kPastelRose,
                  borderColor: _kInkRose.withValues(alpha: 0.35),
                ),

                // ====== Card 5: Notas (Rosa pastel) ======
                if (order.notes != null && order.notes!.isNotEmpty)
                  _buildInfoCard(
                    title: 'Notas Adicionales',
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
                    background: _kPastelRose,
                    borderColor: _kInkRose.withValues(alpha: 0.35),
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
                leading: const Icon(Icons.edit_document),
                title: const Text('Modificar Pedido Completo'),
                onTap: () {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                        'Función de edición completa no implementada.',
                      ),
                    ),
                  );
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

  // ====== Helpers de UI ======
  Widget _buildInfoCard({
    required String title,
    required List<Widget> children,
    Color? background,
    Color? borderColor,
  }) {
    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 16),
      color: background ?? Colors.white,
      surfaceTintColor: Colors.transparent, // mantiene el pastel limpio (M3)
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(15),
        side: BorderSide(color: (borderColor ?? Colors.black12), width: 1.2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
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
