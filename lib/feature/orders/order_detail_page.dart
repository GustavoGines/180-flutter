import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:intl/intl.dart';
import 'package:go_router/go_router.dart';
import 'package:collection/collection.dart'; // Para firstWhereOrNull

import '../../core/models/order.dart';
import '../../core/models/order_item.dart'; // Asegúrate que OrderItem está importado
import '../auth/auth_state.dart';
import 'orders_repository.dart';
import 'home_page.dart'; // Para invalidar ordersByFilterProvider
// Importar product_catalog para acceder a enums y helpers si es necesario
import 'product_catalog.dart';

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

  // ======= Paleta Pastel y Traducciones (Actualizadas Y RESTAURADAS) ======= // <-- MODIFICADO
  static const Color primaryPink = Color(0xFFF8B6B6);
  static const Color darkBrown = Color(0xFF7A4A4A);
  static const Color lightBrownText = Color(0xFFA57D7D);
  static const Color accentGreen = Color(0xFF83D1B9);
  static const Color accentBlue = Color(0xFF8CC5F5);
  static const Color accentRed = Color(0xFFE57373);
  static const Color accentYellow = Color(0xFFFFE082);

  // --- COLORES PASTEL ORIGINALES --- // <-- NUEVO
  static const _kPastelRose = Color(0xFFFFE3E8);
  static const _kPastelLavender = Color(0xFFEDE7FF);
  static const _kInkRose = Color(0xFFF3A9B9);
  static const _kInkLavender = Color(0xFFB4A6FF);
  static const _kPastelMint = Color(0xFFD8F6EC);
  static const _kPastelBabyBlue = Color(0xFFDFF1FF);
  // --- FIN COLORES PASTEL --- // <-- NUEVO

  static const Map<String, String> statusTranslations = {
    'confirmed': 'Confirmado',
    'ready': 'Listo',
    'delivered': 'Entregado',
    'canceled': 'Cancelado',
    'unknown': 'Desconocido', // Añadir default
  };
  // Paleta basada en estado (ligeramente ajustada)
  static const Map<String, Color> _statusPastelBg = {
    'confirmed': _kPastelMint, // Amarillo para confirmado
    'ready': Color(0xFFFFE6EF), // Rosa para listo
    'delivered': _kPastelBabyBlue, // Azul para entregado
    'canceled': Color(0xFFFFE0E0), // Rojo para cancelado
    'unknown': Colors.grey,
  };
  static const Map<String, Color> _statusInk = {
    'confirmed': accentGreen,
    'ready': Color(0xFFF3A9B9), // rosa un poco más saturado
    'delivered': accentBlue,
    'canceled': Color(0xFFE57373), // Rojo oscuro
    'unknown': Colors.black54,
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final orderAsyncValue = ref.watch(orderByIdProvider(orderId));
    final currencyFormat = NumberFormat.currency(locale: 'es_AR', symbol: '\$');

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text('Detalle del Pedido'),
        // Estilos ya definidos en MaterialApp
      ),
      floatingActionButton: orderAsyncValue.whenOrNull(
        data: (order) {
          final userRole = ref.watch(authStateProvider).user?.role;
          // Permitir editar a admin y staff
          if (userRole == 'admin' || userRole == 'staff') {
            return FloatingActionButton.extended(
              icon: const Icon(Icons.edit_note),
              label: const Text('Acciones'),
              onPressed: () => _showActionsModal(context, ref, order),
              backgroundColor: darkBrown,
              foregroundColor: Colors.white,
            );
          }
          return null;
        },
      ),
      body: orderAsyncValue.when(
        loading: () =>
            const Center(child: CircularProgressIndicator(color: darkBrown)),
        error: (err, stack) => Center(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Text(
              'No se pudo cargar el pedido:\n$err',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.red),
            ),
          ),
        ),
        data: (order) {
          // --- Preparación de datos (incluyendo deliveryCost) ---
          final itemsSubtotal = order.items.fold<double>(
            0.0,
            (sum, item) => sum + (item.unitPrice * item.qty),
          );
          final deliveryCost = order.deliveryCost ?? 0.0;
          // Usar el total del backend si existe, si no, calcularlo (como fallback)
          final total = order.total ?? (itemsSubtotal + deliveryCost);
          final deposit = order.deposit ?? 0.0;
          final balance = total - deposit;

          // Juntar todas las URLs de fotos (sin cambios)
          final allPhotoUrls = order.items
              .map((item) => item.customizationJson?['photo_urls'])
              .whereNotNull() // Filtrar items sin 'photo_urls'
              .whereType<List>() // Asegurar que sea una lista
              .expand((urls) => urls) // Unir listas de URLs
              .whereType<String>() // Asegurar que cada URL sea String
              .toSet() // Eliminar duplicados
              .toList();

          final ink = _statusInk[order.status] ?? Colors.grey.shade600;
          final bg = _statusPastelBg[order.status] ?? Colors.grey.shade300;

          return RefreshIndicator(
            // Añadir para recargar fácilmente
            onRefresh: () => ref.refresh(orderByIdProvider(orderId).future),
            color: darkBrown,
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(
                16,
                16,
                16,
                90,
              ), // Más padding inferior por FAB extendido
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // --- Card Cliente/Evento ---
                  _buildInfoCard(
                    title: 'Evento y Cliente',
                    // AHORA USA LOS COLORES DEL ESTADO (bg y ink)
                    backgroundColor: bg, // <-- Color DINÁMICO según estado
                    borderColor: ink.withAlpha(
                      77,
                    ), // <-- Color DINÁMICO según estado
                    children: [
                      _buildInfoTile(
                        Icons.person_outline,
                        'Cliente',
                        order.client?.name ?? 'No especificado',
                        trailing: Text(
                          order.client?.phone ?? '',
                          style: const TextStyle(color: Colors.grey),
                        ),
                      ),
                      if (order.client?.address != null &&
                          order.client!.address!.isNotEmpty)
                        _buildInfoTile(
                          Icons.location_on_outlined,
                          'Dirección',
                          order.client!.address!,
                        ),

                      const Divider(indent: 16, endIndent: 16, height: 1),
                      _buildInfoTile(
                        Icons.calendar_today_outlined,
                        'Fecha',
                        DateFormat(
                          'EEEE d \'de\' MMMM, y',
                          'es_AR',
                        ).format(order.eventDate),
                      ),
                      _buildInfoTile(
                        Icons.access_time,
                        'Horario',
                        '${DateFormat.Hm('es_AR').format(order.startTime)} - ${DateFormat.Hm('es_AR').format(order.endTime)}',
                      ),
                      const Divider(indent: 16, endIndent: 16, height: 1),
                      ListTile(
                        leading: Icon(
                          Icons.flag_outlined,
                          color: ink,
                          size: 28,
                        ),
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
                            color: ink.withAlpha(38),
                            borderRadius: BorderRadius.circular(99),
                            border: Border.all(color: ink.withAlpha(102)),
                          ),
                          child: Text(
                            (statusTranslations[order.status] ?? order.status)
                                .toUpperCase(),
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                              letterSpacing: .5,
                              color: ink,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),

                  // --- Card Galería de Fotos ---
                  if (allPhotoUrls.isNotEmpty)
                    _buildInfoCard(
                      title: 'Fotos de Referencia',
                      backgroundColor: _kPastelLavender, // <-- Color restaurado
                      borderColor: _kInkLavender.withAlpha(
                        89,
                      ), // <-- Color restaurado
                      children: [
                        SizedBox(
                          height: 180,
                          child: ListView.builder(
                            scrollDirection: Axis.horizontal,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 12,
                            ),
                            itemCount: allPhotoUrls.length,
                            itemBuilder: (context, index) {
                              final url = allPhotoUrls[index];
                              return Padding(
                                padding: const EdgeInsets.only(right: 10),
                                child: GestureDetector(
                                  onTap: () => _showImageDialog(
                                    context,
                                    url,
                                  ), // <-- Llama al diálogo
                                  child: Hero(
                                    // <-- Añadir Hero para animación (opcional)
                                    tag: url, // <-- Usar URL como tag único
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(12.0),
                                      child: Image.network(
                                        url,
                                        width: 180,
                                        fit: BoxFit.cover,
                                        loadingBuilder: (context, child, progress) {
                                          return progress == null
                                              ? child
                                              : Container(
                                                  width: 180,
                                                  color: Colors.grey[200],
                                                  child: const Center(
                                                    child:
                                                        CircularProgressIndicator(
                                                          strokeWidth: 2,
                                                        ),
                                                  ),
                                                );
                                        },
                                        errorBuilder: (context, error, stack) =>
                                            Container(
                                              width: 180,
                                              color: Colors.grey[200],
                                              child: const Icon(
                                                Icons.broken_image,
                                                color: Colors.grey,
                                              ),
                                            ),
                                      ),
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                    ),

                  // --- Card Detalles de Productos ---
                  _buildInfoCard(
                    title: 'Productos del Pedido',
                    backgroundColor: _kPastelRose, // <-- Color restaurado
                    borderColor: _kInkRose.withAlpha(
                      89,
                    ), // <-- Color restaurado
                    children: order.items.mapIndexed((index, item) {
                      final custom = item.customizationJson ?? {};
                      final category = ProductCategory.values.firstWhereOrNull(
                        (e) => e.name == custom['product_category']?.toString(),
                      );
                      final itemTotal = item.qty * item.unitPrice;

                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            ListTile(
                              leading: CircleAvatar(
                                backgroundColor: darkBrown.withAlpha(26),
                                child: Text(
                                  '${item.qty}',
                                  style: const TextStyle(
                                    color: darkBrown,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              title: Text(
                                item.name,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              trailing: Text(
                                currencyFormat.format(itemTotal),
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                  color: darkBrown,
                                ),
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.only(
                                left: 72,
                                right: 16,
                                bottom: 8,
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: _buildItemDetails(
                                  item,
                                  category,
                                  currencyFormat,
                                ),
                              ),
                            ),
                            if (index < order.items.length - 1)
                              const Divider(
                                indent: 16,
                                endIndent: 16,
                                height: 1,
                              ),
                          ],
                        ),
                      );
                    }).toList(),
                  ),

                  // --- Card Información Financiera ---
                  _buildInfoCard(
                    title: 'Resumen Financiero',
                    backgroundColor: _kPastelRose, // <-- Color restaurado
                    borderColor: _kInkRose.withAlpha(
                      89,
                    ), // <-- Color restaurado
                    children: [
                      _buildSummaryRow(
                        'Subtotal Productos:',
                        itemsSubtotal,
                        currencyFormat,
                      ),
                      if (deliveryCost > 0)
                        _buildSummaryRow(
                          'Costo Envío:',
                          deliveryCost,
                          currencyFormat,
                        ),
                      const Divider(
                        indent: 16,
                        endIndent: 16,
                        height: 8,
                        thickness: 1,
                      ),
                      _buildSummaryRow(
                        'TOTAL PEDIDO:',
                        total,
                        currencyFormat,
                        isTotal: true,
                      ),
                      if (deposit > 0)
                        _buildSummaryRow(
                          'Seña Recibida:',
                          deposit,
                          currencyFormat,
                        ),
                      const Divider(
                        indent: 16,
                        endIndent: 16,
                        height: 8,
                        thickness: 1,
                      ),
                      _buildSummaryRow(
                        'SALDO PENDIENTE:',
                        balance,
                        currencyFormat,
                        isTotal: true,
                        highlight: balance > 0,
                      ),
                    ],
                  ),

                  // --- Card Notas Generales ---
                  if (order.notes != null && order.notes!.isNotEmpty)
                    _buildInfoCard(
                      title: 'Notas Generales',
                      backgroundColor: _kPastelRose, // <-- Color restaurado
                      borderColor: _kInkRose.withAlpha(
                        89,
                      ), // <-- Color restaurado
                      children: [
                        Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16.0,
                            vertical: 12.0,
                          ),
                          child: Text(
                            order.notes!,
                            style: const TextStyle(fontSize: 15, height: 1.4),
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  // --- NUEVO: Helper para construir los detalles del Item ---
  List<Widget> _buildItemDetails(
    OrderItem item,
    ProductCategory? category,
    NumberFormat currencyFormat,
  ) {
    final List<Widget> details = [];
    final custom = item.customizationJson ?? {};

    // Precio Unitario Base (Mostrar si es relevante, p.ej. tortas por kg)
    if (category == ProductCategory.torta &&
        custom['calculated_price'] != null &&
        item.unitPrice != custom['calculated_price']) {
      // Si el unitPrice guardado es el precio por KG y calculated_price es el total del item torta
      // podríamos mostrar el precio base por kg aquí, o simplemente omitirlo.
      // Por ahora lo omitimos para simplificar, ya que el ListTile principal muestra el total del item.
    } else if (item.qty > 1 && category != ProductCategory.torta) {
      // Para items que no son tortas, si la cantidad es > 1, mostrar el precio unitario
      details.add(
        _buildDetailRow(
          'Precio Unitario:',
          currencyFormat.format(item.unitPrice),
        ),
      );
    }

    // Detalles específicos por categoría
    switch (category) {
      case ProductCategory.torta:
        if (custom['weight_kg'] != null) {
          details.add(_buildDetailRow('Peso:', '${custom['weight_kg']} kg'));
        }
        // Mostrar tipo solo si es diferente al nombre base (p.ej., Torta Chantilly vs Torta)
        if (custom['cake_type'] != null && custom['cake_type'] != item.name) {
          details.add(_buildDetailRow('Tipo:', '${custom['cake_type']}'));
        }

        final List<String> fillings = List<String>.from(
          custom['selected_fillings'] ?? [],
        );
        final List<String> extraFillings = List<String>.from(
          custom['selected_extra_fillings'] ?? [],
        );
        if (fillings.isNotEmpty) {
          details.add(
            _buildDetailRow('Rellenos:', fillings.join(', '), isList: true),
          );
        }
        if (extraFillings.isNotEmpty) {
          details.add(
            _buildDetailRow(
              'Rellenos Extra:',
              extraFillings.join(', '),
              isList: true,
            ),
          );
        }

        final List<String> extrasKg = List<String>.from(
          custom['selected_extras_kg'] ?? [],
        );
        // Corrección aquí: castear a List<dynamic> primero
        final List<dynamic> extrasUnitRaw =
            custom['selected_extras_unit'] ?? [];
        final List<Map> extrasUnitData = extrasUnitRaw
            .whereType<Map>()
            .toList(); // Filtrar solo mapas
        if (extrasKg.isNotEmpty) {
          details.add(
            _buildDetailRow(
              'Extras (x kg):',
              extrasKg.join(', '),
              isList: true,
            ),
          );
        }
        if (extrasUnitData.isNotEmpty) {
          final unitExtrasText = extrasUnitData
              .map((e) => '${e['name']} (x${e['quantity']})')
              .join(', ');
          details.add(
            _buildDetailRow('Extras (x unidad):', unitExtrasText, isList: true),
          );
        }

        break;
      case ProductCategory.mesaDulce:
        // Usar getUnitText de product_catalog.dart (asegúrate que esté importado)
        if (custom['selected_size'] != null) {
          details.add(
            _buildDetailRow(
              'Tamaño:',
              getUnitText(ProductUnit.values.byName(custom['selected_size'])),
            ),
          );
        }
        // Mostrar "Media Docena" si aplica, no mostrar nada si es docena normal o unidad
        if (custom['is_half_dozen'] == true) {
          details.add(_buildDetailRow('Presentación:', 'Media Docena'));
        }
        break;
      case ProductCategory.miniTorta:
        // No hay muchos detalles específicos guardados aparte del precio final
        break;
      default:
        // Mostrar detalles genéricos si no se reconoce
        // Por ejemplo, podríamos intentar mostrar campos comunes si existen
        // if (custom['weight_kg'] != null) details.add(_buildDetailRow('Peso:', '${custom['weight_kg']} kg'));
        // if (custom['fillings'] != null) details.add(_buildDetailRow('Info:', custom['fillings'].toString()));
        // O mostrar JSON crudo si es para debug:
        // if (custom.isNotEmpty) details.add(_buildDetailRow('Custom:', custom.toString()));
        break;
    }

    // Notas específicas del item
    final itemNotes = custom['item_notes'] as String?; // Cast seguro
    if (itemNotes != null && itemNotes.isNotEmpty) {
      details.add(const SizedBox(height: 4)); // Espacio antes de notas
      details.add(_buildDetailRow('Notas Item:', itemNotes, isNote: true));
    }

    return details;
  }

  // --- NUEVO: Helper para fila de detalle de item ---
  Widget _buildDetailRow(
    String label,
    String value, {
    bool isList = false,
    bool isNote = false,
  }) {
    return Padding(
      padding: const EdgeInsets.only(top: 4.0),
      child: Row(
        crossAxisAlignment: isList || isNote
            ? CrossAxisAlignment.start
            : CrossAxisAlignment.center,
        children: [
          Text(
            '$label ',
            style: const TextStyle(
              color: Colors.black54,
              fontWeight: FontWeight.bold,
            ),
          ),
          Expanded(
            child: isList
                ? Wrap(
                    // Usar Wrap para listas (rellenos, extras)
                    spacing: 6.0,
                    runSpacing: 4.0,
                    children: value
                        .split(',')
                        .where((s) => s.trim().isNotEmpty)
                        .map(
                          (e) => Chip(
                            // Añadir filtro de vacíos
                            label: Text(e.trim()),
                            visualDensity: VisualDensity.compact,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 4,
                              vertical: 0,
                            ),
                            backgroundColor: darkBrown.withAlpha(204),
                            labelStyle: TextStyle(
                              fontSize: 12,
                              color: darkBrown.withAlpha(230),
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(6),
                              side: BorderSide(color: darkBrown.withAlpha(51)),
                            ),
                          ),
                        )
                        .toList(),
                  )
                : Text(
                    value,
                    style: TextStyle(
                      color: Colors.black87,
                      fontStyle: isNote ? FontStyle.italic : FontStyle.normal,
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  // --- NUEVO: Helper para fila del resumen financiero ---
  Widget _buildSummaryRow(
    String label,
    double amount,
    NumberFormat currencyFormat, {
    bool isTotal = false,
    bool highlight = false,
  }) {
    // Usar '.abs()' para mostrar la seña como número positivo
    final formattedAmount = currencyFormat.format(
      label == 'Seña Recibida:' ? amount.abs() : amount,
    );
    final sign = label == 'Seña Recibida:'
        ? '-'
        : ''; // Añadir signo negativo a la seña

    final style = TextStyle(
      fontSize: isTotal ? 16 : 14,
      fontWeight: isTotal ? FontWeight.bold : FontWeight.normal,
      color: highlight ? accentRed : (isTotal ? darkBrown : Colors.black87),
    );
    return Padding(
      padding: const EdgeInsets.symmetric(
        vertical: 4.0,
        horizontal: 16.0,
      ), // Padding horizontal
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: style),
          Text(
            '$sign$formattedAmount',
            style: style,
          ), // Añadir signo si es seña
        ],
      ),
    );
  }

  // ====== Acciones (MODIFICADO para usar FAB extendido y dialogos mejorados) ======
  void _showActionsModal(BuildContext context, WidgetRef ref, Order order) {
    // Usar el total del backend directamente para la comprobación
    final bool isPaid = (order.deposit ?? 0.0) >= (order.total ?? 0.0) - 0.01;

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        // Bordes redondeados
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return SafeArea(
          child: Wrap(
            children: <Widget>[
              ListTile(
                leading: const Icon(
                  Icons.flag_circle_outlined,
                  color: darkBrown,
                ),
                title: const Text('Cambiar Estado'),
                onTap: () {
                  Navigator.pop(context); // Cierra modal
                  _showStatusDialog(
                    context,
                    ref,
                    order,
                  ); // Abre diálogo de estado
                },
              ),
              if (!isPaid) // Mostrar solo si no está pagado
                ListTile(
                  leading: const Icon(Icons.price_check, color: Colors.green),
                  title: const Text('Marcar como Pagado Totalmente'),
                  onTap: () async {
                    Navigator.pop(context); // Cierra modal
                    // Mostrar diálogo de confirmación antes de marcar como pagado
                    bool confirm =
                        await showDialog<bool>(
                          context: context,
                          builder: (ctx) => AlertDialog(
                            title: const Text('Confirmar Pago Total'),
                            content: const Text(
                              'Esto establecerá la seña igual al total del pedido. ¿Continuar?',
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(ctx, false),
                                child: const Text('Cancelar'),
                              ),
                              FilledButton(
                                onPressed: () => Navigator.pop(ctx, true),
                                child: const Text('Confirmar'),
                              ),
                            ],
                          ),
                        ) ??
                        false; // Default a false si se cierra sin seleccionar

                    if (confirm) {
                      try {
                        // Mostrar indicador de carga sería ideal aquí
                        await ref.read(ordersRepoProvider).markAsPaid(order.id);
                        ref.invalidate(
                          orderByIdProvider(order.id),
                        ); // Refrescar datos
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Pedido marcado como pagado.'),
                            backgroundColor: Colors.green,
                          ),
                        );
                      } catch (e) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Error al marcar como pagado: $e'),
                            backgroundColor: Colors.red,
                          ),
                        );
                      }
                    }
                  },
                ),
              ListTile(
                leading: const Icon(Icons.edit_outlined, color: darkBrown),
                title: const Text('Modificar Pedido Completo'),
                onTap: () {
                  Navigator.pop(context); // Cierra modal
                  // Navega a la ruta de edición con el ID
                  context.push('/order/${order.id}/edit');
                },
              ),
              const Divider(
                height: 1,
                indent: 16,
                endIndent: 16,
              ), // Separador visual
              ListTile(
                leading: Icon(
                  Icons.delete_forever_outlined,
                  color: Colors.red.shade700,
                ),
                title: Text(
                  'Eliminar Pedido',
                  style: TextStyle(color: Colors.red.shade700),
                ),
                onTap: () {
                  Navigator.pop(context); // Cierra modal de acciones
                  _showDeleteConfirmationDialog(
                    context,
                    ref,
                    order,
                  ); // Abre diálogo de confirmación
                },
              ),
            ],
          ),
        );
      },
    );
  }

  // --- Diálogo Cambiar Estado (Sin cambios funcionales, quizás estilo) ---
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
                items: statusTranslations.keys.where((k) => k != 'unknown').map(
                  (String value) {
                    // Ocultar 'unknown'
                    return DropdownMenuItem<String>(
                      value: value,
                      child: Text(statusTranslations[value]!),
                    );
                  },
                ).toList(),
                onChanged: (String? newValue) {
                  if (newValue != null) {
                    setDialogState(() => selectedStatus = newValue);
                  }
                },
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text(
                    'Cancelar',
                    style: TextStyle(color: darkBrown),
                  ),
                ),
                FilledButton(
                  style: FilledButton.styleFrom(backgroundColor: darkBrown),
                  child: const Text('Guardar Estado'),
                  onPressed: () async {
                    Navigator.pop(context); // Cierra diálogo
                    try {
                      // Mostrar indicador de carga sería ideal
                      await ref
                          .read(ordersRepoProvider)
                          .updateStatus(order.id, selectedStatus);
                      ref.invalidate(orderByIdProvider(order.id)); // Refresca
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Estado actualizado.'),
                          backgroundColor: Colors.green,
                        ),
                      );
                    } catch (e) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Error al actualizar estado: $e'),
                          backgroundColor: Colors.red,
                        ),
                      );
                    }
                  },
                ),
              ],
            );
          },
        );
      },
    );
  }

  // --- Diálogo Confirmar Eliminación (Sin cambios funcionales, quizás estilo) ---
  void _showDeleteConfirmationDialog(
    BuildContext context,
    WidgetRef ref,
    Order order,
  ) {
    showDialog(
      context: context,
      barrierDismissible: false, // Evitar cierre accidental
      builder: (BuildContext context) {
        // Usar Consumer para poder mostrar un estado de carga dentro del diálogo
        return Consumer(
          builder: (context, ref, child) {
            // Usar un StateProvider local para manejar el estado de carga del borrado
            final isDeletingProvider = StateProvider<bool>((_) => false);
            final isDeleting = ref.watch(isDeletingProvider);

            return AlertDialog(
              title: const Text('Confirmar Eliminación'),
              content: const Text(
                '¿Estás seguro de que quieres eliminar este pedido de forma permanente? Esta acción no se puede deshacer y borrará las fotos asociadas.',
              ),
              actions: <Widget>[
                TextButton(
                  onPressed: isDeleting
                      ? null
                      : () => Navigator.of(context).pop(),
                  child: const Text(
                    'Cancelar',
                    style: TextStyle(color: darkBrown),
                  ),
                ),
                FilledButton.icon(
                  icon: isDeleting
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.warning_amber),
                  label: Text(
                    isDeleting ? 'Eliminando...' : 'Eliminar Definitivamente',
                  ),
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.red.shade700,
                    foregroundColor: Colors.white,
                    // Cambiar estilo si está deshabilitado
                    disabledBackgroundColor: Colors.red.shade300,
                  ),
                  // Deshabilitar si ya se está borrando
                  onPressed: isDeleting
                      ? null
                      : () async {
                          // Indicar que estamos borrando
                          ref.read(isDeletingProvider.notifier).state = true;
                          try {
                            await ref
                                .read(ordersRepoProvider)
                                .deleteOrder(order.id);
                            if (context.mounted) {
                              Navigator.of(
                                context,
                              ).pop(); // Cierra el diálogo de confirmación
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Pedido eliminado con éxito.'),
                                  backgroundColor: Colors.green,
                                ),
                              );
                              ref.invalidate(
                                ordersByFilterProvider,
                              ); // Invalida la lista
                              context.go('/'); // Vuelve a la página principal
                            }
                          } catch (e) {
                            if (context.mounted) {
                              Navigator.of(
                                context,
                              ).pop(); // Cierra diálogo en caso de error también
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Error al eliminar: $e'),
                                  backgroundColor: Colors.red,
                                ),
                              );
                            }
                          }
                          // No necesitamos volver a poner isDeleting a false si el diálogo se cierra
                        },
                ),
              ],
            );
          },
        );
      },
    );
  }

  // ====== Helpers de UI (MODIFICADO _buildInfoCard para aceptar children directamente) ======
  Widget _buildInfoCard({
    String? title,
    required List<Widget> children,
    Color? backgroundColor,
    Color? borderColor,
  }) {
    return Card(
      elevation: 0.5,
      margin: const EdgeInsets.only(bottom: 16),
      color: backgroundColor ?? Colors.white,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: borderColor ?? Colors.grey.shade300, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (title != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: Text(
                title,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: darkBrown,
                ),
              ),
            ),
          if (title != null)
            Divider(
              indent: 16,
              endIndent: 16,
              thickness: 0.5,
              height: 1,
              color: borderColor ?? Colors.grey.shade300,
            ),
          // Aplicar padding solo si hay título, los children deben manejar su propio padding interno si es necesario
          // O envolver directamente los children en una columna con padding
          Padding(
            padding: EdgeInsets.only(
              bottom: title != null ? 8.0 : 0,
            ), // Padding inferior si hay título
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start, // Asegurar alineación
              children: children,
            ),
          ),
        ],
      ),
    );
  }

  // _buildInfoTile no necesita cambios
  Widget _buildInfoTile(
    IconData icon,
    String title,
    String subtitle, {
    Widget? trailing,
  }) {
    return ListTile(
      leading: Icon(icon, color: darkBrown.withAlpha(204), size: 26),
      title: Text(
        title,
        style: const TextStyle(
          fontWeight: FontWeight.w600,
          color: Colors.black87,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: const TextStyle(fontSize: 15, color: Colors.black54),
      ),
      trailing: trailing,
      dense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 0),
    );
  }

  // --- NUEVA FUNCIÓN: Mostrar Diálogo con Imagen Grande ---
  void _showImageDialog(BuildContext context, String imageUrl) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          // Hacer el diálogo un poco más grande
          insetPadding: const EdgeInsets.symmetric(
            horizontal: 20,
            vertical: 40,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min, // Ajustar al contenido
            children: <Widget>[
              // Usar InteractiveViewer para zoom/pan
              Expanded(
                // Ocupar el espacio disponible
                child: InteractiveViewer(
                  panEnabled: true, // Habilitar pan
                  minScale: 0.5,
                  maxScale: 4.0, // Aumentar zoom máximo
                  child: Hero(
                    // <-- Añadir Hero aquí también con el mismo tag
                    tag: imageUrl,
                    child: Image.network(
                      imageUrl,
                      fit: BoxFit.contain, // Para ver la imagen completa
                      // Indicador de carga para la imagen grande
                      loadingBuilder: (context, child, loadingProgress) {
                        if (loadingProgress == null) return child;
                        return Center(
                          child: CircularProgressIndicator(
                            value: loadingProgress.expectedTotalBytes != null
                                ? loadingProgress.cumulativeBytesLoaded /
                                      loadingProgress.expectedTotalBytes!
                                : null,
                          ),
                        );
                      },
                      // Indicador de error
                      errorBuilder: (context, error, stackTrace) =>
                          const Center(
                            child: Icon(
                              Icons.broken_image,
                              color: Colors.grey,
                              size: 50,
                            ),
                          ),
                    ),
                  ),
                ),
              ),
              // Botón de cierre
              TextButton(
                child: const Text("Cerrar"),
                onPressed: () {
                  Navigator.of(context).pop();
                },
              ),
              const SizedBox(height: 10), // Pequeño espacio inferior
            ],
          ),
        );
      },
    );
  }
} // Fin OrderDetailPage
