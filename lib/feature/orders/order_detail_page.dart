import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:intl/intl.dart';
import 'package:go_router/go_router.dart';
import 'package:collection/collection.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:pasteleria_180_flutter/core/utils/launcher_utils.dart';
import 'package:pasteleria_180_flutter/feature/orders/home_page.dart';
// <-- Tu nuevo generador

import '../../core/models/order.dart';
import '../../core/models/order_item.dart';
import '../../core/models/client_address.dart'; // <-- IMPORTAR ClientAddress
import '../auth/auth_state.dart';
import 'orders_repository.dart';
// import 'home_page.dart'; // No parece usarse aquí
import 'product_catalog.dart';

// Provider que busca un solo pedido por su ID
final orderByIdProvider = FutureProvider.autoDispose.family<Order?, int>((
  ref,
  orderId,
) {
  final repository = ref.watch(ordersRepoProvider);
  return repository.getOrderById(orderId);
});

class OrderDetailPage extends ConsumerWidget {
  final int orderId;
  const OrderDetailPage({super.key, required this.orderId});

  // ======= Paleta Pastel y Traducciones (COLORES DE MARCA) =======
  // (Tus colores y traducciones se mantienen intactos)
  static const Color darkBrown = Color(0xFF7A4A4A);
  static const Color accentRed = Color(0xFFE57373);
  static const _kPastelRose = Color(0xFFFFE3E8);
  static const _kPastelLavender = Color(0xFFEDE7FF);
  static const _kInkRose = Color(0xFFF3A9B9);
  static const _kInkLavender = Color(0xFFB4A6FF);
  static const _kPastelMint = Color(0xFFD8F6EC);
  static const _kPastelBabyBlue = Color(0xFFDFF1FF);

  static const Map<String, String> statusTranslations = {
    'confirmed': 'Confirmado',
    'ready': 'Listo',
    'delivered': 'Entregado',
    'canceled': 'Cancelado',
    'unknown': 'Desconocido',
  };
  static const Map<String, Color> _statusPastelBg = {
    'confirmed': _kPastelMint,
    'ready': Color(0xFFFFE6EF),
    'delivered': _kPastelBabyBlue,
    'canceled': Color(0xFFFFE0E0),
    'unknown': Colors.grey,
  };
  static const Map<String, Color> _statusInk = {
    'confirmed': Color(0xFF83D1B9),
    'ready': _kInkRose,
    'delivered': Color(0xFF8CC5F5),
    'canceled': accentRed,
    'unknown': Colors.black54,
  };
  // ======= Fin Paleta (Sin cambios) =======

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final orderAsyncValue = ref.watch(orderByIdProvider(orderId));
    final currencyFormat = NumberFormat.currency(locale: 'es_AR', symbol: '\$');
    final cs = Theme.of(context).colorScheme;

