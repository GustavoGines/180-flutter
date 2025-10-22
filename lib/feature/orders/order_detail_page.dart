import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/models/order.dart'; // Asegúrate que la ruta a tu modelo sea correcta
import 'orders_repository.dart'; // Asegúrate que la ruta a tu repositorio sea correcta

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

  // Paleta de colores de la app
  static const Color primaryPink = Color(0xFFF9C0C0);
  static const Color darkBrown = Color(0xFF7A4A4A);
  static const Color lightBrownText = Color(0xFFA57D7D);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final orderAsyncValue = ref.watch(orderByIdProvider(orderId));

    return Scaffold(
      backgroundColor: Colors
          .grey[50], // Un fondo ligeramente gris para que las tarjetas resalten
      appBar: AppBar(
        title: Text(
          'Detalle del Pedido',
          style: const TextStyle(color: darkBrown),
        ),
        backgroundColor: Colors.white,
        elevation: 1,
        iconTheme: const IconThemeData(color: darkBrown),
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
          // --- Preparación de Datos ---
          final total = order.total ?? 0.0;
          final deposit = order.deposit ?? 0.0;
          final balance = total - deposit;
          final currencyFormat = NumberFormat("'\$' #,##0.00", 'es_AR');

          // Asumimos que los detalles especiales están en el primer item.
          final firstItem = order.items.isNotEmpty ? order.items.first : null;

          // --- CAMBIO CLAVE: Leemos 'photo_urls' (plural) ---
          final photoUrls =
              (firstItem?.customizationJson?['photo_urls'] as List<dynamic>?);

          final fillingsList =
              firstItem?.customizationJson?['fillings'] as List<dynamic>?;
          final fillings = fillingsList?.join(', ');

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
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
                      leading: const Icon(Icons.flag, color: darkBrown),
                      title: const Text(
                        'Estado',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      trailing: Chip(
                        label: Text(
                          order.status.toUpperCase(),
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        backgroundColor: _getStatusColor(order.status),
                        labelStyle: const TextStyle(color: Colors.white),
                      ),
                    ),
                  ],
                ),

                // --- CAMBIO CLAVE: Tarjeta de Galería de Fotos ---
                if (photoUrls != null && photoUrls.isNotEmpty)
                  _buildInfoCard(
                    title: 'Modelos de Torta',
                    children: [
                      SizedBox(
                        height: 250, // Altura fija para la galería horizontal
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
                                  width: 250, // Ancho fijo para cada imagen
                                  fit: BoxFit.cover,
                                  loadingBuilder: (context, child, progress) {
                                    return progress == null
                                        ? child
                                        : const Center(
                                            child: CircularProgressIndicator(),
                                          );
                                  },
                                  errorBuilder: (context, error, stack) {
                                    return const Center(
                                      child: Icon(
                                        Icons.broken_image,
                                        size: 50,
                                        color: Colors.grey,
                                      ),
                                    );
                                  },
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),

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
                  ),

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
                ),

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
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  // Widget helper para crear las tarjetas
  Widget _buildInfoCard({
    required String title,
    required List<Widget> children,
  }) {
    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
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
          const Divider(indent: 16, endIndent: 16, thickness: 0.5),
          ...children,
        ],
      ),
    );
  }

  // Widget helper para crear las filas de información
  Widget _buildInfoTile(IconData icon, String title, String subtitle) {
    return ListTile(
      leading: Icon(icon, color: darkBrown, size: 28),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
      subtitle: Text(subtitle, style: const TextStyle(fontSize: 16)),
    );
  }

  // Helper para dar color al estado
  Color _getStatusColor(String status) {
    switch (status) {
      case 'confirmed':
        return Colors.green.shade600;
      case 'delivered':
        return Colors.blue.shade600;
      case 'canceled':
        return Colors.red.shade600;
      case 'draft':
      default:
        return Colors.orange.shade600;
    }
  }
}
