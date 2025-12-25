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
import 'package:flutter/foundation.dart'; // Para mapEquals

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
import 'catalog_repository.dart'; // Importar repositorio
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
          // Si estamos editando, buscamos also el pedido
          if (isEditMode) {
            return ref
                .watch(orderByIdProvider(orderId!))
                .when(
                  loading: () => Center(
                    child: CircularProgressIndicator(color: darkBrown),
                  ),
                  error: (err, stack) =>
                      Center(child: Text('Error al cargar el pedido: $err')),
                  data: (order) {
                    if (order == null)
                      return const Center(child: Text('Pedido no encontrado.'));
                    return _OrderForm(order: order, catalog: catalogData);
                  },
                );
          }
          // Si es nuevo
          return _OrderForm(catalog: catalogData);
        },
      ),
    );
  }
}

// (Clase auxiliar para productos del Box)
class BoxMesaDulceSelection {
  final Product product;
  int quantity;

  // Para productos con variantes (ej. tamaños 20cm, 24cm, o Pan Dulce 500g)
  ProductVariant? selectedVariant;

  BoxMesaDulceSelection({
    required this.product,
    this.quantity = 1,
    this.selectedVariant,
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
  final CatalogResponse? catalog;
  const _OrderForm({this.order, this.catalog});

  @override
  ConsumerState<_OrderForm> createState() => _OrderFormState();
}

class _OrderFormState extends ConsumerState<_OrderForm> {
  final _formKey = GlobalKey<FormState>();

  final _clientNameController = TextEditingController();
  Client? _selectedClient;

  // --- 3. NUEVOS ESTADOS PARA DIRECCIÓN ---
  int? _selectedAddressId; // El ID de la dirección de entrega
  bool _isPaid = false; // Estado local de pagado
  // ------------------------------------

  late DateTime _date;
  late TimeOfDay _start;
  late TimeOfDay _end;
  final _depositController = TextEditingController();
  final _deliveryCostController = TextEditingController();
  final _notesController = TextEditingController();
  final List<OrderItem> _items = [];

  // Listas locales derivadas del catálogo
  List<Product> get boxProducts =>
      widget.catalog?.products
          .where((p) => p.category == ProductCategory.box)
          .toList() ??
      [];
  List<Product> get smallCakeProducts =>
      widget.catalog?.products
          .where(
            (p) =>
                p.category == ProductCategory.torta && p.name.contains('Base'),
          )
          .toList() ??
      []; // Ajustar filtro si es necesario
  // Nota: smallCakeProducts en el código original eran tortas "Base" específicas.
  // Aquí asumo que son las que tienen 'Base' en el nombre o son de cierta categoría.
  // Si smallCakeProducts eran las de 'torta' en general, usaremos eso.
  // Revisando original: smallCakeProducts eran 'Micro Torta', 'Mini Torta', 'Torta Base 1kg'.
  // Y 'cakeProducts' eran las decoradas.
  // Podríamos diferenciar por un flag o convención de nombres. O simplemente usar todas las tortas en ambos si no hay distinción clara en backend.
  // Por ahora filtro por nombre 'Base' para smallCakes y todas para cakeProducts?
  // O mejor:
  List<Product> get cakeProducts =>
      widget.catalog?.products
          .where((p) => p.category == ProductCategory.torta)
          .toList() ??
      [];

  // Re-definir smallCakeProducts como subset de cakeProducts si es necesario, o simplemente usar cakeProducts.
  // En el original 'smallCakeProducts' se usaba para seleccionar la base en Box.
  // Voy a usar las que digan "Base" o sean baratas?
  // Hack temporal: Filtro por precio < 16000 o nombre contiene "Base".
  // Mejor: Filtro por nombre.
  List<Product> get _derivedSmallCakeProducts => cakeProducts
      .where(
        (p) =>
            p.name.contains('Base') ||
            p.name.contains('Mini') ||
            p.name.contains('Micro'),
      )
      .toList();

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
  final NumberFormat _currencyFormat = NumberFormat.currency(
    locale: 'es_AR',
    symbol: '\$',
    decimalDigits: 0,
    customPattern: '\u00a4#,##0',
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
      _isPaid = order.isPaid; // Inicializar estado pagado

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
                      // Permite buscar con 0 caracteres (al hacer click/foco)
                      debounceDuration: const Duration(milliseconds: 500),
                      suggestionsCallback: (pattern) async {
                        // Eliminada la restricción de 2 caracteres.
                        // Si pattern es vacío, traerá los default (paginados) del backend.
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

        final variantId = itemData['variant_id']; // Si guardaste ID
        final variantName = itemData['variant_name']; // O nombre

        final product = mesaDulceProducts.firstWhereOrNull(
          (p) => p.name == name,
        );
        if (product != null) {
          ProductVariant? variant;
          if (product.variants.isNotEmpty) {
            if (variantId != null) {
              variant = product.variants.firstWhereOrNull(
                (v) => v.id == variantId,
              );
            }
            // Fallback por nombre si no hay ID o no se encontró
            variant ??= product.variants.firstWhereOrNull(
              (v) => v.variantName == variantName,
            );
          }

          selectedMesaDulceItems.add(
            BoxMesaDulceSelection(
              product: product,
              quantity: qty,
              selectedVariant: variant,
            ),
          );
        }
      }
    }

    // 🎯 NUEVO: Inicialización de Torta Base solo si estamos editando un Box Predeterminado
    // O si es un Box Personalizado que ya tenía una torta base seleccionada.
    // Esto es para mantener la selección al editar.
    Product? selectedBaseCake = customData['selected_base_cake'] != null
        ? _derivedSmallCakeProducts.firstWhereOrNull(
            (p) => p.name == (customData['selected_base_cake'] as String?),
          )
        : _derivedSmallCakeProducts.firstWhereOrNull(
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
        if (sel.product.variants.isNotEmpty) {
          unitPrice = sel.selectedVariant?.price ?? 0.0;
        } else if (sel.product.unit == ProductUnit.dozen) {
          unitPrice = sel.product.price / 12.0;
        } else if (sel.product.unit == ProductUnit.unit) {
          unitPrice = sel.product.price;
        } else {
          // Fallback
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
          if (sel.product.variants.isNotEmpty) {
            unitPrice = sel.selectedVariant?.price ?? 0.0;
          } else if (sel.product.unit == ProductUnit.dozen) {
            unitPrice = sel.product.price / 12.0;
          } else if (sel.product.unit == ProductUnit.unit) {
            unitPrice = sel.product.price;
          } else {
            // Fallback o precio base si no tiene variantes ni unidad especial
            unitPrice = sel.product.price;
          }
          calculatedSubItemsCost += unitPrice * sel.quantity;
        }
        calculatedTotalBasePrice += calculatedSubItemsCost;
      }

      if (selectedBaseCake != null || !isPersonalizedBox) {
        // --- INICIO CORRECCIÓN ---
        // (Copiar la misma lógica de cálculo de multiplicador de arriba)
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
        // --- FIN CORRECCIÓN ---

        // Suma Extras (rellenos, kg, unit)
        calculatedExtrasCost += selectedExtraFillings.fold(
          0.0,
          (sum, f) =>
              sum + (f.extraCostPerKg * costMultiplier), // <-- CORREGIDO
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
                    ProductVariant? defaultVariant;
                    if (product.variants.isNotEmpty) {
                      defaultVariant = product.variants.first;
                    }

                    selectedMesaDulceItems.add(
                      BoxMesaDulceSelection(
                        product: product,
                        quantity: 1,
                        selectedVariant: defaultVariant,
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

              // Si el producto tiene VARIANTES
              if (product.variants.isNotEmpty) {
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ListTile(
                      leading: Checkbox(
                        value: isSelected,
                        onChanged: toggleSelection,
                      ),
                      title: Text('${product.name} $basePriceText'),
                      onTap: () => toggleSelection(!isSelected),
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                    ),
                    if (isSelected)
                      Padding(
                        padding: const EdgeInsets.only(left: 32.0, bottom: 8.0),
                        child: DropdownButtonFormField<ProductVariant>(
                          value: selection.selectedVariant,
                          items: product.variants
                              .map(
                                (variant) => DropdownMenuItem(
                                  value: variant,
                                  child: Text(
                                    '${variant.variantName} (\$${variant.price.toStringAsFixed(0)})',
                                  ),
                                ),
                              )
                              .toList(),
                          onChanged: (newVariant) {
                            setDialogState(() {
                              selection.selectedVariant = newVariant;
                              calculatePrice();
                            });
                          },
                          decoration: const InputDecoration(
                            labelText: 'Variante / Tamaño',
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
                            selectedBaseCake = _derivedSmallCakeProducts
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
                              ..._derivedSmallCakeProducts.map((
                                Product product,
                              ) {
                                return DropdownMenuItem<Product>(
                                  value: product,
                                  child: Text(
                                    '${product.name} (\$${product.basePrice.toStringAsFixed(0)} Base)',
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
                                if (sel.selectedVariant != null) ...{
                                  'variant_id': sel.selectedVariant!.id,
                                  'variant_name':
                                      sel.selectedVariant!.variantName,
                                },
                              },
                            )
                            .toList(),
                      },

                      if (itemNotes.isNotEmpty) 'item_notes': itemNotes,
                      if (allImageUrls.isNotEmpty) 'photo_urls': allImageUrls,
                    };

                    // --- LOGIC FIX: PRIMARY PHOTO FOR MAIN LIST (BOX) ---
                    String? primaryPhotoUrl;
                    List<Object>? primaryLocalFiles;

                    if (allImageUrls.isNotEmpty) {
                      final firstUrl = allImageUrls.first;
                      if (firstUrl.startsWith('placeholder_')) {
                        final file = _filesToUpload[firstUrl];
                        if (file != null) {
                          primaryLocalFiles = [file];
                        }
                      } else {
                        primaryPhotoUrl = firstUrl;
                      }
                    }
                    if (primaryPhotoUrl != null) {
                      customization['photo_url'] = primaryPhotoUrl;
                    }

                    customization.removeWhere(
                      (key, value) => (value is List && value.isEmpty),
                    );

                    final newItem = OrderItem(
                      id: isEditing ? existingItem.id : null,
                      name: selectedProduct!.name,
                      qty: qty,
                      basePrice: selectedProduct!.price,
                      adjustments: totalAdjustment,
                      customizationNotes: adjustmentNotes.isEmpty
                          ? null
                          : adjustmentNotes,
                      customizationJson: customization,
                      localFile: primaryLocalFiles,
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
          // --- CORRECCIÓN AQUÍ ---
          builder: (context, setDialogState) {
            // 1. Definir las constantes y la variable de estado AQUÍ
            // (Si ya las tenés definidas afuera, podés borrarlas de calculateCakePrice)
            const miniCakeName = 'Mini Torta Personalizada (Base)';
            const microCakeName =
                'Micro Torta (Base)'; // <-- Revisa este nombre

            final bool isMiniCake = selectedCakeType?.name == miniCakeName;
            final bool isMicroCake = selectedCakeType?.name == microCakeName;
            // ESTA ES LA VARIABLE CORRECTA que se actualiza en cada setDialogState
            final bool isSmallCake = isMiniCake || isMicroCake;

            // --- Re-definimos los helpers DENTRO del builder ---
            // (para que tengan acceso al 'setDialogState' y a 'isSmallCake')

            Widget buildFillingCheckbox(Filling filling, bool isExtraCost) {
              bool isSelected = isExtraCost
                  ? selectedExtraFillings.contains(filling)
                  : selectedFillings.contains(filling);
              return CheckboxListTile(
                title: Text(filling.name),
                subtitle: Text(
                  // --- CORREGIDO: Usar isSmallCake ---
                  isSmallCake
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
                // --- CORREGIDO: Usar isSmallCake ---
                subtitle: Text(
                  isSmallCake
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
                            selection.quantity = qty;
                            calculateCakePrice();
                          },
                        ),
                      )
                    : null,
                dense: true,
                contentPadding: EdgeInsets.zero,
              );
            }
            // --- Fin de re-definición de helpers ---

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
                        // --- CORREGIDO: Usar las constantes locales ---
                        final isCurrentProductMiniCake =
                            product.name == miniCakeName ||
                            product.name == microCakeName;
                        return DropdownMenuItem<Product>(
                          value: product,
                          child: Text(
                            '${product.name} (\$${product.price.toStringAsFixed(0)}${isCurrentProductMiniCake ? '/u' : '/kg'})',
                            overflow: TextOverflow.ellipsis,
                          ),
                        );
                      }).toList(),
                      onChanged: (Product? newValue) {
                        setDialogState(() {
                          // Guardar el estado ANTES de cambiarlo
                          final bool eraTortaChica = isSmallCake;

                          selectedCakeType = newValue;

                          // Calcular el NUEVO estado (esto no es necesario si 'isSmallCake' está arriba)
                          final bool esTortaChicaNueva =
                              newValue?.name == miniCakeName ||
                              newValue?.name == microCakeName;

                          if (esTortaChicaNueva) {
                            // Si es Mini Torta, forzar valores
                            weightController.text = '1.0';
                            multiplierAdjustmentController.text = '0';
                          } else if (eraTortaChica) {
                            // Si veníamos de Mini Torta y cambiamos a Torta KG
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

                    // --- PESO ESTIMADO (CORREGIDO: Usar isSmallCake) ---
                    if (!isSmallCake)
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

                    // --- AJUSTE MULTIPLICADOR (CORREGIDO: Usar isSmallCake) ---
                    if (!isSmallCake)
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

                    // ... (El resto del contenido: Rellenos, Extras, Notas, Fotos, Precios) ...
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

                    // --- CORRECCIÓN: Usar la variable 'isSmallCake' del builder ---
                    final weight = isSmallCake
                        ? 1.0
                        : double.tryParse(
                                weightController.text.replaceAll(',', '.'),
                              ) ??
                              0.0;

                    final multiplierAdjustmentValue = isSmallCake
                        ? 0.0
                        : double.tryParse(
                                multiplierAdjustmentController.text,
                              ) ??
                              0.0;
                    // --- FIN CORRECCIÓN ---

                    final adjustmentNotes = adjustmentNotesController.text
                        .trim();

                    if (weight <= 0 && !isSmallCake) {
                      // <-- CORREGIDO
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
                      if (!isSmallCake) // <-- CORREGIDO
                        'multiplier_adjustment_per_kg':
                            multiplierAdjustmentValue,
                      'selected_fillings': selectedFillings
                          .map((f) => f.name)
                          .toList(),
                      'selected_extra_fillings': selectedExtraFillings
                          .map(
                            (f) => {'name': f.name, 'price': f.extraCostPerKg},
                          )
                          .toList(),
                      'selected_extras_kg': selectedExtrasKg
                          .map((ex) => {'name': ex.name, 'price': ex.costPerKg})
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

                    // --- LOGIC FIX: PRIMARY PHOTO FOR MAIN LIST ---
                    // Determine primary photo for thumbnail display
                    // Supports 'photo_url' (single) and 'localFile' (List<XFile>)
                    String? primaryPhotoUrl;
                    List<Object>? primaryLocalFiles;

                    if (allImageUrls.isNotEmpty) {
                      final firstUrl = allImageUrls.first;
                      if (firstUrl.startsWith('placeholder_')) {
                        // It's a local file in _filesToUpload
                        final file = _filesToUpload[firstUrl];
                        if (file != null) {
                          primaryLocalFiles = [file];
                        }
                      } else {
                        // It's a remote URL
                        primaryPhotoUrl = firstUrl;
                      }
                    }
                    if (primaryPhotoUrl != null) {
                      customization['photo_url'] = primaryPhotoUrl;
                    }

                    customization.removeWhere(
                      (key, value) => (value is List && value.isEmpty),
                    );

                    final newItem = OrderItem(
                      id: isEditing ? existingItem.id : null,
                      name: selectedCakeType!.name,
                      qty: 1,
                      basePrice: calculatedBasePrice,
                      adjustments: manualAdjustments,
                      customizationNotes: adjustmentNotes.isEmpty
                          ? null
                          : adjustmentNotes,
                      customizationJson: customization,
                      localFile:
                          primaryLocalFiles, // <-- Attach local file for preview
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

    // --- ESTADO LOCAL DEL CARRITO ---
    List<OrderItem> pendingItems = [];
    if (isEditing) {
      // Si editamos, iniciamos con ese item en la lista (aunque la UX de editar múltiple es rara,
      // asumiremos que si edita, edita ESE item. Pero para mantener consistencia,
      // el modo edición podría mantenerse simple o permitir agregar más).
      // SIMPLIFICACIÓN: SI EDITA, ES SOLO ESE ITEM.
    }

    // Estado del formulario de selección actual
    Product? selectedProduct = isEditing
        ? mesaDulceProducts.firstWhereOrNull((p) => p.name == existingItem.name)
        : mesaDulceProducts.firstWhereOrNull(
                (p) => p.category == ProductCategory.mesaDulce,
              ) ??
              mesaDulceProducts.first;

    ProductVariant? selectedVariant;
    double basePrice = 0.0;
    double adjustments = isEditing ? existingItem.adjustments : 0.0;
    bool isHalfDozen = false;
    if (isEditing) {
      final custom = existingItem.customizationJson ?? {};
      isHalfDozen = custom['is_half_dozen'] as bool? ?? false;
      final vId = custom['variant_id'];
      if (vId != null && selectedProduct != null) {
        selectedVariant = selectedProduct.variants.firstWhereOrNull(
          (v) => v.id == vId,
        );
      }
    }

    // Controladores
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
      text: isEditing
          ? (existingItem.customizationJson?['item_notes'] ?? '')
          : '',
    );
    final unitAdjustmentsController = TextEditingController(
      text: isEditing
          ? (existingItem.customizationJson?['unit_adjustment']?.toString() ??
                '0')
          : '0',
    );
    // Removed duplicate declaration
    final finalPriceController = TextEditingController();
    bool isUnitSaleForDozen = isEditing
        ? (existingItem.customizationJson?['is_unit_sale_for_dozen'] == true)
        : false;

    // Imagenes (Simplificación: Por ahora no implementaremos carga de fotos múltiple por item en esta refactorización masiva,
    // o se aplicará al item que se está creando).
    // Mantenemos la lógica de imagen para el item ACTUAL que se está configurando.
    final ImagePicker picker = ImagePicker();
    // Variables de estado para FOTOS locales en el diálogo
    List<XFile> _selectedFiles = [];
    String? _existingRemoteUrl;

    if (isEditing) {
      // 1. Cargar locales
      if (existingItem.localFile != null &&
          (existingItem.localFile is List) &&
          (existingItem.localFile as List).isNotEmpty) {
        // Asumiendo que son XFile o File, lo convertimos a XFile si es necesario
        // Para simplificar, si ya está en memoria, lo usamos.
        final files = existingItem.localFile as List;
        for (var f in files) {
          if (f is XFile) {
            _selectedFiles.add(f);
          } else if (f is File) {
            _selectedFiles.add(XFile(f.path));
          }
        }
      }

      // 2. Cargar remota (Si no hay locales nuevas que la reemplacen, o para mostrarla)
      // La lógica actual de Mesa Dulce es "Una sola foto" (o al menos UX para una).
      // Si hay URL remota y no hay local, la mostramos.
      if (existingItem.customizationJson?['photo_url'] != null) {
        _existingRemoteUrl = existingItem.customizationJson!['photo_url'];
      }
    }

    showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            // --- CÁLCULO DE PRECIO DEL ITEM ACTUAL ---
            void calculateCurrentItemPrice() {
              if (selectedProduct == null) {
                finalPriceController.text = '0';
                return;
              }
              int qty = int.tryParse(qtyController.text) ?? 0;
              double manualAdj =
                  double.tryParse(adjustmentsController.text) ?? 0.0;
              // Ajuste Unitario
              double unitAdj =
                  double.tryParse(unitAdjustmentsController.text) ?? 0.0;

              double unitBasePrice = 0.0;
              if (selectedProduct!.variants.isNotEmpty) {
                unitBasePrice = selectedVariant?.price ?? 0.0;
              } else if (selectedProduct!.allowHalfDozen && isHalfDozen) {
                unitBasePrice =
                    selectedProduct!.halfDozenPrice ??
                    (selectedProduct!.price / 2);
              } else if (selectedProduct!.unit == ProductUnit.dozen &&
                  isUnitSaleForDozen) {
                // Lógica de venta por unidad suelta para docenas
                unitBasePrice = selectedProduct!.price / 12;
              } else {
                unitBasePrice = selectedProduct!.price;
              }

              // Precio unitario efectivo = precio base + ajuste unitario
              double effectiveUnitDetailPrice = unitBasePrice + unitAdj;
              basePrice = effectiveUnitDetailPrice;

              // Total = (Effective Unit * Qty) + Manual Adjustment (Fixed)
              double total = (effectiveUnitDetailPrice * qty) + manualAdj;
              finalPriceController.text = total.toStringAsFixed(0);
            }

            // Forzamos un cálculo inicial al construir si el controlador está vacío
            if (finalPriceController.text.isEmpty) {
              calculateCurrentItemPrice();
            }

            // --- FUNCIÓN PARA AGREGAR A LA LISTA TEMPORAL ---
            void addToPendingList() {
              if (selectedProduct == null) return;
              int qty = int.tryParse(qtyController.text) ?? 0;
              if (qty <= 0) return;
              if (selectedProduct!.variants.isNotEmpty &&
                  selectedVariant == null)
                return;

              // --- LOGIC FIX: Photo Handling for Mesa Dulce Edit/Add ---
              List<XFile> finalLocalFiles = [];
              String? finalPhotoUrl;

              // 1. Si hay locales nuevas, toman precedencia para la preview
              if (_selectedFiles.isNotEmpty) {
                finalLocalFiles.addAll(_selectedFiles);
              }
              // 2. Si quedó la remota y no se borró
              if (_existingRemoteUrl != null) {
                finalPhotoUrl = _existingRemoteUrl;
              }

              // Construir Customization
              final customization = {
                'product_category': selectedProduct!.category.name,
                'product_unit': selectedProduct!.unit.name,
                if (selectedVariant != null) ...{
                  'variant_id': selectedVariant!.id,
                  'variant_name': selectedVariant!.variantName,
                },
                if (selectedProduct!.allowHalfDozen)
                  'is_half_dozen': isHalfDozen,
                if (itemNotesController.text.trim().isNotEmpty)
                  'item_notes': itemNotesController.text.trim(),
                if (isUnitSaleForDozen) 'is_unit_sale_for_dozen': true,
                if (finalPhotoUrl != null) 'photo_url': finalPhotoUrl,
                if (finalPhotoUrl != null) 'photo_urls': [finalPhotoUrl],
                if (double.tryParse(unitAdjustmentsController.text) != null &&
                    double.parse(unitAdjustmentsController.text) != 0)
                  'unit_adjustment': double.parse(
                    unitAdjustmentsController.text,
                  ),
              };

              final newItem = OrderItem(
                id: isEditing ? existingItem.id : null,
                name: selectedProduct!.name,
                qty: qty,
                basePrice: basePrice * qty,
                adjustments: double.tryParse(adjustmentsController.text) ?? 0.0,
                customizationNotes: notesController.text.trim().isEmpty
                    ? null
                    : notesController.text.trim(),
                customizationJson: customization,
                localFile: finalLocalFiles.isNotEmpty ? finalLocalFiles : null,
              );

              setDialogState(() {
                if (isEditing) {
                  // Si estamos en modo edición, reemplazar y cerrar
                  _updateItemsAndRecalculate(() {
                    _items[itemIndex!] = newItem;
                  });
                  Navigator.pop(context);
                } else {
                  // --- MERGE LOGIC START ---
                  // Check if identical exists
                  int existingIndex = pendingItems.indexWhere((item) {
                    // 1. Core Identity
                    if (item.name != newItem.name) return false;
                    if (item.customizationJson?['variant_id'] !=
                        newItem.customizationJson?['variant_id'])
                      return false;

                    // 2. Adjustments & Price (Must match exactly to merge)
                    // basePrice here is TOTAL for the qty. We should compare UNIT price.
                    // But calculating unit price from totals is risky if floating point.
                    // Instead, check if the config that DERIVES price is same.
                    // The newItem.basePrice is (unitBase * qty).
                    // item.basePrice is (unitBase * item.qty).
                    // So we can check if (item.basePrice / item.qty) ~= (newItem.basePrice / newItem.qty).
                    double itemUnit = item.basePrice / item.qty;
                    double newUnit = newItem.basePrice / newItem.qty;
                    if ((itemUnit - newUnit).abs() > 0.01) return false;

                    if (item.adjustments != 0 || newItem.adjustments != 0)
                      return false;

                    // 3. Customization Notes
                    if (item.customizationNotes != newItem.customizationNotes)
                      return false;

                    // 4. Photos (Merge Logic: Allow merge if one is missing photos)
                    bool itemHasPhotos =
                        (item.customizationJson?['photo_url'] != null) ||
                        (item.customizationJson?['photo_urls'] != null) ||
                        (item.localFile != null);
                    bool newHasPhotos =
                        (newItem.customizationJson?['photo_url'] != null) ||
                        (newItem.customizationJson?['photo_urls'] != null) ||
                        (newItem.localFile != null);

                    // Conflict: Both have photos -> No Merge
                    if (itemHasPhotos && newHasPhotos) return false;

                    return true;
                  });

                  if (existingIndex != -1) {
                    // Update existing
                    final existing = pendingItems[existingIndex];
                    final newQty = existing.qty + newItem.qty;
                    // Recalculate total base price
                    double itemUnit = existing.basePrice / existing.qty;
                    final newBasePrice = itemUnit * newQty;

                    // Determine which photo/customization to keep
                    // If new item has photos, it overrides (or populates) the existing one.
                    // If existing has photos and new doesn't, we keep existing.
                    bool newHasPhotos =
                        (newItem.customizationJson?['photo_url'] != null) ||
                        (newItem.customizationJson?['photo_urls'] != null) ||
                        (newItem.localFile != null);

                    final resolvedCustomization = newHasPhotos
                        ? newItem.customizationJson
                        : existing.customizationJson;
                    final resolvedLocalFile = newHasPhotos
                        ? newItem.localFile
                        : existing.localFile;

                    pendingItems[existingIndex] = OrderItem(
                      id: existing.id,
                      name: existing.name,
                      qty: newQty,
                      basePrice: newBasePrice,
                      adjustments: 0.0,
                      customizationNotes: existing.customizationNotes,
                      customizationJson: resolvedCustomization,
                      localFile: resolvedLocalFile,
                    );
                  } else {
                    pendingItems.add(newItem);
                  }
                  // --- MERGE LOGIC END ---
                  // Resetear formulario para siguiente item
                  qtyController.text = '1';
                  adjustmentsController.text = '0';
                  notesController.clear();
                  itemNotesController.clear();
                  unitAdjustmentsController.text = '0';
                  _selectedFiles.clear();
                  // No agregamos a _filesToUpload todavía, lo hacemos al dar "Agregar Todo"
                }
              });
            }

            return AlertDialog(
              title: Text(
                isEditing ? 'Editar Item Mesa Dulce' : 'Mesa Dulce (Carrito)',
              ),
              content: SizedBox(
                width: double.maxFinite,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (!isEditing) ...[
                      // --- LISTA DE PROVISORIOS ---
                      if (pendingItems.isNotEmpty)
                        Container(
                          constraints: const BoxConstraints(maxHeight: 150),
                          margin: const EdgeInsets.only(bottom: 10),
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey.shade300),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: ListView.separated(
                            shrinkWrap: true,
                            itemCount: pendingItems.length,
                            separatorBuilder: (_, __) =>
                                const Divider(height: 1),
                            itemBuilder: (ctx, idx) {
                              final it = pendingItems[idx];
                              final vName =
                                  it.customizationJson?['variant_name'] ??
                                  (it.customizationJson?['is_half_dozen'] ==
                                          true
                                      ? 'Media Docena'
                                      : 'Unidad');
                              // Limpieza visual del nombre de variante (ej: size20cm -> 20cm)
                              final formattedVName = vName.startsWith('size')
                                  ? vName.replaceAll('size', '')
                                  : vName;
                              return ListTile(
                                dense: true,
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                leading:
                                    (it.localFile != null &&
                                        (it.localFile as List).isNotEmpty)
                                    ? GestureDetector(
                                        onTap: () => _showImagePreview(
                                          context,
                                          (it.localFile as List).first,
                                        ),
                                        child: ClipRRect(
                                          borderRadius: BorderRadius.circular(
                                            4,
                                          ),
                                          child: Image.file(
                                            File(
                                              ((it.localFile as List).first
                                                      as XFile)
                                                  .path,
                                            ),
                                            width: 40,
                                            height: 40,
                                            fit: BoxFit.cover,
                                          ),
                                        ),
                                      )
                                    : null,
                                title: Text('${it.name} ($formattedVName)'),
                                subtitle: Text(
                                  '${it.qty} x \$${it.basePrice.toStringAsFixed(0)}',
                                ),
                                trailing: IconButton(
                                  icon: const Icon(
                                    Icons.delete,
                                    size: 20,
                                    color: Colors.red,
                                  ),
                                  onPressed: () => setDialogState(
                                    () => pendingItems.removeAt(idx),
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      Align(
                        alignment: Alignment.centerRight,
                        child: Padding(
                          padding: const EdgeInsets.only(top: 5, bottom: 5),
                          child: Text(
                            'Total Carrito: \$${pendingItems.fold<double>(0, (sum, item) => sum + (item.basePrice * item.qty) + item.adjustments).toStringAsFixed(0)}',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                              color: Colors.blueGrey,
                            ),
                          ),
                        ),
                      ),
                      const Divider(thickness: 2),
                    ],

                    // --- FORMULARIO DE SELECCIÓN ---
                    Flexible(
                      child: SingleChildScrollView(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            DropdownButtonFormField<Product>(
                              isExpanded: true,
                              value: selectedProduct,
                              items: mesaDulceProducts
                                  .map(
                                    (p) => DropdownMenuItem(
                                      value: p,
                                      child: Text(p.name),
                                    ),
                                  )
                                  .toList(),
                              onChanged: (p) => setDialogState(() {
                                selectedProduct = p;
                                if (p != null && p.variants.isNotEmpty) {
                                  selectedVariant = p.variants.first;
                                } else {
                                  selectedVariant = null;
                                }
                                isHalfDozen = false;
                                isUnitSaleForDozen = false;
                                calculateCurrentItemPrice();
                              }),
                              decoration: const InputDecoration(
                                labelText: 'Producto',
                              ),
                            ),
                            const SizedBox(height: 10),
                            if (selectedProduct != null) ...[
                              if (selectedProduct!.variants.isNotEmpty)
                                DropdownButtonFormField<ProductVariant>(
                                  value: selectedVariant,
                                  items: selectedProduct!.variants
                                      .map(
                                        (v) => DropdownMenuItem(
                                          value: v,
                                          child: Text(
                                            '${v.formattedName} (\$${v.price.toStringAsFixed(0)})',
                                          ),
                                        ),
                                      )
                                      .toList(),
                                  onChanged: (v) => setDialogState(() {
                                    selectedVariant = v;
                                    calculateCurrentItemPrice();
                                  }),
                                  decoration: const InputDecoration(
                                    labelText: 'Variante',
                                  ),
                                )
                              else if (selectedProduct!.allowHalfDozen)
                                SwitchListTile(
                                  title: const Text('Media Docena'),
                                  value: isHalfDozen,
                                  onChanged: (v) => setDialogState(() {
                                    isHalfDozen = v;
                                    if (v) isUnitSaleForDozen = false;
                                    calculateCurrentItemPrice();
                                  }),
                                ),
                              if (selectedProduct!.unit == ProductUnit.dozen &&
                                  !isHalfDozen)
                                SwitchListTile(
                                  title: const Text('Venta por Unidad'),
                                  value: isUnitSaleForDozen,
                                  onChanged: (v) => setDialogState(() {
                                    isUnitSaleForDozen = v;
                                    calculateCurrentItemPrice();
                                  }),
                                ),
                            ],
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  flex: 2,
                                  child: TextField(
                                    controller: qtyController,
                                    keyboardType: TextInputType.number,
                                    decoration: const InputDecoration(
                                      labelText: 'Cant.',
                                      isDense: true,
                                    ),
                                    onChanged: (_) => setDialogState(() {
                                      calculateCurrentItemPrice();
                                    }),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  flex: 3,
                                  child: TextField(
                                    controller: unitAdjustmentsController,
                                    keyboardType: TextInputType.number,
                                    decoration: const InputDecoration(
                                      labelText: '\$ Unit.',
                                      isDense: true,
                                      prefixText: '\$',
                                    ),
                                    onChanged: (_) => setDialogState(() {
                                      calculateCurrentItemPrice();
                                    }),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  flex: 3,
                                  child: TextField(
                                    controller: adjustmentsController,
                                    keyboardType: TextInputType.number,
                                    decoration: const InputDecoration(
                                      labelText: '\$ Tot.',
                                      isDense: true,
                                      prefixText: '\$',
                                    ),
                                    onChanged: (_) => setDialogState(() {
                                      calculateCurrentItemPrice();
                                    }),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            TextFormField(
                              controller: notesController,
                              decoration: const InputDecoration(
                                labelText: 'Notas del Ajuste (Opcional)',
                                hintText: 'Ej: Diseño especial, etc.',
                              ),
                            ),
                            const SizedBox(height: 10),
                            TextFormField(
                              controller: itemNotesController,
                              decoration: const InputDecoration(
                                labelText: 'Notas del Item (Sabor, etc)',
                              ),
                              maxLines: 2,
                            ),
                            const SizedBox(height: 10),

                            // --- SECCIÓN FOTOS (Mejorada) ---
                            // --- SECCIÓN FOTOS (Mejorada) ---
                            if (_selectedFiles.isNotEmpty ||
                                _existingRemoteUrl != null)
                              Container(
                                height: 90,
                                margin: const EdgeInsets.only(bottom: 10),
                                child: ListView(
                                  scrollDirection: Axis.horizontal,
                                  children: [
                                    if (_existingRemoteUrl != null)
                                      Padding(
                                        padding: const EdgeInsets.only(
                                          right: 8.0,
                                        ),
                                        child: _buildImageThumbnail(
                                          _existingRemoteUrl!,
                                          true, // isNetwork? No, isNetwork url string
                                          () => setDialogState(() {
                                            _existingRemoteUrl = null;
                                          }),
                                        ),
                                      ),
                                    ..._selectedFiles.map((file) {
                                      return Padding(
                                        padding: const EdgeInsets.only(
                                          right: 8.0,
                                        ),
                                        child: _buildImageThumbnail(
                                          file,
                                          false, // isNetwork
                                          () => setDialogState(() {
                                            _selectedFiles.remove(file);
                                          }),
                                        ),
                                      );
                                    }).toList(),
                                  ],
                                ),
                              ),
                            TextButton.icon(
                              icon: const Icon(Icons.photo_library),
                              label: const Text('Añadir Fotos al Item/Box'),
                              onPressed: () async {
                                final pickedFiles = await picker
                                    .pickMultiImage();
                                if (pickedFiles.isNotEmpty) {
                                  setDialogState(() {
                                    _selectedFiles.addAll(pickedFiles);
                                  });
                                }
                              },
                            ),
                            const Divider(),
                            const SizedBox(height: 10),
                            // Visualización Precio Actual
                            Align(
                              alignment: Alignment.centerRight,
                              child: Text(
                                'Subtotal Item: \$${finalPriceController.text}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                  color: Colors.green,
                                ),
                              ),
                            ),
                            const SizedBox(height: 10),
                            // Botón Agregar a Lista (Solo si no es editing, o si se quiere permitir)
                            if (!isEditing)
                              SizedBox(
                                width: double.infinity,
                                child: OutlinedButton.icon(
                                  icon: const Icon(Icons.add_shopping_cart),
                                  label: const Text('AGREGAR A LISTA'),
                                  onPressed: addToPendingList,
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cerrar'),
                ),
                if (pendingItems.isNotEmpty || isEditing)
                  FilledButton(
                    onPressed: () {
                      if (isEditing) {
                        addToPendingList(); // Trigger save logic logic inside
                      } else {
                        // Agregar todos los pendientes
                        // Agregar todos los pendientes con lógica de merge
                        _updateItemsAndRecalculate(() {
                          for (var newItem in pendingItems) {
                            // Procesar fotos si existen
                            if (newItem.localFile != null &&
                                (newItem.localFile as List).isNotEmpty) {
                              final files = newItem.localFile as List<XFile>;
                              // Usamos la primera foto como la principal para 'photo_url'
                              final file = files.first;
                              final String key =
                                  'photo_${DateTime.now().microsecondsSinceEpoch}';

                              _filesToUpload[key] = file;

                              // Actualizar el JSON del item para incluir la referencia
                              if (newItem.customizationJson != null) {
                                newItem.customizationJson!['photo_url'] = key;
                              }
                            }

                            // Buscar si ya existe un item idéntico en la lista principal
                            final existingIndex = _items.indexWhere((existing) {
                              final bool nameMatch =
                                  existing.name == newItem.name;
                              final bool priceMatch =
                                  existing.basePrice == newItem.basePrice;
                              // Comparar notas y ajustes
                              final bool notesMatch =
                                  existing.customizationNotes ==
                                  newItem.customizationNotes;
                              // Comparar JSON (IMPORTANTE: ahora incluye photo_url si tiene foto)
                              final bool jsonMatch = mapEquals(
                                existing.customizationJson,
                                newItem.customizationJson,
                              );
                              final bool adjMatch =
                                  existing.adjustments == newItem.adjustments;

                              return nameMatch &&
                                  priceMatch &&
                                  notesMatch &&
                                  adjMatch &&
                                  jsonMatch;
                            });

                            if (existingIndex != -1) {
                              // MERGE: Sumar cantidad al existente
                              final existing = _items[existingIndex];
                              _items[existingIndex] = existing.copyWith(
                                qty: existing.qty + newItem.qty,
                              );
                            } else {
                              // ADD: Agregar nuevo
                              _items.add(newItem);
                            }
                          }
                        });
                        Navigator.pop(context);
                      }
                    },
                    child: Text(
                      isEditing
                          ? 'Guardar Cambios'
                          : 'AGREGAR TODO (${pendingItems.length})',
                    ),
                  ),
              ],
            );
          },
        );
      },
    );
  }

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
            child: const Center(child: CircularProgressIndicator()),
          );
        },
        errorBuilder: (_, __, ___) => const Icon(Icons.broken_image),
      );
    } else {
      // FIX: Cast correcto a XFile y uso de File(path)
      // Soporta tanto File como XFile para evitar errores
      final String path = imageSource is XFile
          ? imageSource.path
          : (imageSource is File ? imageSource.path : imageSource.toString());

      imageWidget = Image.file(
        File(path),
        height: 80,
        width: 80,
        fit: BoxFit.cover,
      );
    }

    return Stack(
      clipBehavior: Clip.none,
      children: [
        GestureDetector(
          onTap: () => _showImagePreview(context, imageSource),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: imageWidget,
          ),
        ),
        Positioned(
          top: -10,
          right: -10,
          child: InkWell(
            onTap: onRemove,
            child: Container(
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white,
              ),
              child: Icon(
                Icons.cancel,
                color: Theme.of(context).colorScheme.error,
                size: 24,
              ),
            ),
          ),
        ),
      ],
    );
  }

  // --- HELPER: VISTA PREVIA DE IMAGEN ---
  void _showImagePreview(BuildContext context, dynamic imageSource) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: EdgeInsets.zero,
        child: Stack(
          alignment: Alignment.center,
          children: [
            InteractiveViewer(
              child: (imageSource is XFile || imageSource is File)
                  ? Image.file(
                      File(
                        imageSource is XFile
                            ? imageSource.path
                            : (imageSource as File).path,
                      ),
                    )
                  : Image.network(imageSource as String),
            ),
            Positioned(
              top: 40,
              right: 20,
              child: CircleAvatar(
                backgroundColor: Colors.black54,
                child: IconButton(
                  icon: const Icon(Icons.close, color: Colors.white),
                  onPressed: () => Navigator.pop(ctx),
                ),
              ),
            ),
          ],
        ),
      ),
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
      'is_paid': _isPaid, // Enviar estado pagado
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

  /// Formatea una lista de extras (que puede ser List<Map> o List<String>)
  /// para mostrar en el resumen del pedido.
  String _formatDetailsForList(List<dynamic>? rawList, double multiplier) {
    if (rawList == null || rawList.isEmpty) {
      return '';
    }

    final parts = <String>[];

    for (final e in rawList) {
      if (e is Map) {
        // Formato Nuevo (con precio)
        final name = e['name'] ?? 'Extra';
        final qty = (e['quantity'] as num?) ?? 1;
        final price = (e['price'] as num?)?.toDouble() ?? 0.0;

        // Aplicamos el multiplicador (0.5 o 1.0/peso)
        final totalCost = (price * qty) * multiplier;

        final priceText = (totalCost > 0)
            ? ' (${_currencyFormat.format(totalCost)})' // Usa _currencyFormat
            : '';

        parts.add(qty > 1 ? '$name (x$qty)$priceText' : '$name$priceText');
      } else if (e is String) {
        // Formato Viejo (solo nombre)
        parts.add(e);
      }
    }
    return parts.join(', ');
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
                      // (Reemplazo para el bloque anterior - Aprox. línea 894)
                      final item = _items[index];
                      final custom = item.customizationJson ?? {};
                      final category = ProductCategory.values.firstWhereOrNull(
                        (e) => e.name == custom['product_category'],
                      );

                      // --- INICIO DE LA LÓGICA DE DETALLES ---
                      final parts = <String>[];

                      if (category == ProductCategory.torta) {
                        // --- 1. Definir si es Torta Chica ---
                        const miniCakeName = 'Mini Torta Personalizada (Base)';
                        const microCakeName =
                            'Micro Torta (Base)'; // <-- Revisa este nombre

                        final bool isSmallCake =
                            item.name == miniCakeName ||
                            item.name == microCakeName;

                        final double weight =
                            (custom['weight_kg'] as num?)?.toDouble() ?? 1.0;

                        // --- 2. Definir el multiplicador de extras ---
                        // Usa 0.5 si es torta chica, si no, el peso
                        final double extraMultiplier = isSmallCake
                            ? 0.5
                            : weight;

                        // --- 3. Calcular Precio Base (despejando) ---
                        final List<dynamic> extraFillingsRaw =
                            custom['selected_extra_fillings'] ?? [];
                        final List<dynamic> extrasKgRaw =
                            custom['selected_extras_kg'] ?? [];
                        final List<dynamic> extrasUnitRaw =
                            custom['selected_extras_unit'] ?? [];

                        final double extraFillingsPrice = extraFillingsRaw.fold(
                          0.0,
                          (sum, data) {
                            final price =
                                (data is Map
                                    ? (data['price'] as num?)?.toDouble()
                                    : null) ??
                                0.0;
                            return sum + (price * extraMultiplier);
                          },
                        );
                        final double extrasKgPrice = extrasKgRaw.fold(0.0, (
                          sum,
                          data,
                        ) {
                          final price =
                              (data is Map
                                  ? (data['price'] as num?)?.toDouble()
                                  : null) ??
                              0.0;
                          return sum + (price * extraMultiplier);
                        });
                        final double extrasUnitPrice = extrasUnitRaw.fold(0.0, (
                          sum,
                          data,
                        ) {
                          final price =
                              (data is Map
                                  ? (data['price'] as num?)?.toDouble()
                                  : null) ??
                              0.0;
                          final qty =
                              (data is Map
                                  ? (data['quantity'] as num?)?.toDouble()
                                  : null) ??
                              1.0;
                          return sum + (price * qty);
                        });

                        final double costoExtrasTotal =
                            extraFillingsPrice +
                            extrasKgPrice +
                            extrasUnitPrice;
                        final double precioCalculadoConAjusteKg =
                            item.basePrice - costoExtrasTotal;

                        // --- 4. Construir 'parts' ---
                        parts.add(
                          'Precio Base: ${_currencyFormat.format(precioCalculadoConAjusteKg)}',
                        );

                        // Muestra el peso solo si NO es una torta chica
                        if (!isSmallCake && custom['weight_kg'] != null) {
                          parts.add('Peso: ${custom['weight_kg']} kg');
                        }

                        final List<String> fillings = List<String>.from(
                          custom['selected_fillings'] ?? [],
                        );
                        if (fillings.isNotEmpty) {
                          parts.add('Rellenos: ${fillings.join(', ')}');
                        }

                        final extraFillings = _formatDetailsForList(
                          custom['selected_extra_fillings'],
                          extraMultiplier,
                        );
                        if (extraFillings.isNotEmpty) {
                          parts.add('Rellenos Extra: $extraFillings');
                        }

                        final extrasKg = _formatDetailsForList(
                          custom['selected_extras_kg'],
                          extraMultiplier,
                        );
                        if (extrasKg.isNotEmpty) {
                          parts.add('Extras (x kg): $extrasKg');
                        }

                        final extrasUnit = _formatDetailsForList(
                          custom['selected_extras_unit'],
                          1.0,
                        );
                        if (extrasUnit.isNotEmpty) {
                          parts.add('Extras (x ud): $extrasUnit');
                        }
                      } else if (category == ProductCategory.mesaDulce) {
                        // 1. Mostrar Variante (String) si existe (ej: "18 cm")
                        if (custom['variant_name'] != null &&
                            custom['variant_name'].toString().isNotEmpty) {
                          final vName = custom['variant_name'].toString();
                          // Limpieza visual: si viene como "size24cm", lo dejamos como "24cm"
                          final formatted = vName.startsWith('size')
                              ? vName.replaceFirst('size', '')
                              : vName;
                          parts.add(formatted);
                        }
                        // 2. Mostrar Size (Enum) si existe (legacy/compatibility)
                        else if (custom['selected_size'] != null) {
                          parts.add(
                            getUnitText(
                              ProductUnit.values.byName(
                                custom['selected_size'],
                              ),
                            ),
                          );
                        } else if (custom['is_half_dozen'] == true) {
                          parts.add('Media Docena');
                        }
                      } else if (category == ProductCategory.box) {
                        // Lógica de Box (replicando la de order_detail_page)
                        const miniCakeName = 'Mini Torta Personalizada (Base)';
                        const microCakeName = 'Micro Torta (Base)';
                        final String boxType = custom['box_type'] ?? '';
                        final bool isPersonalizado =
                            boxType == 'BOX DULCE Personalizado (Armar)';
                        final String? baseCakeName =
                            custom['selected_base_cake'] as String?;

                        bool isSmallCake = isPersonalizado
                            ? (baseCakeName == miniCakeName ||
                                  baseCakeName == microCakeName)
                            : true; // Predefinido siempre es torta chica

                        final double costMultiplier = isSmallCake ? 0.5 : 1.0;

                        final List<String> fillings = List<String>.from(
                          custom['selected_fillings'] ?? [],
                        );
                        if (fillings.isNotEmpty) {
                          parts.add('Rellenos: ${fillings.join(', ')}');
                        }

                        final extraFillings = _formatDetailsForList(
                          custom['selected_extra_fillings'],
                          costMultiplier,
                        );
                        if (extraFillings.isNotEmpty) {
                          parts.add('Rellenos Extra: $extraFillings');
                        }

                        final extrasKg = _formatDetailsForList(
                          custom['selected_extras_kg'],
                          costMultiplier,
                        );
                        if (extrasKg.isNotEmpty) {
                          parts.add('Extras (x kg): $extrasKg');
                        }

                        final extrasUnit = _formatDetailsForList(
                          custom['selected_extras_unit'],
                          1.0,
                        );
                        if (extrasUnit.isNotEmpty) {
                          parts.add('Extras (x ud): $extrasUnit');
                        }

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
                                return size != null
                                    ? '$name (${size.replaceAll('size', '')}) x$qty'
                                    : '$name x$qty';
                              })
                              .join(', ');
                          parts.add('Mesa Dulce: $mesaItemsText');
                        }
                      }

                      double manualAdjustment = 0.0;

                      if (category == ProductCategory.box) {
                        // En los Boxes, el ajuste manual PURO se guarda en el JSON
                        manualAdjustment =
                            (custom['manual_adjustment_value'] as num?)
                                ?.toDouble() ??
                            0.0;
                      } else {
                        // En Tortas y Mesa Dulce, el 'adjustments' del item es el ajuste manual
                        manualAdjustment = item.adjustments;
                      }

                      // Añadir la línea al desglose SOLAMENTE si es diferente de cero
                      if (manualAdjustment != 0) {
                        final sign = manualAdjustment > 0
                            ? '+'
                            : ''; // Añade un '+' si es positivo
                        parts.add(
                          'Ajuste Manual: $sign${_currencyFormat.format(manualAdjustment)}',
                        );
                      }

                      if (item.customizationNotes != null &&
                          item.customizationNotes!.isNotEmpty) {
                        parts.add('Notas Ajuste: ${item.customizationNotes}');
                      }

                      final itemNotes = custom['item_notes'] as String?;
                      if (itemNotes != null && itemNotes.isNotEmpty) {
                        parts.add('Notas Item: $itemNotes');
                      }

                      final String details = parts.join('\n');

                      return Card(
                        margin: const EdgeInsets.symmetric(vertical: 4),
                        elevation: 1,
                        child: ListTile(
                          leading:
                              (custom['photo_url'] != null ||
                                  (item.localFile != null &&
                                      (item.localFile as List).isNotEmpty))
                              ? GestureDetector(
                                  onTap: () {
                                    // Determinar fuente de imagen para preview
                                    dynamic imageSource;
                                    if (item.localFile != null &&
                                        (item.localFile as List).isNotEmpty) {
                                      // Prioridad a local
                                      imageSource =
                                          (item.localFile as List).first;
                                    } else {
                                      // Fallback a URL
                                      imageSource = custom['photo_url'];
                                    }
                                    if (imageSource != null) {
                                      _showImagePreview(context, imageSource);
                                    }
                                  },
                                  child: Stack(
                                    clipBehavior: Clip.none,
                                    children: [
                                      ClipRRect(
                                        borderRadius: BorderRadius.circular(4),
                                        child:
                                            (item.localFile != null &&
                                                (item.localFile as List)
                                                    .isNotEmpty)
                                            ? Image.file(
                                                File(
                                                  ((item.localFile as List)
                                                              .first
                                                          as XFile)
                                                      .path,
                                                ),
                                                width: 50,
                                                height: 50,
                                                fit: BoxFit.cover,
                                              )
                                            : Image.network(
                                                custom['photo_url'],
                                                width: 50,
                                                height: 50,
                                                fit: BoxFit.cover,
                                                errorBuilder: (_, __, ___) =>
                                                    const Icon(Icons.image),
                                              ),
                                      ),
                                      Positioned(
                                        bottom: -6,
                                        right: -6,
                                        child: CircleAvatar(
                                          radius: 10,
                                          backgroundColor: Theme.of(
                                            context,
                                          ).colorScheme.tertiary,
                                          child: Text(
                                            '${item.qty}',
                                            style: TextStyle(
                                              fontSize: 10,
                                              color: Theme.of(
                                                context,
                                              ).colorScheme.onTertiary,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                )
                              : CircleAvatar(
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
      // Usar 'surface' en lugar de 'surfaceContainer' para que se sienta menos "pesado/marrón"
      color: Theme.of(context).colorScheme.surface,
      // Contenedor con borde superior sutil
      shape: Border(
        top: BorderSide(
          color: Theme.of(context).colorScheme.outlineVariant,
          width: 0.5,
        ),
      ),
      child: Padding(
        // Reducir padding vertical
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // (Switch y Divider eliminados para ahorrar espacio)

            // Fila de Entradas + Check Pagado
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  flex: 3,
                  child: TextFormField(
                    controller: _depositController,
                    decoration: const InputDecoration(
                      labelText: 'Seña Recibida (\$)',
                      prefixText: '\$',
                      border: OutlineInputBorder(),
                      isDense: true,
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 12,
                      ),
                    ),
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: false,
                    ),
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    onChanged: (_) => _recalculateTotals(),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  flex: 3,
                  child: TextFormField(
                    controller: _deliveryCostController,
                    decoration: const InputDecoration(
                      labelText: 'Envío (\$)',
                      prefixText: '\$',
                      border: OutlineInputBorder(),
                      isDense: true,
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 12,
                      ),
                    ),
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: false,
                    ),
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  ),
                ),
                const SizedBox(width: 8),
                // Switch Pagado Compacto
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Pagado?',
                      style: TextStyle(
                        fontSize: 10,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                    SizedBox(
                      height: 30, // Forzar altura pequeña
                      child: Transform.scale(
                        scale: 0.8,
                        child: Switch(
                          value: _isPaid,
                          activeColor: Colors.green,
                          onChanged: (val) {
                            setState(() => _isPaid = val);
                            _recalculateTotals();
                          },
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 8),
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