    return orderAsyncValue.when(
      loading: () => Scaffold(
        appBar: AppBar(title: const Text('Detalle del Pedido')),
        body: Center(child: CircularProgressIndicator(color: cs.primary)),
      ),
      error: (err, stack) => Scaffold(
        appBar: AppBar(title: const Text('Detalle del Pedido')),
        body: Center(child: Text('Error al cargar el pedido: $err')),
      ),
      data: (order) {
        // --- Manejo de Pedido Nulo ---
        if (order == null) {
          return Scaffold(
            appBar: AppBar(title: const Text('Detalle del Pedido')),
            body: const Center(
              child: Text('Pedido no encontrado o eliminado.'),
            ),
          );
        }

        // --- Lógica de variables ---
        final userRole = ref.watch(authStateProvider).user?.role;
        final bool canEdit = userRole == 'admin' || userRole == 'staff';

        final itemsSubtotal = order.items.fold<double>(
          0.0,
          (sum, item) => sum + (item.finalUnitPrice * item.qty),
        );
        final deliveryCost = order.deliveryCost ?? 0.0;
        final total = order.total ?? (itemsSubtotal + deliveryCost);
        final deposit = order.deposit ?? 0.0;
        final balance = total - deposit;

        final allPhotoUrls = order.items
            .map((item) => item.customizationJson?['photo_urls'])
            .whereNotNull()
            .whereType<List>()
            .expand((urls) => urls)
            .whereType<String>()
            .toSet()
            .toList();

        final ink = _statusInk[order.status] ?? Colors.grey.shade600;
        final bg = _statusPastelBg[order.status] ?? Colors.grey.shade300;
        // --- Fin Lógica de variables ---

        return Scaffold(
          backgroundColor: cs.background,
          appBar: AppBar(
            title: const Text('Detalle del Pedido'),
            actions: [
              IconButton(
                icon: const Icon(Icons.picture_as_pdf),
                tooltip: 'Vista Previa PDF',
                // Llama a la nueva ruta que configuramos en router.dart
                onPressed: () => context.push('/order/${order.id}/pdf/preview'),
              ),
              // Botón "Editar"
              if (canEdit)
                IconButton(
                  icon: const Icon(Icons.edit_outlined),
                  tooltip: 'Modificar Pedido',
                  onPressed: () => context.push('/order/${order.id}/edit'),
                ),
            ],
          ),
          floatingActionButton: null,
          body: RefreshIndicator(
            onRefresh: () => ref.refresh(orderByIdProvider(orderId).future),
            color: cs.primary,
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 90),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // --- Card Cliente/Evento ---
                  _buildInfoCard(
                    context,
                    title: 'Evento y Cliente',
                    backgroundColor: bg,
                    borderColor: ink, // Usamos el color 'ink' completo
                    children: [
                      // --- CLIENTE (AHORA CLICKEABLE) ---
                      _buildInfoTile(
                        context,
                        Icons.person_outline,
                        'Cliente',
                        order.client?.name ?? 'No especificado',
                        onTap: order.client != null
                            ? () => context.push('/clients/${order.client!.id}')
                            : null, // Navega al detalle del cliente
                        trailing: (order.client?.whatsappUrl != null)
                            ? IconButton(
                                icon: const FaIcon(FontAwesomeIcons.whatsapp),
                                color: Colors.green, // Color de marca
                                tooltip: 'Chatear con ${order.client?.name}',
                                onPressed: () {
                                  launchExternalUrl(order.client!.whatsappUrl!);
                                },
                              )
                            : null,
                      ),

                      // --- DIRECCIÓN DE ENTREGA (NUEVA LÓGICA) ---
                      _buildDeliveryAddressTile(context, order),

                      // --- RESTO DE LA INFO ---
                      const Divider(indent: 16, endIndent: 16, height: 1),
                      _buildInfoTile(
                        context,
                        Icons.calendar_today_outlined,
                        'Fecha',
                        DateFormat(
                          'EEEE d \'de\' MMMM, y',
                          'es_AR',
                        ).format(order.eventDate),
                      ),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Expanded(
                            flex: 5,
                            child: _buildInfoTile(
                              context,
                              Icons.access_time,
                              'Horario',
                              '${DateFormat.Hm('es_AR').format(order.startTime)} - ${DateFormat.Hm('es_AR').format(order.endTime)}',
                            ),
                          ),
                          Expanded(
                            flex: 4,
                            child: Padding(
                              padding: const EdgeInsets.only(
                                right: 16.0,
                                left: 8.0,
                              ),
                              child: DropdownButtonHideUnderline(
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 8,
                                  ),
                                  decoration: BoxDecoration(
                                    // --- ADAPTADO AL TEMA ---
                                    color: canEdit
                                        ? cs.surfaceContainerHigh
                                        : cs.surfaceContainer,
                                    borderRadius: BorderRadius.circular(99),
                                    border: Border.all(
                                      color: canEdit
                                          ? cs.outlineVariant
                                          : cs.outline.withOpacity(0.5),
                                    ),
                                    // --- FIN ---
                                  ),
                                  child: DropdownButton<String>(
                                    value: order.status,
                                    icon: canEdit
                                        ? Icon(
                                            Icons.arrow_drop_down,
                                            // --- ADAPTADO AL TEMA ---
                                            color: cs.onSurfaceVariant,
                                          )
                                        : const SizedBox(width: 8),
                                    isDense: true,
                                    // --- ADAPTADO AL TEMA (Texto del botón) ---
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                      letterSpacing: .5,
                                      color: ink, // Mantiene el color semántico
                                    ),
                                    // Fondo del menú desplegable
                                    dropdownColor: cs.surfaceContainerHighest,
                                    // --- FIN ---
                                    items: statusTranslations.keys
                                        .where((k) => k != 'unknown')
                                        .map((String value) {
                                          final Color optionColor =
                                              _statusInk[value] ?? Colors.grey;
                                          return DropdownMenuItem<String>(
                                            value: value,
                                            child: Text(
                                              statusTranslations[value]!,
                                              style: TextStyle(
                                                color: optionColor,
                                                fontWeight: FontWeight.bold,
                                                fontSize: 14,
                                              ),
                                            ),
                                          );
                                        })
                                        .toList(),
                                    onChanged: !canEdit
                                        ? null
                                        : (String? newStatus) {
                                            if (newStatus == null ||
                                                newStatus == order.status) {
                                              return;
                                            }
                                            _handleChangeStatus(
                                              context,
                                              ref,
                                              order,
                                              newStatus,
                                            );
                                          },
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),

                  // --- Card Galería de Fotos ---
                  if (allPhotoUrls.isNotEmpty)
                    _buildInfoCard(
                      context,
                      title: 'Fotos de Referencia',
                      backgroundColor: _kPastelLavender,
                      borderColor: _kInkLavender,
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
                                  onTap: () => _showImageDialog(context, url),
                                  child: Hero(
                                    tag: url,
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
                                                  color:
                                                      cs.surfaceContainerHigh,
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
                                              color: cs.surfaceContainerHigh,
                                              child: Icon(
                                                Icons.broken_image,
                                                color: cs.onSurfaceVariant,
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
                    context,
                    title: 'Productos del Pedido',
                    backgroundColor: _kPastelRose,
                    borderColor: _kInkRose,
                    children: order.items.mapIndexed((index, item) {
                      final custom = item.customizationJson ?? {};
                      final category = ProductCategory.values.firstWhereOrNull(
                        (e) => e.name == custom['product_category']?.toString(),
                      );
                      final itemTotal = item.qty * item.finalUnitPrice;

                      // --- ADAPTADO AL TEMA ---
                      final isDarkMode =
                          Theme.of(context).brightness == Brightness.dark;
                      final primaryTextColor = cs.onSurface;
                      final secondaryTextColor = cs.onSurfaceVariant;
                      final circleBg = isDarkMode
                          ? cs.secondaryContainer
                          : cs.secondary.withAlpha(51);
                      final circleFg = isDarkMode
                          ? cs.onSecondaryContainer
                          : primaryTextColor;
                      // --- FIN ---

                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            ListTile(
                              leading: CircleAvatar(
                                backgroundColor: circleBg,
                                child: Text(
                                  '${item.qty}',
                                  style: TextStyle(
                                    color: circleFg,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              title: Text(
                                item.name,
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: primaryTextColor,
                                ),
                              ),
                              subtitle:
                                  (category == ProductCategory.torta ||
                                      category == ProductCategory.mesaDulce)
                                  ? Text(
                                      'Precio Base: ${currencyFormat.format(item.finalUnitPrice)}',
                                      style: TextStyle(
                                        color: secondaryTextColor,
                                      ),
                                    )
                                  : null,

                              trailing: Text(
                                currencyFormat.format(itemTotal),
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                  color: primaryTextColor,
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
                                  context, // Pasamos el contexto
                                ),
                              ),
                            ),
                            if (index < order.items.length - 1)
                              Divider(
                                indent: 16,
                                endIndent: 16,
                                height: 1,
                                color: cs.outlineVariant,
                              ),
                          ],
                        ),
                      );
                    }).toList(),
                  ),

                  // --- Card Información Financiera ---
                  _buildInfoCard(
                    context,
                    title: 'Resumen Financiero',
                    backgroundColor: _kPastelRose,
                    borderColor: _kInkRose,
                    children: [
                      _buildSummaryRow(
                        'Subtotal Productos:',
                        itemsSubtotal,
                        currencyFormat,
                        context: context,
                      ),
                      if (deliveryCost > 0)
                        _buildSummaryRow(
                          'Costo Envío:',
                          deliveryCost,
                          currencyFormat,
                          context: context,
                        ),
                      Divider(
                        indent: 16,
                        endIndent: 16,
                        height: 8,
                        thickness: 1,
                        color: cs.outlineVariant,
                      ),
                      _buildSummaryRow(
                        'TOTAL PEDIDO:',
                        total,
                        currencyFormat,
                        isTotal: true,
                        context: context,
                      ),
                      if (deposit > 0)
                        _buildSummaryRow(
                          'Seña Recibida:',
                          deposit,
                          currencyFormat,
                          context: context,
                        ),
                      Divider(
                        indent: 16,
                        endIndent: 16,
                        height: 8,
                        thickness: 1,
                        color: cs.outlineVariant,
                      ),
                      _buildSummaryRow(
                        'SALDO PENDIENTE:',
                        balance,
                        currencyFormat,
                        isTotal: true,
                        highlight: balance > 0,
                        context: context,
                      ),
                      if (canEdit && balance > 0.01) ...[
                        const SizedBox(height: 16),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16.0),
                          child: SizedBox(
                            width: double.infinity,
                            child: FilledButton.icon(
                              icon: const Icon(Icons.price_check, size: 18),
                              label: const Text(
                                'Marcar como Pagado Totalmente',
                              ),
                              // --- ADAPTADO AL TEMA ---
                              style: FilledButton.styleFrom(
                                backgroundColor: const Color(
                                  0xFF1E8E3E,
                                ), // Verde
                                foregroundColor: Colors.white,
                              ),
                              // --- FIN ---
                              onPressed: () {
                                _handleMarkAsPaid(context, ref, order);
                              },
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                      ],
                    ],
                  ),

                  // --- Card Notas Generales ---
                  if (order.notes != null && order.notes!.isNotEmpty)
                    _buildInfoCard(
                      context,
                      title: 'Notas Generales',
                      backgroundColor: _kPastelRose,
                      borderColor: _kInkRose,
                      children: [
                        Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Text(
                            order.notes!,
                            style: TextStyle(
                              fontSize: 15,
                              // --- ADAPTADO AL TEMA ---
                              color: cs.onSurfaceVariant,
                              // --- FIN ---
                            ),
                          ),
                        ),
                      ],
                    ),

                  // --- BOTÓN DE ELIMINAR PEDIDO ---
                  if (canEdit) ...[
                    const SizedBox(height: 16),
                    Divider(color: cs.outline),
                    const SizedBox(height: 16),
                    Center(
                      child: OutlinedButton.icon(
                        // --- ADAPTADO AL TEMA ---
                        icon: Icon(
                          Icons.delete_forever_outlined,
                          color: cs.error,
                        ),
                        label: Text(
                          'Eliminar Pedido',
                          style: TextStyle(color: cs.error),
                        ),
                        style: OutlinedButton.styleFrom(
                          side: BorderSide(color: cs.error.withOpacity(0.5)),
                        ),
                        // --- FIN ---
                        onPressed: () {
                          _showDeleteConfirmationDialog(context, ref, order);
                        },
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  // ===============================================================
  // === WIDGETS HELPER (MOVIDOS FUERA DEL BUILD PARA CLARIDAD) ====
  // ===============================================================

  /// --- NUEVO WIDGET: Helper para la Dirección de Entrega ---
  Widget _buildDeliveryAddressTile(BuildContext context, Order order) {
    final ClientAddress? address = order.clientAddress;

    // Si no hay dirección (es null)
    if (address == null) {
      // Si el costo de envío es 0, asumimos que retira en local
      if ((order.deliveryCost ?? 0) == 0) {
        return _buildInfoTile(
          context,
          Icons.storefront_outlined,
          'Entrega',
          'Retira en local',
        );
      }
      // Si hay costo de envío pero no hay dirección, es un dato faltante
      return _buildInfoTile(
        context,
        Icons.location_off_outlined,
        'Dirección',
        'No especificada (pero con envío)',
      );
    }

    // Si SÍ hay dirección
    return _buildInfoTile(
      context,
      Icons.location_on_outlined,
      'Dirección de Entrega',
      address
          .displayAddress, // Usamos el getter! (Ej: "Casa" o "Av. 9 de Julio 123")
      trailing: IconButton(
        icon: Icon(
          Icons.map_outlined,
          color: Theme.of(context).colorScheme.primary, // Color del tema
        ),
        tooltip: 'Ver en Google Maps',
        onPressed: () => _handleMapsLaunch(address),
      ),
    );
  }

  /// --- NUEVO HELPER: Lógica para abrir Google Maps (CORREGIDO) ---
  void _handleMapsLaunch(ClientAddress address) {
    // Prioridad 1: Usar coordenadas si existen
    if (address.latitude != null && address.longitude != null) {
      // --- CORRECCIÓN AQUÍ ---
      // Creamos un string de consulta con lat,lon
      final query = '${address.latitude},${address.longitude}';
      // Usamos la función que SÍ existe
      launchGoogleMaps(query);
      return;
    }
    // Prioridad 2: Usar la URL de Google Maps si existe
    if (address.googleMapsUrl != null && address.googleMapsUrl!.isNotEmpty) {
      launchExternalUrl(address.googleMapsUrl!);
      return;
    }
    // Prioridad 3: Buscar por la dirección de texto
    if (address.addressLine1 != null && address.addressLine1!.isNotEmpty) {
      // --- CORRECCIÓN AQUÍ ---
      // Usamos la función que SÍ existe
      launchGoogleMaps(address.addressLine1!);
      return;
    }
    // No hay nada que abrir
  }

  // --- Helper para construir la Card principal ---
  Widget _buildInfoCard(
    BuildContext context, {
    String? title,
    required List<Widget> children,
    required Color backgroundColor,
    required Color borderColor,
  }) {
    // --- ADAPTADO AL TEMA ---
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final isDarkMode = theme.brightness == Brightness.dark;

    final Color cardColor = isDarkMode ? cs.surface : backgroundColor;
    final Color titleColor = isDarkMode ? cs.onSurface : Colors.black87;
    final BorderSide border = isDarkMode
        ? BorderSide(color: borderColor, width: 3.0) // Borde grueso en dark
        : BorderSide(
            color: borderColor.withAlpha(77),
            width: 1,
          ); // Borde sutil en light
    // --- FIN ---

    return Card(
      elevation: isDarkMode ? 0 : 0.5,
      margin: const EdgeInsets.only(bottom: 16),
      color: cardColor, // Color adaptado
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: border, // Borde adaptado
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (title != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: Text(
                title,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: titleColor, // Color adaptado
                ),
              ),
            ),
          if (title != null)
            Divider(
              indent: 16,
              endIndent: 16,
              thickness: 0.5,
              height: 1,
              color: isDarkMode
                  ? cs.outlineVariant
                  : borderColor.withAlpha(77), // Color adaptado
            ),
          Padding(
            padding: EdgeInsets.only(bottom: title != null ? 8.0 : 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: children,
            ),
          ),
        ],
      ),
    );
  }

  // --- Helper para filas de detalle ---
  Widget _buildInfoTile(
    BuildContext context,
    IconData icon,
    String title,
    String subtitle, {
    Widget? trailing,
    VoidCallback? onTap, // Añadido para hacerla clickeable
  }) {
    // --- ADAPTADO AL TEMA ---
    final cs = Theme.of(context).colorScheme;
    final primaryTextColor = cs.onSurface;
    final secondaryTextColor = cs.onSurfaceVariant;
    // --- FIN ---

    return ListTile(
      leading: Icon(
        icon,
        color: secondaryTextColor, // Color adaptado
        size: 26,
      ),
      title: Text(
        title,
        style: TextStyle(
          fontWeight: FontWeight.w600,
          color: primaryTextColor, // Color adaptado
        ),
      ),
      subtitle: Text(
        subtitle,
        style: TextStyle(
          fontSize: 15,
          color: secondaryTextColor, // Color adaptado
        ),
      ),
      trailing: trailing,
      dense: true,
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 0),
    );
  }

  // --- Helper para construir los detalles del Item ---
  List<Widget> _buildItemDetails(
    OrderItem item,
    ProductCategory? category,
    NumberFormat currencyFormat,
    BuildContext context,
  ) {
    // (Tu lógica de _buildItemDetails se mantiene intacta,
    // solo se asegura de pasar 'context' a _buildDetailRow)
    final List<Widget> details = [];
    final custom = item.customizationJson ?? {};

    // 🔧 Mostrar precio solo si no es Box y queremos detallar los ajustes
    if (category != ProductCategory.box &&
        category != ProductCategory.mesaDulce &&
        category != ProductCategory.torta) {
      if (item.adjustments != 0) {
        details.add(
          _buildDetailRow(
            context,
            'Ajuste:',
            currencyFormat.format(item.adjustments),
            highlight: item.adjustments > 0
                ? const Color(0xFF1E8E3E)
                : accentRed,
          ),
        );
      }

      // Precio final unitario (solo si no es box)
      details.add(
        _buildDetailRow(
          context,
          'Precio Unitario:',
          currencyFormat.format(item.finalUnitPrice),
          isSubTotal: true,
        ),
      );
    }

    if (item.customizationNotes != null &&
        item.customizationNotes!.isNotEmpty) {
      details.add(
        _buildDetailRow(
          context,
          'Notas de Ajuste:',
          item.customizationNotes!,
          isNote: true,
        ),
      );
    }

    switch (category) {
      case ProductCategory.torta:
        if (custom['weight_kg'] != null) {
          details.add(
            _buildDetailRow(context, 'Peso:', '${custom['weight_kg']} kg'),
          );
        }
        if (custom['cake_type'] != null && custom['cake_type'] != item.name) {
          details.add(
            _buildDetailRow(context, 'Tipo:', '${custom['cake_type']}'),
          );
        }
        final List<String> fillings = List<String>.from(
          custom['selected_fillings'] ?? [],
        );
        final List<String> extraFillings = List<String>.from(
          custom['selected_extra_fillings'] ?? [],
        );
        if (fillings.isNotEmpty) {
          details.add(
            _buildDetailRow(
              context,
              'Rellenos:',
              fillings.join(', '),
              isList: true,
            ),
          );
        }
        if (extraFillings.isNotEmpty) {
          details.add(
            _buildDetailRow(
              context,
              'Rellenos Extra:',
              extraFillings.join(', '),
              isList: true,
            ),
          );
        }
        final List<String> extrasKg = List<String>.from(
          custom['selected_extras_kg'] ?? [],
        );
        final List<dynamic> extrasUnitRaw =
            custom['selected_extras_unit'] ?? [];
        final List<Map> extrasUnitData = extrasUnitRaw
            .whereType<Map>()
            .toList();
        if (extrasKg.isNotEmpty) {
          details.add(
            _buildDetailRow(
              context,
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
            _buildDetailRow(
              context,
              'Extras (x unidad):',
              unitExtrasText,
              isList: true,
            ),
          );
        }
        break;
      case ProductCategory.mesaDulce:
        if (custom['selected_size'] != null) {
          details.add(
            _buildDetailRow(
              context,
              'Tamaño:',
              getUnitText(ProductUnit.values.byName(custom['selected_size'])),
            ),
          );
        }
        if (custom['is_half_dozen'] == true) {
          details.add(
            _buildDetailRow(context, 'Presentación:', 'Media Docena'),
          );
        }
        break;
      case ProductCategory.box:
        final String? boxType = custom['box_type'];

        // 💰 Mostrar solo el precio total del Box (unitario × cantidad)
        details.add(
          _buildDetailRow(
            context,
            'Precio Box:',
            currencyFormat.format(item.finalUnitPrice * item.qty),
            isSubTotal: true,
          ),
        );

        // 🏷️ Tipo de Box
        if (boxType != null) {
          details.add(_buildDetailRow(context, 'Tipo de Box:', boxType));
        }

        // 🎂 Rellenos (si hay torta base en el box)
        final List<String> fillings = List<String>.from(
          custom['selected_fillings'] ?? [],
        );
        final List<String> extraFillings = List<String>.from(
          custom['selected_extra_fillings'] ?? [],
        );

        if (fillings.isNotEmpty) {
          details.add(
            _buildDetailRow(
              context,
              'Rellenos:',
              fillings.join(', '),
              isList: true,
            ),
          );
        }
        if (extraFillings.isNotEmpty) {
          details.add(
            _buildDetailRow(
              context,
              'Rellenos Extra:',
              extraFillings.join(', '),
              isList: true,
            ),
          );
        }

        // 🍓 Extras (por kg o unidad)
        final List<String> extrasKg = List<String>.from(
          custom['selected_extras_kg'] ?? [],
        );
        final List<Map<String, dynamic>> extrasUnit =
            (custom['selected_extras_unit'] as List?)
                ?.whereType<Map<String, dynamic>>()
                .toList() ??
            [];

        if (extrasKg.isNotEmpty) {
          details.add(
            _buildDetailRow(
              context,
              'Extras (x kg):',
              extrasKg.join(', '),
              isList: true,
            ),
          );
        }

        if (extrasUnit.isNotEmpty) {
          final unitExtrasText = extrasUnit
              .map((e) => '${e['name']} (x${e['quantity']})')
              .join(', ');
          details.add(
            _buildDetailRow(
              context,
              'Extras (x unidad):',
              unitExtrasText,
              isList: true,
            ),
          );
        }

        // 🍰 Mesa dulce
        final List<Map<String, dynamic>> mesaDulceItems =
            (custom['selected_mesa_dulce_items'] as List?)
                ?.whereType<Map<String, dynamic>>()
                .toList() ??
            [];
        if (mesaDulceItems.isNotEmpty) {
          final mesaItemsText = mesaDulceItems
              .map((e) {
                final name = e['name'];
                final qty = e['quantity'];
                final size = e['selected_size'];
                return size != null ? '$name ($size) x$qty' : '$name x$qty';
              })
              .join(', ');
          details.add(
            _buildDetailRow(
              context,
              'Mesa Dulce:',
              mesaItemsText,
              isList: true,
            ),
          );
        }

        // 📝 Notas del Box
        final itemNotes = custom['item_notes'] as String?;
        if (itemNotes != null && itemNotes.isNotEmpty) {
          details.add(
            _buildDetailRow(context, 'Notas del Box:', itemNotes, isNote: true),
          );
        }

        break;

      default:
        break;
    }

    final itemNotes = custom['item_notes'] as String?;
    if (itemNotes != null && itemNotes.isNotEmpty) {
      details.add(const SizedBox(height: 4));
      details.add(
        _buildDetailRow(context, 'Notas Item:', itemNotes, isNote: true),
      );
    }

    return details;
  }

  // --- Helper para la fila de detalle de item ---
  Widget _buildDetailRow(
    BuildContext context,
    String label,
    String value, {
    bool isList = false,
    bool isNote = false,
    bool isSubTotal = false,
    Color? highlight,
  }) {
    // --- ADAPTADO AL TEMA ---
    final cs = Theme.of(context).colorScheme;
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    final labelColor = cs.onSurfaceVariant;
    final valueColor = isSubTotal ? cs.onSurface : cs.onSurfaceVariant;

    // Chip
    final chipBg = isDarkMode ? cs.secondaryContainer : darkBrown.withAlpha(26);
    final chipFg = isDarkMode ? cs.onSecondaryContainer : cs.onSurface;
    final chipBorder = isDarkMode ? cs.outlineVariant : darkBrown.withAlpha(51);
    // --- FIN ---

    return Padding(
      padding: const EdgeInsets.only(top: 4.0),
      child: Row(
        crossAxisAlignment: isList || isNote
            ? CrossAxisAlignment.start
            : CrossAxisAlignment.center,
        children: [
          Text(
            '$label ',
            style: TextStyle(color: labelColor, fontWeight: FontWeight.normal),
          ),
          Expanded(
            child: isList
                ? Wrap(
                    spacing: 6.0,
                    runSpacing: 4.0,
                    children: value
                        .split(',')
                        .where((s) => s.trim().isNotEmpty)
                        .map(
                          (e) => Chip(
                            label: Text(e.trim()),
                            visualDensity: VisualDensity.compact,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 4,
                              vertical: 0,
                            ),
                            backgroundColor: chipBg,
                            labelStyle: TextStyle(fontSize: 12, color: chipFg),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(6),
                              side: BorderSide(color: chipBorder),
                            ),
                          ),
                        )
                        .toList(),
                  )
                : Text(
                    value,
                    style: TextStyle(
                      color:
                          highlight ?? (isSubTotal ? cs.onSurface : valueColor),
                      fontStyle: isNote ? FontStyle.italic : FontStyle.normal,
                      fontWeight: isSubTotal
                          ? FontWeight.bold
                          : FontWeight.normal,
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  // --- Helper para fila del resumen financiero ---
  Widget _buildSummaryRow(
    String label,
    double amount,
    NumberFormat currencyFormat, {
    bool isTotal = false,
    bool highlight = false,
    required BuildContext context,
  }) {
    // --- ADAPTADO AL TEMA ---
    final cs = Theme.of(context).colorScheme;
    final mainTextColor = cs.onSurface;
    final secondaryTextColor = cs.onSurfaceVariant;
    // --- FIN ---

    final formattedAmount = currencyFormat.format(
      label == 'Seña Recibida:' ? amount.abs() : amount,
    );
    final sign = label == 'Seña Recibida:' ? '-' : '';

    // --- ADAPTADO AL TEMA ---
    final style = TextStyle(
      fontSize: isTotal ? 16 : 14,
      fontWeight: isTotal ? FontWeight.bold : FontWeight.normal,
      color: highlight
          ? cs.error
          : (isTotal ? mainTextColor : secondaryTextColor),
    );
    // --- FIN ---

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0, horizontal: 16.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: style),
          Text('$sign$formattedAmount', style: style),
        ],
      ),
    );
  }

  // --- _showImageDialog (Adaptado al tema) ---
  void _showImageDialog(BuildContext context, String imageUrl) {
    final cs = Theme.of(context).colorScheme;

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          insetPadding: const EdgeInsets.symmetric(
            horizontal: 20,
            vertical: 40,
          ),
          backgroundColor: cs.surface, // ADAPTADO
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Expanded(
                child: InteractiveViewer(
                  panEnabled: true,
                  minScale: 0.5,
                  maxScale: 4.0,
                  child: Hero(
                    tag: imageUrl,
                    child: Image.network(
                      imageUrl,
                      fit: BoxFit.contain,
                      loadingBuilder: (context, child, loadingProgress) {
                        if (loadingProgress == null) return child;
                        return Center(
                          child: CircularProgressIndicator(
                            value: loadingProgress.expectedTotalBytes != null
                                ? loadingProgress.cumulativeBytesLoaded /
                                      loadingProgress.expectedTotalBytes!
                                : null,
                            color: cs.primary,
                          ),
                        );
                      },
                      errorBuilder: (context, error, stackTrace) => Center(
                        child: Icon(
                          Icons.broken_image,
                          color: cs.onSurfaceVariant,
                          size: 50,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              TextButton(
                child: Text("Cerrar", style: TextStyle(color: cs.primary)),
                onPressed: () {
                  Navigator.of(context).pop();
                },
              ),
              const SizedBox(height: 10),
            ],
          ),
        );
      },
    );
  }

  // --- _handleMarkAsPaid (Adaptado al tema) ---
  Future<void> _handleMarkAsPaid(
    BuildContext context,
    WidgetRef ref,
    Order order,
  ) async {
    // --- ADAPTADO AL TEMA ---
    final cs = Theme.of(context).colorScheme;
    // --- FIN ---

    final bool confirm =
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
                // --- ADAPTADO AL TEMA ---
                // Usa el color primario del tema (Marrón/Rosa)
                style: FilledButton.styleFrom(
                  backgroundColor: cs.primary,
                  foregroundColor: cs.onPrimary,
                ),
                // --- FIN ---
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Confirmar'),
              ),
            ],
          ),
        ) ??
        false;

    if (confirm) {
      try {
        // 1. Capturamos la orden actualizada (CORREGIDO A Order?)
        final Order? updatedOrder = await ref
            .read(ordersRepoProvider)
            .markAsPaid(order.id);

        // 2. 🔥 CHEQUEAMOS SI NO ES NULLA ANTES DE ACTUALIZAR
        if (updatedOrder != null) {
          await ref
              .read(ordersWindowProvider.notifier)
              .updateOrder(updatedOrder);
        }

        // 3. Invalida solo la página actual (esto refrescará desde la API de todos modos)
        ref.invalidate(orderByIdProvider(order.id));

        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Pedido marcado como pagado.')),
        );
      } catch (e) {
        if (!context.mounted) return;
        // --- 👇 CORRECCIÓN SNACKBAR ( foregroundColor -> style ) 👇 ---
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Error al marcar como pagado: $e',
              style: TextStyle(color: cs.onError),
            ),
            backgroundColor: cs.error,
          ),
        );
      }
    }
  }

