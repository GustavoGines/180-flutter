import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pasteleria_180_flutter/core/models/client.dart';
import 'package:pasteleria_180_flutter/feature/clients/clients_repository.dart';

class DeliverySection extends ConsumerWidget {
  final Client selectedClient;
  final int? selectedAddressId;
  final ValueChanged<int?> onAddressSelected;
  final VoidCallback onAddAddress;

  const DeliverySection({
    super.key,
    required this.selectedClient,
    required this.selectedAddressId,
    required this.onAddressSelected,
    required this.onAddAddress,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncClientDetails = ref.watch(clientDetailsProvider(selectedClient.id));

    return asyncClientDetails.when(
      loading: () => Center(
        child: Padding(
          padding: const EdgeInsets.all(8.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
              const SizedBox(width: 16),
              Text(
                'Cargando direcciones...',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
      error: (err, stack) => Text(
        'Error al cargar direcciones: $err',
        style: TextStyle(color: Theme.of(context).colorScheme.onErrorContainer),
      ),
      data: (client) {
        final addresses = client?.addresses ?? [];

        // Asegurarse que el ID seleccionado sigue siendo válido
        int? validAddressId = selectedAddressId;
        if (validAddressId != null && !addresses.any((a) => a.id == validAddressId)) {
          validAddressId = null;
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            DropdownButtonFormField<int?>(
              initialValue: validAddressId,
              decoration: InputDecoration(
                labelText: 'Dirección de Entrega',
                border: const OutlineInputBorder(),
                prefixIcon: Icon(
                  Icons.location_on_outlined,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
              items: [
                const DropdownMenuItem(
                  value: null,
                  child: Text(
                    'Retira en local (o sin dirección)',
                    style: TextStyle(fontStyle: FontStyle.italic),
                  ),
                ),
                ...addresses.map((address) {
                  return DropdownMenuItem(
                    value: address.id,
                    child: Text(
                      address.displayAddress,
                      overflow: TextOverflow.ellipsis,
                    ),
                  );
                }),
              ],
              onChanged: onAddressSelected,
              validator: (value) => null,
            ),
            const SizedBox(height: 8),
            Center(
              child: TextButton.icon(
                icon: const Icon(Icons.add_location_alt_outlined, size: 20),
                label: const Text('Añadir nueva dirección al cliente'),
                style: TextButton.styleFrom(
                  foregroundColor: Theme.of(context).colorScheme.primary,
                ),
                onPressed: onAddAddress,
              ),
            ),
          ],
        );
      },
    );
  }
}
