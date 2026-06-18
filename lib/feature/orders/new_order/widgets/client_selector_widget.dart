import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_typeahead/flutter_typeahead.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:flutter_speed_dial/flutter_speed_dial.dart';

import 'package:pasteleria_180_flutter/core/models/client.dart';
import 'package:pasteleria_180_flutter/feature/clients/clients_repository.dart';
import '../new_order_controller.dart';

class ClientSelectorWidget extends ConsumerStatefulWidget {
  final VoidCallback onSelectFromContacts;
  final VoidCallback onAddManually;
  final Function(String) launchExternalUrl;

  const ClientSelectorWidget({
    super.key,
    required this.onSelectFromContacts,
    required this.onAddManually,
    required this.launchExternalUrl,
  });

  @override
  ConsumerState<ClientSelectorWidget> createState() => _ClientSelectorWidgetState();
}

class _ClientSelectorWidgetState extends ConsumerState<ClientSelectorWidget> {
  late TextEditingController _clientNameController;

  @override
  void initState() {
    super.initState();
    _clientNameController = TextEditingController();
    
    // Inicializar el controlador si hay un cliente en el estado (por ejemplo, en modo edición)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final state = ref.read(newOrderControllerProvider);
      if (state.selectedClient != null) {
        _clientNameController.text = state.selectedClient!.name;
      } else if (state.prefillClientName.isNotEmpty) {
        _clientNameController.text = state.prefillClientName;
      }
    });
  }

  @override
  void dispose() {
    _clientNameController.dispose();
    super.dispose();
  }

  void _clearClient() {
    ref.read(newOrderControllerProvider.notifier).updateClient(null);
    _clientNameController.clear();
  }

  void _selectClient(Client client) {
    ref.read(newOrderControllerProvider.notifier).updateClient(client);
    _clientNameController.text = client.name;
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(newOrderControllerProvider);
    final selectedClient = state.selectedClient;

    ref.listen<NewOrderState>(newOrderControllerProvider, (previous, next) {
      if (next.prefillClientName.isNotEmpty &&
          next.selectedClient == null &&
          _clientNameController.text != next.prefillClientName) {
        _clientNameController.text = next.prefillClientName;
      }
    });

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (selectedClient == null) ...[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: TypeAheadField<Client>(
                  controller: _clientNameController,
                  debounceDuration: const Duration(milliseconds: 500),
                  suggestionsCallback: (pattern) async {
                    if (selectedClient != null) {
                      _clearClient();
                    }
                    return ref.read(clientsListProvider(pattern).future);
                  },
                  itemBuilder: (context, client) => ListTile(
                    leading: const Icon(Icons.person),
                    title: Text(client.name),
                    subtitle: Text(client.phone ?? 'Sin teléfono'),
                  ),
                  onSelected: _selectClient,
                  emptyBuilder: (context) => const Padding(
                    padding: EdgeInsets.all(12.0),
                    child: Text('No se encontraron clientes.'),
                  ),
                  builder: (context, controller, focusNode) => TextFormField(
                    controller: controller,
                    focusNode: focusNode,
                    decoration: const InputDecoration(
                      labelText: 'Buscar cliente...',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.search),
                    ),
                    validator: (value) {
                      if (selectedClient == null) {
                        return 'Debes seleccionar un cliente.';
                      }
                      return null;
                    },
                  ),
                ),
              ),
              const SizedBox(width: 8),
              SpeedDial(
                icon: Icons.add,
                activeIcon: Icons.close,
                foregroundColor: Theme.of(context).colorScheme.onPrimary,
                spacing: 5,
                buttonSize: const Size(56, 56),
                childrenButtonSize: const Size(56, 56),
                direction: SpeedDialDirection.down,
                curve: Curves.easeInOut,
                children: [
                  SpeedDialChild(
                    child: const Icon(Icons.contact_phone_outlined),
                    label: 'Desde Contactos',
                    onTap: widget.onSelectFromContacts,
                  ),
                  SpeedDialChild(
                    child: const Icon(Icons.person_add_alt_1),
                    label: 'Nuevo Manualmente',
                    onTap: widget.onAddManually,
                  ),
                ],
              ),
            ],
          ),

        ] else
          Card(
            elevation: 0,
            color: Theme.of(context).colorScheme.tertiaryContainer,
            margin: EdgeInsets.zero,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(
                color: Theme.of(context).colorScheme.outlineVariant,
              ),
            ),
            child: ListTile(
              leading: Icon(
                Icons.person,
                color: Theme.of(context).colorScheme.onTertiaryContainer,
              ),
              title: Text(
                selectedClient.name,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.onTertiaryContainer,
                ),
              ),
              subtitle: Text(
                'Tel: ${selectedClient.phone ?? "N/A"}',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onTertiaryContainer.withValues(alpha: 0.8),
                ),
              ),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (selectedClient.whatsappUrl != null)
                    IconButton(
                      icon: const FaIcon(FontAwesomeIcons.whatsapp),
                      color: Colors.green,
                      tooltip: 'Chatear por WhatsApp',
                      onPressed: () {
                        widget.launchExternalUrl(selectedClient.whatsappUrl!);
                      },
                    ),
                  IconButton(
                    icon: Icon(
                      Icons.close,
                      color: Theme.of(context).colorScheme.onTertiaryContainer,
                    ),
                    tooltip: 'Quitar cliente',
                    onPressed: _clearClient,
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}