  // --- _handleChangeStatus (Adaptado al tema) ---
  Future<void> _handleChangeStatus(
    BuildContext context,
    WidgetRef ref,
    Order order,
    String newStatus,
  ) async {
    // --- ADAPTADO AL TEMA ---
    final cs = Theme.of(context).colorScheme;
    // --- FIN ---

    try {
      // 1. Capturamos la orden actualizada
      // (Tu repo devuelve Order? pero updateOrderStatus en el Notifier también lo hace)
      // (Asumimos que updateStatus no devuelve null si tiene éxito)
      final Order? updatedOrder = await ref
          .read(ordersRepoProvider)
          .updateStatus(order.id, newStatus);

      if (updatedOrder != null) {
        // 2. 🔥 ACTUALIZA LA LISTA LOCAL (en vez de invalidate)
        await ref.read(ordersWindowProvider.notifier).updateOrder(updatedOrder);
      }

      // 3. Invalida solo la página actual
      ref.invalidate(orderByIdProvider(order.id));

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Estado actualizado.'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        // --- 👇 CORRECCIÓN SNACKBAR ( foregroundColor -> style ) 👇 ---
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Error al actualizar estado: $e',
              style: TextStyle(color: cs.onError),
            ),
            backgroundColor: cs.error,
          ),
        );
        // --- 👆 FIN CORRECCIÓN 👆 ---
      }
      // Revertir el cambio visual en caso de error
      ref.invalidate(orderByIdProvider(order.id));
    }
  }

  // --- Diálogo Confirmar Eliminación (Adaptado al tema) ---
  void _showDeleteConfirmationDialog(
    BuildContext context,
    WidgetRef ref,
    Order order,
  ) {
    // --- ADAPTADO AL TEMA ---
    final cs = Theme.of(context).colorScheme;
    // --- FIN ---

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        // Usamos un StateProvider local para el estado de carga del diálogo
        final isDeletingProvider = StateProvider<bool>((_) => false);

        return Consumer(
          builder: (context, ref, child) {
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
                  // --- ADAPTADO AL TEMA ---
                  child: Text(
                    'Cancelar',
                    style: TextStyle(color: cs.onSurfaceVariant),
                  ),
                  // --- FIN ---
                ),
                FilledButton.icon(
                  icon: isDeleting
                      ? SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            // --- ADAPTADO AL TEMA ---
                            color: cs.onError,
                            // --- FIN ---
                          ),
                        )
                      : const Icon(Icons.warning_amber),
                  label: Text(
                    isDeleting ? 'Eliminando...' : 'Eliminar Definitivamente',
                  ),
                  // --- ADAPTADO AL TEMA ---
                  style: FilledButton.styleFrom(
                    backgroundColor: cs.error,
                    foregroundColor: cs.onError,
                    disabledBackgroundColor: cs.error.withOpacity(0.5),
                  ),
                  // --- FIN ---
                  onPressed: isDeleting
                      ? null
                      : () async {
                          ref.read(isDeletingProvider.notifier).state = true;
                          try {
                            await ref
                                .read(ordersRepoProvider)
                                .deleteOrder(order.id);
                            if (context.mounted) {
                              Navigator.of(context).pop(); // Cierra el diálogo
                              // --- ADAPTADO AL TEMA ---
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Pedido eliminado con éxito.'),
                                  // Deja que el tema decida el color
                                ),
                              );
                              // --- FIN ---
                              ref.invalidate(
                                ordersWindowProvider,
                              ); // Refresca la home
                              context.go('/'); // Vuelve a la home
                            }
                          } catch (e) {
                            if (context.mounted) {
                              Navigator.of(context).pop(); // Cierra el diálogo
                              // --- 👇 CORRECCIÓN SNACKBAR ( foregroundColor -> style ) 👇 ---
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    'Error al eliminar: $e',
                                    style: TextStyle(color: cs.onError),
                                  ),
                                  backgroundColor: cs.error,
                                ),
                              );
                              // --- 👆 FIN CORRECCIÓN 👆 ---
                            }
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
} // Fin OrderDetailPage
