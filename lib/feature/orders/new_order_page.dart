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

// --- AÑADIDOS PARA COMPRESIÓN ---
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:pasteleria_180_flutter/core/json_utils.dart';
import 'package:pasteleria_180_flutter/core/utils/launcher_utils.dart';
import 'package:path_provider/path_provider.dart';
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

  // Paleta de colores
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
        return Theme(
          data: ThemeData.light().copyWith(
            colorScheme: const ColorScheme.light(
              primary: darkBrown,
              onPrimary: Colors.white,
              onSurface: darkBrown,
            ),
            textButtonTheme: TextButtonThemeData(
              style: TextButton.styleFrom(foregroundColor: darkBrown),
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
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true),
          child: Theme(
            data: ThemeData.light().copyWith(
              colorScheme: const ColorScheme.light(
                primary: darkBrown,
                onPrimary: Colors.white,
                surface: primaryPink,
                onSurface: darkBrown,
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

  // --- 5. DIÁLOGO NUEVO CLIENTE (MODIFICADO) ---
  void _addClientDialog() {
    final nameController = TextEditingController();
    final phoneController = TextEditingController();
    // ❌ ELIMINADO: final addressController = TextEditingController();

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Nuevo Cliente', style: TextStyle(color: darkBrown)),
        content: SingleChildScrollView(
          child: Column(
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
              // ❌ ELIMINADO: TextField para 'addressController'
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancelar', style: TextStyle(color: darkBrown)),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: darkBrown),
            onPressed: () async {
              if (nameController.text.trim().isEmpty) return;

              showDialog(
                context: dialogContext,
                barrierDismissible: false,
                builder: (_) =>
                    const Center(child: CircularProgressIndicator()),
              );

              Client? newClient;
              String? errorMessage;

              try {
                // --- 5a. Payload de Creación Modificado ---
                newClient = await ref.read(clientsRepoProvider).createClient({
                  'name': nameController.text.trim(),
                  'phone': phoneController.text.trim().isEmpty
                      ? null
                      : phoneController.text.trim(),
                  // ❌ ELIMINADO: 'address' ya no se envía desde aquí
                });

                if (dialogContext.mounted) Navigator.pop(dialogContext);
              } catch (e) {
                if (dialogContext.mounted) Navigator.pop(dialogContext);

                if (e is DioException &&
                    (e.response?.statusCode == 409 ||
                        e.response?.statusCode == 422)) {
                  final responseData = e.response?.data;
                  if (responseData is Map) {
                    errorMessage =
                        responseData['message'] as String? ??
                        'Error de cliente';

                    if (e.response?.statusCode == 409 &&
                        responseData['client'] != null) {
                      try {
                        final clientData = responseData['client'];
                        final clientToRestore = Client.fromJson(
                          (clientData as Map).map(
                            (k, v) => MapEntry(k.toString(), v),
                          ),
                        );

                        if (dialogContext.mounted) {
                          Navigator.pop(dialogContext);
                        }
                        _showRestoreDialog(clientToRestore);
                        return;
                      } catch (parseError) {
                        errorMessage = 'Error al procesar cliente duplicado.';
                      }
                    }
                  } else {
                    errorMessage = e.toString();
                  }
                } else {
                  errorMessage = e.toString();
                }
                debugPrint("Error creando cliente: $e");
              }

              if (newClient != null && mounted) {
                setState(() {
                  _selectedClient = newClient;
                  _clientNameController.text = newClient!.name;
                  _selectedAddressId = null; // Resetear dirección
                });
                if (dialogContext.mounted) Navigator.pop(dialogContext);

                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Cliente creado y seleccionado'),
                    backgroundColor: Colors.green,
                  ),
                );
              } else if (errorMessage != null && mounted) {
                if (dialogContext.mounted) Navigator.pop(dialogContext);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(errorMessage),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            },
            child: const Text('Guardar Cliente'),
          ),
        ],
      ),
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
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  // --- FUNCIÓN COMPRIMIR Y SUBIR (sin cambios) ---
  Future<String?> _compressAndUpload(XFile imageFile, WidgetRef ref) async {
    final tempDir = await getTemporaryDirectory();
    final fileName =
        '${DateTime.now().millisecondsSinceEpoch}_${imageFile.name.split('/').last}.jpg';
    final tempPath = '${tempDir.path}/$fileName';

    File? tempFile;

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
        tempFile = File(tempPath);
        await tempFile.writeAsBytes(compressedBytes);
        fileToUpload = XFile(tempFile.path);
        debugPrint('Imagen comprimida a: ${tempFile.lengthSync()} bytes');
      } else {
        fileToUpload = imageFile;
        debugPrint(
          'Compresión falló, subiendo original: ${await imageFile.length()} bytes',
        );
      }

      final url = await ref.read(ordersRepoProvider).uploadImage(fileToUpload);
      await tempFile?.delete();
      return url;
    } catch (e) {
      debugPrint("Error en _compressAndUpload: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error subiendo imagen: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
      try {
        await tempFile?.delete();
      } catch (_) {}
      return null;
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
              leading: const Icon(Icons.cake, color: primaryPink),
              title: const Text('Mini Torta / Accesorio'),
              onTap: () {
                Navigator.of(context).pop();
                _addMiniCakeDialog();
              },
            ),
            ListTile(
              leading: const Icon(Icons.cake_outlined, color: darkBrown),
              title: const Text('Torta por Kilo'),
              onTap: () {
                Navigator.of(context).pop();
                _addCakeDialog();
              },
            ),
            ListTile(
              leading: const Icon(Icons.icecream, color: lightBrownText),
              title: const Text('Producto de Mesa Dulce'),
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

  void _addMiniCakeDialog({OrderItem? existingItem, int? itemIndex}) {
    final bool isEditing = existingItem != null;
    Map<String, dynamic> customData = isEditing
        ? (existingItem.customizationJson ?? {})
        : {};

    Product? selectedProduct = isEditing
        ? miniCakeProducts.firstWhereOrNull((p) => p.name == existingItem.name)
        : miniCakeProducts.first;

    double basePrice = isEditing
        ? existingItem.basePrice
        : selectedProduct?.price ?? 0.0;
    double adjustments = isEditing ? existingItem.adjustments : 0.0;

    final qtyController = TextEditingController(
      text: isEditing ? existingItem.qty.toString() : '1',
    );
    final adjustmentsController = TextEditingController(
      text: adjustments.toStringAsFixed(0),
    );
    final adjustmentNotesController = TextEditingController(
      text: isEditing ? existingItem.customizationNotes ?? '' : '',
    );
    final itemNotesController = TextEditingController(
      text: customData['item_notes'] as String? ?? '',
    );

    final ImagePicker picker = ImagePicker();
    List<String> existingImageUrls = List<String>.from(
      customData['photo_urls'] ?? [],
    );
    List<XFile> newImageFiles = [];
    bool isUploading = false;

    final finalPriceController = TextEditingController();

    void calculatePrice() {
      final qty = int.tryParse(qtyController.text) ?? 0;
      final currentAdjustments =
          double.tryParse(adjustmentsController.text) ?? 0.0;
      if (qty > 0) {
        final finalUnitPrice = basePrice + currentAdjustments;
        finalPriceController.text = (finalUnitPrice * qty).toStringAsFixed(0);
      } else {
        finalPriceController.text = 'N/A';
      }
      adjustments = currentAdjustments;
    }

    WidgetsBinding.instance.addPostFrameCallback((_) => calculatePrice());
    showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text(isEditing ? 'Editar Item' : 'Añadir Item'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    DropdownButtonFormField<Product>(
                      value:
                          selectedProduct, // Usar 'value' en lugar de 'initialValue'
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
                          basePrice = newValue?.price ?? 0.0;
                          calculatePrice();
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
                      onChanged: (_) => setDialogState(calculatePrice),
                    ),
                    TextFormField(
                      controller: adjustmentsController,
                      decoration: InputDecoration(
                        labelText: 'Ajuste Manual al Precio Unitario (\$)',
                        hintText: 'Ej: 500 (extra), -200 (descuento)',
                        prefixText: '${basePrice.toStringAsFixed(0)} + ',
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
                        labelText: 'Notas de Ajuste/Personalización',
                        hintText: 'Ej: Diseño especial, cambio de color, etc.',
                      ),
                      maxLines: 2,
                      textCapitalization: TextCapitalization.sentences,
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: itemNotesController,
                      decoration: const InputDecoration(
                        labelText: 'Notas Generales del Item',
                        hintText: 'Ej: Sabor, temática...',
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
                    TextFormField(
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
                  onPressed: isUploading
                      ? null
                      : () async {
                          if (selectedProduct == null) return;
                          final qty = int.tryParse(qtyController.text) ?? 0;

                          if (qty <= 0) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'La cantidad debe ser mayor a 0.',
                                ),
                                backgroundColor: Colors.orange,
                              ),
                            );
                            return;
                          }

                          setDialogState(() => isUploading = true);

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
                          final itemNotes = itemNotesController.text.trim();
                          final adjustmentNotes = adjustmentNotesController.text
                              .trim();

                          final newItem = OrderItem(
                            id: isEditing ? existingItem.id : null,
                            name: selectedProduct!.name,
                            qty: qty,
                            basePrice: basePrice,
                            adjustments: adjustments,
                            customizationNotes: adjustmentNotes.isEmpty
                                ? null
                                : adjustmentNotes,
                            customizationJson: {
                              'product_category':
                                  selectedProduct!.category.name,
                              'product_unit': selectedProduct!.unit.name,
                              if (itemNotes.isNotEmpty) 'item_notes': itemNotes,
                              if (allImageUrls.isNotEmpty)
                                'photo_urls': allImageUrls,
                            },
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

  void _addCakeDialog({OrderItem? existingItem, int? itemIndex}) {
    final bool isEditing = existingItem != null;
    Map<String, dynamic> customData = isEditing
        ? (existingItem.customizationJson ?? {})
        : {};

    Product? selectedCakeType = isEditing
        ? cakeProducts.firstWhereOrNull((p) => p.name == existingItem.name)
        : cakeProducts.first;

    final weightController = TextEditingController(
      text: customData['weight_kg']?.toString() ?? '1.0',
    );
    final adjustmentsController = TextEditingController(
      text: isEditing ? existingItem.adjustments.toStringAsFixed(0) : '0',
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

    final calculatedBasePriceController = TextEditingController();
    final finalPriceController = TextEditingController();

    double calculatedBasePrice = 0.0;
    double manualAdjustments = 0.0;

    void calculateCakePrice() {
      if (selectedCakeType == null) {
        calculatedBasePriceController.text = 'N/A';
        finalPriceController.text = 'N/A';
        return;
      }
      double weight =
          double.tryParse(weightController.text.replaceAll(',', '.')) ?? 0.0;
      manualAdjustments = double.tryParse(adjustmentsController.text) ?? 0.0;

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

            return AlertDialog(
              title: Text(isEditing ? 'Editar Torta' : 'Añadir Torta'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    DropdownButtonFormField<Product>(
                      value: selectedCakeType,
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
                      isExpanded: true,
                    ),
                    const SizedBox(height: 16),
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
                      onChanged: (_) => setDialogState(calculateCakePrice),
                    ),
                    const SizedBox(height: 16),
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
                    TextFormField(
                      controller: calculatedBasePriceController,
                      readOnly: true,
                      decoration: const InputDecoration(
                        labelText: 'Precio Base Calculado',
                        prefixText: '\$',
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: adjustmentsController,
                      decoration: InputDecoration(
                        labelText: 'Ajuste Manual Adicional (\$)',
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
                        hintText: 'Ej: Decoración compleja, descuento especial',
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
                          final adjustmentNotes = adjustmentNotesController.text
                              .trim();

                          if (weight <= 0 || calculatedBasePrice <= 0) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('El peso debe ser mayor a 0.'),
                              ),
                            );
                            return;
                          }

                          setDialogState(() => isUploading = true);

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
                              'item_notes': notesController.text.trim(),
                            if (allImageUrls.isNotEmpty)
                              'photo_urls': allImageUrls,
                          };
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
    List<XFile> newImageFiles = [];
    bool isUploading = false;

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
                          selectedColor: primaryPink,
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
                      value: selectedProduct,
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
                          final adjustmentNotes = notesController.text.trim();
                          final itemNotes = itemNotesController.text.trim();

                          if (qty <= 0 ||
                              basePrice <= 0 ||
                              (selectedProduct!.pricesBySize != null &&
                                  selectedSize == null)) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'Verifica la cantidad y/o tamaño.',
                                ),
                                backgroundColor: Colors.orange,
                              ),
                            );
                            return;
                          }

                          setDialogState(() => isUploading = true);

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

                          final customization = {
                            'product_category': selectedProduct!.category.name,
                            'product_unit': selectedProduct!.unit.name,
                            if (selectedProduct!.pricesBySize != null)
                              'selected_size': selectedSize!.name,
                            if (selectedProduct!.allowHalfDozen)
                              'is_half_dozen': isHalfDozen,
                            if (itemNotes.isNotEmpty) 'item_notes': itemNotes,
                            if (allImageUrls.isNotEmpty)
                              'photo_urls': allImageUrls,
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

  // --- WIDGET HELPER MINIATURA DE IMAGEN (sin cambios) ---
  Widget _buildImageThumbnail(
    dynamic imageSource,
    bool isNetwork,
    VoidCallback onRemove,
  ) {
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
      } else if (miniCakeProducts.any((p) => p.name == item.name)) {
        category = ProductCategory.miniTorta;
      }
    }

    if (category == ProductCategory.torta) {
      _addCakeDialog(existingItem: item, itemIndex: index);
    } else if (category == ProductCategory.mesaDulce) {
      _addMesaDulceDialog(existingItem: item, itemIndex: index);
    } else if (category == ProductCategory.miniTorta) {
      _addMiniCakeDialog(existingItem: item, itemIndex: index);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'No se puede editar (Categoría desconocida: "${item.name}")',
          ),
          backgroundColor: Colors.orange,
        ),
      );
    }
  }

  // --- 6. FUNCIÓN SUBMIT (MODIFICADA) ---
  Future<void> _submit() async {
    final valid = _formKey.currentState?.validate() ?? false;
    _recalculateTotals();

    // --- 6a. Nueva Validación ---
    // (Añadir validación de dirección si el costo de envío es > 0)
    if (_deliveryCost > 0 && _selectedAddressId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Si hay costo de envío, debes seleccionar una dirección de entrega.',
          ),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 4),
        ),
      );
      return;
    }

    if (!valid || _selectedClient == null || _items.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Revisa los campos obligatorios: Cliente y al menos un Producto.',
          ),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 4),
        ),
      );
      return;
    }

    if (_grandTotal <= 0 && _items.isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'El total calculado es cero o negativo. Revisa los precios de los productos.',
          ),
          backgroundColor: Colors.orange,
          duration: Duration(seconds: 4),
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    final fmt = DateFormat('yyyy-MM-dd');
    String t(TimeOfDay x) =>
        '${x.hour.toString().padLeft(2, '0')}:${x.minute.toString().padLeft(2, '0')}';

    // --- 6b. PAYLOAD ACTUALIZADO CON DIRECCIÓN ---
    final payload = {
      'client_id': _selectedClient!.id,
      'event_date': fmt.format(_date),
      'start_time': t(_start),
      'end_time': t(_end),
      'status': isEditMode ? widget.order!.status : 'confirmed',
      'deposit': _depositAmount,
      'delivery_cost': _deliveryCost > 0 ? _deliveryCost : null,
      'delivery_address_id':
          _selectedAddressId, // <-- AQUÍ ESTÁ LA NUEVA FUNCIONALIDAD
      'notes': _notesController.text.trim().isEmpty
          ? null
          : _notesController.text.trim(),
      'client_address_id': _selectedAddressId,
      'items': _items.map((item) => item.toJson()).toList(),
    };
    // ------------------------------------------

    debugPrint('--- Payload a Enviar ---');
    debugPrint(payload.toString());

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
          ref.invalidate(orderByIdProvider(widget.order!.id));
          ref.invalidate(ordersWindowProvider);
          context.pop();
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
          ref.invalidate(ordersWindowProvider);
          context.pop();
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
                                : 'Precio Base: ${_currencyFormat.format(item.basePrice)}',
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
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

  // --- 11. WIDGET NUEVO: SELECCIÓN DE CLIENTE ---
  Widget _buildClientSelector(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_selectedClient == null)
          // --- VISTA DE BÚSQUEDA (Mostrada si NO hay cliente) ---
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: TypeAheadField<Client>(
                  controller: _clientNameController,
                  suggestionsCallback: (pattern) async {
                    if (pattern.length < 2) return [];
                    if (_selectedClient != null) {
                      setState(() {
                        _selectedClient = null;
                      });
                    }
                    // Usar .future para el suggestionsCallback
                    return ref.read(clientsListProvider(pattern).future);
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
                      _selectedAddressId = null; // Resetear dirección
                      _deliveryCostController.text = '0'; // Resetear costo
                    });
                  },
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
                      if (_selectedClient == null) {
                        return 'Debes seleccionar un cliente.';
                      }
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
                style: IconButton.styleFrom(
                  backgroundColor: darkBrown,
                  padding: const EdgeInsets.all(16),
                ),
              ),
            ],
          )
        else
          // --- VISTA "PILL" (Mostrada si SÍ hay cliente) ---
          Card(
            elevation: 0,
            color: primaryPink.withAlpha(51),
            margin: EdgeInsets.zero,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(color: primaryPink.withAlpha(128)),
            ),
            child: ListTile(
              leading: const Icon(Icons.person, color: darkBrown),
              title: Text(
                _selectedClient!.name,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color: darkBrown,
                ),
              ),
              subtitle: Text(
                'Tel: ${_selectedClient!.phone ?? "N/A"}',
                style: TextStyle(color: darkBrown.withAlpha(200)),
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
                    icon: const Icon(Icons.close, color: darkBrown),
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
  }

  // --- 11. WIDGET NUEVO: SELECCIÓN DE DIRECCIÓN ---
  Widget _buildAddressSelector(BuildContext context) {
    // Observamos el provider que trae los detalles (y direcciones) del cliente
    final asyncClientDetails = ref.watch(
      clientDetailsProvider(_selectedClient!.id),
    );

    return asyncClientDetails.when(
      loading: () => const Center(
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
                  color: darkBrown,
                ),
              ),
              SizedBox(width: 16),
              Text(
                'Cargando direcciones...',
                style: TextStyle(color: lightBrownText),
              ),
            ],
          ),
        ),
      ),
      error: (err, stack) => Text(
        'Error al cargar direcciones: $err',
        style: const TextStyle(color: Colors.red),
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
              decoration: const InputDecoration(
                labelText: 'Dirección de Entrega',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.location_on_outlined, color: darkBrown),
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
                style: TextButton.styleFrom(foregroundColor: darkBrown),
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
      backgroundColor: Colors.white,
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
            child: Container(
              color: Colors.white, // Asegura fondo blanco
              child: AddressFormDialog(clientId: _selectedClient!.id),
            ),
          ),
        );
      },
    );
    // No necesitamos un .then() porque AddressFormDialog
    // invalida clientDetailsProvider, y _buildAddressSelector
    // (que está "watcheando" ese provider) se reconstruirá solo.
  }

  // --- WIDGET RESUMEN Y GUARDAR (sin cambios) ---
  Widget _buildSummaryAndSave() {
    return Material(
      elevation: 8.0,
      color: Colors.white,
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
