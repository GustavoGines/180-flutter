import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:collection/collection.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:permission_handler/permission_handler.dart';

import 'package:pasteleria_180_flutter/core/utils/launcher_utils.dart';
import '../../core/models/client.dart';
import '../../core/models/order.dart';
import '../clients/clients_repository.dart';
import '../clients/address_form_dialog.dart';
import 'catalog_repository.dart';
import 'order_detail_page.dart';
import 'product_catalog.dart';

import 'new_order/new_order_controller.dart';
import 'new_order/widgets/date_time_picker_row.dart';
import 'new_order/widgets/delivery_section.dart';
import 'new_order/widgets/order_totals_card.dart';
import 'new_order/widgets/client_selector_widget.dart';
import 'new_order/widgets/order_items_section.dart';

class NewOrderPage extends ConsumerWidget {
  final int? orderId;
  const NewOrderPage({super.key, this.orderId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isEditMode = orderId != null;
    Color darkBrown = Theme.of(context).colorScheme.primary;

    final catalogAsync = ref.watch(catalogProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          isEditMode ? 'Editar Pedido' : 'Nuevo Pedido',
          style: TextStyle(color: Theme.of(context).colorScheme.primary),
        ),
        backgroundColor: Theme.of(context).colorScheme.surface,
        elevation: 1,
        iconTheme: IconThemeData(color: Theme.of(context).colorScheme.primary),
      ),
      body: catalogAsync.when(
        loading: () =>
            Center(child: CircularProgressIndicator(color: darkBrown)),
        error: (err, stack) =>
            Center(child: Text('Error cargando catálogo: $err')),
        data: (catalogData) {
          if (isEditMode) {
            return ref.watch(orderByIdProvider(orderId!)).when(
                  loading: () => Center(
                    child: CircularProgressIndicator(color: darkBrown),
                  ),
                  error: (err, stack) =>
                      Center(child: Text('Error al cargar el pedido: $err')),
                  data: (order) {
                    if (order == null) {
                      return const Center(child: Text('Pedido no encontrado.'));
                    }
                    return _OrderForm(order: order, catalog: catalogData);
                  },
                );
          }
          return _OrderForm(catalog: catalogData);
        },
      ),
    );
  }
}

class _OrderForm extends ConsumerStatefulWidget {
  final Order? order;
  final CatalogResponse? catalog;
  const _OrderForm({this.order, this.catalog});

  @override
  ConsumerState<_OrderForm> createState() => _OrderFormState();
}

class _OrderFormState extends ConsumerState<_OrderForm> {
  final _formKey = GlobalKey<FormState>();
  final _notesController = TextEditingController();

