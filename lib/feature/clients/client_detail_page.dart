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

  // Colores
  static const Color darkBrown = Color(0xFF7A4A4A);
  static const Color primaryPink = Color(0xFFF8B6B6);

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
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
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
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error al eliminar: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Observamos el provider que busca el cliente por ID
    final asyncClient = ref.watch(clientDetailsProvider(id));

    return asyncClient.when(
      loading: () => Scaffold(
        appBar: AppBar(),
        body: const Center(child: CircularProgressIndicator(color: darkBrown)),
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
            backgroundColor: Colors.white,
            elevation: 1,
            iconTheme: const IconThemeData(color: darkBrown),
            titleTextStyle: const TextStyle(
              color: darkBrown,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
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

  // Widget para la tarjeta de Contacto
  Widget _buildContactInfo(BuildContext context, Client client) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Información de Contacto',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: darkBrown,
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
                  leading: const Icon(Icons.phone, color: darkBrown),
                  title: Text(client.phone ?? 'Sin teléfono'),
                  trailing: (client.whatsappUrl != null)
                      ? IconButton(
                          icon: const FaIcon(
                            FontAwesomeIcons.whatsapp,
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
                  leading: const Icon(Icons.email_outlined, color: darkBrown),
                  title: Text(client.email ?? 'Sin email'),
                ),
                // Notas (si existen)
                if (client.notes != null && client.notes!.isNotEmpty) ...[
                  const Divider(height: 1, indent: 16, endIndent: 16),
                  ListTile(
                    leading: const Icon(
                      Icons.note_alt_outlined,
                      color: darkBrown,
                    ),
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
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: darkBrown,
                  fontWeight: FontWeight.bold,
                ),
              ),
              FilledButton.tonalIcon(
                // <-- CORRECCIÓN: De .tonal a .tonalIcon
                onPressed: () => _showAddressForm(context, ref, client.id),
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Añadir'),
                style: FilledButton.styleFrom(
                  backgroundColor: darkBrown.withOpacity(0.1),
                  foregroundColor: darkBrown,
                ),
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
                leading: const Icon(
                  Icons.location_on_outlined,
                  color: darkBrown,
                ),
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
                    // Botón Google Maps
                    if (address.googleMapsUrl != null)
                      IconButton(
                        icon: const Icon(
                          Icons.map_outlined,
                          color: Colors.blue,
                        ),
                        tooltip: 'Ver en Google Maps',
                        onPressed: () =>
                            launchExternalUrl(address.googleMapsUrl!),
                      ),
                    // Botón Editar Dirección
                    IconButton(
                      icon: const Icon(
                        Icons.edit_outlined,
                        color: Colors.grey,
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
                      icon: const Icon(
                        Icons.delete_outline,
                        color: Colors.red,
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
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Historial de Pedidos',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: darkBrown,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          _buildOrdersList(clientId), // Widget interno que ya tenías
        ],
      ),
    );
  }

  /// Widget interno para cargar y mostrar la lista de pedidos
  Widget _buildOrdersList(int clientId) {
    // Usamos un Consumer para poder usar 'ref' aquí
    return Consumer(
      builder: (context, ref, child) {
        // Obtenemos el repositorio de Pedidos
        final repo = ref.watch(
          ordersRepoProvider,
        ); // Asumiendo que tienes este provider

        // --- INICIO DE LA MODIFICACIÓN ---

        // Helper para traducir y dar color a los estados
        (String, Color) getStatusStyle(String status) {
          final statusLower = status.toLowerCase();
          final Color deliveredColor = Colors.green.shade700;
          final Color pendingColor = Colors.orange.shade700;
          final Color cancelledColor = Colors.red.shade700;
          final Color defaultColor = Colors.grey.shade600;

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
        // --- FIN DE LA MODIFICACIÓN ---

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
                  child: CircularProgressIndicator(color: darkBrown),
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

                  // --- INICIO DE LA MODIFICACIÓN ---
                  final statusStyle = getStatusStyle(o.status);
                  // --- FIN DE LA MODIFICACIÓN ---

                  return ListTile(
                    title: Text(
                      'Pedido para: ${DateFormat('dd/MM/yyyy').format(o.eventDate)}',
                    ),
                    subtitle: Text(
                      // --- INICIO DE LA MODIFICACIÓN ---
                      'Estado: ${statusStyle.$1}', // Usamos el texto traducido
                      style: TextStyle(
                        color:
                            statusStyle.$2, // Usamos el color correspondiente
                      ),
                      // --- FIN DE LA MODIFICACIÓN ---
                    ),
                    trailing: Text(
                      '\$${o.total?.toStringAsFixed(0) ?? '0'}',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: darkBrown,
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
