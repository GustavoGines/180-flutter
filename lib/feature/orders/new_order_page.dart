import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:flutter_typeahead/flutter_typeahead.dart';
import 'package:image_picker/image_picker.dart';
import 'package:pasteleria_180_flutter/feature/orders/home_page.dart';
import 'dart:io';

import '../../core/models/client.dart';
import '../../core/models/order.dart';
import '../../core/models/order_item.dart';
import '../clients/clients_repository.dart';
import 'orders_repository.dart';
import 'order_detail_page.dart'; // Importamos para usar el orderByIdProvider

// Providers
final clientsRepoProvider = Provider((_) => ClientsRepository());

// La página principal ahora es un ConsumerWidget simple que decide si crear o editar
class NewOrderPage extends ConsumerWidget {
  final int? orderId; // Recibe el ID, o nulo si es un pedido nuevo
  const NewOrderPage({super.key, this.orderId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isEditMode = orderId != null;

    return Scaffold(
      appBar: AppBar(
        title: Text(isEditMode ? 'Editar Pedido' : 'Nuevo Pedido'),
      ),
      body: isEditMode
          // Si estamos editando, buscamos el pedido primero
          ? ref
                .watch(orderByIdProvider(orderId!))
                .when(
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                  error: (err, stack) =>
                      Center(child: Text('Error al cargar el pedido: $err')),
                  // Cuando tenemos los datos, construimos el formulario y se los pasamos
                  data: (order) => _OrderForm(order: order),
                )
          // Si estamos creando, construimos el formulario vacío
          : const _OrderForm(),
    );
  }
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
  final _deposit = TextEditingController();
  final _notes = TextEditingController();
  final List<OrderItem> _items = [];

  bool get isEditMode => widget.order != null;

  @override
  void initState() {
    super.initState();
    // Esta lógica ahora funciona porque este widget solo se construye
    // cuando ya tenemos el 'order' en modo edición.
    if (isEditMode) {
      final order = widget.order!;
      _selectedClient = order.client;
      _clientNameController.text = order.client?.name ?? '';
      _date = order.eventDate;
      _start = TimeOfDay.fromDateTime(order.startTime);
      _end = TimeOfDay.fromDateTime(order.endTime);
      _deposit.text = order.deposit?.toStringAsFixed(2) ?? '0';
      _notes.text = order.notes ?? '';
      _items.addAll(order.items);
    } else {
      // Valores por defecto para un pedido nuevo
      _date = DateTime.now();
      _start = const TimeOfDay(hour: 9, minute: 0);
      _end = const TimeOfDay(hour: 10, minute: 0);
      _deposit.text = '0';
    }
  }

  @override
  void dispose() {
    _clientNameController.dispose();
    _deposit.dispose();
    _notes.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final d = await showDatePicker(
      context: context,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 365 * 2)),
      initialDate: _date,
    );
    if (d != null) setState(() => _date = d);
  }

  Future<void> _pickTime(bool isStart) async {
    final t = await showTimePicker(
      context: context,
      initialTime: isStart ? _start : _end,
    );
    if (t != null) setState(() => isStart ? _start = t : _end = t);
  }

  void _addClientDialog() {
    final nameController = TextEditingController();
    final phoneController = TextEditingController();
    final addressController = TextEditingController();

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Nuevo Cliente'),
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
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () async {
              if (nameController.text.trim().isEmpty) return;
              final newClient = await ref
                  .read(clientsRepoProvider)
                  .createClient({
                    'name': nameController.text.trim(),
                    'phone': phoneController.text.trim().isEmpty
                        ? null
                        : phoneController.text.trim(),
                    'address': addressController.text.trim().isEmpty
                        ? null
                        : addressController.text.trim(),
                  });

              if (mounted) {
                setState(() {
                  _selectedClient = newClient;
                  _clientNameController.text = newClient.name;
                });
                Navigator.pop(context);
              }
            },
            child: const Text('Guardar Cliente'),
          ),
        ],
      ),
    );
  }

  void _addItemDialog() {
    final nameController = TextEditingController();
    final qtyController = TextEditingController(text: '1');
    final priceController = TextEditingController();
    final weightController = TextEditingController();
    final fillingsController = TextEditingController();
    final ImagePicker picker = ImagePicker();
    List<XFile> imageFiles = [];
    bool isUploading = false;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Agregar Productos'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: nameController,
                      decoration: const InputDecoration(
                        labelText: 'Nombre del Producto',
                      ),
                    ),
                    TextField(
                      controller: qtyController,
                      decoration: const InputDecoration(labelText: 'Cantidad'),
                      keyboardType: TextInputType.number,
                    ),
                    TextField(
                      controller: priceController,
                      decoration: const InputDecoration(
                        labelText: 'Precio Unitario',
                      ),
                      keyboardType: TextInputType.number,
                    ),
                    const SizedBox(height: 16),
                    const Divider(),
                    const Text(
                      'Personalización (Opcional)',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    if (imageFiles.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 16.0),
                        child: Wrap(
                          spacing: 8.0,
                          runSpacing: 8.0,
                          children: imageFiles.map((file) {
                            return Stack(
                              clipBehavior: Clip.none,
                              children: [
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: Image.file(
                                    File(file.path),
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
                                    ),
                                    onPressed: () => setDialogState(
                                      () => imageFiles.remove(file),
                                    ),
                                  ),
                                ),
                              ],
                            );
                          }).toList(),
                        ),
                      ),
                    TextButton.icon(
                      icon: const Icon(Icons.photo_library),
                      label: Text(
                        imageFiles.isEmpty
                            ? 'Seleccionar Fotos'
                            : 'Añadir más Fotos',
                      ),
                      onPressed: () async {
                        final pickedFiles = await picker.pickMultiImage();
                        if (pickedFiles.isNotEmpty) {
                          setDialogState(() => imageFiles.addAll(pickedFiles));
                        }
                      },
                    ),
                    TextField(
                      controller: weightController,
                      decoration: const InputDecoration(labelText: 'Peso (kg)'),
                      keyboardType: TextInputType.number,
                    ),
                    TextField(
                      controller: fillingsController,
                      decoration: const InputDecoration(
                        labelText: 'Rellenos (separados por coma)',
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Cancelar'),
                ),
                FilledButton(
                  onPressed: isUploading
                      ? null
                      : () async {
                          final name = nameController.text.trim();
                          final qty = int.tryParse(qtyController.text) ?? 0;
                          final price =
                              num.tryParse(
                                priceController.text.replaceAll(',', '.'),
                              ) ??
                              -1;
                          if (name.isEmpty || qty <= 0 || price < 0) return;

                          setDialogState(() => isUploading = true);

                          final List<String> uploadedImageUrls = [];
                          if (imageFiles.isNotEmpty) {
                            for (final imageFile in imageFiles) {
                              final url = await ref
                                  .read(ordersRepoProvider)
                                  .uploadImage(imageFile);
                              if (url != null) {
                                uploadedImageUrls.add(url);
                              }
                            }
                          }

                          final customizations = {
                            'weight_kg': double.tryParse(
                              weightController.text.replaceAll(',', '.'),
                            ),
                            'photo_urls': uploadedImageUrls.isNotEmpty
                                ? uploadedImageUrls
                                : null,
                            'fillings': fillingsController.text.trim().isEmpty
                                ? null
                                : fillingsController.text
                                      .split(',')
                                      .map((e) => e.trim())
                                      .toList(),
                          };
                          customizations.removeWhere(
                            (key, value) => value == null,
                          );

                          final newItem = OrderItem(
                            name: name,
                            qty: qty,
                            unitPrice: price.toDouble(),
                            customizationJson: customizations.isNotEmpty
                                ? customizations
                                : null,
                          );

                          setState(() => _items.add(newItem));
                          if (mounted) Navigator.of(context).pop();
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
                      : const Text('Agregar'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _editItemDialog(int itemIndex) {
    // Obtenemos el ítem existente para pre-rellenar el formulario
    final existingItem = _items[itemIndex];

    // Rellenamos los controllers con los datos del ítem existente
    final nameController = TextEditingController(text: existingItem.name);
    final qtyController = TextEditingController(
      text: existingItem.qty.toString(),
    );
    final priceController = TextEditingController(
      text: existingItem.unitPrice.toString(),
    );
    final weightController = TextEditingController(
      text: existingItem.customizationJson?['weight_kg']?.toString() ?? '',
    );
    final fillingsController = TextEditingController(
      text:
          (existingItem.customizationJson?['fillings'] as List<dynamic>?)?.join(
            ', ',
          ) ??
          '',
    );
    final ImagePicker picker = ImagePicker();

    // Mantenemos dos listas: las URLs que ya existen y los nuevos archivos locales a subir
    List<String> existingImageUrls = List<String>.from(
      existingItem.customizationJson?['photo_urls'] ?? [],
    );
    List<XFile> newImageFiles = [];
    bool isUploading = false;

    showDialog(
      context: context,
      builder: (context) {
        // Usamos un StatefulBuilder para que el diálogo pueda tener su propio estado
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Editar Ítem'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: nameController,
                      decoration: const InputDecoration(
                        labelText: 'Nombre del Producto',
                      ),
                    ),
                    TextField(
                      controller: qtyController,
                      decoration: const InputDecoration(labelText: 'Cantidad'),
                      keyboardType: TextInputType.number,
                    ),
                    TextField(
                      controller: priceController,
                      decoration: const InputDecoration(
                        labelText: 'Precio Unitario',
                      ),
                      keyboardType: TextInputType.number,
                    ),
                    const SizedBox(height: 16),
                    const Divider(),
                    const Text(
                      'Personalización (Opcional)',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),

                    // --- SECCIÓN DE FOTOS MEJORADA ---
                    // Muestra tanto las fotos existentes como las nuevas
                    Padding(
                      padding: const EdgeInsets.only(top: 16.0),
                      child: Wrap(
                        spacing: 8.0,
                        runSpacing: 8.0,
                        children: [
                          // Fotos existentes (cargadas desde la red)
                          ...existingImageUrls.map(
                            (url) => Stack(
                              clipBehavior: Clip.none,
                              children: [
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: Image.network(
                                    url,
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
                                    ),
                                    onPressed: () => setDialogState(
                                      () => existingImageUrls.remove(url),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          // Fotos nuevas (cargadas desde el dispositivo)
                          ...newImageFiles.map(
                            (file) => Stack(
                              clipBehavior: Clip.none,
                              children: [
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: Image.file(
                                    File(file.path),
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
                                    ),
                                    onPressed: () => setDialogState(
                                      () => newImageFiles.remove(file),
                                    ),
                                  ),
                                ),
                              ],
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
                    // -----------------------
                    TextField(
                      controller: weightController,
                      decoration: const InputDecoration(labelText: 'Peso (kg)'),
                      keyboardType: TextInputType.number,
                    ),
                    TextField(
                      controller: fillingsController,
                      decoration: const InputDecoration(
                        labelText: 'Rellenos (separados por coma)',
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Cancelar'),
                ),
                FilledButton(
                  onPressed: isUploading
                      ? null
                      : () async {
                          final name = nameController.text.trim();
                          final qty = int.tryParse(qtyController.text) ?? 0;
                          final price =
                              num.tryParse(
                                priceController.text.replaceAll(',', '.'),
                              ) ??
                              -1;
                          if (name.isEmpty || qty <= 0 || price < 0) return;

                          setDialogState(() => isUploading = true);

                          // 1. Sube solo las imágenes NUEVAS
                          final List<String> newUploadedUrls = [];
                          if (newImageFiles.isNotEmpty) {
                            for (final imageFile in newImageFiles) {
                              final url = await ref
                                  .read(ordersRepoProvider)
                                  .uploadImage(imageFile);
                              if (url != null) {
                                newUploadedUrls.add(url);
                              }
                            }
                          }

                          // 2. Combina las URLs viejas que no se borraron con las nuevas
                          final allImageUrls = [
                            ...existingImageUrls,
                            ...newUploadedUrls,
                          ];

                          final customizations = {
                            'weight_kg': double.tryParse(
                              weightController.text.replaceAll(',', '.'),
                            ),
                            'photo_urls': allImageUrls.isNotEmpty
                                ? allImageUrls
                                : null,
                            'fillings': fillingsController.text.trim().isEmpty
                                ? null
                                : fillingsController.text
                                      .split(',')
                                      .map((e) => e.trim())
                                      .toList(),
                          };
                          customizations.removeWhere(
                            (key, value) => value == null,
                          );

                          // 3. Crea el ítem actualizado y REEMPLAZA el viejo en la lista
                          final updatedItem = OrderItem(
                            id: existingItem.id, // Mantenemos el ID si lo tiene
                            name: name,
                            qty: qty,
                            unitPrice: price.toDouble(),
                            customizationJson: customizations.isNotEmpty
                                ? customizations
                                : null,
                          );

                          setState(() => _items[itemIndex] = updatedItem);

                          if (mounted) Navigator.of(context).pop();
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
                      : const Text('Guardar Cambios'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _submit() async {
    final valid = _formKey.currentState?.validate() ?? false;
    if (!valid || _selectedClient == null || _items.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Por favor, selecciona un cliente y añade al menos un producto.',
          ),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final fmt = DateFormat('yyyy-MM-dd');
    String t(TimeOfDay x) =>
        '${x.hour.toString().padLeft(2, '0')}:${x.minute.toString().padLeft(2, '0')}';

    final payload = {
      'client_id': _selectedClient!.id,
      'event_date': fmt.format(_date),
      'start_time': t(_start),
      'end_time': t(_end),
      'status': isEditMode ? widget.order!.status : 'confirmed',
      'deposit': num.tryParse(_deposit.text.replaceAll(',', '.')) ?? 0,
      'notes': _notes.text.trim().isEmpty ? null : _notes.text.trim(),
      'items': _items.map((e) => e.toJson()).toList(),
    };

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
          ref.invalidate(ordersByFilterProvider);
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
          ref.invalidate(ordersByFilterProvider);
          context.pop();
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Form(
      key: _formKey,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: TypeAheadField<Client>(
                  controller: _clientNameController,
                  suggestionsCallback: (pattern) async {
                    if (pattern.length < 2) return [];
                    if (_selectedClient != null &&
                        _selectedClient!.name != pattern) {
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        setState(() => _selectedClient = null);
                      });
                    }
                    return ref.read(clientsRepoProvider).searchClients(pattern);
                  },
                  itemBuilder: (context, client) => ListTile(
                    title: Text(client.name),
                    subtitle: Text(client.phone ?? 'Sin teléfono'),
                  ),
                  onSelected: (client) {
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      setState(() {
                        _selectedClient = client;
                        _clientNameController.text = client.name;
                      });
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
                      labelText: 'Buscar cliente',
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
                iconSize: 30,
                padding: const EdgeInsets.all(14),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (_selectedClient != null)
            Card(
              elevation: 0,
              color: Theme.of(
                context,
              ).colorScheme.surfaceContainerHighest.withAlpha(128),
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: Text(
                  'Teléfono: ${_selectedClient!.phone ?? 'N/A'}\nDirección: ${_selectedClient!.address ?? 'N/A'}',
                ),
              ),
            ),
          const SizedBox(height: 12),
          ListTile(
            title: Text('Fecha: ${DateFormat('dd/MM/yyyy').format(_date)}'),
            trailing: const Icon(Icons.calendar_today),
            onTap: _pickDate,
          ),
          Row(
            children: [
              Expanded(
                child: ListTile(
                  title: Text('Desde: ${_start.format(context)}'),
                  onTap: () => _pickTime(true),
                ),
              ),
              Expanded(
                child: ListTile(
                  title: Text('Hasta: ${_end.format(context)}'),
                  onTap: () => _pickTime(false),
                ),
              ),
            ],
          ),
          TextFormField(
            controller: _deposit,
            decoration: const InputDecoration(
              labelText: 'Seña / Depósito',
              border: OutlineInputBorder(),
            ),
            keyboardType: TextInputType.number,
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _notes,
            decoration: const InputDecoration(
              labelText: 'Notas del pedido',
              border: OutlineInputBorder(),
            ),
            maxLines: 3,
          ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Productos:', style: Theme.of(context).textTheme.titleLarge),
              IconButton.filled(
                onPressed: _addItemDialog,
                icon: const Icon(Icons.add),
              ),
            ],
          ),
          if (_items.isEmpty)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(16.0),
                child: Text('Añade al menos un producto.'),
              ),
            )
          else
            ..._items.asMap().entries.map((entry) {
              final index = entry.key;
              final item = entry.value;
              return Card(
                child: ListTile(
                  title: Text('${item.name} (x${item.qty})'),
                  subtitle: Text(
                    'Precio: \$${item.unitPrice.toStringAsFixed(2)}',
                  ),
                  // --- CAMBIO: Tocar el ítem lo edita ---
                  onTap: () => _editItemDialog(index),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete_outline, color: Colors.red),
                    onPressed: () => setState(() => _items.removeAt(index)),
                  ),
                ),
              );
            }),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: _submit,
            icon: const Icon(Icons.save),
            label: Text(isEditMode ? 'Guardar Cambios' : 'Guardar Pedido'),
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
          ),
        ],
      ),
    );
  }
}
