import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:pasteleria_180_flutter/core/models/client.dart';
import 'package:pasteleria_180_flutter/core/models/client_address.dart';
import 'package:pasteleria_180_flutter/feature/clients/address_form_dialog.dart';

// Repositorios
import 'package:pasteleria_180_flutter/core/models/order.dart';
import 'package:pasteleria_180_flutter/feature/orders/orders_repository.dart';
import 'package:pasteleria_180_flutter/feature/clients/clients_repository.dart';

// Utils
import 'package:pasteleria_180_flutter/core/utils/launcher_utils.dart';
import 'package:intl/intl.dart';

class ClientDetailPage extends ConsumerWidget {
  final int id;
  const ClientDetailPage({super.key, required this.id});

  // --- Funciones para manejar Direcciones ---

  // Muestra el modal para Añadir/Editar dirección
  void _showAddressForm(
    BuildContext context,
    WidgetRef ref,
    int clientId, {
    ClientAddress? addressToEdit, // Si es null, es "Crear"
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom,
          ),
          child: AddressFormDialog(
            clientId: clientId,
            addressToEdit: addressToEdit,
          ),
        );
      },
    );
  }

  // Muestra confirmación para eliminar dirección
  Future<void> _confirmDeleteAddress(
    BuildContext context,
    WidgetRef ref,
    ClientAddress address,
  ) async {
    // Obtenemos el ColorScheme aquí ANTES de llamar a showDialog
    // para evitar problemas de contexto asíncrono.
    final cs = Theme.of(context).colorScheme;

    final didConfirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirmar Eliminación'),
        content: Text(
          '¿Seguro que quieres eliminar la dirección "${address.displayAddress}"?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            // Adaptado al tema: usa el color de error del tema
            style: FilledButton.styleFrom(
              backgroundColor: cs.error,
              foregroundColor:
                  cs.onError, // <-- Esta línea SÍ es correcta para FilledButton
            ),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );

    if (didConfirm == true) {
      try {
        await ref
            .read(clientsRepoProvider)
            .deleteAddress(address.clientId, address.id);
        // Refrescar los detalles del cliente (para que se actualice la lista de direcciones)
        ref.invalidate(clientDetailsProvider(address.clientId));

        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Dirección eliminada'),
              // Dejamos que el SnackBarTheme del tema decida el color de éxito
            ),
          );
        }
      } on DioException catch (e) {
        if (!context.mounted) return;
        // Obtenemos el ColorScheme para los SnackBar de error
        final errorCs = Theme.of(context).colorScheme;

        if (e.response?.statusCode == 409) {
          // Error de conflicto (Dirección en uso)
          final message =
              e.response?.data['message'] as String? ??
              'Conflicto desconocido. La dirección podría estar asociada a un pedido.';
          _showAddressInUseDialog(context, message);
        } else {
          // Otro error de API
          final message =
              e.response?.data['message'] as String? ??
              'Error al eliminar dirección. Intenta de nuevo.';
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              // --- 👇 CORRECCIÓN AQUÍ 👇 ---
              content: Text(message, style: TextStyle(color: errorCs.onError)),
              backgroundColor: errorCs.error,
              // --- 👆 foregroundColor eliminado 👆 ---
            ),
          );
        }
      } catch (e) {
        // Error genérico (ej. sin conexión)
        if (!context.mounted) return;
        final errorCs = Theme.of(context).colorScheme;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            // --- 👇 CORRECCIÓN AQUÍ 👇 ---
            content: Text(
              'Error desconocido al eliminar.',
              style: TextStyle(color: errorCs.onError),
            ),
            backgroundColor: errorCs.error,
            // --- 👆 foregroundColor eliminado 👆 ---
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Obtenemos el tema y los esquemas de color/texto
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final tt = theme.textTheme;

    // Observamos el provider que busca el cliente por ID
    final asyncClient = ref.watch(clientDetailsProvider(id));

    return asyncClient.when(
      loading: () => Scaffold(
        appBar: AppBar(),
        body: Center(
          // El CircularProgressIndicator usará cs.primary por defecto
          child: CircularProgressIndicator(color: cs.primary),
        ),
      ),
      error: (err, stack) => Scaffold(
        appBar: AppBar(),
        body: Center(child: Text('Error al cargar cliente: $err')),
      ),
      data: (client) {
        if (client == null) {
          return Scaffold(
            appBar: AppBar(),
            body: const Center(child: Text('Cliente no encontrado')),
          );
        }

        // Si tenemos el cliente, construimos la página
        return Scaffold(
          appBar: AppBar(
            title: Text(client.name),
            // Colores de AppBar adaptados al tema (M3)
            backgroundColor: cs.surface,
            foregroundColor: cs.onSurface,
            elevation: 1,
            titleTextStyle: tt.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
              color: cs.onSurface, // Asegura el color del texto
            ),
            // Íconos de acción
            actionsIconTheme: IconThemeData(color: cs.onSurfaceVariant),
            actions: [
              // Botón "Editar" que lleva al formulario
              IconButton(
                icon: const Icon(Icons.edit_outlined),
                tooltip: 'Editar Cliente',
                onPressed: () => context.push('/clients/${client.id}/edit'),
              ),
            ],
          ),
          body: RefreshIndicator(
            onRefresh: () => ref.refresh(clientDetailsProvider(id).future),
            child: ListView(
              children: [
                // --- SECCIÓN DE DATOS DE CONTACTO ---
                _buildContactInfo(context, client),

                // --- SECCIÓN DE DIRECCIONES ---
                _buildAddressList(context, ref, client),

                // --- SECCIÓN HISTORIAL DE PEDIDOS ---
                _buildOrdersSection(context, client.id),
              ],
            ),
          ),
        );
      },
    );
  }

  /// Muestra un diálogo si la dirección está asociada a pedidos.
  /// (Este widget ya estaba bien adaptado al tema)
  void _showAddressInUseDialog(BuildContext context, String message) {
    final cs = Theme.of(context).colorScheme;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Dirección en Uso', style: TextStyle(color: cs.error)),
        content: Text(message),
        actions: [
          FilledButton.tonal(
            style: FilledButton.styleFrom(
              backgroundColor: cs.errorContainer,
              foregroundColor: cs.onErrorContainer,
            ),
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(
              'Entendido',
              style: TextStyle(color: cs.onErrorContainer),
            ),
          ),
        ],
      ),
    );
  }

  // Widget para la tarjeta de Contacto
  Widget _buildContactInfo(BuildContext context, Client client) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final tt = theme.textTheme;

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Información de Contacto',
            style: tt.titleMedium?.copyWith(
              // Color de subtítulo del tema
              color: cs.onSurfaceVariant,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          // Tarjeta de Contacto
          Card(
            elevation: 1,
            margin: EdgeInsets.zero,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            clipBehavior: Clip.antiAlias,
            child: Column(
              children: [
                // Teléfono y WhatsApp
                ListTile(
                  // Icono con color primario del tema
                  leading: Icon(Icons.phone, color: cs.primary),
                  title: Text(client.phone ?? 'Sin teléfono'),
                  trailing: (client.whatsappUrl != null)
                      ? IconButton(
                          icon: const FaIcon(
                            FontAwesomeIcons.whatsapp,
                            // El color de marca (WhatsApp) se puede mantener
                            color: Colors.green,
                          ),
                          tooltip: 'Chatear por WhatsApp',
                          onPressed: () =>
                              launchExternalUrl(client.whatsappUrl!),
                        )
                      : null,
                ),
                const Divider(height: 1, indent: 16, endIndent: 16),
                // Email
                ListTile(
                  leading: Icon(Icons.email_outlined, color: cs.primary),
                  title: Text(client.email ?? 'Sin email'),
                ),
                // Notas (si existen)
                if (client.notes != null && client.notes!.isNotEmpty) ...[
                  const Divider(height: 1, indent: 16, endIndent: 16),
                  ListTile(
                    leading: Icon(Icons.note_alt_outlined, color: cs.primary),
                    title: Text(client.notes!),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Widget para la lista de Direcciones
  Widget _buildAddressList(BuildContext context, WidgetRef ref, Client client) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final tt = theme.textTheme;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Direcciones',
                style: tt.titleMedium?.copyWith(
                  color: cs.onSurfaceVariant,
                  fontWeight: FontWeight.bold,
                ),
              ),
              FilledButton.tonalIcon(
                onPressed: () => _showAddressForm(context, ref, client.id),
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Añadir'),
                // El estilo por defecto de .tonalIcon ya se adapta al tema
                // (usa secondaryContainer y onSecondaryContainer)
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Si no hay direcciones
          if (client.addresses.isEmpty)
            Card(
              elevation: 1,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Padding(
                padding: EdgeInsets.all(16.0),
                child: Center(
                  child: Text('Este cliente no tiene direcciones guardadas.'),
                ),
              ),
            ),

          // Si hay direcciones, las listamos
          ...client.addresses.map((address) {
            return Card(
              elevation: 1,
              margin: const EdgeInsets.only(bottom: 8),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              clipBehavior: Clip.antiAlias,
              child: ListTile(
                leading: Icon(Icons.location_on_outlined, color: cs.primary),
                title: Text(
                  address.label ?? address.addressLine1 ?? 'Dirección',
                ),
                subtitle: Text(
                  address.label != null
                      ? address.addressLine1 ?? ''
                      : address.notes ?? '',
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Botón Google Maps (Color de marca)
                    if (address.googleMapsUrl != null)
                      IconButton(
                        icon: const Icon(
                          Icons.map_outlined,
                          color: Colors.blue, // Mantenemos color de marca
                        ),
                        tooltip: 'Ver en Google Maps',
                        onPressed: () =>
                            launchExternalUrl(address.googleMapsUrl!),
                      ),
                    // Botón Editar Dirección
                    IconButton(
                      icon: Icon(
                        Icons.edit_outlined,
                        // Color neutral del tema para íconos
                        color: cs.onSurfaceVariant,
                        size: 20,
                      ),
                      tooltip: 'Editar Dirección',
                      onPressed: () => _showAddressForm(
                        context,
                        ref,
                        client.id,
                        addressToEdit: address,
                      ),
                    ),
                    // Botón Eliminar Dirección
                    IconButton(
                      icon: Icon(
                        Icons.delete_outline,
                        // Color de error del tema
                        color: cs.error,
                        size: 20,
                      ),
                      tooltip: 'Eliminar Dirección',
                      onPressed: () =>
                          _confirmDeleteAddress(context, ref, address),
                    ),
                  ],
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  // Widget para la sección de Historial de Pedidos
  Widget _buildOrdersSection(BuildContext context, int clientId) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final tt = theme.textTheme;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Historial de Pedidos',
            style: tt.titleMedium?.copyWith(
              color: cs.onSurfaceVariant,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          _buildOrdersList(clientId), // Widget interno
        ],
      ),
    );
  }

  /// Widget interno para cargar y mostrar la lista de pedidos
  Widget _buildOrdersList(int clientId) {
    // Usamos un Consumer para poder usar 'ref' aquí
    return Consumer(
      builder: (context, ref, child) {
        // Obtenemos el ColorScheme para la función helper
        final cs = Theme.of(context).colorScheme;
        final tt = Theme.of(context).textTheme;

        // Obtenemos el repositorio de Pedidos
        final repo = ref.watch(
          ordersRepoProvider,
        ); // Asumiendo que tienes este provider

        // Helper para traducir y dar color a los estados (AHORA USA EL TEMA)
        (String, Color) getStatusStyle(String status) {
          final statusLower = status.toLowerCase();
          // Colores del tema
          final Color deliveredColor = cs.primary; // Verde/Principal
          final Color pendingColor = cs.tertiary; // Naranja/Terciario
          final Color cancelledColor = cs.error; // Rojo/Error
          final Color defaultColor = cs.onSurfaceVariant; // Gris/Neutral

          switch (statusLower) {
            case 'pending':
              return ('Pendiente', pendingColor);
            case 'confirmed':
              return ('Confirmado', defaultColor);
            case 'delivered':
              return ('Entregado', deliveredColor);
            case 'cancelled':
              return ('Cancelado', cancelledColor);
            default:
              // Capitalizar el estado si no lo conocemos
              final capitalized = status.isNotEmpty
                  ? status[0].toUpperCase() + status.substring(1)
                  : 'Desconocido';
              return (capitalized, defaultColor);
          }
        }

        // NOTA: Esta API no es ideal. Deberíamos tener un endpoint
        // /clients/{id}/orders o /orders?client_id={id}
        // Pero mantenemos tu lógica original por ahora.
        return FutureBuilder<List<Order>>(
          future: repo.getOrders(
            from: DateTime.now().subtract(
              const Duration(days: 365 * 2),
            ), // 2 años
            to: DateTime.now().add(const Duration(days: 365)),
          ),
          builder: (ctx, snap) {
            if (snap.connectionState != ConnectionState.done) {
              return const Center(
                child: Padding(
                  padding: EdgeInsets.all(24.0),
                  // Usará el color primario del tema por defecto
                  child: CircularProgressIndicator(),
                ),
              );
            }
            if (snap.hasError) {
              return Center(child: Text('Error: ${snap.error}'));
            }

            final allOrders = snap.data ?? [];
            final clientOrders = allOrders
                .where((o) => o.clientId == clientId)
                .toList();

            if (clientOrders.isEmpty) {
              return const Card(
                elevation: 1,
                child: Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Center(
                    child: Text('Este cliente no tiene pedidos registrados.'),
                  ),
                ),
              );
            }

            // Si hay pedidos, los mostramos
            return Card(
              elevation: 1,
              margin: EdgeInsets.zero,
              clipBehavior: Clip.antiAlias,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: clientOrders.length,
                separatorBuilder: (context, index) =>
                    const Divider(height: 1, indent: 16, endIndent: 16),
                itemBuilder: (_, i) {
                  final o = clientOrders[i];

                  // Obtenemos el estilo del estado (ya adaptado al tema)
                  final statusStyle = getStatusStyle(o.status);

                  return ListTile(
                    title: Text(
                      'Pedido para: ${DateFormat('dd/MM/yyyy').format(o.eventDate)}',
                    ),
                    subtitle: Text(
                      'Estado: ${statusStyle.$1}', // Usamos el texto traducido
                      style: TextStyle(
                        color:
                            statusStyle.$2, // Usamos el color correspondiente
                      ),
                    ),
                    trailing: Text(
                      '\$${o.total?.toStringAsFixed(0) ?? '0'}',
                      style: tt.bodyLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: cs.primary, // Color primario para el total
                      ),
                    ),
                    onTap: () => context.push(
                      '/order/${o.id}',
                    ), // Ir al detalle del pedido
                  );
                },
              ),
            );
          },
        );
      },
    );
  }
}
