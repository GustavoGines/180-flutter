import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

// Repositorios
import 'package:pasteleria_180_flutter/core/models/order.dart';
import 'package:pasteleria_180_flutter/feature/orders/orders_repository.dart';

// Utils
import 'package:pasteleria_180_flutter/core/utils/launcher_utils.dart';
import 'package:pasteleria_180_flutter/feature/clients/client_form_page.dart';
import 'package:intl/intl.dart';

class ClientDetailPage extends ConsumerWidget {
  final int id;
  const ClientDetailPage({super.key, required this.id});

  // Colores (los mismos de new_order_page)
  static const Color darkBrown = Color(0xFF7A4A4A);
  static const Color primaryPink = Color(0xFFF8B6B6);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Observamos el provider que busca el cliente por ID
    final asyncClient = ref.watch(clientByIdProvider(id));

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
          body: ListView(
            children: [
              // --- SECCIÓN DE DATOS DE CONTACTO ---
              Padding(
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
                            leading: const Icon(
                              Icons.email_outlined,
                              color: darkBrown,
                            ),
                            title: Text(client.email ?? 'Sin email'),
                          ),
                          const Divider(height: 1, indent: 16, endIndent: 16),
                          // Dirección y Google Maps
                          ListTile(
                            leading: const Icon(
                              Icons.location_on_outlined,
                              color: darkBrown,
                            ),
                            title: Text(client.address ?? 'Sin dirección'),
                            trailing:
                                (client.address != null &&
                                    client.address!.isNotEmpty)
                                ? IconButton(
                                    icon: const Icon(
                                      Icons.map_outlined,
                                      color: Colors.blue,
                                    ),
                                    tooltip: 'Ver en Google Maps',
                                    onPressed: () =>
                                        launchGoogleMaps(client.address!),
                                  )
                                : null,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // --- SECCIÓN HISTORIAL DE PEDIDOS ---
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16.0,
                  vertical: 8.0,
                ),
                child: Text(
                  'Historial de Pedidos',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: darkBrown,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              // Reutilizamos la lógica del FutureBuilder que ya tenías
              // para cargar los pedidos de este cliente.
              _buildOrdersList(client.id),
            ],
          ),
        );
      },
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

        return FutureBuilder<List<Order>>(
          // Buscamos pedidos en un rango amplio.
          // Idealmente, la API debería soportar: /orders?client_id=:id
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
              return const Center(
                child: Padding(
                  padding: EdgeInsets.all(24.0),
                  child: Text('Este cliente no tiene pedidos registrados.'),
                ),
              );
            }

            // Si hay pedidos, los mostramos
            return ListView.builder(
              shrinkWrap:
                  true, // Para que funcione dentro del ListView principal
              physics: const NeverScrollableScrollPhysics(),
              itemCount: clientOrders.length,
              itemBuilder: (_, i) {
                final o = clientOrders[i];
                return ListTile(
                  title: Text(
                    'Pedido para: ${DateFormat('dd/MM/yyyy').format(o.eventDate)}',
                  ),
                  subtitle: Text(
                    'Estado: ${o.status}',
                    style: TextStyle(
                      color: o.status == 'delivered'
                          ? Colors.green
                          : Colors.orange,
                    ),
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
            );
          },
        );
      },
    );
  }
}