  @override
  void initState() {
    super.initState();
    if (widget.order != null) {
      _notesController.text = widget.order!.notes ?? '';
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ref.read(newOrderControllerProvider.notifier).initializeWithOrder(widget.order!);
      });
    }

    _notesController.addListener(() {
      ref.read(newOrderControllerProvider.notifier).updateNotes(_notesController.text);
    });
  }

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _selectClientFromContacts() async {
    if (!await FlutterContacts.requestPermission(readonly: true)) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Permiso de contactos denegado.'),
          backgroundColor: Theme.of(context).colorScheme.onErrorContainer,
        ),
      );
      await openAppSettings();
      return;
    }

    final Contact? contact = await FlutterContacts.openExternalPick();

    if (contact != null) {
      final String name = contact.displayName;
      final String? phone =
          contact.phones.isNotEmpty ? contact.phones.first.number : null;

      if (phone == null) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'El contacto no tiene número de teléfono.',
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSecondaryContainer,
              ),
            ),
            backgroundColor: Theme.of(context).colorScheme.secondaryContainer,
          ),
        );
        return;
      }

      final existingClients =
          await ref.read(clientsRepoProvider).searchClients(query: phone);
      final existingClient = existingClients.firstWhereOrNull(
        (c) => c.phone == phone,
      );

      if (existingClient != null) {
        ref.read(newOrderControllerProvider.notifier).updateClient(existingClient);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Cliente "${existingClient.name}" seleccionado.'),
            ),
          );
        }
      } else {
        _createClientFromData(name: name, phone: phone);
      }
    }
  }

  Future<void> _createClientFromData({
    required String name,
    String? phone,
  }) async {
    if (name.trim().isEmpty) return;

    try {
      await ref.read(newOrderControllerProvider.notifier).createClient(name, phone);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Cliente creado y seleccionado'),
          backgroundColor: Colors.green,
        ),
      );
    } on ClientExistsException catch (e) {
      _showRestoreDialog(e.clientToRestore);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString()),
          backgroundColor: Theme.of(context).colorScheme.errorContainer,
        ),
      );
    }
  }

  void _addClientManuallyDialog() {
    final nameController = TextEditingController();
    final phoneController = TextEditingController();

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(
          'Nuevo Cliente Manual',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(labelText: 'Nombre *'),
              textCapitalization: TextCapitalization.words,
            ),
            TextField(
              controller: phoneController,
              decoration: const InputDecoration(labelText: 'Teléfono'),
              keyboardType: TextInputType.phone,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () {
              if (nameController.text.trim().isNotEmpty) {
                Navigator.pop(dialogContext);
                _createClientFromData(
                  name: nameController.text,
                  phone: phoneController.text.trim().isNotEmpty
                      ? phoneController.text
                      : null,
                );
              }
            },
            child: const Text('Guardar Cliente'),
          ),
        ],
      ),
    );
  }

  Future<void> _showRestoreDialog(Client clientToRestore) async {
    final didConfirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cliente Encontrado'),
        content: Text(
          'El cliente "${clientToRestore.name}" ya existe pero fue eliminado. ¿Deseas restaurarlo?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Sí, Restaurar'),
          ),
        ],
      ),
    );

    if (didConfirm != true) return;

    try {
      await ref.read(newOrderControllerProvider.notifier).restoreClient(clientToRestore.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Cliente restaurado y seleccionado'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al restaurar: $e'),
          backgroundColor: Theme.of(context).colorScheme.onErrorContainer,
        ),
      );
    }
  }

  Future<void> _submit() async {
    final valid = _formKey.currentState?.validate() ?? false;
    if (!valid) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Revisa los campos obligatorios: Cliente y al menos un Producto.'),
          backgroundColor: Theme.of(context).colorScheme.onErrorContainer,
        ),
      );
      return;
    }

    try {
      final isEditMode = ref.read(newOrderControllerProvider).isEditMode;
      final savedOrder = await ref.read(newOrderControllerProvider.notifier).saveOrder();

      if (!mounted) return;
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(isEditMode ? 'Pedido actualizado con éxito.' : 'Pedido creado con éxito.'),
          backgroundColor: Colors.green,
        ),
      );

      if (isEditMode) {
        context.pop();
      } else {
        context.pushReplacement('/order/${savedOrder.id}');
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString()),
          backgroundColor: Theme.of(context).colorScheme.onErrorContainer,
          duration: const Duration(seconds: 4),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Form(
      key: _formKey,
      child: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              children: [
                ClientSelectorWidget(
                  onSelectFromContacts: _selectClientFromContacts,
                  onAddManually: _addClientManuallyDialog,
                  launchExternalUrl: launchExternalUrl,
                ),
                DeliverySection(
                  onAddAddress: _showAddAddressDialog,
                ),
                const SizedBox(height: 16),
                const DateTimePickerRow(),
                const SizedBox(height: 20),
                TextFormField(
                  controller: _notesController,
                  decoration: const InputDecoration(
                    labelText: 'Notas Generales del Pedido',
                    hintText: 'Ej: Decoración especial, Extras, etc.',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.notes),
                  ),
                  maxLines: 3,
                  textCapitalization: TextCapitalization.sentences,
                ),
                const SizedBox(height: 24),
                OrderItemsSection(
                  catalog: widget.catalog,
                ),
                const SizedBox(height: 100),
              ],
            ),
          ),
          OrderTotalsCard(
            onSubmit: _submit,
          ),
        ],
      ),
    );
  }

  Future<void> _showAddAddressDialog() async {
    final selectedClient = ref.read(newOrderControllerProvider).selectedClient;
    if (selectedClient == null) return;

    final int clientId = selectedClient.id;

    await showModalBottomSheet(
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
          child: ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            child: AddressFormDialog(clientId: clientId),
          ),
        );
      },
    );

    if (!mounted) return;

    ref.invalidate(clientDetailsProvider(clientId));

    try {
      final refreshed =
          await ref.read(clientsRepoProvider).getClientById(clientId);
      if (refreshed != null && mounted) {
        ref.read(newOrderControllerProvider.notifier).updateClient(refreshed);
      }
    } catch (e) {
      debugPrint('Error refrescando cliente: $e');
    }
  }
}
