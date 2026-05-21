import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:collection/collection.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter/foundation.dart';

import 'package:pasteleria_180_flutter/core/json_utils.dart';
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
                    if (order == null)
                      return const Center(child: Text('Pedido no encontrado.'));
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

class BoxMesaDulceSelection {
  final Product product;
  int quantity;
  ProductVariant? selectedVariant;

  BoxMesaDulceSelection({
    required this.product,
    this.quantity = 1,
    this.selectedVariant,
  });
}

class UnitExtraSelection {
  final CakeExtra extra;
  int quantity;

  UnitExtraSelection({required this.extra, this.quantity = 1});
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Permiso de contactos denegado.'),
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Cliente "${existingClient.name}" seleccionado.'),
          ),
        );
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
        if (context.mounted) Navigator.pop(context);
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
                Icons.card_giftcard,
                color: Theme.of(context).colorScheme.tertiary,
              ),
              title: const Text('Box Dulce'),
              onTap: () {
                Navigator.of(context).pop();
                _addBoxDialog();
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
    Map<String, dynamic> customData =
        isEditing ? (existingItem.customizationJson ?? {}) : {};

    const personalizedBoxName = 'BOX DULCE Personalizado (Armar)';

    Product? selectedProduct = isEditing
        ? boxProducts.firstWhereOrNull((p) => p.name == existingItem.name)
        : boxProducts.first;

    double basePrice =
        isEditing ? existingItem.basePrice : selectedProduct?.price ?? 0.0;
    double manualAdjustmentValue = isEditing
        ? (customData['manual_adjustment_value'] is num
            ? (customData['manual_adjustment_value'] as num).toDouble()
            : 0.0)
        : 0.0;

    double adjustments = manualAdjustmentValue;

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

    List<BoxMesaDulceSelection> selectedMesaDulceItems = [];
    if (isEditing && existingItem.name == personalizedBoxName) {
      final List<dynamic> itemsData =
          customData['selected_mesa_dulce_items'] as List<dynamic>? ?? [];
      for (var itemData in itemsData) {
        final name = itemData['name'];
        final qty = itemData['quantity'] ?? 1;

        final variantId = itemData['variant_id'];
        final variantName = itemData['variant_name'];

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

    Product? selectedBaseCake = customData['selected_base_cake'] != null
        ? _derivedSmallCakeProducts.firstWhereOrNull(
            (p) => p.name == (customData['selected_base_cake'] as String?),
          )
        : _derivedSmallCakeProducts.firstWhereOrNull(
            (p) => p.name == 'Mini Torta Personalizada (Base)',
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

    final finalPriceController = TextEditingController();

    double calculatedTotalBasePrice = basePrice;

    final isPersonalizedBox = selectedProduct?.name == personalizedBoxName;
    double calculatedExtrasCost = 0.0;
    double calculatedSubItemsCost = 0.0;

    if (isPersonalizedBox) {
      calculatedTotalBasePrice = selectedBaseCake?.price ?? 0.0;

      for (var sel in selectedMesaDulceItems) {
        double unitPrice = 0.0;
        if (sel.product.variants.isNotEmpty) {
          unitPrice = sel.selectedVariant?.price ?? 0.0;
        } else if (sel.product.unit == ProductUnit.dozen) {
          unitPrice = sel.product.price / 12.0;
        } else if (sel.product.unit == ProductUnit.unit) {
          unitPrice = sel.product.price;
        } else {
          unitPrice = sel.product.price;
        }
        calculatedSubItemsCost += unitPrice * sel.quantity;
      }
      calculatedTotalBasePrice += calculatedSubItemsCost;
    }

    if (selectedBaseCake != null || !isPersonalizedBox) {
      const miniCakeName = 'Mini Torta Personalizada (Base)';
      const microCakeName = 'Micro Torta';

      bool isSmallCake = false;
      if (isPersonalizedBox) {
        isSmallCake = selectedBaseCake?.name == miniCakeName ||
            selectedBaseCake?.name == microCakeName;
      } else {
        isSmallCake = true;
      }

      final double costMultiplier = isSmallCake ? 0.5 : 1.0;
      calculatedExtrasCost += selectedExtraFillings.fold(
        0.0,
        (sum, f) => sum + (f.extraCostPerKg * costMultiplier),
      );
      calculatedExtrasCost += selectedExtrasKg.fold(
        0.0,
        (sum, ex) => sum + (ex.costPerKg * costMultiplier),
      );
      calculatedExtrasCost += selectedExtrasUnit.fold(
        0.0,
        (sum, sel) => sum + (sel.extra.costPerUnit * sel.quantity),
      );
      calculatedTotalBasePrice += calculatedExtrasCost;
    }

    void calculatePrice() {
      final qty = int.tryParse(qtyController.text) ?? 0;
      final currentAdjustments =
          double.tryParse(adjustmentsController.text) ?? 0.0;

      calculatedTotalBasePrice = basePrice;
      calculatedSubItemsCost = 0.0;
      calculatedExtrasCost = 0.0;

      if (isPersonalizedBox) {
        calculatedTotalBasePrice = selectedBaseCake?.price ?? 0.0;
        for (var sel in selectedMesaDulceItems) {
          double unitPrice = 0.0;
          if (sel.product.variants.isNotEmpty) {
            unitPrice = sel.selectedVariant?.price ?? 0.0;
          } else if (sel.product.unit == ProductUnit.dozen) {
            unitPrice = sel.product.price / 12.0;
          } else if (sel.product.unit == ProductUnit.unit) {
            unitPrice = sel.product.price;
          } else {
            unitPrice = sel.product.price;
          }
          calculatedSubItemsCost += unitPrice * sel.quantity;
        }
        calculatedTotalBasePrice += calculatedSubItemsCost;
      }

      if (selectedBaseCake != null || !isPersonalizedBox) {
        const miniCakeName = 'Mini Torta Personalizada (Base)';
        const microCakeName = 'Micro Torta';

        bool isSmallCake = false;
        if (isPersonalizedBox) {
          isSmallCake = selectedBaseCake?.name == miniCakeName ||
              selectedBaseCake?.name == microCakeName;
        } else {
          isSmallCake = true;
        }

        final double costMultiplier = isSmallCake ? 0.5 : 1.0;

        calculatedExtrasCost += selectedExtraFillings.fold(
          0.0,
          (sum, f) => sum + (f.extraCostPerKg * costMultiplier),
        );
        calculatedExtrasCost += selectedExtrasKg.fold(
          0.0,
          (sum, ex) => sum + (ex.costPerKg * costMultiplier),
        );
        calculatedExtrasCost += selectedExtrasUnit.fold(
          0.0,
          (sum, sel) => sum + (sel.extra.costPerUnit * sel.quantity),
        );
        calculatedTotalBasePrice += calculatedExtrasCost;
      }

      if (qty > 0) {
        final finalUnitPrice = calculatedTotalBasePrice + currentAdjustments;
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
            final isCurrentPersonalizedBox =
                selectedProduct?.name == personalizedBoxName;

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

            Widget buildMesaDulceItemSelector(Product product) {
              BoxMesaDulceSelection? selection = selectedMesaDulceItems
                  .firstWhereOrNull((sel) => sel.product == product);
              bool isSelected = selection != null;

              String basePriceText;
              if (product.pricesBySize != null) {
                basePriceText = '(Tamaños)';
              } else if (product.unit == ProductUnit.dozen) {
                basePriceText =
                    '(~\$${(product.price / 12).toStringAsFixed(0)} c/u)';
              } else if (product.unit == ProductUnit.unit) {
                basePriceText = '(+\$${product.price.toStringAsFixed(0)} c/u)';
              } else {
                basePriceText = '(Error de unidad)';
              }

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
              } else {
                return ListTile(
                  leading: Checkbox(
                    value: isSelected,
                    onChanged: toggleSelection,
                  ),
                  title: Text('${product.name} $basePriceText'),
                  onTap: () => toggleSelection(
                    !isSelected,
                  ),
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  trailing: isSelected
                      ? SizedBox(
                          width: 60,
                          child: TextFormField(
                            key: ValueKey(
                              product.name,
                            ),
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
                            onChanged: (value) {
                              int qty = int.tryParse(value) ?? 1;
                              if (qty < 1) {
                                qty = 1;
                              }

                              selection.quantity = qty;

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

            return AlertDialog(
              title: Row(
                children: [
                  if (!isEditing)
                    IconButton(
                        icon: const Icon(Icons.arrow_back),
                        onPressed: () {
                          Navigator.pop(dialogContext);
                          _addItemDialog();
                        }),
                  Expanded(
                    child:
                        Text(isEditing ? 'Editar Item Box' : 'Añadir Item Box'),
                  ),
                ],
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    DropdownButtonFormField<Product>(
                      value: selectedProduct,
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
                          if (newValue?.name == personalizedBoxName) {
                            qtyController.text = '1';
                          }
                          selectedFillings = [];
                          selectedExtraFillings = [];
                          selectedExtrasKg = [];
                          selectedExtrasUnit = [];
                          selectedMesaDulceItems = [];
                          if (newValue?.name == personalizedBoxName) {
                            basePrice = 0.0;
                          } else {
                            basePrice = newValue?.price ?? 0.0;
                            selectedBaseCake =
                                _derivedSmallCakeProducts.firstWhereOrNull(
                              (p) =>
                                  p.name == 'Mini Torta Personalizada (Base)',
                            );
                          }

                          calculatePrice();
                        });
                      },
                      decoration: const InputDecoration(labelText: 'Producto'),
                      isExpanded: true,
                    ),
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
                    if (isCurrentPersonalizedBox)
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Base de Torta para el Box Personalizado (Opcional):',
                            style: Theme.of(context)
                                .textTheme
                                .titleMedium
                                ?.copyWith(fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 8),
                          DropdownButtonFormField<Product>(
                            value: selectedBaseCake,
                            items: [
                              const DropdownMenuItem<Product>(
                                value: null,
                                child: Text(
                                  'No Incluir Torta Base (Solo Mesa Dulce)',
                                ),
                              ),
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
                          if (selectedBaseCake != null) ...[
                            Text(
                              'Personalización de Torta Base:',
                              style: Theme.of(context)
                                  .textTheme
                                  .titleMedium
                                  ?.copyWith(fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Rellenos Incluidos (Mini Torta)',
                              style: Theme.of(context).textTheme.titleSmall,
                            ),
                            ...freeFillings.map(
                              (f) => buildFillingCheckbox(f, false),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Rellenos con Costo Extra (Mini Torta)',
                              style: Theme.of(context).textTheme.titleSmall,
                            ),
                            ...extraCostFillings.map(
                              (f) => buildFillingCheckbox(f, true),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Extras por Peso (Costo Fijo/Box)',
                              style: Theme.of(context).textTheme.titleSmall,
                            ),
                            ...cakeExtras
                                .where((ex) => !ex.isPerUnit)
                                .map(buildExtraKgCheckbox),
                            const SizedBox(height: 8),
                            Text(
                              'Extras por Unidad (Costo por Unidad/Box)',
                              style: Theme.of(context).textTheme.titleSmall,
                            ),
                            ...cakeExtras
                                .where((ex) => ex.isPerUnit)
                                .map(buildExtraUnitSelector),
                            const SizedBox(height: 16),
                          ],
                          Text(
                            'Productos de Mesa Dulce a Incluir:',
                            style: Theme.of(context)
                                .textTheme
                                .titleMedium
                                ?.copyWith(fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 8),
                          ...mesaDulceProducts
                              .map(buildMesaDulceItemSelector)
                              .toList(),
                          const SizedBox(height: 16),
                        ],
                      )
                    else
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Personalización de Mini Torta/Contenido:',
                            style: Theme.of(context)
                                .textTheme
                                .titleMedium
                                ?.copyWith(fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Rellenos Incluidos (Mini Torta)',
                            style: Theme.of(context).textTheme.titleSmall,
                          ),
                          ...freeFillings.map(
                            (f) => buildFillingCheckbox(f, false),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Rellenos con Costo Extra (Mini Torta)',
                            style: Theme.of(context).textTheme.titleSmall,
                          ),
                          ...extraCostFillings.map(
                            (f) => buildFillingCheckbox(f, true),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Extras por Peso (Costo Fijo/Box)',
                            style: Theme.of(context).textTheme.titleSmall,
                          ),
                          ...cakeExtras
                                .where((ex) => !ex.isPerUnit)
                                .map(buildExtraKgCheckbox),
                          const SizedBox(height: 8),
                          Text(
                            'Extras por Unidad (Costo por Unidad/Box)',
                            style: Theme.of(context).textTheme.titleSmall,
                          ),
                          ...cakeExtras
                                .where((ex) => ex.isPerUnit)
                                .map(buildExtraUnitSelector),
                        ],
                      ),
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
                            final dynamic imageSource =
                                isPlaceholder ? _filesToUpload[url] : url;
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
                  onPressed: () {
                    if (selectedProduct == null) return;

                    final qty = isCurrentPersonalizedBox
                        ? 1
                        : int.tryParse(qtyController.text) ?? 0;
                    final itemNotes = itemNotesController.text.trim();
                    final adjustmentNotes =
                        adjustmentNotesController.text.trim();

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
                    final costOfExtras = calculatedTotalBasePrice - basePrice;
                    final totalAdjustment = costOfExtras + adjustments;

                    final customization = {
                      'product_category': ProductCategory.box.name,
                      'box_type': selectedProduct!.name,
                      'manual_adjustment_value': adjustments,
                      if (!isCurrentPersonalizedBox) ...{
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
                                'price': sel.extra.costPerUnit,
                              },
                            )
                            .toList(),
                      },
                      if (isCurrentPersonalizedBox) ...{
                        if (selectedBaseCake != null)
                          'selected_base_cake': selectedBaseCake?.name,
                        if (selectedBaseCake != null) ...{
                          'selected_fillings':
                              selectedFillings.map((f) => f.name).toList(),
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
                                  'price': sel.extra.costPerUnit,
                                },
                              )
                              .toList(),
                        },
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

                    List<Object> finalLocalFiles = [];
                    if (allImageUrls.isNotEmpty) {
                      for (var url in allImageUrls) {
                        if (url.startsWith('placeholder_')) {
                          final file = _filesToUpload[url];
                          if (file != null) {
                            finalLocalFiles.add(file);
                          }
                        }
                      }
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
                      customizationNotes:
                          adjustmentNotes.isEmpty ? null : adjustmentNotes,
                      customizationJson: customization,
                      localFile:
                          finalLocalFiles.isNotEmpty ? finalLocalFiles : null,
                    );

                    _updateItemsAndRecalculate(() {
                      if (isEditing) {
                        _items[itemIndex!] = newItem;
                      } else {
                        _smartMergeItem(_items, newItem);
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
    Map<String, dynamic> customData =
        isEditing ? (existingItem.customizationJson ?? {}) : {};

    Product? selectedCakeType = isEditing
        ? cakeProducts.firstWhereOrNull((p) => p.name == existingItem.name)
        : cakeProducts.first;

    const miniCakeName = 'Mini Torta Personalizada (Base)';

    final weightController = TextEditingController(
      text: existingItem?.name == miniCakeName
          ? '1.0'
          : customData['weight_kg']?.toString() ?? '1.0',
    );
    final adjustmentsController = TextEditingController(
      text: isEditing ? existingItem.adjustments.toStringAsFixed(0) : '0',
    );
    final multiplierAdjustmentController = TextEditingController(
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

      const miniCakeName = 'Mini Torta Personalizada (Base)';
      const microCakeName = 'Micro Torta (Base)';

      final bool isSmallCake =
          selectedCakeType?.name == miniCakeName ||
          selectedCakeType?.name == microCakeName;

      double weight = isSmallCake
          ? 1.0
          : double.tryParse(weightController.text.replaceAll(',', '.')) ?? 0.0;

      manualAdjustments = double.tryParse(adjustmentsController.text) ?? 0.0;

      multiplierAdjustment = isSmallCake
          ? 0.0
          : double.tryParse(multiplierAdjustmentController.text) ?? 0.0;

      if (weight <= 0 && !isSmallCake) {
        calculatedBasePriceController.text = 'N/A';
        finalPriceController.text = 'N/A';
        return;
      }

      double base = (selectedCakeType!.price + multiplierAdjustment) * weight;

      double multiplier;
      if (isSmallCake) {
        multiplier = 0.5;
      } else {
        multiplier = weight;
      }

      double extraFillingsPrice = selectedExtraFillings.fold(
        0.0,
        (sum, f) => sum + (f.extraCostPerKg * multiplier),
      );
      double extrasKgPrice = selectedExtrasKg.fold(
        0.0,
        (sum, ex) => sum + (ex.costPerKg * multiplier),
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
            const miniCakeName = 'Mini Torta Personalizada (Base)';
            const microCakeName = 'Micro Torta (Base)';

            final bool isMiniCake = selectedCakeType?.name == miniCakeName;
            final bool isMicroCake = selectedCakeType?.name == microCakeName;
            final bool isSmallCake = isMiniCake || isMicroCake;

            Widget buildFillingCheckbox(Filling filling, bool isExtraCost) {
              bool isSelected = isExtraCost
                  ? selectedExtraFillings.contains(filling)
                  : selectedFillings.contains(filling);
              return CheckboxListTile(
                title: Text(filling.name),
                subtitle: Text(
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

            return AlertDialog(
              title: Row(
                children: [
                  if (!isEditing)
                    IconButton(
                        icon: const Icon(Icons.arrow_back),
                        onPressed: () {
                          Navigator.pop(dialogContext);
                          _addItemDialog();
                        }),
                  Expanded(
                      child: Text(isEditing ? 'Editar Torta' : 'Añadir Torta')),
                ],
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    DropdownButtonFormField<Product>(
                      value: selectedCakeType,
                      items: cakeProducts.map((Product product) {
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
                          final bool eraTortaChica = isSmallCake;
                          selectedCakeType = newValue;
                          final bool esTortaChicaNueva =
                              newValue?.name == miniCakeName ||
                                  newValue?.name == microCakeName;

                          if (esTortaChicaNueva) {
                            weightController.text = '1.0';
                            multiplierAdjustmentController.text = '0';
                          } else if (eraTortaChica) {
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
                            final dynamic imageSource =
                                isPlaceholder ? _filesToUpload[url] : url;

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
                  onPressed: () {
                    if (selectedCakeType == null) return;

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

                    final adjustmentNotes =
                        adjustmentNotesController.text.trim();

                    if (weight <= 0 && !isSmallCake) {
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
                      if (!isSmallCake)
                        'multiplier_adjustment_per_kg':
                            multiplierAdjustmentValue,
                      'selected_fillings':
                          selectedFillings.map((f) => f.name).toList(),
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

                    List<Object> finalLocalFiles = [];
                    if (allImageUrls.isNotEmpty) {
                      for (var url in allImageUrls) {
                        if (url.startsWith('placeholder_')) {
                          final file = _filesToUpload[url];
                          if (file != null) {
                            finalLocalFiles.add(file);
                          }
                        }
                      }
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
                      customizationNotes:
                          adjustmentNotes.isEmpty ? null : adjustmentNotes,
                      customizationJson: customization,
                      localFile:
                          finalLocalFiles.isNotEmpty ? finalLocalFiles : null,
                    );

                    _updateItemsAndRecalculate(() {
                      if (isEditing) {
                        _items[itemIndex!] = newItem;
                      } else {
                        _smartMergeItem(_items, newItem);
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

    List<OrderItem> pendingItems = [];

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
    final finalPriceController = TextEditingController();
    bool isUnitSaleForDozen = isEditing
        ? (existingItem.customizationJson?['is_unit_sale_for_dozen'] == true)
        : false;

    final ImagePicker picker = ImagePicker();
    List<XFile> _selectedFiles = [];
    String? _existingRemoteUrl;

    if (isEditing) {
      if (existingItem.localFile != null &&
          (existingItem.localFile is List) &&
          (existingItem.localFile as List).isNotEmpty) {
        final files = existingItem.localFile as List;
        for (var f in files) {
          if (f is XFile) {
            _selectedFiles.add(f);
          } else if (f is File) {
            _selectedFiles.add(XFile(f.path));
          }
        }
      }

      if (existingItem.customizationJson?['photo_url'] != null) {
        final url = existingItem.customizationJson!['photo_url'];
        if (!url.startsWith('placeholder_')) {
          _existingRemoteUrl = url;
        }
      }
    }

    showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            void calculateCurrentItemPrice() {
              if (selectedProduct == null) {
                finalPriceController.text = '0';
                return;
              }
              int qty = int.tryParse(qtyController.text) ?? 0;
              double manualAdj =
                  double.tryParse(adjustmentsController.text) ?? 0.0;
              double unitAdj =
                  double.tryParse(unitAdjustmentsController.text) ?? 0.0;

              double unitBasePrice = 0.0;
              if (selectedProduct!.variants.isNotEmpty) {
                unitBasePrice = selectedVariant?.price ?? 0.0;
              } else if (selectedProduct!.allowHalfDozen && isHalfDozen) {
                unitBasePrice = selectedProduct!.halfDozenPrice ??
                    (selectedProduct!.price / 2);
              } else if (selectedProduct!.unit == ProductUnit.dozen &&
                  isUnitSaleForDozen) {
                unitBasePrice = selectedProduct!.price / 12;
              } else {
                unitBasePrice = selectedProduct!.price;
              }

              double effectiveUnitDetailPrice = unitBasePrice + unitAdj;
              basePrice = effectiveUnitDetailPrice;

              double total = (effectiveUnitDetailPrice * qty) + manualAdj;
              finalPriceController.text = total.toStringAsFixed(0);
            }

            if (finalPriceController.text.isEmpty) {
              calculateCurrentItemPrice();
            }

            void addToPendingList() {
              if (selectedProduct == null) return;
              int qty = int.tryParse(qtyController.text) ?? 0;
              if (qty <= 0) return;
              if (selectedProduct!.variants.isNotEmpty &&
                  selectedVariant == null) return;

              List<XFile> finalLocalFiles = [];
              String? finalPhotoUrl;

              if (_selectedFiles.isNotEmpty) {
                finalLocalFiles.addAll(_selectedFiles);
              }
              if (_existingRemoteUrl != null) {
                finalPhotoUrl = _existingRemoteUrl;
              }

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
                basePrice: basePrice,
                adjustments: double.tryParse(adjustmentsController.text) ?? 0.0,
                customizationNotes: notesController.text.trim().isEmpty
                    ? null
                    : notesController.text.trim(),
                customizationJson: customization,
                localFile: finalLocalFiles.isNotEmpty ? finalLocalFiles : null,
              );

              setDialogState(() {
                if (isEditing) {
                  _updateItemsAndRecalculate(() {
                    _items[itemIndex!] = newItem;
                  });
                  Navigator.pop(context);
                } else {
                  _smartMergeItem(pendingItems, newItem);
                  qtyController.text = '1';
                  adjustmentsController.text = '0';
                  notesController.clear();
                  itemNotesController.clear();
                  unitAdjustmentsController.text = '0';
                  _selectedFiles.clear();
                }
              });
            }

            return AlertDialog(
              title: Row(
                children: [
                  if (!isEditing)
                    IconButton(
                        icon: const Icon(Icons.arrow_back),
                        onPressed: () {
                          Navigator.pop(dialogContext);
                          _addItemDialog();
                        }),
                  Expanded(
                    child: Text(
                      isEditing
                          ? 'Editar Item Mesa Dulce'
                          : 'Mesa Dulce (Carrito)',
                    ),
                  ),
                ],
              ),
              content: SizedBox(
                width: double.maxFinite,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (!isEditing) ...[
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
                              final formattedVName = vName.startsWith('size')
                                  ? vName.replaceAll('size', '')
                                  : vName;

                              return Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Expanded(
                                      child: Row(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          if (it.localFile != null &&
                                              (it.localFile as List).isNotEmpty)
                                            Container(
                                              margin: const EdgeInsets.only(
                                                  right: 8),
                                              constraints: const BoxConstraints(
                                                  maxWidth: 130),
                                              child: Wrap(
                                                spacing: 4,
                                                runSpacing: 4,
                                                children: _buildCompactImageRow(
                                                  context,
                                                  it.localFile as List<Object>,
                                                ),
                                              ),
                                            ),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  '${it.name} ($formattedVName)',
                                                  style: const TextStyle(
                                                      fontWeight:
                                                          FontWeight.bold,
                                                      fontSize: 13),
                                                ),
                                                Text(
                                                  '${it.qty} x \$${it.basePrice.toStringAsFixed(0)}',
                                                  style: TextStyle(
                                                    fontSize: 12,
                                                    color: Colors.grey[700],
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    IconButton(
                                      icon: const Icon(
                                        Icons.delete,
                                        size: 20,
                                        color: Colors.red,
                                      ),
                                      onPressed: () {
                                        setDialogState(() {
                                          pendingItems.removeAt(idx);
                                        });
                                      },
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                        ),
                      Align(
                        alignment: Alignment.centerRight,
                        child: Padding(
                          padding: const EdgeInsets.only(top: 2, bottom: 2),
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
                    Flexible(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.only(top: 8),
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
                                isDense: true,
                                contentPadding: EdgeInsets.symmetric(
                                  vertical: 8,
                                  horizontal: 10,
                                ),
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
                              else if (selectedProduct!.allowHalfDozen ||
                                  selectedProduct!.unit == ProductUnit.dozen)
                                Padding(
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 8.0),
                                  child: Row(
                                    children: [
                                      if (selectedProduct!.allowHalfDozen) ...[
                                        const Text('Media Doc.',
                                            style: TextStyle(fontSize: 14)),
                                        Transform.scale(
                                          scale: 0.8,
                                          child: Switch(
                                            value: isHalfDozen,
                                            onChanged: (v) =>
                                                setDialogState(() {
                                              isHalfDozen = v;
                                              if (v) isUnitSaleForDozen = false;
                                              calculateCurrentItemPrice();
                                            }),
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                      ],
                                      if (selectedProduct!.unit ==
                                              ProductUnit.dozen &&
                                          !isHalfDozen) ...[
                                        const Text('Unidad',
                                            style: TextStyle(fontSize: 14)),
                                        Transform.scale(
                                          scale: 0.8,
                                          child: Switch(
                                            value: isUnitSaleForDozen,
                                            onChanged: (v) =>
                                                setDialogState(() {
                                              isUnitSaleForDozen = v;
                                              calculateCurrentItemPrice();
                                            }),
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
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
                                          true,
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
                                          false,
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
                                final pickedFiles =
                                    await picker.pickMultiImage();
                                if (pickedFiles.isNotEmpty) {
                                  setDialogState(() {
                                    _selectedFiles.addAll(pickedFiles);
                                  });
                                }
                              },
                            ),
                            const Divider(),
                            const SizedBox(height: 10),
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
                        addToPendingList();
                      } else {
                        _updateItemsAndRecalculate(() {
                          for (var newItem in pendingItems) {
                            if (newItem.localFile != null &&
                                (newItem.localFile as List).isNotEmpty) {
                              final files = newItem.localFile as List<XFile>;
                              final List<String> placeholderKeys = [];

                              for (var file in files) {
                                final String key =
                                    'placeholder_${DateTime.now().microsecondsSinceEpoch}_${file.name}';
                                _filesToUpload[key] = file;
                                placeholderKeys.add(key);
                              }

                              if (newItem.customizationJson != null) {
                                final existingUrls =
                                    newItem.customizationJson!['photo_urls'];
                                List<String> currentList = [];
                                if (existingUrls is List) {
                                  currentList = List<String>.from(existingUrls);
                                }

                                currentList.addAll(placeholderKeys);

                                newItem.customizationJson!['photo_urls'] =
                                    currentList;

                                if (currentList.isNotEmpty) {
                                  newItem.customizationJson!['photo_url'] =
                                      currentList.first;
                                }
                              }
                            }
                            _smartMergeItem(_items, newItem);
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
      if (kIsWeb) {
        final String path = imageSource is XFile
            ? imageSource.path
            : (imageSource is File ? imageSource.path : imageSource.toString());
        imageWidget = Image.network(
          path,
          height: 80,
          width: 80,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => const Icon(Icons.broken_image),
        );
      } else {
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
              child: _buildPreviewImage(imageSource),
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

  Widget _buildPreviewImage(dynamic imageSource) {
    if (imageSource is XFile || imageSource is File) {
      final String path =
          imageSource is XFile ? imageSource.path : (imageSource as File).path;

      if (kIsWeb) {
        return Image.network(path);
      } else {
        return Image.file(File(path));
      }
    }
    return Image.network(imageSource as String);
  }

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
              color: Theme.of(context).colorScheme.onSecondaryContainer,
            ),
          ),
          backgroundColor: Theme.of(context).colorScheme.secondaryContainer,
        ),
      );
    }
  }

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
          context.pop();
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

  String _formatDetailsForList(List<dynamic>? rawList, double multiplier) {
    if (rawList == null || rawList.isEmpty) {
      return '';
    }

    final parts = <String>[];

    for (final e in rawList) {
      if (e is Map) {
        final name = e['name'] ?? 'Extra';
        final qty = (e['quantity'] as num?) ?? 1;
        final price = (e['price'] as num?)?.toDouble() ?? 0.0;

        final totalCost = (price * qty) * multiplier;

        final priceText = (totalCost > 0)
            ? ' (${_currencyFormat.format(totalCost)})'
            : '';

        parts.add(qty > 1 ? '$name (x$qty)$priceText' : '$name$priceText');
      } else if (e is String) {
        parts.add(e);
      }
    }
    return parts.join(', ');
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
                      final custom = item.customizationJson ?? {};
                      final category = ProductCategory.values.firstWhereOrNull(
                        (e) => e.name == custom['product_category'],
                      );

                      final parts = <String>[];

                      if (category == ProductCategory.torta) {
                        const miniCakeName = 'Mini Torta Personalizada (Base)';
                        const microCakeName = 'Micro Torta (Base)';

                        final bool isSmallCake = item.name == miniCakeName ||
                            item.name == microCakeName;

                        final double weight =
                            (custom['weight_kg'] as num?)?.toDouble() ?? 1.0;

                        final double extraMultiplier =
                            isSmallCake ? 0.5 : weight;

                        final List<dynamic> extraFillingsRaw =
                            custom['selected_extra_fillings'] ?? [];
                        final List<dynamic> extrasKgRaw =
                            custom['selected_extras_kg'] ?? [];
                        final List<dynamic> extrasUnitRaw =
                            custom['selected_extras_unit'] ?? [];

                        final double extraFillingsPrice = extraFillingsRaw.fold(
                          0.0,
                          (sum, data) {
                            final price = (data is Map
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
                          final price = (data is Map
                                  ? (data['price'] as num?)?.toDouble()
                                  : null) ??
                              0.0;
                          return sum + (price * extraMultiplier);
                        });
                        final double extrasUnitPrice = extrasUnitRaw.fold(0.0, (
                          sum,
                          data,
                        ) {
                          final price = (data is Map
                                  ? (data['price'] as num?)?.toDouble()
                                  : null) ??
                              0.0;
                          final qty = (data is Map
                                  ? (data['quantity'] as num?)?.toDouble()
                                  : null) ??
                              1.0;
                          return sum + (price * qty);
                        });

                        final double costoExtrasTotal = extraFillingsPrice +
                            extrasKgPrice +
                            extrasUnitPrice;
                        final double precioCalculadoConAjusteKg =
                            item.basePrice - costoExtrasTotal;

                        parts.add(
                          'Precio Base: ${_currencyFormat.format(precioCalculadoConAjusteKg)}',
                        );

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
                        if (custom['variant_name'] != null &&
                            custom['variant_name'].toString().isNotEmpty) {
                          final vName = custom['variant_name'].toString();
                          final formatted = vName.startsWith('size')
                              ? vName.replaceFirst('size', '')
                              : vName;
                          parts.add(formatted);
                        } else if (custom['selected_size'] != null) {
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
                            : true;

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
                          final mesaItemsText = mesaDulceItems.map((e) {
                            final name = e['name'];
                            final qty = e['quantity'];
                            final size = e['selected_size'];
                            return size != null
                                ? '$name (${size.replaceAll('size', '')}) x$qty'
                                : '$name x$qty';
                          }).join(', ');
                          parts.add('Mesa Dulce: $mesaItemsText');
                        }
                      }

                      double manualAdjustment = 0.0;

                      if (category == ProductCategory.box) {
                        manualAdjustment =
                            (custom['manual_adjustment_value'] as num?)
                                    ?.toDouble() ??
                                0.0;
                      } else {
                        manualAdjustment = item.adjustments;
                      }

                      if (manualAdjustment != 0) {
                        final sign = manualAdjustment > 0
                            ? '+'
                            : '';
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
                        child: Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Builder(
                                builder: (context) {
                                  final List<dynamic> allImages = [];

                                  if (item.localFile != null &&
                                      (item.localFile as List).isNotEmpty) {
                                    allImages.addAll(item.localFile as List);
                                  }

                                  if (custom['photo_urls'] != null && custom['photo_urls'] is List) {
                                    for (var url in custom['photo_urls'] as List) {
                                      if (!url.toString().startsWith('placeholder_')) {
                                        allImages.add(url);
                                      }
                                    }
                                  } else if (custom['photo_url'] != null) {
                                    final url = custom['photo_url'].toString();
                                    if (!url.startsWith('placeholder_')) {
                                      allImages.add(url);
                                    }
                                  }

                                  if (allImages.isEmpty) {
                                    return CircleAvatar(
                                      backgroundColor: Theme.of(context)
                                          .colorScheme
                                          .tertiaryContainer,
                                      child: Text(
                                        '${item.qty}',
                                        style: TextStyle(
                                          color: Theme.of(context)
                                              .colorScheme
                                              .onTertiaryContainer,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    );
                                  }

                                  return Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      for (int i = 0;
                                          i < allImages.length && i < 3;
                                          i++) ...[
                                        if (i > 0)
                                          const SizedBox(width: 4),

                                        GestureDetector(
                                          onTap: () => _showImagePreview(
                                              context, allImages[i]),
                                          child: Stack(
                                            children: [
                                              ClipRRect(
                                                borderRadius:
                                                    BorderRadius.circular(4),
                                                child: _buildSafeImageWidget(
                                                    allImages[i], 50, 50),
                                              ),
                                              if (i == 0 && item.qty > 1)
                                                Positioned(
                                                  bottom: 0,
                                                  right: 0,
                                                  child: Container(
                                                    padding: const EdgeInsets
                                                        .symmetric(
                                                        horizontal: 4,
                                                        vertical: 1),
                                                    decoration: BoxDecoration(
                                                      color: Theme.of(context)
                                                          .colorScheme
                                                          .secondary,
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                              4),
                                                    ),
                                                    child: Text(
                                                      'x${item.qty}',
                                                      style: TextStyle(
                                                        color: Theme.of(context)
                                                            .colorScheme
                                                            .onSecondary,
                                                        fontSize: 10,
                                                        fontWeight:
                                                            FontWeight.bold,
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                              if (i == 2 &&
                                                  allImages.length > 3)
                                                Positioned.fill(
                                                  child: Container(
                                                    decoration: BoxDecoration(
                                                      color: Colors.black
                                                          .withOpacity(0.5),
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                              4),
                                                    ),
                                                    alignment: Alignment.center,
                                                    child: Text(
                                                      '+${allImages.length - 2}',
                                                      style: const TextStyle(
                                                        color: Colors.white,
                                                        fontWeight:
                                                            FontWeight.bold,
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ],
                                  );
                                },
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: InkWell(
                                  onTap: () => _editItemDialogRouter(index),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        item.name,
                                        style: Theme.of(context)
                                            .textTheme
                                            .titleMedium,
                                      ),
                                      if (details.isNotEmpty)
                                        Padding(
                                          padding:
                                              const EdgeInsets.only(top: 4.0),
                                          child: Text(
                                            details,
                                            style: Theme.of(context)
                                                .textTheme
                                                .bodyMedium
                                                ?.copyWith(
                                                  color: Theme.of(context)
                                                      .colorScheme
                                                      .onSurfaceVariant,
                                                ),
                                          ),
                                        )
                                      else
                                        Padding(
                                          padding:
                                              const EdgeInsets.only(top: 4.0),
                                          child: Text(
                                            'Precio Base: ${_currencyFormat.format(item.basePrice)}',
                                            style: Theme.of(context)
                                                .textTheme
                                                .bodyMedium
                                                ?.copyWith(
                                                  color: Theme.of(context)
                                                      .colorScheme
                                                      .onSurfaceVariant,
                                                ),
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                              ),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(
                                    _currencyFormat.format(
                                      item.finalUnitPrice * item.qty,
                                    ),
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color:
                                          Theme.of(context).colorScheme.primary,
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
                            ],
                          ),
                        ),
                      );
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

  Widget _buildSafeImageWidget(dynamic imageSource, double width, double height) {
    if (imageSource is XFile || imageSource is File) {
      if (kIsWeb) {
        return Image.network(
          (imageSource is XFile) ? imageSource.path : (imageSource as File).path,
          width: width,
          height: height,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => const Icon(Icons.broken_image),
        );
      } else {
        return Image.file(
          File(imageSource is XFile ? imageSource.path : (imageSource as File).path),
          width: width,
          height: height,
          fit: BoxFit.cover,
        );
      }
    }
    return Image.network(
      imageSource as String,
      width: width,
      height: height,
      fit: BoxFit.cover,
      errorBuilder: (_, __, ___) => const Icon(Icons.broken_image),
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

  // --- HELPER DE UI: FILA DE IMAGENES COMPACTA (Para Pending List) ---
  List<Widget> _buildCompactImageRow(
      BuildContext context, List<Object> images) {
    // Máximo 3 elementos visibles (2 fotos + 1 indicador, o 3 fotos)
    const int maxVisible = 3;
    final int totalCount = images.length;
    final List<Widget> widgets = [];

    for (int i = 0; i < totalCount; i++) {
      if (widgets.length >= maxVisible) break;

      // Si es el último slot y quedan más imágenes, mostrar +N
      if (widgets.length == maxVisible - 1 && totalCount > maxVisible) {
        final remaining = totalCount - (maxVisible - 1);
        widgets.add(
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primaryContainer,
              borderRadius: BorderRadius.circular(4),
            ),
            child: Center(
              child: Text(
                '+$remaining',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.onPrimaryContainer,
                  fontSize: 12,
                ),
              ),
            ),
          ),
        );
      } else {
        // Mostrar imagen normal
        final imageSource = images[i];
        widgets.add(
          GestureDetector(
            onTap: () => _showImagePreview(context, imageSource),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: _buildSafeImageWidget(imageSource, 40, 40),
            ),
          ),
        );
      }
    }
    return widgets;
  }

  // --- SMART MERGE LOGIC (Centralized) ---
  // Returns TRUE if merged, FALSE if added as new (caller might not care, but useful)
  // This modifies 'targetList' in place.
  bool _smartMergeItem(List<OrderItem> targetList, OrderItem newItem) {
    int existingIndex = targetList.indexWhere((item) {
      // 1. Core Identity (Name & Variant)
      if (item.name != newItem.name) return false;
      if (item.customizationJson?['variant_id'] !=
          newItem.customizationJson?['variant_id']) return false;

      // 2. Adjustments & Price (Must match exactly to merge)
      // Check if Unit Price is effectively the same
      double itemUnit = item.qty > 0 ? item.basePrice / item.qty : 0;
      double newUnit = newItem.qty > 0 ? newItem.basePrice / newItem.qty : 0;
      if ((itemUnit - newUnit).abs() > 0.01) return false;

      if (item.adjustments != newItem.adjustments) return false;

      // 3. Deep check of crucial Customization Fields (Fillings, Sizes, etc.)
      final c1 = item.customizationJson ?? {};
      final c2 = newItem.customizationJson ?? {};

      // Helper to compare lists (like fillings) regardless of order
      // FIX: Treat null and empty list as equivalent
      bool listEquals(List? l1, List? l2) {
        final list1 = l1 ?? [];
        final list2 = l2 ?? [];
        if (list1.isEmpty && list2.isEmpty) return true;

        if (list1.length != list2.length) return false;
        final s1 = list1.map((e) => e.toString()).toSet();
        final s2 = list2.map((e) => e.toString()).toSet();
        return s1.containsAll(s2) && s2.containsAll(s1);
      }

      if (!listEquals(c1['selected_fillings'], c2['selected_fillings']))
        return false;
      if (!listEquals(
          c1['selected_extra_fillings'], c2['selected_extra_fillings']))
        return false;
      if (!listEquals(c1['selected_extras_kg'], c2['selected_extras_kg']))
        return false;
      if (!listEquals(c1['selected_extras_unit'], c2['selected_extras_unit']))
        return false;
      if (!listEquals(
          c1['selected_mesa_dulce_items'], c2['selected_mesa_dulce_items']))
        return false;

      // is_half_dozen check (FIX: Safe boolean compare)
      if ((c1['is_half_dozen'] ?? false) != (c2['is_half_dozen'] ?? false))
        return false;

      // unit_adjustment check (FIX: Prevent merging if unit adjustment differs)
      final u1 = c1['unit_adjustment'] ?? 0.0;
      final u2 = c2['unit_adjustment'] ?? 0.0;
      if (u1 != u2) return false;

      return true;
    });

    if (existingIndex != -1) {
      // --- MERGE ---
      final existing = targetList[existingIndex];
      final newQty = existing.qty + newItem.qty;
      // Recalculate total base price (Unit * NewQty)
      double itemUnit =
          existing.qty > 0 ? existing.basePrice / existing.qty : 0;
      final newBasePrice = itemUnit * newQty;

      // Merge Notes (Concatenate if different)
      String? mergedNotes = existing.customizationNotes;
      if (newItem.customizationNotes != null &&
          newItem.customizationNotes!.isNotEmpty) {
        if (mergedNotes == null || mergedNotes.isEmpty) {
          mergedNotes = newItem.customizationNotes;
        } else if (mergedNotes != newItem.customizationNotes) {
          mergedNotes = '$mergedNotes | ${newItem.customizationNotes}';
        }
      }

      // Merge Item Notes (Concatenate if different)
      final c1 = Map<String, dynamic>.from(existing.customizationJson ?? {});
      final c2 = newItem.customizationJson ?? {};
      String? note1 = c1['item_notes'];
      String? note2 = c2['item_notes'];
      if (note2 != null && note2.isNotEmpty) {
        if (note1 == null || note1.isEmpty) {
          c1['item_notes'] = note2;
        } else if (note1 != note2) {
          c1['item_notes'] = '$note1 | $note2';
        }
      }

      // Merge Local Files (Unify lists)
      List<dynamic> mergedLocalFiles = [];
      if (existing.localFile != null && existing.localFile is List) {
        mergedLocalFiles.addAll(existing.localFile as List);
      }
      if (newItem.localFile != null && newItem.localFile is List) {
        // Add only if not effectively same path (basic dedup)
        for (var f in (newItem.localFile as List)) {
          // Simplistic dedup by path if XFile/File
          String path =
              (f is XFile) ? f.path : (f is File ? f.path : f.toString());
          bool exists = mergedLocalFiles.any((e) {
            String ePath =
                (e is XFile) ? e.path : (e is File ? e.path : e.toString());
            return ePath == path;
          });
          if (!exists) mergedLocalFiles.add(f);
        }
      }

      // Merge Photo URLs (Unify lists)
      List<String> mergedUrls = [];
      if (c1['photo_urls'] != null && c1['photo_urls'] is List) {
        mergedUrls.addAll(List<String>.from(c1['photo_urls']));
      } else if (c1['photo_url'] != null) {
        mergedUrls.add(c1['photo_url']); // Migration from old single field
      }

      List<String> newUrls = [];
      if (c2['photo_urls'] != null && c2['photo_urls'] is List) {
        newUrls.addAll(List<String>.from(c2['photo_urls']));
      } else if (c2['photo_url'] != null) {
        newUrls.add(c2['photo_url']);
      }

      for (var url in newUrls) {
        if (!mergedUrls.contains(url)) {
          mergedUrls.add(url);
        }
      }
      if (mergedUrls.isNotEmpty) {
        c1['photo_urls'] = mergedUrls;
        // Keep 'photo_url' as the first one for backwards compat if needed, or just rely on list
        c1['photo_url'] = mergedUrls.first;
      }

      targetList[existingIndex] = OrderItem(
        id: existing.id, // Keep existing ID
        name: existing.name,
        qty: newQty,
        basePrice: newBasePrice,
        adjustments: existing
            .adjustments, // Assuming fixed manual adjustment stays? Or should imply per-unit? Users request implies "same product".
        // Usually "Adjustments" in this app logic are manual fixed additions.
        // If we merge, we actually KEEP the existing adjustment and DO NOT add the new one?
        // Or if they are identical (checked in comparator), it doesn't matter.
        // The comparator checks: item.adjustments != newItem.adjustments => return false.
        // So they are equal.
        customizationNotes: mergedNotes,
        customizationJson: c1,
        localFile: mergedLocalFiles.isNotEmpty ? mergedLocalFiles : null,
      );
      return true; // Merged
    } else {
      // --- ADD NEW ---
      targetList.add(newItem);
      return false; // Added new
    }
  }

  // --- FUNCIÓN NUEVA: MOSTRAR MODAL DE DIRECCIONES ---
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
