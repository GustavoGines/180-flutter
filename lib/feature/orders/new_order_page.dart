import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // Para input formatters
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:flutter_typeahead/flutter_typeahead.dart';
import 'package:image_picker/image_picker.dart';
import 'package:collection/collection.dart'; // Para .firstWhereOrNull
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:flutter_speed_dial/flutter_speed_dial.dart';
import 'package:permission_handler/permission_handler.dart';

// --- AÑADIDOS PARA COMPRESIÓN ---
import 'package:pasteleria_180_flutter/core/json_utils.dart';
import 'package:pasteleria_180_flutter/core/utils/launcher_utils.dart';
// --- FIN DE AÑADIDOS ---

// --- IMPORTAR EL CATÁLOGO ---
import 'product_catalog.dart';
// --- FIN IMPORTAR CATÁLOGO ---
import '../../core/models/client.dart';
import '../../core/models/order.dart';
import '../../core/models/order_item.dart';
import '../clients/clients_repository.dart';
import '../clients/address_form_dialog.dart'; // <-- 2. IMPORTAR DIÁLOGO
import 'orders_repository.dart';
import 'order_detail_page.dart';
import 'home_page.dart'; // Para invalidar ordersByFilterProvider

// La página principal ahora es un ConsumerWidget simple que decide si crear o editar
class NewOrderPage extends ConsumerWidget {
  final int? orderId; // Recibe el ID, o nulo si es un pedido nuevo
  const NewOrderPage({super.key, this.orderId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isEditMode = orderId != null;

    // Colores de la marca (podrían estar en un archivo de tema global)
    Color darkBrown = Theme.of(context).colorScheme.primary;

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
      body: isEditMode
          // Si estamos editando, buscamos el pedido primero
          ? ref
                .watch(orderByIdProvider(orderId!))
                .when(
                  loading: () => Center(
                    child: CircularProgressIndicator(color: darkBrown),
                  ),
                  error: (err, stack) => Center(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Text(
                        'Error al cargar el pedido: $err\nIntenta recargar la página.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onErrorContainer,
                        ),
                      ),
                    ),
                  ),
                  // Cuando tenemos los datos, construimos el formulario y se los pasamos
                  data: (order) {
                    if (order == null) {
                      return const Center(
                        child: Text('Pedido no encontrado o eliminado.'),
                      );
                    }
                    return _OrderForm(order: order);
                  },
                )
          // Si estamos creando, construimos el formulario vacío
          : const _OrderForm(),
    );
  }
}

// (Clase auxiliar para productos del Box)
class BoxMesaDulceSelection {
  final Product product;
  int quantity;

  // Para productos vendidos por tamaño (Tarta/Brownie Redondo), usamos esto en lugar de quantity
  ProductUnit? selectedSize;

  BoxMesaDulceSelection({
    required this.product,
    this.quantity = 1,
    this.selectedSize,
  });
}

// --- CLASE AUXILIAR PARA EXTRAS POR UNIDAD ---
class UnitExtraSelection {
  final CakeExtra extra;
  int quantity;

  UnitExtraSelection({required this.extra, this.quantity = 1});
}

// Widget interno que contiene TODA la lógica y estado del formulario
class _OrderForm extends ConsumerStatefulWidget {
  final Order? order; // El pedido a editar (puede ser nulo)
  const _OrderForm({this.order});

  @override
  ConsumerState<_OrderForm> createState() => _OrderFormState();
}

class _OrderFormState extends ConsumerState<_OrderForm> {
  final _formKey = GlobalKey<FormState>();

  final _clientNameController = TextEditingController();
  Client? _selectedClient;

  // --- 3. NUEVOS ESTADOS PARA DIRECCIÓN ---
  int? _selectedAddressId; // El ID de la dirección de entrega
  // ------------------------------------

  late DateTime _date;
  late TimeOfDay _start;
  late TimeOfDay _end;
  final _depositController = TextEditingController();
  final _deliveryCostController = TextEditingController();
  final _notesController = TextEditingController();
  final List<OrderItem> _items = [];

  bool _isLoading = false;
  final NumberFormat _currencyFormat = NumberFormat.currency(
    locale: 'es_AR',
    symbol: '\$',
  );

  bool get isEditMode => widget.order != null;
  // La Key será un ID temporal (ej: "placeholder_12345"),
  // el Value será el archivo a subir.
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

