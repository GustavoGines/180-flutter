
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:collection/collection.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:permission_handler/permission_handler.dart';

import 'package:pasteleria_180_flutter/core/utils/launcher_utils.dart';

import 'product_catalog.dart';
import '../../core/models/client.dart';
import '../../core/models/order.dart';
import '../../core/models/order_item.dart';
import '../clients/clients_repository.dart';
import '../clients/address_form_dialog.dart';
import 'catalog_repository.dart';
import 'orders_repository.dart';
import 'order_detail_page.dart';
import 'home_page.dart';

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

  final _clientNameController = TextEditingController();
  Client? _selectedClient;

  int? _selectedAddressId;
  bool _isPaid = false;

  late DateTime _date;
  late TimeOfDay _start;
  late TimeOfDay _end;
  final _depositController = TextEditingController();
  final _deliveryCostController = TextEditingController();
  final _notesController = TextEditingController();
  final List<OrderItem> _items = [];

  List<Product> get boxProducts =>
      widget.catalog?.products
          .where((p) => p.category == ProductCategory.box)
          .toList() ??
      [];

  List<Product> get cakeProducts =>
      widget.catalog?.products
          .where((p) => p.category == ProductCategory.torta)
          .toList() ??
      [];



  List<Product> get mesaDulceProducts =>
      widget.catalog?.products
          .where((p) => p.category == ProductCategory.mesaDulce)
          .toList() ??
      [];

  List<Filling> get allFillings => widget.catalog?.fillings ?? [];
  List<Filling> get freeFillings => allFillings.where((f) => f.isFree).toList();
  List<Filling> get extraCostFillings =>
      allFillings.where((f) => !f.isFree).toList();

  List<Extra> get cakeExtras => widget.catalog?.extras ?? [];

  bool _isLoading = false;

  bool get isEditMode => widget.order != null;
  final Map<String, XFile> _filesToUpload = {};

  @override
  void initState() {
    super.initState();
    if (isEditMode) {
      final order = widget.order!;
      _selectedClient = order.client;
      _clientNameController.text = order.client?.name ?? '';
      _date = order.eventDate;
      _start = TimeOfDay.fromDateTime(order.startTime);
      _end = TimeOfDay.fromDateTime(order.endTime);
      _depositController.text = order.deposit?.toStringAsFixed(0) ?? '0';
      _deliveryCostController.text =
          order.deliveryCost?.toStringAsFixed(0) ?? '0';
      _notesController.text = order.notes ?? '';
      _items.addAll(order.items);
      _isPaid = order.isPaid;

      _selectedAddressId = order.clientAddressId;
      if (_selectedClient != null) {
        ref.read(clientDetailsProvider(_selectedClient!.id).future).then((
          client,
        ) {
          if (mounted) {
            setState(() {});
          }
        });
      }
    } else {
      _date = DateTime.now();
      _start = const TimeOfDay(hour: 9, minute: 0);
      _end = const TimeOfDay(hour: 10, minute: 0);
      _depositController.text = '0';
      _deliveryCostController.text = '0';
    }

    _deliveryCostController.addListener(_recalculateTotals);
    _clientNameController.addListener(_onClientNameChanged);
  }

  @override
  void dispose() {
    _clientNameController.dispose();
    _depositController.dispose();
    _deliveryCostController.dispose();
    _notesController.dispose();
    _clientNameController.removeListener(_onClientNameChanged);
    _deliveryCostController.removeListener(_recalculateTotals);

    super.dispose();
  }

  double _itemsSubtotal = 0.0;
  double _deliveryCost = 0.0;
  double _grandTotal = 0.0;
  double _depositAmount = 0.0;
  double _remainingBalance = 0.0;

  void _recalculateTotals() {
    double subtotal = 0.0;
    for (var item in _items) {
      subtotal += (item.finalUnitPrice * item.qty);
    }

    double delivery =
        double.tryParse(_deliveryCostController.text.replaceAll(',', '.')) ??
            0.0;
    double deposit =
        double.tryParse(_depositController.text.replaceAll(',', '.')) ?? 0.0;
    double total = subtotal + delivery;
    double remaining = _isPaid ? 0.0 : (total - deposit);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        setState(() {
          _itemsSubtotal = subtotal;
          _deliveryCost = delivery;
          _grandTotal = total;
          _depositAmount = deposit;
          _remainingBalance = remaining;
        });
      }
    });
  }

  void _updateItemsAndRecalculate(Function updateLogic) {
    setState(() {
      updateLogic();
      _recalculateTotals();
    });
  }

  Future<void> _pickDate() async {
    final d = await showDatePicker(
      context: context,
      locale: const Locale('es', 'AR'),
      firstDate: DateTime.now().subtract(const Duration(days: 90)),
      lastDate: DateTime.now().add(const Duration(days: 730)),
      initialDate: _date,
      builder: (context, child) {
        final theme = Theme.of(context);
        return Theme(
          data: theme.copyWith(
            textButtonTheme: TextButtonThemeData(
              style: TextButton.styleFrom(
                foregroundColor: theme.colorScheme.primary,
              ),
            ),
          ),
          child: child!,
        );
      },
    );
    if (d != null) setState(() => _date = d);
  }

  Future<void> _pickTime(bool isStart) async {
    final t = await showTimePicker(
      context: context,
      initialTime: isStart ? _start : _end,
      initialEntryMode: TimePickerEntryMode.input,
      builder: (context, child) {
        final theme = Theme.of(context);
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true),
          child: Theme(
            data: theme.copyWith(
              textButtonTheme: TextButtonThemeData(
                style: TextButton.styleFrom(
                  foregroundColor: theme.colorScheme.primary,
                ),
              ),
            ),
            child: child!,
          ),
        );
      },
    );

    if (t != null) {
      setState(() {
        if (isStart) {
          _start = t;
          if ((_start.hour * 60 + _start.minute) >=
              (_end.hour * 60 + _end.minute)) {
            _end = TimeOfDay(
              hour: (_start.hour + 1) % 24,
              minute: _start.minute,
            );
          }
        } else {
          _end = t;
          if ((_start.hour * 60 + _start.minute) >=
              (_end.hour * 60 + _end.minute)) {
            _start = TimeOfDay(
              hour: (_end.hour - 1 + 24) % 24,
              minute: _end.minute,
            );
          }
        }
      });
    }
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
        setState(() {
          _selectedClient = existingClient;
          _clientNameController.text = existingClient.name;
          _selectedAddressId = null;
          _deliveryCostController.text = '0';
        });
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

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    Client? newClient;
    String? errorMessage;

    try {
      newClient = await ref.read(clientsRepoProvider).createClient({
        'name': name.trim(),
        'phone': phone?.trim(),
      });
    } on DioException catch (e) {
      if (e.response?.statusCode == 409 && e.response?.data['client'] != null) {
        if (mounted) Navigator.pop(context);
        final clientData = e.response?.data['client'];
        final clientToRestore = Client.fromJson(
          (clientData as Map).map((k, v) => MapEntry(k.toString(), v)),
        );
        _showRestoreDialog(clientToRestore);
        return;
      }
      errorMessage =
          e.response?.data['message'] as String? ?? 'Error al crear cliente.';
    } catch (e) {
      errorMessage = e.toString();
    }

    if (mounted) Navigator.pop(context);

    if (newClient != null && mounted) {
      setState(() {
        _selectedClient = newClient;
        _clientNameController.text = newClient!.name;
        _selectedAddressId = null;
        _deliveryCostController.text = '0';
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Cliente creado y seleccionado'),
          backgroundColor: Colors.green,
        ),
      );
    } else if (errorMessage != null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(errorMessage),
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

    setState(() => _isLoading = true);
    try {
      final restoredClient =
          await ref.read(clientsRepoProvider).restoreClient(clientToRestore.id);

      ref.invalidate(clientsListProvider(''));
      ref.invalidate(trashedClientsProvider);

      if (mounted) {
        setState(() {
          _selectedClient = restoredClient;
          _clientNameController.text = restoredClient.name;
          _selectedAddressId = null;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Cliente restaurado y seleccionado'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al restaurar: $e'),
            backgroundColor: Theme.of(context).colorScheme.onErrorContainer,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _submit() async {
    final valid = _formKey.currentState?.validate() ?? false;
    _recalculateTotals();

    if (_depositAmount > _grandTotal + 0.01) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text(
            'El monto de la seña/depósito no puede ser mayor al TOTAL del pedido. Verifica los valores.',
          ),
          backgroundColor: Theme.of(context).colorScheme.onErrorContainer,
          duration: const Duration(seconds: 4),
        ),
      );
      return;
    }

    if (_deliveryCost > 0 && _selectedAddressId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text(
            'Si hay costo de envío, debes seleccionar una dirección de entrega.',
          ),
          backgroundColor: Theme.of(context).colorScheme.onErrorContainer,
          duration: const Duration(seconds: 4),
        ),
      );
      return;
    }

    if (!valid || _selectedClient == null || _items.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text(
            'Revisa los campos obligatorios: Cliente y al menos un Producto.',
          ),
          backgroundColor: Theme.of(context).colorScheme.onErrorContainer,
          duration: const Duration(seconds: 4),
        ),
      );
      return;
    }

    if (_grandTotal <= 0 && _items.isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'El total calculado es cero o negativo. Revisa los precios de los productos.',
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSecondaryContainer,
            ),
          ),
          backgroundColor: Theme.of(context).colorScheme.secondaryContainer,
          duration: const Duration(seconds: 4),
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    final fmt = DateFormat('yyyy-MM-dd');
    String t(TimeOfDay x) =>
        '${x.hour.toString().padLeft(2, '0')}:${x.minute.toString().padLeft(2, '0')}';

    final payload = {
      'client_id': _selectedClient!.id,
      'event_date': fmt.format(_date),
      'start_time': t(_start),
      'end_time': t(_end),
      'status': isEditMode ? widget.order!.status : 'confirmed',
      'deposit': _depositAmount,
      'delivery_cost': _deliveryCost > 0 ? _deliveryCost : null,
      'notes': _notesController.text.trim().isEmpty
          ? null
          : _notesController.text.trim(),
      'client_address_id': _selectedAddressId,
      'is_paid': _isPaid,
      'items': _items.map((item) => item.toJson()).toList(),
    };

    try {
      if (isEditMode) {
        final Order updatedOrder = await ref
            .read(ordersRepoProvider)
            .updateOrderWithFiles(widget.order!.id, payload, _filesToUpload);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Pedido actualizado con éxito.',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onTertiaryContainer,
                ),
              ),
              backgroundColor: Theme.of(context).colorScheme.tertiaryContainer,
            ),
          );

          await ref
              .read(ordersWindowProvider.notifier)
              .updateOrder(updatedOrder);

          ref.invalidate(orderByIdProvider(widget.order!.id));
          if (mounted) context.pop();
        }
      } else {
        final Order createdOrder = await ref
            .read(ordersRepoProvider)
            .createOrderWithFiles(payload, _filesToUpload);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Pedido creado con éxito.',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onTertiaryContainer,
                ),
              ),
              backgroundColor: Theme.of(context).colorScheme.tertiaryContainer,
            ),
          );

          await ref.read(ordersWindowProvider.notifier).addOrder(createdOrder);

          if (mounted) context.pop();
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al guardar: ${e.toString()}'),
            backgroundColor: Theme.of(context).colorScheme.onErrorContainer,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    WidgetsBinding.instance.addPostFrameCallback((_) => _recalculateTotals());

    return Form(
      key: _formKey,
      child: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              children: [
                ClientSelectorWidget(
                  selectedClient: _selectedClient,
                  clientNameController: _clientNameController,
                  onClientSelected: (client) {
                    setState(() {
                      _selectedClient = client;
                      _clientNameController.text = client.name;
                      _selectedAddressId = null;
                      _deliveryCostController.text = '0';
                    });
                  },
                  onClearClient: () {
                    setState(() {
                      _selectedClient = null;
                      _clientNameController.clear();
                      _selectedAddressId = null;
                    });
                  },
                  onSelectFromContacts: _selectClientFromContacts,
                  onAddManually: _addClientManuallyDialog,
                  launchExternalUrl: launchExternalUrl,
                ),
                if (_selectedClient != null)
                  DeliverySection(
                    selectedClient: _selectedClient!,
                    selectedAddressId: _selectedAddressId,
                    onAddressSelected: (newId) {
                      setState(() {
                        _selectedAddressId = newId;
                        if (newId == null) {
                          _deliveryCostController.text = '0';
                        }
                      });
                    },
                    onAddAddress: _showAddAddressDialog,
                  ),
                const SizedBox(height: 16),
                DateTimePickerRow(
                  date: _date,
                  startTime: _start,
                  endTime: _end,
                  onPickDate: _pickDate,
                  onPickStartTime: () => _pickTime(true),
                  onPickEndTime: () => _pickTime(false),
                ),
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
                  items: _items,
                  catalog: widget.catalog,
                  filesToUpload: _filesToUpload,
                  onItemsChanged: (newItems) {
                    _updateItemsAndRecalculate(() {
                      final snapshot = List<OrderItem>.from(newItems);
                      _items.clear();
                      _items.addAll(snapshot);
                    });
                  },
                ),
                const SizedBox(height: 100),
              ],
            ),
          ),
          OrderTotalsCard(
            depositController: _depositController,
            deliveryCostController: _deliveryCostController,
            isPaid: _isPaid,
            onPaidChanged: (val) {
              setState(() => _isPaid = val);
              _recalculateTotals();
            },
            onTotalsChanged: _recalculateTotals,
            itemsSubtotal: _itemsSubtotal,
            deliveryCost: _deliveryCost,
            grandTotal: _grandTotal,
            depositAmount: _depositAmount,
            remainingBalance: _remainingBalance,
            isLoading: _isLoading,
            isEditMode: isEditMode,
            onSubmit: _submit,
          ),
        ],
      ),
    );
  }

  void _onClientNameChanged() {
    if (_selectedClient != null &&
        _clientNameController.text != _selectedClient!.name) {
      setState(() {
        _selectedClient = null;
        _selectedAddressId = null; // <-- 14. LIMPIAR DIRECCIÓN
      });
    }
  }

  // --- HELPER DE UI: FILA DE IMAGENES COMPACTA (Para Pending List) ---
  Future<void> _showAddAddressDialog() async {
    if (_selectedClient == null) return;

    final int clientId = _selectedClient!.id;

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

    // Al cerrar el modal, refrescar los datos del cliente para ver la nueva dirección
    if (!mounted) return;

    // Invalida el provider global para asegurar que futuros usos traigan data fresca
    ref.invalidate(clientDetailsProvider(clientId));

    // Trae la data fresca manualmente para actualizar el estado local
    try {
      final refreshed =
          await ref.read(clientsRepoProvider).getClientById(clientId);
      if (refreshed != null && mounted) {
        setState(() {
          _selectedClient = refreshed;
          // Opcional: Auto-seleccionar la última dirección agregada
          if (refreshed.addresses.isNotEmpty) {
            // _selectedAddressId = refreshed.addresses.last.id;
          }
        });
      }
    } catch (e) {
      debugPrint('Error refrescando cliente: $e');
    }
  }
}
