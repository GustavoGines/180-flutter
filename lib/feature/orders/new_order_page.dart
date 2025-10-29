import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // Para input formatters
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:flutter_typeahead/flutter_typeahead.dart';
import 'package:image_picker/image_picker.dart';
import 'package:collection/collection.dart'; // Para .firstWhereOrNull

// --- AÑADIDOS PARA COMPRESIÓN ---
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:pasteleria_180_flutter/core/json_utils.dart';
import 'package:path_provider/path_provider.dart';
// --- FIN DE AÑADIDOS ---

// --- IMPORTAR EL CATÁLOGO ---
import 'product_catalog.dart';
// --- FIN IMPORTAR CATÁLOGO ---

import '../../core/models/client.dart';
import '../../core/models/order.dart';
import '../../core/models/order_item.dart';
import '../clients/clients_repository.dart';
import 'orders_repository.dart';
import 'order_detail_page.dart';
import 'home_page.dart'; // Para invalidar ordersByFilterProvider

// Providers
final clientsRepoProvider = Provider((_) => ClientsRepository());
// El provider de ordersRepo ya debería existir globalmente, si no, defínelo aquí o impórtalo.
// final ordersRepoProvider = Provider((_) => OrdersRepository());

// La página principal ahora es un ConsumerWidget simple que decide si crear o editar
class NewOrderPage extends ConsumerWidget {
  final int? orderId; // Recibe el ID, o nulo si es un pedido nuevo
  const NewOrderPage({super.key, this.orderId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isEditMode = orderId != null;

    // Colores de la marca (podrían estar en un archivo de tema global)
    const Color darkBrown = Color(0xFF7A4A4A);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          isEditMode ? 'Editar Pedido' : 'Nuevo Pedido',
          style: const TextStyle(color: darkBrown),
        ),
        backgroundColor: Colors.white,
        elevation: 1,
        iconTheme: const IconThemeData(color: darkBrown),
      ),
      body: isEditMode
          // Si estamos editando, buscamos el pedido primero
          ? ref
                .watch(orderByIdProvider(orderId!))
                .when(
                  loading: () => const Center(
                    child: CircularProgressIndicator(color: darkBrown),
                  ),
                  error: (err, stack) => Center(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Text(
                        'Error al cargar el pedido: $err\nIntenta recargar la página.',
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Colors.red),
                      ),
                    ),
                  ),
                  // Cuando tenemos los datos, construimos el formulario y se los pasamos
                  data: (order) => _OrderForm(order: order),
                )
          // Si estamos creando, construimos el formulario vacío
          : const _OrderForm(),
    );
  }
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

  late DateTime _date;
  late TimeOfDay _start;
  late TimeOfDay _end;
  final _depositController = TextEditingController(); // Cambiado a controller
  final _deliveryCostController =
      TextEditingController(); // Nuevo controller para envío
  final _notesController = TextEditingController(); // Cambiado a controller
  final List<OrderItem> _items = [];

  bool _isLoading = false; // Para el botón de guardar
  final NumberFormat _currencyFormat = NumberFormat.currency(
    locale: 'es_AR',
    symbol: '\$',
  ); // Formato de moneda

  // Paleta de colores (podría venir del tema)
  static const Color primaryPink = Color(0xFFF8B6B6);
  static const Color darkBrown = Color(0xFF7A4A4A);
  static const Color lightBrownText = Color(0xFFA57D7D);

  bool get isEditMode => widget.order != null;

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
      _depositController.text =
          order.deposit?.toStringAsFixed(0) ?? '0'; // Sin decimales
      _deliveryCostController.text =
          order.deliveryCost?.toStringAsFixed(0) ??
          '0'; // Cargar costo envío si existe
      _notesController.text = order.notes ?? '';
      _items.addAll(order.items);
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
  }

  @override
  void dispose() {
    _clientNameController.dispose();
    _depositController.dispose();
    _deliveryCostController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  // --- CÁLCULO DE TOTALES ---
  double _itemsSubtotal = 0.0;
  double _deliveryCost = 0.0;
  double _grandTotal = 0.0;
  double _depositAmount = 0.0;
  double _remainingBalance = 0.0;

  void _recalculateTotals() {
    double subtotal = 0.0;
    for (var item in _items) {
      // 👇 USA EL GETTER finalUnitPrice
      subtotal += (item.finalUnitPrice * item.qty);
    }

    double delivery =
        double.tryParse(_deliveryCostController.text.replaceAll(',', '.')) ??
        0.0;
    double deposit =
        double.tryParse(_depositController.text.replaceAll(',', '.')) ?? 0.0;
    double total = subtotal + delivery;
    double remaining = total - deposit;

    // Usamos addPostFrameCallback para evitar errores de setState durante el build
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

  // Llama a _recalculateTotals cada vez que se añada, edite o elimine un item
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
      locale: const Locale('es', 'AR'), // Para español
      firstDate: DateTime.now().subtract(
        const Duration(days: 90),
      ), // Ajustar rango
      lastDate: DateTime.now().add(const Duration(days: 730)),
      initialDate: _date,
      // Theming básico
      builder: (context, child) {
        return Theme(
          data: ThemeData.light().copyWith(
            colorScheme: const ColorScheme.light(
              primary: darkBrown, // color header background
              onPrimary: Colors.white, // color header text
              onSurface: darkBrown, // color body text
            ),
            textButtonTheme: TextButtonThemeData(
              style: TextButton.styleFrom(
                foregroundColor: darkBrown, // button text color
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
      initialEntryMode: TimePickerEntryMode.input, // Facilita ingreso rápido
      builder: (context, child) {
        return Theme(
          data: ThemeData.light().copyWith(
            colorScheme: const ColorScheme.light(
              primary: darkBrown, // color header background
              onPrimary: Colors.white,
              surface: primaryPink, // Background selector
              onSurface: darkBrown, // Números
            ),
            timePickerTheme: TimePickerThemeData(
              // Estilos adicionales si quieres
            ),
          ),
          child: child!,
        );
      },
    );
    if (t != null) {
      setState(() {
        if (isStart) {
          _start = t;
          // Opcional: ajustar _end si _start es posterior
          if ((_start.hour * 60 + _start.minute) >=
              (_end.hour * 60 + _end.minute)) {
            _end = TimeOfDay(
              hour: (_start.hour + 1) % 24,
              minute: _start.minute,
            );
          }
        } else {
          _end = t;
          // Opcional: ajustar _start si _end es anterior
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

  // --- DIÁLOGO NUEVO CLIENTE (sin cambios) ---

  void _addClientDialog() {
    final nameController = TextEditingController();
    final phoneController = TextEditingController();
    final addressController = TextEditingController();

    showDialog(
      context: context, // <-- Contexto de _OrderFormState
      builder: (dialogContext) => AlertDialog(
        // <-- Contexto del Dialog
        title: const Text('Nuevo Cliente', style: TextStyle(color: darkBrown)),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(labelText: 'Nombre'),
              ),
              TextField(
                controller: phoneController,
                decoration: const InputDecoration(labelText: 'Teléfono'),
                keyboardType: TextInputType.phone,
              ),
              TextField(
                controller: addressController,
                decoration: const InputDecoration(labelText: 'Dirección'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () =>
                Navigator.pop(dialogContext), // Usa dialogContext para cerrar
            child: const Text('Cancelar', style: TextStyle(color: darkBrown)),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: darkBrown),
            onPressed: () async {
              if (nameController.text.trim().isEmpty) return;
              // Mostrar loader (opcional pero recomendado)
              showDialog(
                context: dialogContext,
                barrierDismissible: false,
                builder: (_) =>
                    const Center(child: CircularProgressIndicator()),
              );

              Client? newClient; // Declarar fuera del try
              String? errorMessage; // Para guardar mensaje de error

              try {
                newClient = await ref.read(clientsRepoProvider).createClient({
                  'name': nameController.text.trim(),
                  'phone': phoneController.text.trim().isEmpty
                      ? null
                      : phoneController.text.trim(),
                  'address': addressController.text.trim().isEmpty
                      ? null
                      : addressController.text.trim(),
                });

                // Si llegamos aquí, la creación fue exitosa
                // Cerrar el loader si se mostró
                if (dialogContext.mounted) Navigator.pop(dialogContext);
              } catch (e) {
                errorMessage = e.toString(); // Guardar el error
                debugPrint("Error creando cliente: $e");
                // Cerrar el loader si se mostró
                if (dialogContext.mounted) Navigator.pop(dialogContext);
                // No cerramos el diálogo principal aquí todavía, lo hacemos después del SnackBar
              }

              // --- CORRECCIÓN: Comprobar 'mounted' ANTES de usar context/dialogContext ---
              // Usar el context del _OrderFormState (this.context) para setState y SnackBar
              // Usar dialogContext para cerrar el diálogo en sí

              // Si hubo éxito Y el _OrderFormState sigue montado
              if (newClient != null && mounted) {
                setState(() {
                  _selectedClient = newClient;
                  _clientNameController.text = newClient!
                      .name; // Usar ! porque ya sabemos que no es null
                });
                // Cerrar el diálogo de "Nuevo Cliente"
                if (dialogContext.mounted) Navigator.pop(dialogContext);
                // Mostrar SnackBar de éxito usando el context principal
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Cliente creado con éxito'),
                    backgroundColor: Colors.green,
                  ),
                );
              }
              // Si hubo un error Y el _OrderFormState sigue montado
              else if (errorMessage != null && mounted) {
                // Primero, intentar cerrar el diálogo si aún está abierto
                if (dialogContext.mounted) Navigator.pop(dialogContext);
                // Luego mostrar el SnackBar de error usando el context principal
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Error al crear cliente: $errorMessage'),
                    backgroundColor: Colors.red,
                  ),
                );
              }
              // --- FIN CORRECCIÓN ---
            },
            child: const Text('Guardar Cliente'),
          ),
        ],
      ),
    );
  }

  // --- FUNCIÓN HELPER PARA COMPRIMIR Y SUBIR (sin cambios) ---
  Future<String?> _compressAndUpload(XFile imageFile, WidgetRef ref) async {
    final tempDir = await getTemporaryDirectory();
    // Crear un nombre de archivo un poco más único
    final fileName =
        '${DateTime.now().millisecondsSinceEpoch}_${imageFile.name.split('/').last}.jpg';
    final tempPath = '${tempDir.path}/$fileName';

    File? tempFile; // Para asegurar la limpieza

    try {
      final compressedBytes = await FlutterImageCompress.compressWithFile(
        imageFile.path,
        minWidth: 1200,
        minHeight: 1200,
        quality: 80,
        format: CompressFormat.jpeg,
      );

      XFile fileToUpload;

      if (compressedBytes != null) {
        tempFile = File(tempPath); // Asignar antes de escribir
        await tempFile.writeAsBytes(compressedBytes);
        fileToUpload = XFile(tempFile.path);
        debugPrint('Imagen comprimida a: ${tempFile.lengthSync()} bytes');
      } else {
        fileToUpload = imageFile; // Fallback
        debugPrint(
          'Compresión falló, subiendo original: ${await imageFile.length()} bytes',
        );
      }

      // --- Operación Async ---
      final url = await ref.read(ordersRepoProvider).uploadImage(fileToUpload);
      // --- Fin Operación Async ---

      // Limpiar después de subir exitosamente
      await tempFile?.delete();

      return url;
    } catch (e) {
      debugPrint("Error en _compressAndUpload: $e");

      // --- CORRECCIÓN: Comprobar mounted antes de SnackBar ---
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error subiendo imagen: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
      // --- FIN CORRECCIÓN ---

      // Intentar borrar temporal si existe incluso con error
      try {
        await tempFile?.delete();
      } catch (_) {}
      return null; // Retornar null en caso de error
    }
  }

  // --- DIÁLOGO PRINCIPAL PARA AÑADIR ITEM ---
  void _addItemDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Seleccionar Tipo de Producto'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.cake, color: primaryPink),
              title: const Text('Mini Torta / Accesorio'),
              onTap: () {
                Navigator.of(context).pop();
                _addMiniCakeDialog(); // Nuevo diálogo específico
              },
            ),
            ListTile(
              leading: const Icon(Icons.cake_outlined, color: darkBrown),
              title: const Text('Torta por Kilo'),
              onTap: () {
                Navigator.of(context).pop();
                _addCakeDialog(); // Diálogo para tortas
              },
            ),
            ListTile(
              leading: const Icon(Icons.icecream, color: lightBrownText),
              title: const Text('Producto de Mesa Dulce'),
              onTap: () {
                Navigator.of(context).pop();
                _addMesaDulceDialog(); // Diálogo para mesa dulce
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

  // --- DIÁLOGO PARA MINI TORTAS Y ACCESORIOS (ACTUALIZADO) ---
  void _addMiniCakeDialog({OrderItem? existingItem, int? itemIndex}) {
    final bool isEditing = existingItem != null;

    // --- Inicialización ---
    Product? selectedProduct = isEditing
        ? miniCakeProducts.firstWhereOrNull(
            (p) => p.name == existingItem.name,
          ) // Usar !
        : miniCakeProducts.first;

    double basePrice = isEditing
        ? existingItem
              .basePrice // Usar !
        : selectedProduct?.price ?? 0.0; // Precio base del catálogo

    double adjustments = isEditing ? existingItem.adjustments : 0.0; // Usar !

    final qtyController = TextEditingController(
      text: isEditing ? existingItem.qty.toString() : '1', // Usar !
    );
    final adjustmentsController = TextEditingController(
      text: adjustments.toStringAsFixed(0), // Mostrar ajuste actual
    );
    final notesController = TextEditingController(
      text: isEditing ? existingItem.customizationNotes ?? '' : '', // Usar !
    );
    final finalPriceController = TextEditingController();
    // --- Fin Inicialización ---

    // --- Función para calcular precio ---
    void calculatePrice() {
      final qty = int.tryParse(qtyController.text) ?? 0;
      final currentAdjustments =
          double.tryParse(adjustmentsController.text) ?? 0.0;
      if (qty > 0) {
        final finalUnitPrice = basePrice + currentAdjustments;
        finalPriceController.text = (finalUnitPrice * qty).toStringAsFixed(
          0,
        ); // Muestra el total del item
      } else {
        finalPriceController.text = 'N/A';
      }
      // Actualizar el estado local de adjustments para guardarlo
      adjustments = currentAdjustments;
    }

    // Calcular precio inicial
    WidgetsBinding.instance.addPostFrameCallback((_) => calculatePrice());
    // --- Fin Función Precio ---
    showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          // Necesario para Dropdown y cálculos
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text(isEditing ? 'Editar Item' : 'Añadir Item'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    DropdownButtonFormField<Product>(
                      initialValue: selectedProduct, // Ahora usa 'value'
                      items: miniCakeProducts.map((Product product) {
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
                          basePrice =
                              newValue?.price ?? 0.0; // Actualiza precio base
                          // Reinicia ajustes si cambia el producto? Opcional.
                          // adjustmentsController.text = '0';
                          calculatePrice(); // Recalcula
                        });
                      },
                      decoration: const InputDecoration(labelText: 'Producto'),
                      isExpanded: true,
                    ),
                    TextFormField(
                      controller: qtyController,
                      decoration: const InputDecoration(labelText: 'Cantidad'),
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      onChanged: (_) =>
                          setDialogState(calculatePrice), // Recalcula
                    ),
                    // --- NUEVOS CAMPOS ---
                    TextFormField(
                      controller: adjustmentsController,
                      decoration: InputDecoration(
                        labelText: 'Ajuste Manual al Precio Unitario (\$)',
                        hintText: 'Ej: 500 (extra), -200 (descuento)',
                        prefixText:
                            '${basePrice.toStringAsFixed(0)} + ', // Muestra base
                      ),
                      keyboardType: const TextInputType.numberWithOptions(
                        signed: true, // Permite negativo
                        decimal: false,
                      ),
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(
                          RegExp(r'^-?\d*'),
                        ), // Permite '-' al inicio y dígitos
                      ],
                      onChanged: (_) =>
                          setDialogState(calculatePrice), // Recalcula
                    ),
                    TextFormField(
                      controller: notesController,
                      decoration: const InputDecoration(
                        labelText: 'Notas de Ajuste/Personalización',
                        hintText: 'Ej: Diseño especial, cambio de color, etc.',
                      ),
                      maxLines: 2,
                      textCapitalization: TextCapitalization.sentences,
                    ),
                    // --- FIN NUEVOS CAMPOS ---
                    TextFormField(
                      // Mostrar precio final (no editable)
                      controller: finalPriceController,
                      readOnly: true,
                      decoration: const InputDecoration(
                        labelText: 'Precio Final Item (Cant * (Base + Ajuste))',
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
                  style: FilledButton.styleFrom(backgroundColor: darkBrown),
                  onPressed: () {
                    if (selectedProduct == null) return;
                    final qty = int.tryParse(qtyController.text) ?? 0;
                    // 'adjustments' ya está actualizado por el onChanged

                    if (qty <= 0) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('La cantidad debe ser mayor a 0.'),
                          backgroundColor: Colors.orange,
                        ),
                      );
                      return;
                    }

                    final newItem = OrderItem(
                      id: isEditing ? existingItem.id : null, // Usar !
                      name: selectedProduct!.name, // Usar !
                      qty: qty,
                      basePrice: basePrice, // Guardar precio base
                      adjustments: adjustments, // Guardar ajuste
                      customizationNotes: notesController.text.trim().isEmpty
                          ? null
                          : notesController.text.trim(),
                      customizationJson: {
                        // Guardar info relevante
                        'product_category':
                            selectedProduct!.category.name, // Usar !
                        'product_unit': selectedProduct!.unit.name, // Usar !
                        // Puedes añadir más si es necesario, pero evita duplicar lo que ya está en campos
                      },
                    );

                    _updateItemsAndRecalculate(() {
                      if (isEditing) {
                        _items[itemIndex!] = newItem; // Usar !
                      } else {
                        _items.add(newItem);
                      }
                    });

                    if (dialogContext.mounted) Navigator.pop(dialogContext);
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

  // --- DIÁLOGO PARA TORTAS POR KILO (ACTUALIZADO) ---
  void _addCakeDialog({OrderItem? existingItem, int? itemIndex}) {
    final bool isEditing = existingItem != null;
    Map<String, dynamic> customData = isEditing
        ? (existingItem.customizationJson ?? {})
        : {}; // Usar !

    // --- Inicialización ---
    Product? selectedCakeType = isEditing
        ? cakeProducts.firstWhereOrNull(
            (p) => p.name == existingItem.name,
          ) // Usar !
        : cakeProducts.first;

    final weightController = TextEditingController(
      text: customData['weight_kg']?.toString() ?? '1.0',
    );
    // NUEVO: Controller para ajuste manual
    final adjustmentsController = TextEditingController(
      text: isEditing
          ? existingItem.adjustments.toStringAsFixed(0)
          : '0', // Usar !
    );
    final notesController = TextEditingController(
      // Notas generales del item
      text: customData['item_notes'] as String? ?? '',
    );
    // NUEVO: Controller para notas DEL AJUSTE
    final adjustmentNotesController = TextEditingController(
      text: isEditing ? existingItem.customizationNotes ?? '' : '', // Usar !
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
            .map(
              (name) => extraCostFillings.firstWhereOrNull(
                (f) => f.name == name?.toString(),
              ),
            )
            .whereType<Filling>()
            .toList();
    List<CakeExtra> selectedExtrasKg =
        (customData['selected_extras_kg'] as List<dynamic>? ?? [])
            .map(
              (name) => cakeExtras.firstWhereOrNull(
                (ex) => ex.name == name?.toString() && !ex.isPerUnit,
              ),
            )
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
    List<XFile> newImageFiles = [];
    bool isUploading = false;

    // Controladores para precios (solo display)
    final calculatedBasePriceController =
        TextEditingController(); // Precio calculado ANTES de ajuste manual
    final finalPriceController =
        TextEditingController(); // Precio final DESPUÉS de ajuste manual
    // --- Fin Inicialización ---

    // --- Función para calcular precio ---
    double calculatedBasePrice = 0.0; // Variable para guardar el base calculado
    double manualAdjustments = 0.0; // Variable para guardar el ajuste manual

    void calculateCakePrice() {
      if (selectedCakeType == null) {
        calculatedBasePriceController.text = 'N/A';
        finalPriceController.text = 'N/A';
        return;
      }
      double weight =
          double.tryParse(weightController.text.replaceAll(',', '.')) ?? 0.0;
      manualAdjustments =
          double.tryParse(adjustmentsController.text) ??
          0.0; // Lee ajuste manual

      if (weight <= 0) {
        calculatedBasePriceController.text = 'N/A';
        finalPriceController.text = 'N/A';
        return;
      }

      double base = selectedCakeType!.price * weight;
      double extraFillingsPrice = selectedExtraFillings.fold(
        0.0,
        (sum, f) => sum + (f.extraCostPerKg * weight),
      );
      double extrasKgPrice = selectedExtrasKg.fold(
        0.0,
        (sum, ex) => sum + (ex.costPerKg * weight),
      );
      double extrasUnitPrice = selectedExtrasUnit.fold(
        0.0,
        (sum, sel) => sum + (sel.extra.costPerUnit * sel.quantity),
      );

      calculatedBasePrice =
          base +
          extraFillingsPrice +
          extrasKgPrice +
          extrasUnitPrice; // Base = Suma de todo lo calculado
      double finalPrice =
          calculatedBasePrice +
          manualAdjustments; // Final = Base Calculado + Ajuste Manual

      calculatedBasePriceController.text = calculatedBasePrice.toStringAsFixed(
        0,
      );
      finalPriceController.text = finalPrice.toStringAsFixed(0);
    }

    WidgetsBinding.instance.addPostFrameCallback((_) => calculateCakePrice());
    // --- Fin Función Precio ---

    showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            // ... (Helpers buildFillingCheckbox, buildExtraKgCheckbox, buildExtraUnitSelector SIN CAMBIOS) ...
            Widget buildFillingCheckbox(Filling filling, bool isExtraCost) {
              bool isSelected = isExtraCost
                  ? selectedExtraFillings.contains(filling)
                  : selectedFillings.contains(filling);
              return CheckboxListTile(
                title: Text(filling.name),
                subtitle: Text(
                  isExtraCost
                      ? '(+\$${filling.extraCostPerKg.toStringAsFixed(0)}/kg)'
                      : '(Gratis)',
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
                subtitle: Text('(+\$${extra.costPerKg.toStringAsFixed(0)}/kg)'),
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
                              qty = 1; // Mínimo 1 si está seleccionado
                            }
                            selection.quantity = qty;
                            // No necesitamos setDialogState aquí si usamos un controller, pero sí recalcular
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
                    // --- Campos existentes (Tipo, Peso, Rellenos, Extras, Notas, Fotos...) ---
                    DropdownButtonFormField<Product>(
                      initialValue: selectedCakeType,
                      items: cakeProducts.map((Product product) {
                        return DropdownMenuItem<Product>(
                          value: product,
                          child: Text(
                            '${product.name} (\$${product.price.toStringAsFixed(0)}/kg)',
                            overflow: TextOverflow.ellipsis,
                          ),
                        );
                      }).toList(),
                      onChanged: (Product? newValue) {
                        setDialogState(() {
                          selectedCakeType = newValue;
                          calculateCakePrice();
                        });
                      },
                      decoration: const InputDecoration(
                        labelText: 'Tipo de Torta',
                      ),
                      isExpanded:
                          true, // Para que el texto largo no se corte tanto
                    ),
                    const SizedBox(height: 16),
                    // Peso
                    TextFormField(
                      // Peso
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
                        ), // Acepta . o ,
                      ],
                      onChanged: (_) => setDialogState(calculateCakePrice),
                    ),
                    const SizedBox(height: 16),

                    // Rellenos Gratuitos
                    Text(
                      'Rellenos Incluidos (Seleccionar)',
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                    // Rellenos
                    ...freeFillings.map((f) => buildFillingCheckbox(f, false)),
                    const SizedBox(height: 16),

                    // Rellenos con Costo Extra
                    Text(
                      'Rellenos con Costo Extra (Seleccionar)',
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                    // Rellenos Extra
                    ...extraCostFillings.map(
                      (f) => buildFillingCheckbox(f, true),
                    ),
                    const SizedBox(height: 16),

                    // Extras por Kg
                    Text(
                      'Extras (Costo por Kg)',
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                    // Extras KG
                    ...cakeExtras
                        .where((ex) => !ex.isPerUnit)
                        .map(buildExtraKgCheckbox),
                    const SizedBox(height: 16),

                    // Extras por Unidad
                    Text(
                      'Extras (Costo por Unidad)',
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                    // Extras Unidad
                    ...cakeExtras
                        .where((ex) => ex.isPerUnit)
                        .map(buildExtraUnitSelector),
                    const SizedBox(height: 16),

                    // Notas específicas del item
                    TextField(
                      // Notas Item
                      controller: notesController,
                      decoration: const InputDecoration(
                        labelText:
                            'Notas Específicas (ej. diseño, detalles fondant)',
                      ),
                      maxLines: 3,
                    ),
                    const SizedBox(height: 16),

                    // Sección de Fotos (igual que en addItemDialog)
                    // ... Sección de Fotos (SIN CAMBIOS) ...
                    const Divider(),
                    const Text(
                      'Fotos de Referencia (Opcional)',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    // Wrap de fotos
                    Padding(
                      padding: const EdgeInsets.only(top: 8.0),
                      child: Wrap(
                        spacing: 8.0,
                        runSpacing: 8.0,
                        children: [
                          ...existingImageUrls.map(
                            (url) => _buildImageThumbnail(
                              url,
                              true,
                              () => setDialogState(
                                () => existingImageUrls.remove(url),
                              ),
                            ),
                          ),
                          ...newImageFiles.map(
                            (file) => _buildImageThumbnail(
                              file,
                              false,
                              () => setDialogState(
                                () => newImageFiles.remove(file),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Botón Añadir Fotos
                    TextButton.icon(
                      icon: const Icon(Icons.photo_library),
                      label: const Text('Añadir Fotos'),
                      onPressed: () async {
                        final pickedFiles = await picker.pickMultiImage();
                        if (pickedFiles.isNotEmpty) {
                          setDialogState(
                            () => newImageFiles.addAll(pickedFiles),
                          );
                        }
                      },
                    ),
                    const Divider(),
                    // --- FIN Campos existentes ---

                    // --- NUEVOS CAMPOS ---
                    TextFormField(
                      // Mostrar precio base calculado (readOnly)
                      controller: calculatedBasePriceController,
                      readOnly: true,
                      decoration: const InputDecoration(
                        labelText: 'Precio Base Calculado',
                        prefixText: '\$',
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      // Input para ajuste manual
                      controller: adjustmentsController,
                      decoration: InputDecoration(
                        labelText: 'Ajuste Manual Adicional (\$)',
                        hintText: 'Ej: 5000 (extra), -2000 (descuento)',
                        prefixText:
                            '${calculatedBasePriceController.text} + ', // Muestra base calculado
                      ),
                      keyboardType: const TextInputType.numberWithOptions(
                        signed: true,
                        decimal: false,
                      ),
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(RegExp(r'^-?\d*')),
                      ],
                      onChanged: (_) =>
                          setDialogState(calculateCakePrice), // Recalcula
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      // Input para notas del ajuste
                      controller: adjustmentNotesController,
                      decoration: const InputDecoration(
                        labelText: 'Notas del Ajuste Manual',
                        hintText: 'Ej: Decoración compleja, descuento especial',
                      ),
                      textCapitalization: TextCapitalization.sentences,
                    ),
                    // --- FIN NUEVOS CAMPOS ---
                    const SizedBox(height: 16),
                    // Precio Final (readOnly)
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
                  style: FilledButton.styleFrom(backgroundColor: darkBrown),
                  onPressed: isUploading
                      ? null
                      : () async {
                          if (selectedCakeType == null) return;
                          final weight =
                              double.tryParse(
                                weightController.text.replaceAll(',', '.'),
                              ) ??
                              0.0;
                          // 'manualAdjustments' ya se actualizó en calculateCakePrice
                          final adjustmentNotes = adjustmentNotesController.text
                              .trim();

                          if (weight <= 0 || calculatedBasePrice <= 0) {
                            // Validar base calculado
                            // Mostrar algún error si el peso o precio es inválido
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('El peso debe ser mayor a 0.'),
                              ), // Error
                            );
                            return;
                          }

                          setDialogState(() => isUploading = true);

                          // Subir NUEVAS imágenes
                          // ... (Lógica para subir imágenes SIN CAMBIOS) ...
                          final List<String> newUploadedUrls = [];
                          if (newImageFiles.isNotEmpty) {
                            for (final imageFile in newImageFiles) {
                              final url = await _compressAndUpload(
                                imageFile,
                                ref,
                              );
                              if (url != null) newUploadedUrls.add(url);
                            }
                          }
                          // Combinar URLs
                          final allImageUrls = [
                            ...existingImageUrls,
                            ...newUploadedUrls,
                          ];
                          // --- FIN Lógica subir imágenes ---

                          // Construcción del customizationJson (SIN CAMBIOS, ya incluía todo)
                          final customization = {
                            'product_category': selectedCakeType!.category.name,
                            'cake_type': selectedCakeType!.name,
                            'weight_kg': weight,
                            'selected_fillings': selectedFillings
                                .map((f) => f.name)
                                .toList(),
                            'selected_extra_fillings': selectedExtraFillings
                                .map((f) => f.name)
                                .toList(),
                            'selected_extras_kg': selectedExtrasKg
                                .map((ex) => ex.name)
                                .toList(),
                            'selected_extras_unit': selectedExtrasUnit
                                .map(
                                  (sel) => {
                                    'name': sel.extra.name,
                                    'quantity': sel.quantity,
                                  },
                                )
                                .toList(),
                            if (notesController.text.trim().isNotEmpty)
                              'item_notes': notesController.text
                                  .trim(), // Notas generales del item
                            if (allImageUrls.isNotEmpty)
                              'photo_urls': allImageUrls,
                            // 'calculated_base_price': calculatedBasePrice, // COMENTADO: Quitar campos calculados
                          };
                          // Limpiar nulos o listas vacías si prefieres
                          customization.removeWhere(
                            (key, value) => (value is List && value.isEmpty),
                          );

                          final newItem = OrderItem(
                            id: isEditing ? existingItem.id : null, // Usar !
                            name: selectedCakeType!
                                .name, // Nombre base de la torta
                            qty:
                                1, // Para tortas, la cantidad suele ser 1, el precio depende del peso/extras
                            basePrice:
                                calculatedBasePrice, // El base es el calculado
                            adjustments:
                                manualAdjustments, // El ajuste es el manual
                            customizationNotes: adjustmentNotes.isEmpty
                                ? null
                                : adjustmentNotes, // Notas del ajuste
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
                  child: isUploading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : Text(isEditing ? 'Guardar Cambios' : 'Agregar'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // --- DIÁLOGO PARA PRODUCTO DE MESA DULCE (ACTUALIZADO) ---
  void _addMesaDulceDialog({OrderItem? existingItem, int? itemIndex}) {
    final bool isEditing = existingItem != null;
    Map<String, dynamic> customData = isEditing
        ? (existingItem.customizationJson ?? {})
        : {}; // Usar !

    // --- Inicialización ---
    Product? selectedProduct = isEditing
        ? mesaDulceProducts.firstWhereOrNull(
            (p) => p.name == existingItem.name,
          ) // Usar !
        : mesaDulceProducts.first; // Default para nuevo item

    ProductUnit?
    selectedSize; // Determinar basado en producto y datos guardados
    double basePrice = 0.0; // Se calculará
    double adjustments = isEditing ? existingItem.adjustments : 0.0; // Usar !
    bool isHalfDozen = customData['is_half_dozen'] as bool? ?? false;

    // Determinar tamaño inicial
    if (selectedProduct?.pricesBySize != null) {
      final sizeName = customData['selected_size'] as String?;
      if (sizeName != null) {
        try {
          selectedSize = ProductUnit.values.byName(sizeName);
        } catch (_) {}
      }
      // Asegurar que el tamaño sea válido para el producto actual o default
      if (selectedSize == null ||
          !selectedProduct!.pricesBySize!.containsKey(selectedSize)) {
        selectedSize = selectedProduct!.pricesBySize!.keys.first;
      }
    }

    final qtyController = TextEditingController(
      // Usaremos controller ahora
      text: isEditing ? existingItem.qty.toString() : '1', // Usar !
    );
    final adjustmentsController = TextEditingController(
      text: adjustments.toStringAsFixed(0),
    );
    final notesController = TextEditingController(
      // Notas del ajuste
      text: isEditing ? existingItem.customizationNotes ?? '' : '', // Usar !
    );
    final itemNotesController = TextEditingController(
      // Notas generales del item
      text: customData['item_notes'] as String? ?? '',
    );

    final ImagePicker picker = ImagePicker();
    List<String> existingImageUrls = List<String>.from(
      customData['photo_urls'] ?? [],
    );
    List<XFile> newImageFiles = [];
    bool isUploading = false;

    final finalPriceController =
        TextEditingController(); // Precio final calculado
    // --- Fin Inicialización ---

    // --- Función para calcular precio ---
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

      // Determinar precio base unitario
      double unitBasePrice = 0.0;
      if (selectedProduct!.pricesBySize != null) {
        if (selectedSize == null) {
          finalPriceController.text = 'Seleccione tamaño';
          return;
        }
        unitBasePrice = getPriceBySize(selectedProduct!, selectedSize!) ?? 0.0;
        // Forzar qty a 1 si es por tamaño
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

      basePrice = unitBasePrice; // Guardamos el base unitario determinado
      double finalUnitPrice = basePrice + manualAdjustments;
      double totalItemPrice = finalUnitPrice * qty;
      finalPriceController.text = totalItemPrice.toStringAsFixed(0);
    }

    // Calcular precio inicial
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => calculateMesaDulcePrice(),
    );
    // --- Fin Función Precio ---

    // --- Build Dialog ---
    showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            // Helper para input cantidad/tamaño (SIN CAMBIOS FUNCIONALES, usa controller)
            Widget buildQuantityOrSizeInput() {
              if (selectedProduct == null) return const SizedBox.shrink();
              if (selectedProduct!.pricesBySize != null) {
                // Dropdown para tamaños
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
                  initialValue: selectedSize,
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
                // Input numérico + Toggle Docena/Media Docena
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
                          selectedColor: primaryPink,
                        ),
                      ],
                    ),
                  ],
                );
              } else {
                // Input numérico simple (para unidades o docenas sin media docena)
                return TextFormField(
                  controller: qtyController,
                  decoration: InputDecoration(
                    labelText:
                        'Cantidad (${getUnitText(selectedProduct!.unit, plural: true)})',
                  ),
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  onChanged: (_) =>
                      setDialogState(calculateMesaDulcePrice), // Recalcula
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
                    // Selección Producto Mesa Dulce
                    DropdownButtonFormField<Product>(
                      initialValue: selectedProduct, // Usa 'value'
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
                          // Resetear tamaño si el nuevo producto no lo usa
                          if (newValue?.pricesBySize == null) {
                            selectedSize = null;
                          }
                          // Resetear media docena si el nuevo producto no lo permite
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
                    // Input de Cantidad/Tamaño (dinámico)
                    buildQuantityOrSizeInput(),
                    const SizedBox(height: 16),
                    // --- NUEVOS CAMPOS ---
                    TextFormField(
                      // Input para ajuste manual
                      controller: adjustmentsController,
                      decoration: InputDecoration(
                        labelText: 'Ajuste Manual al Precio Unitario (\$)',
                        hintText: 'Ej: 50 (extra), -20 (desc)',
                        prefixText:
                            '${basePrice.toStringAsFixed(0)} + ', // Muestra base unitario
                      ),
                      keyboardType: const TextInputType.numberWithOptions(
                        signed: true,
                        decimal: false,
                      ),
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(RegExp(r'^-?\d*')),
                      ],
                      onChanged: (_) =>
                          setDialogState(calculateMesaDulcePrice), // Recalcula
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      // Input para notas del ajuste
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
                      // Notas generales del item
                      controller: itemNotesController,
                      decoration: const InputDecoration(
                        labelText: 'Notas Generales del Item',
                      ),
                      maxLines: 2,
                      textCapitalization: TextCapitalization.sentences,
                    ),
                    const SizedBox(height: 16),

                    // Sección de Fotos (Opcional para Mesa Dulce?)
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
                          ...existingImageUrls.map(
                            (url) => _buildImageThumbnail(
                              url,
                              true,
                              () => setDialogState(
                                () => existingImageUrls.remove(url),
                              ),
                            ),
                          ),
                          ...newImageFiles.map(
                            (file) => _buildImageThumbnail(
                              file,
                              false,
                              () => setDialogState(
                                () => newImageFiles.remove(file),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    TextButton.icon(
                      icon: const Icon(Icons.photo_library),
                      label: const Text('Añadir Fotos'),
                      onPressed: () async {
                        final pickedFiles = await picker.pickMultiImage();
                        if (pickedFiles.isNotEmpty) {
                          setDialogState(
                            () => newImageFiles.addAll(pickedFiles),
                          );
                        }
                      },
                    ),
                    const Divider(),

                    // Precio Calculado (solo mostrar)
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
                  style: FilledButton.styleFrom(backgroundColor: darkBrown),
                  onPressed: isUploading
                      ? null
                      : () async {
                          if (selectedProduct == null) return;

                          final qty = int.tryParse(qtyController.text) ?? 0;
                          // 👇 CORRECCIÓN: Declaración de variables dentro del scope
                          final manualAdjustments =
                              double.tryParse(adjustmentsController.text) ??
                              0.0;
                          final adjustmentNotes = notesController.text.trim();
                          final itemNotes = itemNotesController.text.trim();

                          // Validación (sin cambios)
                          if (qty <= 0 ||
                              basePrice <=
                                  0 || // 'basePrice' SÍ existe en el estado
                              (selectedProduct!.pricesBySize != null &&
                                  selectedSize == null)) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'Verifica la cantidad y/o tamaño.',
                                ),
                                backgroundColor:
                                    Colors.orange, // Añadido para claridad
                              ),
                            );
                            return;
                          }

                          setDialogState(() => isUploading = true);

                          // --- Lógica subir imágenes (SIN CAMBIOS) ---
                          final List<String> newUploadedUrls = [];
                          if (newImageFiles.isNotEmpty) {
                            for (final imageFile in newImageFiles) {
                              final url = await _compressAndUpload(
                                imageFile,
                                ref,
                              );
                              if (url != null) newUploadedUrls.add(url);
                            }
                          }
                          final allImageUrls = [
                            ...existingImageUrls,
                            ...newUploadedUrls,
                          ];
                          // --- FIN Lógica subir imágenes ---

                          // --- CUSTOMIZATION JSON ACTUALIZADO ---
                          final customization = {
                            'product_category': selectedProduct!.category.name,
                            'product_unit': selectedProduct!.unit.name,
                            if (selectedProduct!.pricesBySize != null)
                              'selected_size': selectedSize!.name,
                            if (selectedProduct!.allowHalfDozen)
                              'is_half_dozen': isHalfDozen,
                            // 👇 Guarda las notas generales del item aquí
                            if (itemNotes.isNotEmpty) 'item_notes': itemNotes,
                            if (allImageUrls.isNotEmpty)
                              'photo_urls': allImageUrls,
                            // 'calculated_base_price': basePrice, // NO ENVIAR CALCULADOS
                          };
                          customization.removeWhere(
                            (key, value) => (value is List && value.isEmpty),
                          );
                          // --- FIN CUSTOMIZATION JSON ---

                          // --- CREACIÓN DEL OrderItem ACTUALIZADO ---
                          final newItem = OrderItem(
                            id: isEditing ? existingItem.id : null,
                            name: selectedProduct!.name,
                            qty: qty,
                            basePrice: basePrice, // Base unitario determinado
                            // 👇 Usa la variable correcta para el ajuste manual
                            adjustments: manualAdjustments,
                            // 👇 Usa la variable correcta para las notas de ajuste
                            customizationNotes: adjustmentNotes.isEmpty
                                ? null
                                : adjustmentNotes,
                            customizationJson: customization,
                          );
                          // --- FIN CREACIÓN OrderItem ---

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
                  child: isUploading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : Text(isEditing ? 'Guardar Cambios' : 'Agregar Torta'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // --- NUEVO: WIDGET HELPER PARA MOSTRAR MINIATURAS DE IMAGEN ---
  Widget _buildImageThumbnail(
    dynamic imageSource,
    bool isNetwork,
    VoidCallback onRemove,
  ) {
    // dynamic porque puede ser String (URL) o XFile
    return Stack(
      clipBehavior: Clip.none,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: isNetwork
              ? Image.network(
                  imageSource as String,
                  height: 80,
                  width: 80,
                  fit: BoxFit.cover,
                  // Placeholder mientras carga
                  loadingBuilder: (context, child, loadingProgress) {
                    if (loadingProgress == null) return child;
                    return Container(
                      height: 80,
                      width: 80,
                      color: Colors.grey[300],
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
                  // Placeholder si falla la carga
                  errorBuilder: (context, error, stackTrace) => Container(
                    height: 80,
                    width: 80,
                    color: Colors.grey[300],
                    child: const Icon(Icons.broken_image, color: Colors.grey),
                  ),
                )
              : Image.file(
                  File((imageSource as XFile).path),
                  height: 80,
                  width: 80,
                  fit: BoxFit.cover,
                ),
        ),
        Positioned(
          top: -14,
          right: -14,
          child: IconButton(
            icon: const Icon(
              Icons.cancel_rounded,
              color: Colors.redAccent,
              size: 28,
            ), // Más grande
            onPressed: onRemove,
            tooltip: 'Quitar imagen',
          ),
        ),
      ],
    );
  }

  // --- FUNCIÓN PARA ABRIR DIÁLOGO DE EDICIÓN CORRECTO ---
  void _editItemDialogRouter(int index) {
    final item = _items[index];
    final categoryString =
        item.customizationJson?['product_category'] as String?;
    final category = ProductCategory.values.firstWhereOrNull(
      (e) => e.name == categoryString,
    );

    if (category == ProductCategory.torta) {
      _addCakeDialog(existingItem: item, itemIndex: index);
    } else if (category == ProductCategory.mesaDulce) {
      _addMesaDulceDialog(existingItem: item, itemIndex: index);
    } else if (category == ProductCategory.miniTorta) {
      _addMiniCakeDialog(existingItem: item, itemIndex: index);
    } else {
      // Fallback: Abrir diálogo genérico o mostrar error si no se reconoce
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No se puede editar este tipo de item aún.'),
          backgroundColor: Colors.orange,
        ),
      );
      // O podrías tener un _addGenericItemDialog como antes para items viejos/desconocidos
    }
  }

  // --- FUNCIÓN SUBMIT (MODIFICADA PARA INCLUIR DELIVERY COST) ---
  Future<void> _submit() async {
    final valid = _formKey.currentState?.validate() ?? false;
    // Recalcular una última vez por si acaso
    _recalculateTotals();

    if (!valid || _selectedClient == null || _items.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Revisa los campos obligatorios: Cliente, al menos un Producto y verifica que los precios/cantidades sean correctos.',
          ),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 4),
        ),
      );
      return;
    }

    // Doble chequeo de que los totales son razonables
    if (_grandTotal <= 0 && _items.isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'El total calculado es cero o negativo. Revisa los precios de los productos añadidos.',
          ),
          backgroundColor: Colors.orange,
          duration: Duration(seconds: 4),
        ),
      );
      return;
    }

    setState(() => _isLoading = true); // Activar indicador en botón

    final fmt = DateFormat('yyyy-MM-dd');
    String t(TimeOfDay x) =>
        '${x.hour.toString().padLeft(2, '0')}:${x.minute.toString().padLeft(2, '0')}';

    // --- PAYLOAD ACTUALIZADO ---
    final payload = {
      'client_id': _selectedClient!.id,
      'event_date': fmt.format(_date),
      'start_time': t(_start),
      'end_time': t(_end),
      'status': isEditMode ? widget.order!.status : 'confirmed',
      'deposit': _depositAmount, // Usar valor calculado/parseado
      'delivery_cost': _deliveryCost > 0 ? _deliveryCost : null,
      'notes': _notesController.text.trim().isEmpty
          ? null
          : _notesController.text.trim(),
      // 👇 Mapea items usando toJson() del OrderItem actualizado
      'items': _items.map((item) => item.toJson()).toList(),
      // No enviar 'total', el backend lo recalcula.
    };

    // 👇 AÑADE ESTO PARA VER QUÉ SE ENVÍA
    print('--- Payload a Enviar ---');
    print(payload);
    // ----------------------------

    try {
      if (isEditMode) {
        await ref
            .read(ordersRepoProvider)
            .updateOrder(widget.order!.id, payload);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Pedido actualizado con éxito.'),
              backgroundColor: Colors.green,
            ),
          );
          // Invalidar caché para refrescar vistas
          ref.invalidate(orderByIdProvider(widget.order!.id));
          ref.invalidate(
            ordersWindowProvider,
          ); // Asume que este provider existe
          context.pop(); // Volver a la pantalla anterior
        }
      } else {
        await ref.read(ordersRepoProvider).createOrder(payload);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Pedido creado con éxito.'),
              backgroundColor: Colors.green,
            ),
          );
          ref.invalidate(
            ordersWindowProvider,
          ); // Asume que este provider existe
          context.pop(); // Volver a la pantalla anterior
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al guardar: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false); // Desactivar indicador
      }
    }
  }

  // --- BUILD WIDGET (MODIFICADO PARA TOTALES Y DELIVERY) ---
  @override
  Widget build(BuildContext context) {
    // Calcular totales iniciales
    WidgetsBinding.instance.addPostFrameCallback((_) => _recalculateTotals());

    return Form(
      key: _formKey,
      child: Column(
        // Usar Column para poner el resumen abajo
        children: [
          Expanded(
            // El ListView ocupa el espacio disponible
            child: ListView(
              padding: const EdgeInsets.fromLTRB(
                16,
                16,
                16,
                0,
              ), // Quitar padding inferior
              children: [
                // --- SECCIÓN CLIENTE ---
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: TypeAheadField<Client>(
                        controller: _clientNameController,
                        suggestionsCallback: (pattern) async {
                          if (pattern.length < 2) return [];
                          // Limpiar cliente seleccionado si el texto cambia y no coincide
                          if (_selectedClient != null &&
                              _selectedClient!.name != pattern) {
                            WidgetsBinding.instance.addPostFrameCallback((_) {
                              if (mounted) {
                                setState(() => _selectedClient = null);
                              }
                            });
                          }
                          return ref
                              .read(clientsRepoProvider)
                              .searchClients(pattern);
                        },
                        itemBuilder: (context, client) => ListTile(
                          title: Text(client.name),
                          subtitle: Text(client.phone ?? 'Sin teléfono'),
                        ),
                        onSelected: (client) {
                          // Usar addPostFrameCallback para asegurar que setState ocurra después del build
                          WidgetsBinding.instance.addPostFrameCallback((_) {
                            if (mounted) {
                              setState(() {
                                _selectedClient = client;
                                _clientNameController.text = client.name;
                              });
                            }
                          });
                        },
                        emptyBuilder: (context) => const Padding(
                          padding: EdgeInsets.all(8.0),
                          child: Text('No se encontraron clientes.'),
                        ),
                        builder: (context, controller, focusNode) => TextFormField(
                          controller: controller,
                          focusNode: focusNode,
                          decoration: InputDecoration(
                            labelText:
                                'Buscar cliente *', // Marcar como obligatorio
                            border: const OutlineInputBorder(),
                            suffixIcon: _clientNameController.text.isNotEmpty
                                ? IconButton(
                                    icon: const Icon(Icons.clear),
                                    onPressed: () {
                                      controller.clear();
                                      _clientNameController.clear();
                                      setState(() => _selectedClient = null);
                                    },
                                  )
                                : null,
                          ),
                          validator: (value) {
                            // Validar que se haya seleccionado un cliente, no solo escrito texto
                            if (_selectedClient == null) {
                              return 'Debes seleccionar un cliente de la lista o crear uno nuevo.';
                            }
                            // Opcional: validar que el texto coincida con el cliente seleccionado
                            // if (value != _selectedClient!.name) {
                            //   return 'El nombre no coincide con el cliente seleccionado.';
                            // }
                            return null;
                          },
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton.filled(
                      icon: const Icon(Icons.add),
                      onPressed: _addClientDialog,
                      tooltip: 'Crear nuevo cliente',
                      style: IconButton.styleFrom(backgroundColor: darkBrown),
                      // Ajustar tamaño si es necesario
                      // iconSize: 30,
                      // padding: const EdgeInsets.all(14),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                if (_selectedClient != null)
                  Card(
                    elevation: 0,
                    // color: Theme.of(context).colorScheme.surfaceVariant, // Un color suave del tema
                    color: primaryPink.withAlpha(26),
                    child: Padding(
                      padding: const EdgeInsets.all(12.0),
                      child: Text(
                        'Tel: ${_selectedClient!.phone ?? "N/A"} | Dir: ${_selectedClient!.address ?? "N/A"}',
                        style: TextStyle(color: darkBrown.withAlpha(230)),
                      ),
                    ),
                  ),
                const SizedBox(height: 16),

                // --- SECCIÓN FECHA Y HORA ---
                Card(
                  elevation: 0,
                  color: primaryPink.withAlpha(26),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8.0),
                    child: Column(
                      children: [
                        ListTile(
                          dense: true,
                          leading: const Icon(
                            Icons.calendar_today,
                            color: darkBrown,
                          ),
                          title: Text(
                            'Fecha Evento: ${DateFormat('EEEE d \'de\' MMMM, y', 'es_AR').format(_date)}',
                          ),
                          // trailing: const Icon(Icons.edit_calendar_outlined),
                          onTap: _pickDate,
                        ),
                        Divider(
                          height: 1,
                          indent: 16,
                          endIndent: 16,
                          color: primaryPink.withAlpha(128),
                        ),
                        Row(
                          children: [
                            Expanded(
                              child: ListTile(
                                dense: true,
                                leading: const Icon(
                                  Icons.access_time,
                                  color: darkBrown,
                                ),
                                title: Text('Desde: ${_start.format(context)}'),
                                // trailing: const Icon(Icons.edit_outlined),
                                onTap: () => _pickTime(true),
                              ),
                            ),
                            Container(
                              height: 30,
                              width: 1,
                              color: primaryPink.withAlpha(128),
                            ),
                            Expanded(
                              child: ListTile(
                                dense: true,
                                leading: const Icon(
                                  Icons.update,
                                  color: darkBrown,
                                ),
                                title: Text('Hasta: ${_end.format(context)}'),
                                // trailing: const Icon(Icons.edit_outlined),
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

                // --- SECCIÓN NOTAS ---
                TextFormField(
                  controller: _notesController,
                  decoration: const InputDecoration(
                    labelText: 'Notas Generales del Pedido',
                    hintText: 'Ej: Decoración especial, alergias, etc.',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.notes),
                  ),
                  maxLines: 3,
                  textCapitalization: TextCapitalization.sentences,
                ),
                const SizedBox(height: 24),

                // --- SECCIÓN PRODUCTOS ---
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Productos *',
                      style: Theme.of(
                        context,
                      ).textTheme.titleLarge?.copyWith(color: darkBrown),
                    ),
                    IconButton.filled(
                      onPressed: _addItemDialog,
                      icon: const Icon(Icons.add),
                      style: IconButton.styleFrom(backgroundColor: darkBrown),
                      tooltip: 'Añadir producto',
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                // Validar que haya items (visualmente y en submit)
                if (_items.isEmpty)
                  const Center(
                    child: Padding(
                      padding: EdgeInsets.symmetric(vertical: 24.0),
                      child: Text(
                        'Añade al menos un producto al pedido.',
                        style: TextStyle(color: lightBrownText),
                      ),
                    ),
                  )
                else
                  // --- LISTA DE ITEMS MEJORADA ---
                  ListView.builder(
                    shrinkWrap:
                        true, // Para que funcione dentro de otro ListView
                    physics:
                        const NeverScrollableScrollPhysics(), // Deshabilitar scroll interno
                    itemCount: _items.length,
                    itemBuilder: (context, index) {
                      final item = _items[index];
                      // Extraer detalles para mostrar
                      String details = '';
                      final custom = item.customizationJson ?? {};
                      final category = ProductCategory.values.firstWhereOrNull(
                        (e) => e.name == custom['product_category'],
                      );

                      if (category == ProductCategory.torta) {
                        details += '${custom['weight_kg']}kg';
                        if (custom['selected_fillings'] != null &&
                            (custom['selected_fillings'] as List).isNotEmpty) {
                          details +=
                              ' | Rellenos: ${(custom['selected_fillings'] as List).join(", ")}';
                        }
                        // Podrías añadir extras aquí también
                      } else if (category == ProductCategory.mesaDulce) {
                        if (custom['selected_size'] != null) {
                          details += getUnitText(
                            ProductUnit.values.byName(custom['selected_size']),
                          );
                        } else if (custom['is_half_dozen'] == true) {
                          details += ' (Media Docena)';
                        }
                      } else if (category == ProductCategory.miniTorta) {
                        // Detalles específicos de mini torta si los hay
                      }
                      if (item.customizationNotes != null) {
                        details += ' | Notas: ${item.customizationNotes}';
                      }

                      return Card(
                        margin: const EdgeInsets.symmetric(vertical: 4),
                        elevation: 1,
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: primaryPink.withAlpha(51),
                            child: Text(
                              '${item.qty}',
                              style: const TextStyle(
                                color: darkBrown,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          title: Text(item.name),
                          subtitle: Text(
                            details.isNotEmpty
                                ? details
                                : 'Precio Base: ${_currencyFormat.format(item.basePrice)}', // Mostrar base si no hay detalles
                          ),
                          trailing: Row(
                            // Usar Row para precio y botón borrar
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                // 👇 USA finalUnitPrice para el total del item
                                _currencyFormat.format(
                                  item.finalUnitPrice * item.qty,
                                ),
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: darkBrown,
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
                          onTap: () => _editItemDialogRouter(
                            index,
                          ), // Usar el router para editar
                          dense: true,
                        ),
                      );
                    },
                  ),

                // Espacio antes del resumen
                const SizedBox(height: 100),
              ],
            ),
          ),

          // --- SECCIÓN INFERIOR FIJA CON RESUMEN Y BOTÓN GUARDAR ---
          _buildSummaryAndSave(),
        ],
      ),
    );
  }

  // --- WIDGET PARA EL RESUMEN Y BOTÓN GUARDAR ---
  Widget _buildSummaryAndSave() {
    return Material(
      // Usar Material para elevación y color
      elevation: 8.0,
      color: Colors.white, // O el color de fondo de tu Scaffold
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Fila para Seña y Envío
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
                    onChanged: (_) =>
                        _recalculateTotals(), // Recalcular al cambiar
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
                    // El listener ya recalcula
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            // Resumen de Totales
            _buildSummaryRow('Subtotal Productos:', _itemsSubtotal),
            if (_deliveryCost > 0)
              _buildSummaryRow('Costo Envío:', _deliveryCost),
            _buildSummaryRow('TOTAL PEDIDO:', _grandTotal, isTotal: true),
            if (_depositAmount > 0)
              _buildSummaryRow(
                'Seña Recibida:',
                -_depositAmount,
              ), // Mostrar en negativo o como resta
            if (_grandTotal > 0)
              _buildSummaryRow(
                'Saldo Pendiente:',
                _remainingBalance,
                isTotal: true,
                highlight: _remainingBalance > 0,
              ),

            const SizedBox(height: 16),
            // Botón Guardar
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _isLoading ? null : _submit,
                icon: _isLoading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.save),
                label: Text(isEditMode ? 'Guardar Cambios' : 'Guardar Pedido'),
                style: FilledButton.styleFrom(
                  backgroundColor: darkBrown,
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

  // --- WIDGET HELPER PARA FILAS DEL RESUMEN ---
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
          ? Colors.redAccent
          : (isTotal ? darkBrown : Colors.black87),
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
} // Fin de _OrderFormState
