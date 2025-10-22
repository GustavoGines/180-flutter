import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:flutter_typeahead/flutter_typeahead.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';

import '../../core/models/client.dart';
import '../../core/models/order_item.dart';
import '../clients/clients_repository.dart';
import 'orders_repository.dart';

// Providers
final clientsRepoProvider = Provider((_) => ClientsRepository());
final ordersRepoProvider = Provider((_) => OrdersRepository());

class NewOrderPage extends ConsumerStatefulWidget {
  const NewOrderPage({super.key});
  @override
  ConsumerState<NewOrderPage> createState() => _NewOrderPageState();
}

class _NewOrderPageState extends ConsumerState<NewOrderPage> {
  final _formKey = GlobalKey<FormState>();

  final _clientNameController = TextEditingController();
  Client? _selectedClient;
  int? _clientId;

  DateTime _date = DateTime.now();
  TimeOfDay _start = const TimeOfDay(hour: 9, minute: 0);
  TimeOfDay _end = const TimeOfDay(hour: 10, minute: 0);

  final _deposit = TextEditingController(text: '0');
  final _notes = TextEditingController();

  final List<OrderItem> _items = [];

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
      firstDate: DateTime.now(),
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

  // --- NUEVO DIÁLOGO PARA CREAR CLIENTE ---
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
    // Controllers para los campos del formulario
    final nameController = TextEditingController();
    final qtyController = TextEditingController(text: '1');
    final priceController = TextEditingController();
    final weightController = TextEditingController();
    final fillingsController = TextEditingController();
    final ImagePicker picker = ImagePicker();

    // --- CAMBIO: Usamos una lista para las imágenes ---
    List<XFile> imageFiles = [];
    bool isUploading = false;

    showDialog(
      context: context,
      builder: (context) {
        // Usamos un StatefulBuilder para que el diálogo pueda tener su propio estado
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Agregar Ítem al Pedido'),
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

                    // --- SECCIÓN DE FOTOS MODIFICADA ---
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
                                    onPressed: () {
                                      setDialogState(() {
                                        imageFiles.remove(file);
                                      });
                                    },
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
                        // Usamos pickMultiImage para seleccionar varias
                        final pickedFiles = await picker.pickMultiImage();
                        if (pickedFiles.isNotEmpty) {
                          setDialogState(() {
                            imageFiles.addAll(pickedFiles);
                          });
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

                          // --- LÓGICA DE SUBIDA MODIFICADA ---
                          final List<String> uploadedImageUrls = [];
                          if (imageFiles.isNotEmpty) {
                            for (final imageFile in imageFiles) {
                              // Asumo que tu repositorio tiene un método para subir la imagen
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
                            // Usamos 'photo_urls' y pasamos la lista
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

                          // Esto actualiza la lista en la página principal
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

  Future<void> _submit() async {
    final valid = _formKey.currentState?.validate() ?? false;
    // Ahora validamos que un cliente haya sido seleccionado
    if (!valid || _selectedClient == null || _items.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Por favor, selecciona un cliente y añade al menos un ítem.',
          ),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    _clientId = _selectedClient!.id;

    final fmt = DateFormat('yyyy-MM-dd');
    String t(TimeOfDay x) =>
        '${x.hour.toString().padLeft(2, '0')}:${x.minute.toString().padLeft(2, '0')}';

    final payload = {
      'client_id': _clientId,
      'event_date': fmt.format(_date),
      'start_time': t(_start),
      'end_time': t(_end),
      'status': 'confirmed',
      'deposit': num.tryParse(_deposit.text.replaceAll(',', '.')) ?? 0,
      'notes': _notes.text.trim().isEmpty ? null : _notes.text.trim(),
      'items': _items.map((e) => e.toJson()).toList(),
    };

    try {
      await ref.read(ordersRepoProvider).createOrder(payload);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Pedido creado con éxito.'),
            backgroundColor: Colors.green,
          ),
        );
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al crear el pedido: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Nuevo Pedido')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // --- NUEVO DISEÑO PARA LA SECCIÓN DE CLIENTE ---
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
                      return ref
                          .read(clientsRepoProvider)
                          .searchClients(pattern);
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

            // Si se selecciona un cliente, mostrar sus datos
            if (_selectedClient != null)
              Card(
                elevation: 0,
                color: Theme.of(
                  context,
                ).colorScheme.surfaceVariant.withOpacity(0.5),
                child: Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Text(
                    'Teléfono: ${_selectedClient!.phone ?? 'N/A'}\nDirección: ${_selectedClient!.address ?? 'N/A'}',
                  ),
                ),
              ),

            const SizedBox(height: 12),

            // --- EL RESTO DEL FORMULARIO QUEDA IGUAL ---
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
                Text(
                  'Ítems del Pedido',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
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
                  child: Text('Añade al menos un ítem.'),
                ),
              )
            else
              ..._items.asMap().entries.map((e) {
                final i = e.key;
                final it = e.value;
                return Card(
                  child: ListTile(
                    title: Text('${it.name} (x${it.qty})'),
                    subtitle: Text(
                      'Precio: \$${it.unitPrice.toStringAsFixed(2)}',
                    ),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete_outline, color: Colors.red),
                      onPressed: () => setState(() => _items.removeAt(i)),
                    ),
                  ),
                );
              }),

            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: _submit,
              icon: const Icon(Icons.save),
              label: const Text('Guardar Pedido'),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