      // --- 4. CARGAR DATOS DE DIRECCIÓN EN MODO EDICIÓN ---
      _selectedAddressId = order.clientAddressId;
      // Cargar las direcciones del cliente en modo edición
      if (_selectedClient != null) {
        // Usamos ref.read().future para cargar los datos iniciales
        // El widget _buildAddressSelector usará ref.watch() para reactividad
        ref.read(clientDetailsProvider(_selectedClient!.id).future).then((
          client,
        ) {
          if (mounted) {
            setState(() {});
          }
        });
      }
      // ------------------------------------------------
    } else {
      // Valores por defecto para un pedido nuevo
      _date = DateTime.now();
      _start = const TimeOfDay(hour: 9, minute: 0);
      _end = const TimeOfDay(hour: 10, minute: 0);
      _depositController.text = '0';
      _deliveryCostController.text = '0';
    }

    // Listener para recalcular totales si cambia el costo de envío
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

  // --- CÁLCULO DE TOTALES (sin cambios) ---
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
    double remaining = total - deposit;

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

  // --- PICKERS DE FECHA Y HORA (sin cambios) ---
  Future<void> _pickDate() async {
    final d = await showDatePicker(
      context: context,
      locale: const Locale('es', 'AR'),
      firstDate: DateTime.now().subtract(const Duration(days: 90)),
      lastDate: DateTime.now().add(const Duration(days: 730)),
      initialDate: _date,
      builder: (context, child) {
        // Obtenemos el tema actual
        final theme = Theme.of(context);
        return Theme(
          // Usamos la base del tema (light o dark)
          data: theme.copyWith(
            textButtonTheme: TextButtonThemeData(
              // Hacemos que los botones usen el color primary del tema
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
        // Obtenemos el tema actual
        final theme = Theme.of(context);
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true),
          child: Theme(
            // Usamos la base del tema (light o dark)
            data: theme.copyWith(
              // ¡No sobrescribimos 'primary'!
              textButtonTheme: TextButtonThemeData(
                // Hacemos que los botones usen el color primary del tema
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

  // =========================================================================
  // === INICIO DE MÉTODOS DEL SPEED DIAL (Reemplazan _addClientDialog) =======
  // =========================================================================

  // --- Función para obtener Cliente desde Contactos ---
  Future<void> _selectClientFromContacts() async {
    // 1. Pedir Permiso de Contactos
    if (!await FlutterContacts.requestPermission(readonly: true)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Permiso de contactos denegado.'),
          backgroundColor: Theme.of(context).colorScheme.onErrorContainer,
        ),
      );
      await openAppSettings(); // Sugerir abrir configuración
      return;
    }

    // 2. Abrir Selector Nativo
    final Contact? contact = await FlutterContacts.openExternalPick();

    if (contact != null) {
      // 3. Extraer datos y normalizar
      final String name = contact.displayName;
      final String? phone = contact.phones.isNotEmpty
          ? contact.phones.first.number
          : null;

      if (phone == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'El contacto no tiene número de teléfono.',
              style: TextStyle(
                // Color de texto sobre el contenedor secundario
                color: Theme.of(context).colorScheme.onSecondaryContainer,
              ),
            ),
            backgroundColor: Theme.of(context).colorScheme.secondaryContainer,
          ),
        );
        return;
      }

      // 4. Intentar buscar si el cliente ya existe por teléfono
      // NOTA: Tu API debe tener una búsqueda por teléfono implementada en searchClients
      final existingClients = await ref
          .read(clientsRepoProvider)
          .searchClients(query: phone);
      final existingClient = existingClients.firstWhereOrNull(
        (c) => c.phone == phone,
      );

      if (existingClient != null) {
        // 5. Cliente ya existe: simplemente seleccionarlo
        setState(() {
          _selectedClient = existingClient;
          _clientNameController.text = existingClient.name;
          _selectedAddressId = null;
          _deliveryCostController.text = '0';
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Cliente "${existingClient.name}" seleccionado.'),
          ),
        );
      } else {
        // 6. Cliente no existe: crear el nuevo cliente directamente
        _createClientFromData(name: name, phone: phone);
      }
    }
  }

  // --- Helper: Crear Cliente desde Contacto/Manual ---
  Future<void> _createClientFromData({
    required String name,
    String? phone,
  }) async {
    // Simula el flujo de _addClientDialog, pero sin el formulario modal
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
      // Si es 409 (cliente borrado), lo manejamos con el diálogo de restauración
      if (e.response?.statusCode == 409 && e.response?.data['client'] != null) {
        // Cierra el loader primero
        if (context.mounted) Navigator.pop(context);
        final clientData = e.response?.data['client'];
        final clientToRestore = Client.fromJson(
          (clientData as Map).map((k, v) => MapEntry(k.toString(), v)),
        );
        _showRestoreDialog(clientToRestore);
        return; // Sale del try/catch
      }
      errorMessage =
          e.response?.data['message'] as String? ?? 'Error al crear cliente.';
    } catch (e) {
      errorMessage = e.toString();
    }

    // Cerrar loader
    if (context.mounted) Navigator.pop(context);

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
          backgroundColor: Theme.of(context).colorScheme.onErrorContainer,
        ),
      );
    }
  }

  // --- Diálogo Manual (Versión simplificada) ---
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
            style: FilledButton.styleFrom(),
            onPressed: () {
              if (nameController.text.trim().isNotEmpty) {
                Navigator.pop(dialogContext); // Cierra el diálogo manual
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

  // --- Selector de Cliente Completo con SpeedDial ---
  Widget _buildClientSelector(BuildContext context) {
    return Builder(
      builder: (context) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_selectedClient == null)
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: TypeAheadField<Client>(
                      controller: _clientNameController,
                      debounceDuration: const Duration(milliseconds: 500),
                      suggestionsCallback: (pattern) async {
                        if (pattern.length < 2) return [];
                        if (_selectedClient != null) {
                          setState(() {
                            _selectedClient = null;
                          });
                        }
                        return ref.watch(clientsListProvider(pattern).future);
                      },
                      itemBuilder: (context, client) => ListTile(
                        leading: const Icon(Icons.person),
                        title: Text(client.name),
                        subtitle: Text(client.phone ?? 'Sin teléfono'),
                      ),
                      onSelected: (client) {
                        setState(() {
                          _selectedClient = client;
                          _clientNameController.text = client.name;
                          _selectedAddressId = null;
                          _deliveryCostController.text = '0';
                        });
                      },
                      emptyBuilder: (context) => const Padding(
                        padding: EdgeInsets.all(12.0),
                        child: Text('No se encontraron clientes.'),
                      ),
                      builder: (context, controller, focusNode) =>
                          TextFormField(
                            controller: controller,
                            focusNode: focusNode,
                            decoration: const InputDecoration(
                              labelText: 'Buscar cliente...',
                              border: OutlineInputBorder(),
                              prefixIcon: Icon(Icons.search),
                            ),
                            validator: (value) {
                              if (_selectedClient == null) {
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

                    buttonSize: const Size(
                      56,

                      56,
                    ), // Mismo tamaño que un FAB estándar

                    childrenButtonSize: const Size(56, 56),

                    direction: SpeedDialDirection.down,

                    curve: Curves.easeInOut,

                    children: [
                      // Opción 1: Seleccionar desde Contactos
                      SpeedDialChild(
                        child: const Icon(Icons.contact_phone_outlined),

                        label: 'Desde Contactos',

                        onTap: _selectClientFromContacts,
                      ),

                      // Opción 2: Agregar Nuevo Manualmente
                      SpeedDialChild(
                        child: const Icon(Icons.person_add_alt_1),

                        label: 'Nuevo Manualmente',

                        onTap: _addClientManuallyDialog,
                      ),
                    ],
                  ),
                ],
              )
            else
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
                    _selectedClient!.name,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.onTertiaryContainer,
                    ),
                  ),
                  subtitle: Text(
                    'Tel: ${_selectedClient!.phone ?? "N/A"}',
                    style: TextStyle(
                      color: Theme.of(
                        context,
                      ).colorScheme.onTertiaryContainer.withOpacity(0.8),
                    ),
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (_selectedClient!.whatsappUrl != null)
                        IconButton(
                          icon: const FaIcon(FontAwesomeIcons.whatsapp),
                          color: Colors.green,
                          tooltip: 'Chatear por WhatsApp',
                          onPressed: () {
                            launchExternalUrl(_selectedClient!.whatsappUrl!);
                          },
                        ),
                      IconButton(
                        icon: Icon(
                          Icons.close,
                          color: Theme.of(
                            context,
                          ).colorScheme.onTertiaryContainer,
                        ),
                        tooltip: 'Quitar cliente',
                        onPressed: () {
                          setState(() {
                            _selectedClient = null;
                            _clientNameController.clear();
                            _selectedAddressId = null;
                          });
                        },
                      ),
                    ],
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  // --- DIÁLOGO RESTAURAR CLIENTE (sin cambios) ---
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
      final restoredClient = await ref
          .read(clientsRepoProvider)
          .restoreClient(clientToRestore.id);

      ref.invalidate(clientsListProvider('')); // Invalida búsqueda
      ref.invalidate(trashedClientsProvider);

      if (mounted) {
        setState(() {
          _selectedClient = restoredClient;
          _clientNameController.text = restoredClient.name;
          _selectedAddressId = null; // Resetear dirección
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

  // --- DIÁLOGOS DE ITEMS (MiniTorta, Torta, MesaDulce) ---
  // (Sin cambios en la lógica interna de estos diálogos)
  void _addItemDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Seleccionar Tipo de Producto'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Icon(
                Icons.card_giftcard, // ⬅️ CAMBIO: Ícono para Box
                color: Theme.of(
                  context,
                ).colorScheme.tertiary, // ⬅️ CAMBIO: Color
              ),
              title: const Text('Box Dulce'), // ⬅️ CAMBIO: Nuevo texto
              onTap: () {
                Navigator.of(context).pop();
                _addBoxDialog(); // ⬅️ CAMBIO: Llamada a _addBoxDialog
              },
            ),
            ListTile(
              leading: Icon(
                Icons.cake_outlined,
                color: Theme.of(context).colorScheme.primary,
              ),
              title: const Text('Tortas y Mini Tortas'),
              onTap: () {
                Navigator.of(context).pop();
                _addCakeDialog();
              },
            ),
            ListTile(
              leading: Icon(
                Icons.icecream,
                color: Theme.of(context).colorScheme.tertiary,
              ),
              title: const Text('Mesa Dulce'),
              onTap: () {
                Navigator.of(context).pop();
                _addMesaDulceDialog();
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancelar'),
          ),
        ],
      ),
    );
  }

  void _addBoxDialog({OrderItem? existingItem, int? itemIndex}) {
    final bool isEditing = existingItem != null;
    Map<String, dynamic> customData = isEditing
        ? (existingItem.customizationJson ?? {})
        : {};

    const personalizedBoxName = 'BOX DULCE Personalizado (Armar)';

    Product? selectedProduct = isEditing
        ? boxProducts.firstWhereOrNull((p) => p.name == existingItem.name)
        : boxProducts.first;

    double basePrice = isEditing
        ? existingItem.basePrice
        : selectedProduct?.price ?? 0.0;
    // 🎯 Paso 1: Leer el Ajuste Manual Puro del JSON si existe
    double manualAdjustmentValue = isEditing
        ? (customData['manual_adjustment_value'] is num
              ? (customData['manual_adjustment_value'] as num).toDouble()
              : 0.0)
        : 0.0;

    // La variable 'adjustments' DEBE reflejar el valor inicial del controlador (el ajuste manual puro)
    double adjustments = manualAdjustmentValue;

    final qtyController = TextEditingController(
      text: isEditing ? existingItem.qty.toString() : '1',
    );

    final adjustmentsController = TextEditingController(
      text: adjustments.toStringAsFixed(
        0,
      ), // ⬅️ Inicializado con el ajuste MANUAL PURO o 0
    );

    final adjustmentNotesController = TextEditingController(
      text: isEditing ? existingItem.customizationNotes ?? '' : '',
    );
    final itemNotesController = TextEditingController(
      text: customData['item_notes'] as String? ?? '',
    );

    // --- Control de ítems seleccionados para Box Personalizado (Mesa Dulce) ---
    List<BoxMesaDulceSelection> selectedMesaDulceItems = [];
    if (isEditing && existingItem.name == personalizedBoxName) {
      final List<dynamic> itemsData =
          customData['selected_mesa_dulce_items'] as List<dynamic>? ?? [];
      for (var itemData in itemsData) {
        final name = itemData['name'];
        final qty = itemData['quantity'] ?? 1;
        final sizeName = itemData['selected_size'];
        final product = mesaDulceProducts.firstWhereOrNull(
          (p) => p.name == name,
        );
        if (product != null) {
          selectedMesaDulceItems.add(
            BoxMesaDulceSelection(
              product: product,
              quantity: qty,
              selectedSize: sizeName != null
                  ? ProductUnit.values.firstWhereOrNull(
                      (e) => e.name == sizeName,
                    )
                  : null,
            ),
          );
        }
      }
    }

    // 🎯 NUEVO: Inicialización de Torta Base solo si estamos editando un Box Predeterminado
    // O si es un Box Personalizado que ya tenía una torta base seleccionada.
    // Esto es para mantener la selección al editar.
    Product? selectedBaseCake = customData['selected_base_cake'] != null
        ? smallCakeProducts.firstWhereOrNull(
            (p) => p.name == (customData['selected_base_cake'] as String?),
          )
        : smallCakeProducts.firstWhereOrNull(
            (p) => p.name == 'Mini Torta Personalizada (Base)',
          ); // Default: Mini Torta

    // Para Boxes predefinidos (que contienen Mini Torta) o si se selecciona una en el Box Personalizado
    List<Filling> selectedFillings =
        (customData['selected_fillings'] as List<dynamic>? ?? [])
            .map(
              (name) => allFillings.firstWhereOrNull(
                (f) => f.name == name?.toString(),
              ),
            )
            .whereType<Filling>()
            .toList();
    List<Filling> selectedExtraFillings =
        (customData['selected_extra_fillings'] as List<dynamic>? ?? [])
            .map((data) {
              // --- INICIO CORRECCIÓN LECTURA ---
              if (data is Map) {
                final name = data['name']?.toString();
                return extraCostFillings.firstWhereOrNull(
                  (f) => f.name == name,
                );
              }
              if (data is String) {
                // Compatibilidad con datos viejos
                return extraCostFillings.firstWhereOrNull(
                  (f) => f.name == data,
                );
              }
              return null;
              // --- FIN CORRECCIÓN LECTURA ---
            })
            .whereType<Filling>()
            .toList();
    List<CakeExtra> selectedExtrasKg =
        (customData['selected_extras_kg'] as List<dynamic>? ?? [])
            .map((data) {
              // --- INICIO CORRECCIÓN LECTURA ---
              if (data is Map) {
                final name = data['name']?.toString();
                return cakeExtras.firstWhereOrNull(
                  (ex) => ex.name == name && !ex.isPerUnit,
                );
              }
              if (data is String) {
                // Compatibilidad con datos viejos
                return cakeExtras.firstWhereOrNull(
                  (ex) => ex.name == data && !ex.isPerUnit,
                );
              }
              return null;
              // --- FIN CORRECCIÓN LECTURA ---
            })
            .whereType<CakeExtra>()
            .toList();
    List<UnitExtraSelection> selectedExtrasUnit =
        (customData['selected_extras_unit'] as List<dynamic>? ?? [])
            .map((data) {
              if (data is Map) {
                final name = data['name']?.toString();
                final extra = cakeExtras.firstWhereOrNull(
                  (ex) => ex.name == name && ex.isPerUnit,
                );
                if (extra != null) {
                  final quantity = toInt(data['quantity'], fallback: 1);
                  return UnitExtraSelection(
                    extra: extra,
                    quantity: quantity >= 1 ? quantity : 1,
                  );
                }
              }
              return null;
            })
            .whereType<UnitExtraSelection>()
            .toList();
    // ------------------------------------------------

    final ImagePicker picker = ImagePicker();
    List<String> existingImageUrls = List<String>.from(
      customData['photo_urls'] ?? [],
    );

    final finalPriceController = TextEditingController();

    // -------------------------------------------------------------
    // 🚨 CÁLCULO SÍNCRONO DEL PRECIO BASE CALCULADO (Para el prefixText)
    // Se necesita para que el prefixText muestre el valor antes del postFrameCallback.
    // -------------------------------------------------------------
    double calculatedTotalBasePrice = basePrice;

    final isPersonalizedBox = selectedProduct?.name == personalizedBoxName;
    double calculatedExtrasCost = 0.0;
    double calculatedSubItemsCost = 0.0;

    if (isPersonalizedBox) {
      calculatedTotalBasePrice = selectedBaseCake?.price ?? 0.0;

      // Sumar Mesa Dulce (sólo si se está editando un box personalizado)
      for (var sel in selectedMesaDulceItems) {
        double unitPrice = 0.0;
        if (sel.product.pricesBySize != null) {
          unitPrice = sel.product.pricesBySize![sel.selectedSize] ?? 0.0;
        } else if (sel.product.unit == ProductUnit.dozen) {
          unitPrice = sel.product.price / 12.0;
        } else if (sel.product.unit == ProductUnit.unit) {
          unitPrice = sel.product.price;
        }
        calculatedSubItemsCost += unitPrice * sel.quantity;
      }
      calculatedTotalBasePrice += calculatedSubItemsCost;
    }

    // Sumar extras de Torta (rellenos/extras por unidad/kg)
    if (selectedBaseCake != null || !isPersonalizedBox) {
      const miniCakeName = 'Mini Torta Personalizada (Base)';
      const microCakeName = 'Micro Torta'; // <-- CONFIRMA ESTE NOMBRE

      bool isSmallCake = false;
      if (isPersonalizedBox) {
        // Si es personalizado, chequea la torta base seleccionada
        isSmallCake =
            selectedBaseCake?.name == miniCakeName ||
            selectedBaseCake?.name == microCakeName;
      } else {
        // Si es predefinido, asumimos que SIEMPRE usa la lógica de mini torta
        isSmallCake = true;
      }

      // Define el multiplicador de costo (0.5 para chicas, 1.0 para tortas de 1kg si las agregaras)
      final double costMultiplier = isSmallCake ? 0.5 : 1.0;
      // Suma Extras (rellenos, kg, unit)
      calculatedExtrasCost += selectedExtraFillings.fold(
        0.0,
        (sum, f) => sum + (f.extraCostPerKg * costMultiplier), // <-- CORREGIDO
      );
      calculatedExtrasCost += selectedExtrasKg.fold(
        0.0,
        (sum, ex) => sum + (ex.costPerKg * costMultiplier), // <-- CORREGIDO
      );
      calculatedExtrasCost += selectedExtrasUnit.fold(
        0.0,
        (sum, sel) => sum + (sel.extra.costPerUnit * sel.quantity),
      );
      calculatedTotalBasePrice += calculatedExtrasCost;
    }
    // -------------------------------------------------------------

    // -------------------------------------------------------------
    // FUNCIÓN calculatePrice (Ajustada para usar currentAdjustments y actualizar 'adjustments')
    // -------------------------------------------------------------
    void calculatePrice() {
      final qty = int.tryParse(qtyController.text) ?? 0;
      // 🚨 CRÍTICO: La función asíncrona DEBE leer el valor actualizado del controlador
      final currentAdjustments =
          double.tryParse(adjustmentsController.text) ?? 0.0;

      // **Nota:** No necesitamos recalcular calculatedTotalBasePrice aquí si las selecciones
      // no cambian; si cambian (ej. un checkbox), se debe hacer la re-evaluación completa.
      // Asumiendo que los cambios en la UI (checkboxes, dropdowns) llaman a setDialogState(calculatePrice),
      // este cálculo se realiza correctamente:

      // Si hay cambios de selección en la UI, el cálculo de calculatedTotalBasePrice
      // necesita ser re-ejecutado. Por seguridad, volvemos a calcular el costo base aquí.

      // [INICIO RE-CÁLCULO DENTRO DE calculatePrice]
      calculatedTotalBasePrice = basePrice;
      calculatedSubItemsCost = 0.0;
      calculatedExtrasCost = 0.0;

      if (isPersonalizedBox) {
        calculatedTotalBasePrice = selectedBaseCake?.price ?? 0.0;
        // Suma Mesa Dulce
        for (var sel in selectedMesaDulceItems) {
          double unitPrice = 0.0;
          // ... (Lógica de precio unitario)
          if (sel.product.pricesBySize != null) {
            unitPrice = sel.product.pricesBySize![sel.selectedSize] ?? 0.0;
          } else if (sel.product.unit == ProductUnit.dozen) {
            unitPrice = sel.product.price / 12.0;
          } else if (sel.product.unit == ProductUnit.unit) {
            unitPrice = sel.product.price;
          }
          calculatedSubItemsCost += unitPrice * sel.quantity;
        }
        calculatedTotalBasePrice += calculatedSubItemsCost;
      }

      if (selectedBaseCake != null || !isPersonalizedBox) {
        // Suma Extras (rellenos, kg, unit)
        calculatedExtrasCost += selectedExtraFillings.fold(
          0.0,
          (sum, f) => sum + f.extraCostPerKg,
        );
        calculatedExtrasCost += selectedExtrasKg.fold(
          0.0,
          (sum, ex) => sum + ex.costPerKg,
        );
        calculatedExtrasCost += selectedExtrasUnit.fold(
          0.0,
          (sum, sel) => sum + (sel.extra.costPerUnit * sel.quantity),
        );
        calculatedTotalBasePrice += calculatedExtrasCost;
      }
      // [FIN RE-CÁLCULO DENTRO DE calculatePrice]

      if (qty > 0) {
        final finalUnitPrice = calculatedTotalBasePrice + currentAdjustments;
        finalPriceController.text = (finalUnitPrice * qty).toStringAsFixed(0);
      } else {
        finalPriceController.text = 'N/A';
      }

      // 🚨 CRÍTICO: Actualizar la variable de alcance superior 'adjustments' para el onPressed
      adjustments = currentAdjustments;
    }
    // ------------------------------------------------

    WidgetsBinding.instance.addPostFrameCallback((_) => calculatePrice());

    showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final isCurrentPersonalizedBox =
                selectedProduct?.name == personalizedBoxName;

            // --- HELPER WIDGETS (Rellenos/Extras Predefinidos) ---
            // (Los builders son los mismos que en la respuesta anterior, se mantienen)

            Widget buildFillingCheckbox(Filling filling, bool isExtraCost) {
              bool isSelected = isExtraCost
                  ? selectedExtraFillings.contains(filling)
                  : selectedFillings.contains(filling);
              return CheckboxListTile(
                title: Text(filling.name),
                subtitle: Text(
                  filling.extraCostPerKg > 0
                      ? '(+\$${filling.extraCostPerKg.toStringAsFixed(0)} - Costo Fijo por Box)'
                      : '(Gratis)',
                ),
                value: isSelected,
                onChanged: (bool? value) {
                  setDialogState(() {
                    if (value == true) {
                      isExtraCost
                          ? selectedExtraFillings.add(filling)
                          : selectedFillings.add(filling);
                    } else {
                      isExtraCost
                          ? selectedExtraFillings.remove(filling)
                          : selectedFillings.remove(filling);
                    }
                    calculatePrice();
                  });
                },
                controlAffinity: ListTileControlAffinity.leading,
                dense: true,
                contentPadding: EdgeInsets.zero,
              );
            }

            Widget buildExtraKgCheckbox(CakeExtra extra) {
              bool isSelected = selectedExtrasKg.contains(extra);
              return CheckboxListTile(
                title: Text(extra.name),
                subtitle: Text(
                  '(+\$${extra.costPerKg.toStringAsFixed(0)} - Costo Fijo por Box)',
                ),
                value: isSelected,
                onChanged: (bool? value) {
                  setDialogState(() {
                    if (value == true) {
                      selectedExtrasKg.add(extra);
                    } else {
                      selectedExtrasKg.remove(extra);
                    }
                    calculatePrice();
                  });
                },
                controlAffinity: ListTileControlAffinity.leading,
                dense: true,
                contentPadding: EdgeInsets.zero,
              );
            }

            Widget buildExtraUnitSelector(CakeExtra extra) {
              UnitExtraSelection? selection = selectedExtrasUnit
                  .firstWhereOrNull((sel) => sel.extra == extra);
              bool isSelected = selection != null;

              return ListTile(
                leading: Checkbox(
                  value: isSelected,
                  onChanged: (bool? value) {
                    setDialogState(() {
                      if (value == true) {
                        selectedExtrasUnit.add(
                          UnitExtraSelection(extra: extra),
                        );
                      } else {
                        selectedExtrasUnit.removeWhere(
                          (sel) => sel.extra == extra,
                        );
                      }
                      calculatePrice();
                    });
                  },
                ),
                title: Text(extra.name),
                subtitle: Text(
                  '(+\$${extra.costPerUnit.toStringAsFixed(0)} c/u)',
                ),
                trailing: isSelected
                    ? SizedBox(
                        width: 60,
                        child: TextField(
                          controller: TextEditingController(
                            text: selection.quantity.toString(),
                          ),
                          keyboardType: TextInputType.number,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                          ],
                          textAlign: TextAlign.center,
                          decoration: const InputDecoration(labelText: 'Cant.'),
                          onChanged: (value) {
                            int qty = int.tryParse(value) ?? 1;
                            if (qty < 1) {
                              qty = 1;
                            }
                            selection.quantity = qty;
                            calculatePrice();
                          },
                        ),
                      )
                    : null,
                dense: true,
                contentPadding: EdgeInsets.zero,
              );
            }

            // --- HELPER WIDGET PARA ITEM DE MESA DULCE UNITARIO/POR TAMAÑO ---
            Widget buildMesaDulceItemSelector(Product product) {
              BoxMesaDulceSelection? selection = selectedMesaDulceItems
                  .firstWhereOrNull((sel) => sel.product == product);
              bool isSelected = selection != null;

              // Determinar el precio unitario base a mostrar
              String basePriceText;
              if (product.pricesBySize != null) {
                basePriceText = '(Tamaños)';
              } else if (product.unit == ProductUnit.dozen) {
                // Muestra precio por unidad, dividiendo por 12
                basePriceText =
                    '(~\$${(product.price / 12).toStringAsFixed(0)} c/u)';
              } else if (product.unit == ProductUnit.unit) {
                // Muestra precio por unidad
                basePriceText = '(+\$${product.price.toStringAsFixed(0)} c/u)';
              } else {
                basePriceText = '(Error de unidad)';
              }

              // Función centralizada para la selección
              void toggleSelection(bool? value) {
                setDialogState(() {
                  if (value == true) {
                    ProductUnit? defaultSize;
                    if (product.pricesBySize != null) {
                      // Si el producto es un bizcochuelo/tarta por tamaño, selecciona 20cm por defecto
                      defaultSize =
                          product.pricesBySize!.keys.firstWhereOrNull(
                            (s) => s == ProductUnit.size20cm,
                          ) ??
                          product.pricesBySize!.keys.first;
                    }

                    selectedMesaDulceItems.add(
                      BoxMesaDulceSelection(
                        product: product,
                        quantity: 1,
                        selectedSize: defaultSize, // Usa el tamaño por defecto
                      ),
                    );
                  } else {
                    selectedMesaDulceItems.removeWhere(
                      (sel) => sel.product == product,
                    );
                  }
                  calculatePrice();
                });
              }

              // Si el producto usa precios por tamaño (Tartas, Brownie Redondo)
              if (product.pricesBySize != null) {
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ListTile(
                      // Usamos ListTile y Checkbox manual
                      leading: Checkbox(
                        value: isSelected,
                        onChanged: toggleSelection,
                      ),
                      title: Text('${product.name} $basePriceText'),
                      onTap: () => toggleSelection(
                        !isSelected,
                      ), // Permite seleccionar al tocar la fila
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                    ),
                    if (isSelected)
                      Padding(
                        padding: const EdgeInsets.only(left: 32.0, bottom: 8.0),
                        child: DropdownButtonFormField<ProductUnit>(
                          value: selection.selectedSize,
                          items: product.pricesBySize!.keys
                              .map(
                                (size) => DropdownMenuItem(
                                  value: size,
                                  child: Text(
                                    '${getUnitText(size)} (\$${product.pricesBySize![size]!.toStringAsFixed(0)})',
                                  ),
                                ),
                              )
                              .toList(),
                          onChanged: (newSize) {
                            setDialogState(() {
                              selection.selectedSize = newSize;
                              calculatePrice();
                            });
                          },
                          decoration: const InputDecoration(
                            labelText: 'Tamaño',
                          ),
                        ),
                      ),
                  ],
                );
              }
              // Si el producto se cuenta por unidad (Docena o Unidad simple)
              else {
                return ListTile(
                  leading: Checkbox(
                    value: isSelected,
                    onChanged: toggleSelection,
                  ),
                  title: Text('${product.name} $basePriceText'),
                  onTap: () => toggleSelection(
                    !isSelected,
                  ), // Permite seleccionar al tocar la fila
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  // 🎯 TRAILING: El campo de cantidad compacto
                  trailing: isSelected
                      ? SizedBox(
                          width: 60, // Ancho pequeño para el campo de número
                          child: TextFormField(
                            // Usamos TextFormField sin controller
                            key: ValueKey(
                              product.name,
                            ), // Clave única para evitar errores de renderizado
                            initialValue: selection.quantity.toString(),
                            keyboardType: TextInputType.number,
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly,
                            ],
                            textAlign: TextAlign.center,
                            decoration: InputDecoration(
                              labelText: product.unit == ProductUnit.dozen
                                  ? 'Uds.'
                                  : 'Cant.',
                              contentPadding: const EdgeInsets.symmetric(
                                vertical: 8.0,
                                horizontal: 4.0,
                              ),
                              isDense: true,
                            ),
                            // Aquí actualizamos el modelo de datos directamente
                            onChanged: (value) {
                              int qty = int.tryParse(value) ?? 1;
                              if (qty < 1) {
                                qty = 1;
                              }

                              // 1. Actualizar el modelo de datos
                              selection.quantity = qty;

                              // 2. Notificar al StatefulBuilder más cercano (el del AlertDialog)
                              setDialogState(() {
                                calculatePrice();
                              });
                            },
                          ),
                        )
                      : null,
                );
              }
            }
            // -----------------------------------------------------

            return AlertDialog(
              title: Text(isEditing ? 'Editar Item Box' : 'Añadir Item Box'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // SELECTOR DE PRODUCTO/BOX
                    DropdownButtonFormField<Product>(
                      initialValue: selectedProduct,
                      items: boxProducts.map((Product product) {
                        return DropdownMenuItem<Product>(
                          value: product,
                          child: Text(
                            '${product.name} (\$${product.price.toStringAsFixed(0)})',
                          ),
                        );
                      }).toList(),
                      onChanged: (Product? newValue) {
                        setDialogState(() {
                          selectedProduct = newValue;
                          basePrice = newValue?.price ?? 0.0;
                          // Si cambia a/desde personalizado, ajusta la cantidad
                          if (newValue?.name == personalizedBoxName) {
                            qtyController.text = '1';
                          }
                          // 🎯 Limpiar selecciones de extras/rellenos si cambiamos de Box
                          selectedFillings = [];
                          selectedExtraFillings = [];
                          selectedExtrasKg = [];
                          selectedExtrasUnit = [];
                          selectedMesaDulceItems = [];
                          // 🎯 En Box Personalizado, el costo base empieza en 0.0, y en el predefinido se mantiene.
                          if (newValue?.name == personalizedBoxName) {
                            basePrice = 0.0;
                          } else {
                            basePrice = newValue?.price ?? 0.0;
                            // Opcional: Re-seleccionar la torta base por defecto para el Box predefinido
                            selectedBaseCake = smallCakeProducts
                                .firstWhereOrNull(
                                  (p) =>
                                      p.name ==
                                      'Mini Torta Personalizada (Base)',
                                );
                          }

                          calculatePrice();
                        });
                      },
                      decoration: const InputDecoration(labelText: 'Producto'),
                      isExpanded: true,
                    ),

                    // CAMPO DE CANTIDAD (OCULTAR SI ES PERSONALIZADO)
                    if (!isCurrentPersonalizedBox)
                      TextFormField(
                        controller: qtyController,
                        decoration: const InputDecoration(
                          labelText: 'Cantidad de Boxes',
                        ),
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                        ],
                        onChanged: (_) => setDialogState(calculatePrice),
                      ),

                    const SizedBox(height: 16),
                    const Divider(),

                    // --- SECCIÓN DE SELECCIÓN DE PRODUCTOS Y OPCIONES (SOLO PARA BOX PERSONALIZADO) ---
                    if (isCurrentPersonalizedBox)
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // ⬅️ NUEVO: SELECTOR DE TORTA BASE
                          Text(
                            'Base de Torta para el Box Personalizado (Opcional):',
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 8),
                          DropdownButtonFormField<Product>(
                            value: selectedBaseCake,
                            items: [
                              // Opción para no incluir ninguna torta
                              const DropdownMenuItem<Product>(
                                value: null,
                                child: Text(
                                  'No Incluir Torta Base (Solo Mesa Dulce)',
                                ),
                              ),
                              // Opciones de tortas
                              ...smallCakeProducts.map((Product product) {
                                return DropdownMenuItem<Product>(
                                  value: product,
                                  child: Text(
                                    '${product.name} (\$${product.price.toStringAsFixed(0)} Base)',
                                  ),
                                );
                              }),
                            ].toList(),
                            onChanged: (Product? newValue) {
                              setDialogState(() {
                                selectedBaseCake = newValue;
                                // Limpiar rellenos/extras si se deselecciona la torta base
                                if (newValue == null) {
                                  selectedFillings = [];
                                  selectedExtraFillings = [];
                                  selectedExtrasKg = [];
                                  selectedExtrasUnit = [];
                                }
                                calculatePrice();
                              });
                            },
                            decoration: const InputDecoration(
                              labelText: 'Tipo de Torta Base',
                            ),
                            isExpanded: true,
                          ),
                          const SizedBox(height: 16),

                          // Opciones de Rellenos/Extras solo si hay Torta Base seleccionada
                          if (selectedBaseCake != null) ...[
                            Text(
                              'Personalización de Torta Base:',
                              style: Theme.of(context).textTheme.titleMedium
                                  ?.copyWith(fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 8),
                            // Rellenos Incluidos (Mini Torta)
                            Text(
                              'Rellenos Incluidos (Mini Torta)',
                              style: Theme.of(context).textTheme.titleSmall,
                            ),
                            ...freeFillings.map(
                              (f) => buildFillingCheckbox(f, false),
                            ),
                            const SizedBox(height: 8),
                            // Rellenos con Costo Extra (Mini Torta)
                            Text(
                              'Rellenos con Costo Extra (Mini Torta)',
                              style: Theme.of(context).textTheme.titleSmall,
                            ),
                            ...extraCostFillings.map(
                              (f) => buildFillingCheckbox(f, true),
                            ),
                            const SizedBox(height: 8),
                            // Extras por Peso
                            Text(
                              'Extras por Peso (Costo Fijo/Box)',
                              style: Theme.of(context).textTheme.titleSmall,
                            ),
                            ...cakeExtras
                                .where((ex) => !ex.isPerUnit)
                                .map(buildExtraKgCheckbox),
                            const SizedBox(height: 8),
                            // Extras por Unidad
                            Text(
                              'Extras por Unidad (Costo por Unidad/Box)',
                              style: Theme.of(context).textTheme.titleSmall,
                            ),
                            ...cakeExtras
                                .where((ex) => ex.isPerUnit)
                                .map(buildExtraUnitSelector),
                            const SizedBox(height: 16),
                          ],

                          // Selector de Productos de Mesa Dulce
                          Text(
                            'Productos de Mesa Dulce a Incluir:',
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 8),
                          // Lista de productos de Mesa Dulce para seleccionar
                          ...mesaDulceProducts
                              .map(buildMesaDulceItemSelector)
                              .toList(),
                          const SizedBox(height: 16),
                        ],
                      )
                    // --- SECCIÓN DE PERSONALIZACIÓN (SOLO PARA BOX PREDEFINIDO) ---
                    else
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Personalización de Mini Torta/Contenido:',
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 8),
                          // 🎯 MANTENEMOS la lógica de Extras/Rellenos para el Box Predeterminado
                          // Rellenos Incluidos (Mini Torta)
                          Text(
                            'Rellenos Incluidos (Mini Torta)',
                            style: Theme.of(context).textTheme.titleSmall,
                          ),
                          ...freeFillings.map(
                            (f) => buildFillingCheckbox(f, false),
                          ),
                          const SizedBox(height: 8),
                          // Rellenos con Costo Extra (Mini Torta)
                          Text(
                            'Rellenos con Costo Extra (Mini Torta)',
                            style: Theme.of(context).textTheme.titleSmall,
                          ),
                          ...extraCostFillings.map(
                            (f) => buildFillingCheckbox(f, true),
                          ),
                          const SizedBox(height: 8),
                          // Extras por Peso
                          Text(
                            'Extras por Peso (Costo Fijo/Box)',
                            style: Theme.of(context).textTheme.titleSmall,
                          ),
                          ...cakeExtras
                              .where((ex) => !ex.isPerUnit)
                              .map(buildExtraKgCheckbox),
                          const SizedBox(height: 8),
                          // Extras por Unidad
                          Text(
                            'Extras por Unidad (Costo por Unidad/Box)',
                            style: Theme.of(context).textTheme.titleSmall,
                          ),
                          ...cakeExtras
                              .where((ex) => ex.isPerUnit)
                              .map(buildExtraUnitSelector),
                        ],
                      ),

                    // NOTAS Y AJUSTES MANUALES (Visibles siempre)
                    TextFormField(
                      controller: itemNotesController,
                      decoration: InputDecoration(
                        labelText: isCurrentPersonalizedBox
                            ? 'Notas para los ítems seleccionados'
                            : 'Notas Generales del Box (Sabores, temáticas)',
                        hintText:
                            'Ej: Detalles de decoración o personalización del box.',
                      ),
                      maxLines: 2,
                      textCapitalization: TextCapitalization.sentences,
                    ),
                    const SizedBox(height: 16),

                    TextFormField(
                      controller: adjustmentsController,
                      decoration: InputDecoration(
                        labelText:
                            'Ajuste Manual Adicional (SUMA al Precio Base Total \$)',
                        hintText: 'Ej: 500 (extra), -200 (descuento)',
                        prefixText:
                            '\$${calculatedTotalBasePrice.toStringAsFixed(0)} + ',
                      ),
                      keyboardType: const TextInputType.numberWithOptions(
                        signed: true,
                        decimal: false,
                      ),
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(RegExp(r'^-?\d*')),
                      ],
                      onChanged: (_) => setDialogState(calculatePrice),
                    ),
                    TextFormField(
                      controller: adjustmentNotesController,
                      decoration: const InputDecoration(
                        labelText: 'Notas del Ajuste/Descuento',
                        hintText: 'Ej: Descuento por promoción',
                      ),
                      maxLines: 2,
                      textCapitalization: TextCapitalization.sentences,
                    ),
                    const Divider(),

                    TextFormField(
                      controller: finalPriceController,
                      readOnly: true,
                      decoration: const InputDecoration(
                        labelText: 'Precio Final Item (Total)',
                        prefixText: '\$',
                      ),
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Fotos de Referencia (Opcional)',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    // ... (Sección de fotos)
                    Padding(
                      padding: const EdgeInsets.only(top: 8.0),
                      child: Wrap(
                        spacing: 8.0,
                        runSpacing: 8.0,
                        children: [
                          ...existingImageUrls.map((url) {
                            final bool isPlaceholder = url.startsWith(
                              'placeholder_',
                            );
                            final dynamic imageSource = isPlaceholder
                                ? _filesToUpload[url]
                                : url;
                            if (imageSource == null)
                              return const SizedBox.shrink();
                            return _buildImageThumbnail(
                              imageSource,
                              !isPlaceholder,
                              () => setDialogState(() {
                                if (isPlaceholder) _filesToUpload.remove(url);
                                existingImageUrls.remove(url);
                              }),
                            );
                          }).toList(),
                        ],
                      ),
                    ),
                    TextButton.icon(
                      icon: const Icon(Icons.photo_library),
                      label: const Text('Añadir Fotos'),
                      onPressed: () async {
                        final pickedFiles = await picker.pickMultiImage();
                        if (pickedFiles.isNotEmpty) {
                          setDialogState(() {
                            for (var file in pickedFiles) {
                              final String placeholderId =
                                  'placeholder_${DateTime.now().millisecondsSinceEpoch}_${file.name.replaceAll(' ', '_')}';
                              _filesToUpload[placeholderId] = file;
                              existingImageUrls.add(placeholderId);
                            }
                          });
                        }
                      },
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: const Text('Cancelar'),
                ),
                FilledButton(
                  style: FilledButton.styleFrom(),
                  onPressed: () {
                    if (selectedProduct == null) return;

                    final qty = isCurrentPersonalizedBox
                        ? 1
                        : int.tryParse(qtyController.text) ?? 0;
                    final itemNotes = itemNotesController.text.trim();
                    final adjustmentNotes = adjustmentNotesController.text
                        .trim();

                    if (qty <= 0 || calculatedTotalBasePrice <= 0) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            isCurrentPersonalizedBox &&
                                    calculatedTotalBasePrice <= 0
                                ? 'Debes seleccionar ítems y verificar precios.'
                                : 'Verifica la cantidad y el precio.',
                          ),
                        ),
                      );
                      return;
                    }
                    // Si es Box Personalizado, al menos un sub-item o la torta base debe estar seleccionada
                    if (isCurrentPersonalizedBox &&
                        selectedMesaDulceItems.isEmpty &&
                        selectedBaseCake == null) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            'Debes seleccionar al menos un ítem de Mesa Dulce o una Torta Base para el Box Personalizado.',
                          ),
                        ),
                      );
                      return;
                    }

                    final allImageUrls = existingImageUrls;

                    // 1. Calcular el Costo de los Extras (Costo calculado total - Precio Base original del Box).
                    final costOfExtras = calculatedTotalBasePrice - basePrice;

                    // 2. El totalAdjustment debe ser la SUMA de los extras (costOfExtras) + el ajuste manual (variable 'adjustments').
                    // 🚨 CORRECCIÓN DEL CÁLCULO DE TOTAL ADJUSTMENT:
                    final totalAdjustment = costOfExtras + adjustments;
                    // ⬆️ 'adjustments' es la variable del scope superior que fue actualizada en calculatePrice() con el valor del controlador.

                    final customization = {
                      'product_category': ProductCategory.box.name,
                      'box_type': selectedProduct!.name,
                      'manual_adjustment_value': adjustments,

                      // Personalización para Box Predefinido
                      if (!isCurrentPersonalizedBox) ...{
                        // 🎯 NO se guarda 'selected_base_cake' aquí para boxes predefinidos,
                        // ya que el precio ya lo incluye, pero se mantiene la info de rellenos/extras
                        // si el Box tiene una mini torta.
                        // Solo guardamos los extras de la Mini Torta:
                        'selected_extra_fillings': selectedExtraFillings
                            .map(
                              (f) => {
                                'name': f.name,
                                'price': f.extraCostPerKg,
                              },
                            )
                            .toList(),
                        'selected_extras_kg': selectedExtrasKg
                            .map(
                              (ex) => {'name': ex.name, 'price': ex.costPerKg},
                            )
                            .toList(),
                        'selected_extras_unit': selectedExtrasUnit
                            .map(
                              (sel) => {
                                'name': sel.extra.name,
                                'quantity': sel.quantity,
                                'price':
                                    sel.extra.costPerUnit, // <-- Agregar precio
                              },
                            )
                            .toList(),
                      },
                      // Personalización para Box Armado
                      if (isCurrentPersonalizedBox) ...{
                        // 🎯 NUEVO: Guardar la torta base si fue seleccionada
                        if (selectedBaseCake != null)
                          'selected_base_cake': selectedBaseCake?.name,
                        // Guardar la personalización de la torta base si existe
                        if (selectedBaseCake != null) ...{
                          'selected_fillings': selectedFillings
                              .map((f) => f.name)
                              .toList(),
                          'selected_extra_fillings': selectedExtraFillings
                              .map(
                                (f) => {
                                  'name': f.name,
                                  'price': f.extraCostPerKg,
                                },
                              )
                              .toList(),
                          'selected_extras_kg': selectedExtrasKg
                              .map(
                                (ex) => {
                                  'name': ex.name,
                                  'price': ex.costPerKg,
                                },
                              )
                              .toList(),
                          'selected_extras_unit': selectedExtrasUnit
                              .map(
                                (sel) => {
                                  'name': sel.extra.name,
                                  'quantity': sel.quantity,
                                  'price': sel
                                      .extra
                                      .costPerUnit, // <-- Agregar precio
                                },
                              )
                              .toList(),
                        },
                        // Guardar los ítems de Mesa Dulce
                        'selected_mesa_dulce_items': selectedMesaDulceItems
                            .map(
                              (sel) => {
                                'name': sel.product.name,
                                'quantity': sel.quantity,
                                if (sel.selectedSize != null)
                                  'selected_size': sel.selectedSize!.name,
                              },
                            )
                            .toList(),
                      },

                      if (itemNotes.isNotEmpty) 'item_notes': itemNotes,
                      if (allImageUrls.isNotEmpty) 'photo_urls': allImageUrls,
                    };
                    customization.removeWhere(
                      (key, value) => (value is List && value.isEmpty),
                    );

                    final newItem = OrderItem(
                      id: isEditing ? existingItem.id : null,
                      name: selectedProduct!.name,
                      qty: qty,
                      basePrice: selectedProduct!
                          .price, // Usamos el precio original del producto
                      adjustments:
                          totalAdjustment, // Ajuste es la diferencia de precio
                      customizationNotes: adjustmentNotes.isEmpty
                          ? null
                          : adjustmentNotes,
                      customizationJson: customization,
                    );

                    _updateItemsAndRecalculate(() {
                      if (isEditing) {
                        _items[itemIndex!] = newItem;
                      } else {
                        _items.add(newItem);
                      }
                    });

                    if (dialogContext.mounted) {
                      Navigator.pop(dialogContext);
                    }
                  },
                  child: Text(isEditing ? 'Guardar Cambios' : 'Agregar'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _addCakeDialog({OrderItem? existingItem, int? itemIndex}) {
    final bool isEditing = existingItem != null;
    Map<String, dynamic> customData = isEditing
        ? (existingItem.customizationJson ?? {})
        : {};

    Product? selectedCakeType = isEditing
        ? cakeProducts.firstWhereOrNull((p) => p.name == existingItem.name)
        : cakeProducts.first;

    // Bandera para identificar la Mini Torta
    const miniCakeName = 'Mini Torta Personalizada (Base)';

    final weightController = TextEditingController(
      // Si se está editando una mini torta, forzar a '1.0' para el cálculo interno.
      text: existingItem?.name == miniCakeName
          ? '1.0'
          : customData['weight_kg']?.toString() ?? '1.0',
    );
    final adjustmentsController = TextEditingController(
      text: isEditing ? existingItem.adjustments.toStringAsFixed(0) : '0',
    );
    final multiplierAdjustmentController = TextEditingController(
      // Si se está editando una mini torta, forzar a '0'
      text: existingItem?.name == miniCakeName
          ? '0'
          : customData['multiplier_adjustment_per_kg']?.toStringAsFixed(0) ??
                '0',
    );
    final notesController = TextEditingController(
      text: customData['item_notes'] as String? ?? '',
    );
    final adjustmentNotesController = TextEditingController(
      text: isEditing ? existingItem.customizationNotes ?? '' : '',
    );

    List<Filling> selectedFillings =
        (customData['selected_fillings'] as List<dynamic>? ?? [])
            .map(
              (name) => allFillings.firstWhereOrNull(
                (f) => f.name == name?.toString(),
              ),
            )
            .whereType<Filling>()
            .toList();
    List<Filling> selectedExtraFillings =
        (customData['selected_extra_fillings'] as List<dynamic>? ?? [])
            .map((data) {
              if (data is Map) {
                final name = data['name']?.toString();
                return extraCostFillings.firstWhereOrNull(
                  (f) => f.name == name,
                );
              }
              // Lógica anterior para (data is String)
              if (data is String) {
                return extraCostFillings.firstWhereOrNull(
                  (f) => f.name == data,
                );
              }
              return null;
            })
            .whereType<Filling>()
            .toList();
    List<CakeExtra> selectedExtrasKg =
        (customData['selected_extras_kg'] as List<dynamic>? ?? [])
            .map((data) {
              if (data is Map) {
                final name = data['name']?.toString();
                return cakeExtras.firstWhereOrNull(
                  (ex) => ex.name == name && !ex.isPerUnit,
                );
              }
              // Lógica anterior para (data is String)
              if (data is String) {
                return cakeExtras.firstWhereOrNull(
                  (ex) => ex.name == data && !ex.isPerUnit,
                );
              }
              return null;
            })
            .whereType<CakeExtra>()
            .toList();
    List<UnitExtraSelection> selectedExtrasUnit =
        (customData['selected_extras_unit'] as List<dynamic>? ?? [])
            .map((data) {
              if (data is Map) {
                final name = data['name']?.toString();
                final extra = cakeExtras.firstWhereOrNull(
                  (ex) => ex.name == name && ex.isPerUnit,
                );
                if (extra != null) {
                  final quantity = toInt(data['quantity'], fallback: 1);
                  return UnitExtraSelection(
                    extra: extra,
                    quantity: quantity >= 1 ? quantity : 1,
                  );
                }
              }
              return null;
            })
            .whereType<UnitExtraSelection>()
            .toList();

    final ImagePicker picker = ImagePicker();
    List<String> existingImageUrls = List<String>.from(
      customData['photo_urls'] ?? [],
    );

    final calculatedBasePriceController = TextEditingController();
    final finalPriceController = TextEditingController();

    double calculatedBasePrice = 0.0;
    double manualAdjustments = 0.0;
    double multiplierAdjustment = 0.0;

    void calculateCakePrice() {
      if (selectedCakeType == null) {
        calculatedBasePriceController.text = 'N/A';
        finalPriceController.text = 'N/A';
        return;
      }

      // --- 1. DEFINIR CONSTANTES PRIMERO ---
      // (Si ya tenés estas constantes definidas AFUERA de la función, podés borrar estas 2 líneas)
      const miniCakeName = 'Mini Torta Personalizada (Base)';
      const microCakeName = 'Micro Torta (Base)'; // <-- CONFIRMA ESTE NOMBRE

      // --- 2. USAR LAS CONSTANTES PARA TODO ---
      final bool isMiniCake = selectedCakeType?.name == miniCakeName;
      final bool isMicroCake = selectedCakeType?.name == microCakeName;
      final bool isSmallCake =
          isMiniCake ||
          isMicroCake; // <-- Esta es la única variable que importa

      // --- Lógica de Peso y Multiplicador (AHORA USA isSmallCake) ---
      double weight =
          isSmallCake // <-- Corregido
          ? 1.0 // Fuerza el peso a 1.0 si es Torta Chica
          : double.tryParse(weightController.text.replaceAll(',', '.')) ?? 0.0;

      manualAdjustments = double.tryParse(adjustmentsController.text) ?? 0.0;

      multiplierAdjustment =
          isSmallCake // <-- Corregido
          ? 0.0 // Fuerza el multiplicador a 0 si es Torta Chica
          : double.tryParse(multiplierAdjustmentController.text) ?? 0.0;

      if (weight <= 0 && !isSmallCake) {
        // <-- Corregido
        // Solo valida peso > 0 si NO es Torta Chica
        calculatedBasePriceController.text = 'N/A';
        finalPriceController.text = 'N/A';
        return;
      }

      // El 'base' ya está bien porque 'weight' y 'multiplierAdjustment' son correctos
      double base = (selectedCakeType!.price + multiplierAdjustment) * weight;

      // Multiplicador para Extras y Rellenos por KG
      double multiplier;
      if (isSmallCake) {
        // Si es Torta Chica, el multiplicador es 0.5 (mitad de precio)
        multiplier = 0.5;
      } else {
        // Si es Torta normal, el multiplicador es el peso en KG
        multiplier = weight;
      }

      // (El resto de tu lógica de cálculo de precios ya estaba perfecta)
      double extraFillingsPrice = selectedExtraFillings.fold(
        0.0,
        (sum, f) => sum + (f.extraCostPerKg * multiplier),
      );
      double extrasKgPrice = selectedExtrasKg.fold(
        0.0,
        (sum, ex) => sum + (ex.costPerKg * multiplier),
      );

      // Extras por Unidad (no dependen del peso)
      double extrasUnitPrice = selectedExtrasUnit.fold(
        0.0,
        (sum, sel) => sum + (sel.extra.costPerUnit * sel.quantity),
      );

      calculatedBasePrice =
          base + extraFillingsPrice + extrasKgPrice + extrasUnitPrice;
      double finalPrice = calculatedBasePrice + manualAdjustments;

      calculatedBasePriceController.text = calculatedBasePrice.toStringAsFixed(
        0,
      );
      finalPriceController.text = finalPrice.toStringAsFixed(0);
    }

    WidgetsBinding.instance.addPostFrameCallback((_) => calculateCakePrice());

    showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final isCurrentMiniCake = selectedCakeType?.name == miniCakeName;

            Widget buildFillingCheckbox(Filling filling, bool isExtraCost) {
              bool isSelected = isExtraCost
                  ? selectedExtraFillings.contains(filling)
                  : selectedFillings.contains(filling);
              return CheckboxListTile(
                title: Text(filling.name),
                subtitle: Text(
                  // Ajuste de texto para Mini Torta
                  isCurrentMiniCake
                      ? (filling.extraCostPerKg > 0
                            ? '(+\$${filling.extraCostPerKg.toStringAsFixed(0)})'
                            : '(Gratis)')
                      : (isExtraCost
                            ? '(+\$${filling.extraCostPerKg.toStringAsFixed(0)}/kg)'
                            : '(Gratis)'),
                ),
                value: isSelected,
                onChanged: (bool? value) {
                  setDialogState(() {
                    if (value == true) {
                      if (isExtraCost) {
                        selectedExtraFillings.add(filling);
                      } else {
                        selectedFillings.add(filling);
                      }
                    } else {
                      if (isExtraCost) {
                        selectedExtraFillings.remove(filling);
                      } else {
                        selectedFillings.remove(filling);
                      }
                    }
                    calculateCakePrice();
                  });
                },
                controlAffinity: ListTileControlAffinity.leading,
                dense: true,
                contentPadding: EdgeInsets.zero,
              );
            }

            Widget buildExtraKgCheckbox(CakeExtra extra) {
              bool isSelected = selectedExtrasKg.contains(extra);
              return CheckboxListTile(
                title: Text(extra.name),
                // Ajuste de texto para Mini Torta
                subtitle: Text(
                  isCurrentMiniCake
                      ? '(+\$${extra.costPerKg.toStringAsFixed(0)})'
                      : '(+\$${extra.costPerKg.toStringAsFixed(0)}/kg)',
                ),
                value: isSelected,
                onChanged: (bool? value) {
                  setDialogState(() {
                    if (value == true) {
                      selectedExtrasKg.add(extra);
                    } else {
                      selectedExtrasKg.remove(extra);
                    }
                    calculateCakePrice();
                  });
                },
                controlAffinity: ListTileControlAffinity.leading,
                dense: true,
                contentPadding: EdgeInsets.zero,
              );
            }

            Widget buildExtraUnitSelector(CakeExtra extra) {
              UnitExtraSelection? selection = selectedExtrasUnit
                  .firstWhereOrNull((sel) => sel.extra == extra);
              bool isSelected = selection != null;

              return ListTile(
                leading: Checkbox(
                  value: isSelected,
                  onChanged: (bool? value) {
                    setDialogState(() {
                      if (value == true) {
                        selectedExtrasUnit.add(
                          UnitExtraSelection(extra: extra),
                        );
                      } else {
                        selectedExtrasUnit.removeWhere(
                          (sel) => sel.extra == extra,
                        );
                      }
                      calculateCakePrice();
                    });
                  },
                ),
                title: Text(extra.name),
                subtitle: Text(
                  '(+\$${extra.costPerUnit.toStringAsFixed(0)} c/u)',
                ),
                trailing: isSelected
                    ? SizedBox(
                        width: 60,
                        child: TextField(
                          controller: TextEditingController(
                            text: selection.quantity.toString(),
                          ),
                          keyboardType: TextInputType.number,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                          ],
                          textAlign: TextAlign.center,
                          decoration: const InputDecoration(labelText: 'Cant.'),
                          onChanged: (value) {
                            int qty = int.tryParse(value) ?? 1;
                            if (qty < 1) {
                              qty = 1;
                            }
                            selection.quantity =
                                qty; // Usar selection! ya que isSelected es true
                            calculateCakePrice();
                          },
                        ),
                      )
                    : null,
                dense: true,
                contentPadding: EdgeInsets.zero,
              );
            }

            return AlertDialog(
              title: Text(isEditing ? 'Editar Torta' : 'Añadir Torta'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    DropdownButtonFormField<Product>(
                      initialValue: selectedCakeType,
                      items: cakeProducts.map((Product product) {
                        final isCurrentProductMiniCake =
                            product.name == miniCakeName;
                        return DropdownMenuItem<Product>(
                          value: product,
                          child: Text(
                            // Muestra el precio base y la unidad correcta
                            '${product.name} (\$${product.price.toStringAsFixed(0)}${isCurrentProductMiniCake ? '/u' : '/kg'})',
                            overflow: TextOverflow.ellipsis,
                          ),
                        );
                      }).toList(),
                      onChanged: (Product? newValue) {
                        setDialogState(() {
                          selectedCakeType = newValue;
                          final isNewValueMiniCake =
                              newValue?.name == miniCakeName;

                          if (isNewValueMiniCake) {
                            // Si es Mini Torta, forzar valores y texto
                            weightController.text = '1.0';
                            multiplierAdjustmentController.text = '0';
                          } else if (isCurrentMiniCake) {
                            // Si veníamos de Mini Torta y cambiamos a Torta KG, inicializar campos
                            weightController.text = '1.0';
                            multiplierAdjustmentController.text = '0';
                          }

                          calculateCakePrice();
                        });
                      },
                      decoration: const InputDecoration(
                        labelText: 'Tipo de Torta',
                      ),
                      isExpanded: true,
                    ),
                    const SizedBox(height: 16),

                    // --- PESO ESTIMADO (OCULTAR PARA MINI TORTA) ---
                    if (!isCurrentMiniCake)
                      Column(
                        children: [
                          TextFormField(
                            controller: weightController,
                            decoration: const InputDecoration(
                              labelText: 'Peso Estimado (kg)',
                              hintText: 'Ej: 1.5',
                            ),
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            inputFormatters: [
                              FilteringTextInputFormatter.allow(
                                RegExp(r'^\d*[\.,]?\d{0,2}'),
                              ),
                            ],
                            onChanged: (_) =>
                                setDialogState(calculateCakePrice),
                          ),
                          const SizedBox(height: 16),
                        ],
                      ),

                    // --- AJUSTE MULTIPLICADOR (OCULTAR PARA MINI TORTA) ---
                    if (!isCurrentMiniCake)
                      Column(
                        children: [
                          TextFormField(
                            controller: multiplierAdjustmentController,
                            decoration: InputDecoration(
                              labelText:
                                  'Ajuste Multiplicador al Precio Base/kg (\$)',
                              hintText: 'Ej: 1000 (+\$1000/kg extra)',
                              prefixText:
                                  '\$${selectedCakeType?.price.toStringAsFixed(0) ?? '0'} + ',
                            ),
                            keyboardType: const TextInputType.numberWithOptions(
                              signed: true,
                              decimal: false,
                            ),
                            inputFormatters: [
                              FilteringTextInputFormatter.allow(
                                RegExp(r'^-?\d*'),
                              ),
                            ],
                            onChanged: (_) =>
                                setDialogState(calculateCakePrice),
                          ),
                          const SizedBox(height: 16),
                        ],
                      ),

                    // Rellenos y Extras
                    Text(
                      'Rellenos Incluidos (Seleccionar)',
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                    ...freeFillings.map((f) => buildFillingCheckbox(f, false)),
                    const SizedBox(height: 16),
                    Text(
                      'Rellenos con Costo Extra (Seleccionar)',
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                    ...extraCostFillings.map(
                      (f) => buildFillingCheckbox(f, true),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Extras (Costo por Kg)',
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                    ...cakeExtras
                        .where((ex) => !ex.isPerUnit)
                        .map(buildExtraKgCheckbox),
                    const SizedBox(height: 16),
                    Text(
                      'Extras (Costo por Unidad)',
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                    ...cakeExtras
                        .where((ex) => ex.isPerUnit)
                        .map(buildExtraUnitSelector),
                    const SizedBox(height: 16),
                    TextField(
                      controller: notesController,
                      decoration: const InputDecoration(
                        labelText:
                            'Notas Específicas (ej. diseño, detalles fondant)',
                      ),
                      maxLines: 3,
                    ),
                    const SizedBox(height: 16),
                    const Divider(),
                    const Text(
                      'Fotos de Referencia (Opcional)',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    Padding(
                      padding: const EdgeInsets.only(top: 8.0),
                      child: Wrap(
                        spacing: 8.0,
                        runSpacing: 8.0,
                        children: [
                          ...existingImageUrls.map((url) {
                            final bool isPlaceholder = url.startsWith(
                              'placeholder_',
                            );
                            final dynamic imageSource = isPlaceholder
                                ? _filesToUpload[url]
                                : url;

                            if (imageSource == null) {
                              return const SizedBox.shrink();
                            }

                            return _buildImageThumbnail(
                              imageSource,
                              !isPlaceholder,
                              () => setDialogState(() {
                                if (isPlaceholder) _filesToUpload.remove(url);
                                existingImageUrls.remove(url);
                              }),
                            );
                          }).toList(),
                        ],
                      ),
                    ),
                    TextButton.icon(
                      icon: const Icon(Icons.photo_library),
                      label: const Text('Añadir Fotos'),
                      onPressed: () async {
                        final pickedFiles = await picker.pickMultiImage();
                        if (pickedFiles.isNotEmpty) {
                          setDialogState(() {
                            for (var file in pickedFiles) {
                              final String placeholderId =
                                  'placeholder_${DateTime.now().millisecondsSinceEpoch}_${file.name.replaceAll(' ', '_')}';
                              _filesToUpload[placeholderId] = file;
                              existingImageUrls.add(placeholderId);
                            }
                          });
                        }
                      },
                    ),
                    const Divider(),
                    TextFormField(
                      controller: calculatedBasePriceController,
                      readOnly: true,
                      decoration: const InputDecoration(
                        labelText: 'Precio Calculado',
                        prefixText: '\$',
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: adjustmentsController,
                      decoration: InputDecoration(
                        labelText:
                            'Ajuste Manual Adicional (SUMA al Precio Total del Item \$)',
                        hintText: 'Ej: 5000 (extra), -2000 (descuento)',
                        prefixText: '${calculatedBasePriceController.text} + ',
                      ),
                      keyboardType: const TextInputType.numberWithOptions(
                        signed: true,
                        decimal: false,
                      ),
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(RegExp(r'^-?\d*')),
                      ],
                      onChanged: (_) => setDialogState(calculateCakePrice),
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: adjustmentNotesController,
                      decoration: const InputDecoration(
                        labelText: 'Notas del Ajuste Manual',
                      ),
                      textCapitalization: TextCapitalization.sentences,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: finalPriceController,
                      readOnly: true,
                      decoration: const InputDecoration(
                        labelText: 'Precio Final Item',
                        prefixText: '\$',
                      ),
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: const Text('Cancelar'),
                ),
                FilledButton(
                  style: FilledButton.styleFrom(),
                  onPressed: () {
                    if (selectedCakeType == null) return;

                    // Obtener peso final (1.0 si es Mini Torta, sino el valor del campo)
                    final weight = isCurrentMiniCake
                        ? 1.0
                        : double.tryParse(
                                weightController.text.replaceAll(',', '.'),
                              ) ??
                              0.0;

                    // Obtener ajuste multiplicador (0.0 si es Mini Torta, sino el valor del campo)
                    final multiplierAdjustmentValue = isCurrentMiniCake
                        ? 0.0
                        : double.tryParse(
                                multiplierAdjustmentController.text,
                              ) ??
                              0.0;

                    final adjustmentNotes = adjustmentNotesController.text
                        .trim();

                    if (weight <= 0 && !isCurrentMiniCake) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('El peso debe ser mayor a 0.'),
                        ),
                      );
                      return;
                    }

                    final allImageUrls = existingImageUrls;

                    final customization = {
                      'product_category': selectedCakeType!.category.name,
                      'cake_type': selectedCakeType!.name,
                      'weight_kg': weight,
                      // Solo guardar el ajuste multiplicador si NO es Mini Torta
                      if (!isCurrentMiniCake)
                        'multiplier_adjustment_per_kg':
                            multiplierAdjustmentValue,
                      'selected_fillings': selectedFillings
                          .map((f) => f.name)
                          .toList(),
                      'selected_extra_fillings': selectedExtraFillings
                          .map(
                            (f) => {
                              'name': f.name,
                              'price': f.extraCostPerKg, // <-- AÑADIR ESTO
                            },
                          )
                          .toList(),
                      'selected_extras_kg': selectedExtrasKg
                          .map(
                            (ex) => {
                              'name': ex.name,
                              'price': ex.costPerKg, // <-- AÑADIR ESTO
                            },
                          )
                          .toList(),
                      'selected_extras_unit': selectedExtrasUnit
                          .map(
                            (sel) => {
                              'name': sel.extra.name,
                              'quantity': sel.quantity,
                              'price': sel.extra.costPerUnit,
                            },
                          )
                          .toList(),
                      if (notesController.text.trim().isNotEmpty)
                        'item_notes': notesController.text.trim(),
                      if (allImageUrls.isNotEmpty) 'photo_urls': allImageUrls,
                    };
                    customization.removeWhere(
                      (key, value) => (value is List && value.isEmpty),
                    );

                    final newItem = OrderItem(
                      id: isEditing ? existingItem.id : null,
                      name: selectedCakeType!.name,
                      qty: 1, // La cantidad es 1 para la torta/mini torta
                      basePrice: calculatedBasePrice,
                      adjustments: manualAdjustments,
                      customizationNotes: adjustmentNotes.isEmpty
                          ? null
                          : adjustmentNotes,
                      customizationJson: customization,
                    );

                    _updateItemsAndRecalculate(() {
                      if (isEditing) {
                        _items[itemIndex!] = newItem;
                      } else {
                        _items.add(newItem);
                      }
                    });

                    if (dialogContext.mounted) {
                      Navigator.pop(dialogContext);
                    }
                  },
                  child: Text(isEditing ? 'Guardar Cambios' : 'Agregar'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _addMesaDulceDialog({OrderItem? existingItem, int? itemIndex}) {
    final bool isEditing = existingItem != null;
    Map<String, dynamic> customData = isEditing
        ? (existingItem.customizationJson ?? {})
        : {};

    Product? selectedProduct = isEditing
        ? mesaDulceProducts.firstWhereOrNull((p) => p.name == existingItem.name)
        : mesaDulceProducts.first;

    ProductUnit? selectedSize;
    double basePrice = 0.0;
    double adjustments = isEditing ? existingItem.adjustments : 0.0;
    bool isHalfDozen = customData['is_half_dozen'] as bool? ?? false;

    if (selectedProduct?.pricesBySize != null) {
      final sizeName = customData['selected_size'] as String?;
      if (sizeName != null) {
        try {
          selectedSize = ProductUnit.values.byName(sizeName);
        } catch (_) {}
      }
      if (selectedSize == null ||
          !selectedProduct!.pricesBySize!.containsKey(selectedSize)) {
        selectedSize = selectedProduct!.pricesBySize!.keys.first;
      }
    }

    final qtyController = TextEditingController(
      text: isEditing ? existingItem.qty.toString() : '1',
    );
    final adjustmentsController = TextEditingController(
      text: adjustments.toStringAsFixed(0),
    );
    final notesController = TextEditingController(
      text: isEditing ? existingItem.customizationNotes ?? '' : '',
    );
    final itemNotesController = TextEditingController(
      text: customData['item_notes'] as String? ?? '',
    );

    final ImagePicker picker = ImagePicker();
    List<String> existingImageUrls = List<String>.from(
      customData['photo_urls'] ?? [],
    );
    // 🚨 ELIMINADO: List<XFile> newImageFiles = [];

    final finalPriceController = TextEditingController();

    double manualAdjustments = 0.0;

    void calculateMesaDulcePrice() {
      if (selectedProduct == null) {
        finalPriceController.text = 'N/A';
        return;
      }

      int qty = int.tryParse(qtyController.text) ?? 0;
      manualAdjustments = double.tryParse(adjustmentsController.text) ?? 0.0;

      if (qty <= 0) {
        finalPriceController.text = 'N/A';
        return;
      }

      double unitBasePrice = 0.0;
      if (selectedProduct!.pricesBySize != null) {
        if (selectedSize == null) {
          finalPriceController.text = 'Seleccione tamaño';
          return;
        }
        unitBasePrice = getPriceBySize(selectedProduct!, selectedSize!) ?? 0.0;
        if (qtyController.text != '1') {
          qtyController.text = '1';
          qty = 1;
        }
      } else if (selectedProduct!.allowHalfDozen && isHalfDozen) {
        unitBasePrice =
            selectedProduct!.halfDozenPrice ?? (selectedProduct!.price / 2);
      } else {
        unitBasePrice = selectedProduct!.price;
      }

      basePrice = unitBasePrice;
      double finalUnitPrice = basePrice + manualAdjustments;
      double totalItemPrice = finalUnitPrice * qty;
      finalPriceController.text = totalItemPrice.toStringAsFixed(0);
    }

    WidgetsBinding.instance.addPostFrameCallback(
      (_) => calculateMesaDulcePrice(),
    );

    showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            Widget buildQuantityOrSizeInput() {
              if (selectedProduct == null) return const SizedBox.shrink();
              if (selectedProduct!.pricesBySize != null) {
                List<ProductUnit> availableSizes = selectedProduct!
                    .pricesBySize!
                    .keys
                    .toList();
                if (selectedSize == null ||
                    !availableSizes.contains(selectedSize)) {
                  selectedSize = availableSizes.first;
                  WidgetsBinding.instance.addPostFrameCallback(
                    (_) => calculateMesaDulcePrice(),
                  );
                }
                return DropdownButtonFormField<ProductUnit>(
                  value: selectedSize,
                  items: availableSizes
                      .map(
                        (size) => DropdownMenuItem(
                          value: size,
                          child: Text(getUnitText(size)),
                        ),
                      )
                      .toList(),
                  onChanged: (ProductUnit? newValue) {
                    setDialogState(() {
                      selectedSize = newValue;
                      calculateMesaDulcePrice();
                    });
                  },
                  decoration: const InputDecoration(labelText: 'Tamaño'),
                );
              } else if (selectedProduct!.allowHalfDozen) {
                return Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: qtyController,
                            decoration: InputDecoration(
                              labelText: isHalfDozen
                                  ? 'Cantidad (Medias Docenas)'
                                  : 'Cantidad (Docenas)',
                            ),
                            keyboardType: TextInputType.number,
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly,
                            ],
                            onChanged: (_) =>
                                setDialogState(calculateMesaDulcePrice),
                          ),
                        ),
                        const SizedBox(width: 10),
                        ChoiceChip(
                          label: const Text('Media Docena'),
                          selected: isHalfDozen,
                          onSelected: (selected) {
                            setDialogState(() {
                              isHalfDozen = selected;
                              calculateMesaDulcePrice();
                            });
                          },
                          selectedColor: Theme.of(
                            context,
                          ).colorScheme.secondary,
                        ),
                      ],
                    ),
                  ],
                );
              } else {
                return TextFormField(
                  controller: qtyController,
                  decoration: InputDecoration(
                    labelText:
                        'Cantidad (${getUnitText(selectedProduct!.unit, plural: true)})',
                  ),
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  onChanged: (_) => setDialogState(calculateMesaDulcePrice),
                );
              }
            }

            return AlertDialog(
              title: Text(isEditing ? 'Editar Item' : 'Añadir Item Mesa Dulce'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    DropdownButtonFormField<Product>(
                      initialValue: selectedProduct,
                      items: mesaDulceProducts.map((Product product) {
                        String priceSuffix = '';
                        if (product.unit == ProductUnit.dozen) {
                          priceSuffix = '/doc';
                        } else if (product.pricesBySize != null) {
                          priceSuffix = '(ver tamaños)';
                        } else if (product.unit == ProductUnit.unit) {
                          priceSuffix = '/u';
                        }
                        return DropdownMenuItem<Product>(
                          value: product,
                          child: Text(
                            '${product.name} ${product.price > 0 ? '\$${product.price.toStringAsFixed(0)}$priceSuffix' : priceSuffix}',
                            overflow: TextOverflow.ellipsis,
                          ),
                        );
                      }).toList(),
                      onChanged: (Product? newValue) {
                        setDialogState(() {
                          selectedProduct = newValue;
                          if (newValue?.pricesBySize == null) {
                            selectedSize = null;
                          }
                          if (newValue?.allowHalfDozen == false) {
                            isHalfDozen = false;
                          }
                          calculateMesaDulcePrice();
                        });
                      },
                      decoration: const InputDecoration(labelText: 'Producto'),
                      isExpanded: true,
                    ),
                    const SizedBox(height: 16),
                    buildQuantityOrSizeInput(),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: adjustmentsController,
                      decoration: InputDecoration(
                        labelText: 'Ajuste Manual al Precio Unitario (\$)',
                        hintText: 'Ej: 50 (extra), -20 (desc)',
                        prefixText: '${basePrice.toStringAsFixed(0)} + ',
                      ),
                      keyboardType: const TextInputType.numberWithOptions(
                        signed: true,
                        decimal: false,
                      ),
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(RegExp(r'^-?\d*')),
                      ],
                      onChanged: (_) => setDialogState(calculateMesaDulcePrice),
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: notesController,
                      decoration: const InputDecoration(
                        labelText: 'Notas del Ajuste',
                        hintText: 'Ej: Diseño especial galletas, etc.',
                      ),
                      maxLines: 2,
                      textCapitalization: TextCapitalization.sentences,
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: itemNotesController,
                      decoration: const InputDecoration(
                        labelText: 'Notas Generales del Item',
                      ),
                      maxLines: 2,
                      textCapitalization: TextCapitalization.sentences,
                    ),
                    const SizedBox(height: 16),
                    const Divider(),
                    const Text(
                      'Fotos de Referencia (Opcional)',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    Padding(
                      padding: const EdgeInsets.only(top: 8.0),
                      child: Wrap(
                        spacing: 8.0,
                        runSpacing: 8.0,
                        children: [
                          ...existingImageUrls.map((url) {
                            final bool isPlaceholder = url.startsWith(
                              'placeholder_',
                            );
                            final dynamic imageSource = isPlaceholder
                                ? _filesToUpload[url]
                                : url;

                            if (imageSource == null) {
                              return const SizedBox.shrink();
                            }

                            return _buildImageThumbnail(
                              imageSource,
                              !isPlaceholder,
                              () => setDialogState(() {
                                if (isPlaceholder) {
                                  _filesToUpload.remove(url);
                                }
                                existingImageUrls.remove(url);
                              }),
                            );
                          }).toList(),
                        ],
                      ),
                    ),
                    TextButton.icon(
                      icon: const Icon(Icons.photo_library),
                      label: const Text('Añadir Fotos'),
                      onPressed: () async {
                        final pickedFiles = await picker.pickMultiImage();
                        if (pickedFiles.isNotEmpty) {
                          setDialogState(() {
                            for (var file in pickedFiles) {
                              final String placeholderId =
                                  'placeholder_${DateTime.now().millisecondsSinceEpoch}_${file.name.replaceAll(' ', '_')}';
                              _filesToUpload[placeholderId] = file;
                              existingImageUrls.add(placeholderId);
                            }
                          });
                        }
                      },
                    ),
                    const Divider(),
                    TextFormField(
                      controller: finalPriceController,
                      readOnly: true,
                      decoration: const InputDecoration(
                        labelText: 'Precio Final Item (Total)',
                        prefixText: '\$',
                      ),
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: const Text('Cancelar'),
                ),
                FilledButton(
                  style: FilledButton.styleFrom(),
                  onPressed: () {
                    if (selectedProduct == null) return;

                    final qty = int.tryParse(qtyController.text) ?? 0;
                    final adjustmentNotes = notesController.text.trim();
                    final itemNotes = itemNotesController.text.trim();

                    if (qty <= 0 ||
                        basePrice <= 0 ||
                        (selectedProduct!.pricesBySize != null &&
                            selectedSize == null)) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Verifica la cantidad y/o tamaño.'),
                        ),
                      );
                      return;
                    }

                    final allImageUrls = existingImageUrls;

                    final customization = {
                      'product_category': selectedProduct!.category.name,
                      'product_unit': selectedProduct!.unit.name,
                      if (selectedProduct!.pricesBySize != null)
                        'selected_size': selectedSize!.name,
                      if (selectedProduct!.allowHalfDozen)
                        'is_half_dozen': isHalfDozen,
                      if (itemNotes.isNotEmpty) 'item_notes': itemNotes,
                      if (allImageUrls.isNotEmpty) 'photo_urls': allImageUrls,
                    };
                    customization.removeWhere(
                      (key, value) => (value is List && value.isEmpty),
                    );

                    final newItem = OrderItem(
                      id: isEditing ? existingItem.id : null,
                      name: selectedProduct!.name,
                      qty: qty,
                      basePrice: basePrice,
                      adjustments: manualAdjustments,
                      customizationNotes: adjustmentNotes.isEmpty
                          ? null
                          : adjustmentNotes,
                      customizationJson: customization,
                    );

                    _updateItemsAndRecalculate(() {
                      if (isEditing) {
                        _items[itemIndex!] = newItem;
                      } else {
                        _items.add(newItem);
                      }
                    });

                    if (dialogContext.mounted) {
                      Navigator.pop(dialogContext);
                    }
                  },
                  child: Text(isEditing ? 'Guardar Cambios' : 'Agregar'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // --- WIDGET HELPER MINIATURA DE IMAGEN (sin cambios) ---
  Widget _buildImageThumbnail(
    dynamic imageSource,
    bool isNetwork,
    VoidCallback onRemove,
  ) {
    Widget imageWidget;

    if (isNetwork) {
      imageWidget = Image.network(
        imageSource as String,
        height: 80,
        width: 80,
        fit: BoxFit.cover,
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) return child;
          return Container(
            height: 80,
            width: 80,
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            child: Center(
              child: CircularProgressIndicator(
                strokeWidth: 2,
                value: loadingProgress.expectedTotalBytes != null
                    ? loadingProgress.cumulativeBytesLoaded /
                          loadingProgress.expectedTotalBytes!
                    : null,
              ),
            ),
          );
        },
        errorBuilder: (context, error, stackTrace) => Container(
          height: 80,
          width: 80,
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          child: Icon(
            Icons.broken_image,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      );
    } else {
      imageWidget = Image.file(
        File((imageSource as XFile).path),
        height: 80,
        width: 80,
        fit: BoxFit.cover,
      );
    }

    return Stack(
      clipBehavior: Clip.none,
      children: [
        ClipRRect(borderRadius: BorderRadius.circular(8), child: imageWidget),
        Positioned(
          top: -14,
          right: -14,
          child: IconButton(
            icon: Icon(
              Icons.cancel_rounded,
              color: Theme.of(context).colorScheme.error,
              size: 28,
            ),
            onPressed: onRemove,
            tooltip: 'Quitar imagen',
          ),
        ),
      ],
    );
  }

  // --- FUNCIÓN EDITAR ITEM ROUTER (sin cambios) ---
  void _editItemDialogRouter(int index) {
    final item = _items[index];
    final custom = item.customizationJson ?? {};

    ProductCategory? category;
    final categoryString = custom['product_category'] as String?;
    if (categoryString != null) {
      category = ProductCategory.values.firstWhereOrNull(
        (e) => e.name == categoryString,
      );
    }

    if (category == null) {
      if (cakeProducts.any((p) => p.name == item.name)) {
        category = ProductCategory.torta;
      } else if (mesaDulceProducts.any((p) => p.name == item.name)) {
        category = ProductCategory.mesaDulce;
      } else if (boxProducts.any((p) => p.name == item.name)) {
        category = ProductCategory.box;
      }
    }

    if (category == ProductCategory.torta) {
      _addCakeDialog(existingItem: item, itemIndex: index);
    } else if (category == ProductCategory.mesaDulce) {
      _addMesaDulceDialog(existingItem: item, itemIndex: index);
    } else if (category == ProductCategory.box) {
      _addBoxDialog(existingItem: item, itemIndex: index);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'No se puede editar (Categoría desconocida: "${item.name}")',
            style: TextStyle(
              // Color de texto sobre el contenedor secundario
              color: Theme.of(context).colorScheme.onSecondaryContainer,
            ),
          ),
          backgroundColor: Theme.of(context).colorScheme.secondaryContainer,
        ),
      );
    }
  }

  // --- 6. FUNCIÓN SUBMIT (MODIFICADA) ---
  Future<void> _submit() async {
    final valid = _formKey.currentState?.validate() ?? false;
    _recalculateTotals();

    if (_depositAmount > _grandTotal + 0.01) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'El monto de la seña/depósito no puede ser mayor al TOTAL del pedido. Verifica los valores.',
          ),
          backgroundColor: Theme.of(context).colorScheme.onErrorContainer,
          duration: Duration(seconds: 4),
        ),
      );
      return;
    }

    if (_deliveryCost > 0 && _selectedAddressId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Si hay costo de envío, debes seleccionar una dirección de entrega.',
          ),
          backgroundColor: Theme.of(context).colorScheme.onErrorContainer,
          duration: Duration(seconds: 4),
        ),
      );
      return;
    }

    if (!valid || _selectedClient == null || _items.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Revisa los campos obligatorios: Cliente y al menos un Producto.',
          ),
          backgroundColor: Theme.of(context).colorScheme.onErrorContainer,
          duration: Duration(seconds: 4),
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
          duration: Duration(seconds: 4),
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
      'items': _items.map((item) => item.toJson()).toList(),
    };

    debugPrint('--- Payload a Enviar ---');
    debugPrint(payload.toString());

    try {
      if (isEditMode) {
        // 1. Llama a la API y captura la orden actualizada
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

          // 2. 🔥 ACTUALIZA LA LISTA LOCAL (en vez de invalidate)
          await ref
              .read(ordersWindowProvider.notifier)
              .updateOrder(updatedOrder);

          // 3. Invalida solo el detalle (para la pág de detalle)
          ref.invalidate(orderByIdProvider(widget.order!.id));
          context.pop();
        }
      } else {
        // 1. Llama a la API y captura la orden creada
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

          // 2. 🔥 AÑADE A LA LISTA LOCAL (en vez de invalidate)
          await ref.read(ordersWindowProvider.notifier).addOrder(createdOrder);

          context.pop();
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

  // --- BUILD WIDGET (MODIFICADO PARA DIRECCIONES) ---
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
                _buildClientSelector(context), // El buscador de clientes
                // --- SECCIÓN DIRECCIÓN (NUEVA) ---
                if (_selectedClient != null)
                  _buildAddressSelector(context), // <-- AÑADIDO
                const SizedBox(height: 16),

                // --- SECCIÓN FECHA Y HORA (sin cambios) ---
                Card(
                  elevation: 0,
                  // Un contenedor de superficie ligeramente tintado
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8.0),
                    child: Column(
                      children: [
                        ListTile(
                          dense: true,
                          leading: Icon(
                            Icons.calendar_today,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                          title: Text(
                            'Fecha Evento: ${DateFormat('EEEE d \'de\' MMMM, y', 'es_AR').format(_date)}',
                          ),
                          onTap: _pickDate,
                        ),
                        Divider(
                          height: 1,
                          indent: 16,
                          endIndent: 16,
                          color: Theme.of(context).colorScheme.surfaceContainer,
                        ),
                        Row(
                          children: [
                            Expanded(
                              child: ListTile(
                                dense: true,
                                leading: Icon(
                                  Icons.access_time,
                                  color: Theme.of(context).colorScheme.primary,
                                ),
                                title: Text('Desde: ${_start.format(context)}'),
                                onTap: () => _pickTime(true),
                              ),
                            ),
                            Container(
                              height: 30,
                              width: 1,
                              color: Theme.of(
                                context,
                              ).colorScheme.surfaceContainer,
                            ),
                            Expanded(
                              child: ListTile(
                                dense: true,
                                leading: Icon(
                                  Icons.update,
                                  color: Theme.of(context).colorScheme.primary,
                                ),
                                title: Text('Hasta: ${_end.format(context)}'),
                                onTap: () => _pickTime(false),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                // --- SECCIÓN NOTAS (sin cambios) ---
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

                // --- SECCIÓN PRODUCTOS (sin cambios) ---
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Productos *',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                    IconButton.filled(
                      onPressed: _addItemDialog,
                      icon: const Icon(Icons.add),
                      style: IconButton.styleFrom(),
                      tooltip: 'Añadir producto',
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                if (_items.isEmpty)
                  Center(
                    child: Padding(
                      padding: EdgeInsets.symmetric(vertical: 24.0),
                      child: Text(
                        'Añade al menos un producto al pedido.',
                        // Usa el color de texto "variante" (más sutil)
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  )
                else
                  ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: _items.length,
                    itemBuilder: (context, index) {
                      final item = _items[index];
                      String details = '';
                      final custom = item.customizationJson ?? {};
                      final category = ProductCategory.values.firstWhereOrNull(
                        (e) => e.name == custom['product_category'],
                      );

                      if (category == ProductCategory.torta) {
                        details += '${custom['weight_kg']}kg';

                        // ⬅️ NUEVO: Muestra el ajuste multiplicador por kg
                        final multiplierAdj =
                            (custom['multiplier_adjustment_per_kg'] is num)
                            ? (custom['multiplier_adjustment_per_kg'] as num)
                                  .toDouble()
                            : 0.0;
                        if (multiplierAdj != 0.0) {
                          details +=
                              ' | Ajuste/kg: ${_currencyFormat.format(multiplierAdj)}';
                        }

                        if (custom['selected_fillings'] != null &&
                            (custom['selected_fillings'] as List).isNotEmpty) {
                          details +=
                              ' | Rellenos: ${(custom['selected_fillings'] as List).join(", ")}';
                        }
                      } else if (category == ProductCategory.mesaDulce) {
                        if (custom['selected_size'] != null) {
                          details += getUnitText(
                            ProductUnit.values.byName(custom['selected_size']),
                          );
                        } else if (custom['is_half_dozen'] == true) {
                          details += ' (Media Docena)';
                        }
                      } else if (category == ProductCategory.box) {
                        // ⬅️ NUEVO: Mostrar el detalle del Box
                        details = 'Categoría: Box';
                      }
                      if (item.customizationNotes != null) {
                        details += ' | Notas: ${item.customizationNotes}';
                      }

                      return Card(
                        margin: const EdgeInsets.symmetric(vertical: 4),
                        elevation: 1,
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: Theme.of(
                              context,
                            ).colorScheme.tertiaryContainer,
                            child: Text(
                              '${item.qty}',
                              style: TextStyle(
                                color: Theme.of(
                                  context,
                                ).colorScheme.onTertiaryContainer,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          title: Text(item.name),
                          subtitle: Text(
                            details.isNotEmpty
                                ? details
                                : 'Precio Base: ${_currencyFormat.format(item.basePrice)}',
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                _currencyFormat.format(
                                  item.finalUnitPrice * item.qty,
                                ),
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Theme.of(context).colorScheme.primary,
                                ),
                              ),
                              IconButton(
                                icon: const Icon(
                                  Icons.delete_outline,
                                  color: Colors.redAccent,
                                ),
                                onPressed: () => _updateItemsAndRecalculate(
                                  () => _items.removeAt(index),
                                ),
                                tooltip: 'Eliminar item',
                              ),
                            ],
                          ),
                          onTap: () => _editItemDialogRouter(index),
                          dense: true,
                        ),
                      );
                    },
                  ),

                const SizedBox(height: 100),
              ],
            ),
          ),

          // --- SECCIÓN INFERIOR FIJA (sin cambios) ---
          _buildSummaryAndSave(),
        ],
      ),
    );
  }

  // --- 11. WIDGET NUEVO: SELECCIÓN DE DIRECCIÓN ---
  Widget _buildAddressSelector(BuildContext context) {
    // Observamos el provider que trae los detalles (y direcciones) del cliente
    final asyncClientDetails = ref.watch(
      clientDetailsProvider(_selectedClient!.id),
    );

    return asyncClientDetails.when(
      loading: () => Center(
        child: Padding(
          padding: EdgeInsets.all(8.0),
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
              SizedBox(width: 16),
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
        // Esto es útil si el usuario edita el pedido y la dirección fue borrada
        if (_selectedAddressId != null &&
            !addresses.any((a) => a.id == _selectedAddressId)) {
          // El ID guardado ya no existe, resetear.
          _selectedAddressId = null;
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            DropdownButtonFormField<int?>(
              initialValue: _selectedAddressId,
              decoration: InputDecoration(
                labelText: 'Dirección de Entrega',
                border: OutlineInputBorder(),
                prefixIcon: Icon(
                  Icons.location_on_outlined,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
              items: [
                // Opción "Retira en local"
                const DropdownMenuItem(
                  value: null,
                  child: Text(
                    'Retira en local (o sin dirección)',
                    style: TextStyle(fontStyle: FontStyle.italic),
                  ),
                ),
                // Lista de direcciones del cliente
                ...addresses.map((address) {
                  return DropdownMenuItem(
                    value: address.id,
                    child: Text(
                      address.displayAddress, // 'Casa', 'Oficina', etc.
                      overflow: TextOverflow.ellipsis,
                    ),
                  );
                }),
              ],
              onChanged: (int? newId) {
                setState(() {
                  _selectedAddressId = newId;
                  // Si eligen "Retira en local", poner costo de envío en 0
                  if (newId == null) {
                    _deliveryCostController.text = '0';
                  }
                  // Si eligen una dirección, ¿poner costo de envío?
                  // Mejor dejar que el usuario lo ponga manualmente.
                });
              },
              validator: (value) {
                // Es válido que sea nulo (retira en local)
                return null;
              },
            ),
            const SizedBox(height: 8),
            // Botón para añadir nueva dirección
            Center(
              child: TextButton.icon(
                icon: const Icon(Icons.add_location_alt_outlined, size: 20),
                label: const Text('Añadir nueva dirección al cliente'),
                style: TextButton.styleFrom(
                  foregroundColor: Theme.of(context).colorScheme.primary,
                ),
                onPressed: _showAddAddressDialog,
              ),
            ),
          ],
        );
      },
    );
  }

  // --- 12. FUNCIÓN NUEVA: MOSTRAR MODAL DE DIRECCIONES ---
  void _showAddAddressDialog() {
    if (_selectedClient == null) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true, // Permite que el modal sea alto
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        // Usamos el widget que ya creamos y probamos
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom,
          ),
          // Envuelve el diálogo en un contenedor con bordes redondeados
          child: ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            child: AddressFormDialog(clientId: _selectedClient!.id),
          ),
        );
      },
    );
  }

  // --- WIDGET RESUMEN Y GUARDAR (sin cambios) ---
  Widget _buildSummaryAndSave() {
    return Material(
      elevation: 8.0,
      color: Theme.of(context).colorScheme.surfaceContainer,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _depositController,
                    decoration: const InputDecoration(
                      labelText: 'Seña Recibida (\$)',
                      prefixText: '\$',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: false,
                    ),
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    onChanged: (_) => _recalculateTotals(),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: TextFormField(
                    controller: _deliveryCostController,
                    decoration: const InputDecoration(
                      labelText: 'Costo Envío (\$)',
                      prefixText: '\$',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: false,
                    ),
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _buildSummaryRow('Subtotal Productos:', _itemsSubtotal),
            if (_deliveryCost > 0)
              _buildSummaryRow('Costo Envío:', _deliveryCost),
            _buildSummaryRow('TOTAL PEDIDO:', _grandTotal, isTotal: true),
            if (_depositAmount > 0)
              _buildSummaryRow('Seña Recibida:', -_depositAmount),
            if (_grandTotal > 0)
              _buildSummaryRow(
                'Saldo Pendiente:',
                _remainingBalance,
                isTotal: true,
                highlight: _remainingBalance > 0,
              ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _isLoading ? null : _submit,
                icon: _isLoading
                    ? SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Theme.of(context).colorScheme.onPrimary,
                        ),
                      )
                    : const Icon(Icons.save),
                label: Text(isEditMode ? 'Guardar Cambios' : 'Guardar Pedido'),
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  textStyle: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- WIDGET HELPER RESUMEN (sin cambios) ---
  Widget _buildSummaryRow(
    String label,
    double amount, {
    bool isTotal = false,
    bool highlight = false,
  }) {
    final style = TextStyle(
      fontSize: isTotal ? 16 : 14,
      fontWeight: isTotal ? FontWeight.bold : FontWeight.normal,
      color: highlight
          ? Theme.of(context).colorScheme.error
          : (isTotal
                ? Theme.of(context).colorScheme.primary
                : Theme.of(context).colorScheme.onSurface),
    );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: style),
          Text(_currencyFormat.format(amount), style: style),
        ],
      ),
    );
  }

  // --- LISTENER CAMBIO DE NOMBRE (modificado) ---
  void _onClientNameChanged() {
    if (_selectedClient != null &&
        _clientNameController.text != _selectedClient!.name) {
      setState(() {
        _selectedClient = null;
        _selectedAddressId = null; // <-- 14. LIMPIAR DIRECCIÓN
      });
    }
  }
}
