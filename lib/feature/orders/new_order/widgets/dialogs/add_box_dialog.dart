import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:collection/collection.dart';
import '../../../../../../core/models/order_item.dart';
import '../../../../../../core/models/catalog.dart';
import '../../../product_catalog.dart';
import '../order_items_section.dart';

class AddBoxDialog extends StatefulWidget {
  final CatalogResponse? catalog;
  final OrderItem? existingItem;
  final int? itemIndex;
  final Map<String, XFile> filesToUpload;
  final void Function(String placeholderId, XFile file) onFileAdded;
  final void Function(OrderItem newItem) onSaveEditing;
  final void Function(OrderItem newItem) onAddPending;
  final Widget Function(dynamic imageSource, bool isNetwork, VoidCallback onRemove) buildImageThumbnail;
  final List<Widget> Function(BuildContext context, List<dynamic> allImages, int qty) buildCompactImageRow;

  const AddBoxDialog({
    super.key,
    this.catalog,
    this.existingItem,
    this.itemIndex,
    required this.filesToUpload,
    required this.onFileAdded,
    required this.onSaveEditing,
    required this.onAddPending,
    required this.buildImageThumbnail,
    required this.buildCompactImageRow,
  });

  @override
  State<AddBoxDialog> createState() => _AddBoxDialogState();
}

class _AddBoxDialogState extends State<AddBoxDialog> {
  late bool isEditing;
  late Map<String, dynamic> customData;

  Product? selectedProduct;
  ProductVariant? selectedVariant;
  List<BoxMesaDulceSelection> selectedMesaDulceItems = [];
  Product? selectedBaseCake;
  List<Filling> selectedFillings = [];
  List<Filling> selectedExtraFillings = [];
  List<CakeExtra> selectedExtrasKg = [];
  List<UnitExtraSelection> selectedExtrasUnit = [];
  
  final ImagePicker picker = ImagePicker();
  List<String> existingImageUrls = [];
  List<XFile> selectedFiles = [];

  late TextEditingController qtyController;
  late TextEditingController itemNotesController;
  late TextEditingController unitAdjustmentsController;
  late TextEditingController adjustmentNotesController;
  late TextEditingController finalPriceController;

  double calculatedTotalBasePrice = 0.0;
  double calculatedExtrasCost = 0.0;
  double calculatedSubItemsCost = 0.0;

  List<Product> get boxProducts => widget.catalog?.products.where((p) => p.category == ProductCategory.box).toList() ?? [];
  List<Product> get cakeProducts => widget.catalog?.products.where((p) => p.category == ProductCategory.torta).toList() ?? [];
  List<Product> get _derivedSmallCakeProducts => cakeProducts.where((p) => p.name.contains('Base') || p.name.contains('Mini') || p.name.contains('Micro')).toList();
  List<Product> get mesaDulceProducts => widget.catalog?.products.where((p) => p.category == ProductCategory.mesaDulce).toList() ?? [];
  List<Filling> get allFillings => widget.catalog?.fillings ?? [];
  List<Filling> get freeFillings => allFillings.where((f) => f.isFree).toList();
  List<Filling> get extraCostFillings => allFillings.where((f) => !f.isFree).toList();
  List<Extra> get cakeExtras => widget.catalog?.extras ?? [];

  @override
  void initState() {
    super.initState();
    isEditing = widget.existingItem != null;
    customData = isEditing ? (widget.existingItem!.customizationJson ?? {}) : {};

    selectedProduct = customData['product_category'] == 'box'
        ? boxProducts.firstWhereOrNull((p) => p.name == widget.existingItem!.name)
        : (boxProducts.isNotEmpty ? boxProducts.first : null);

    if (selectedProduct != null && selectedProduct!.variants.isNotEmpty) {
      if (isEditing) {
        final vId = customData['variant_id'];
        selectedVariant = selectedProduct!.variants.firstWhereOrNull((v) => v.id == vId);
      } else {
        selectedVariant = selectedProduct!.variants.first;
      }
    }

    qtyController = TextEditingController(text: isEditing ? widget.existingItem!.qty.toString() : '1');
    itemNotesController = TextEditingController(text: customData['item_notes'] ?? '');
    unitAdjustmentsController = TextEditingController(text: isEditing ? (customData['unit_adjustment']?.toString() ?? '0') : '0');
    adjustmentNotesController = TextEditingController(text: isEditing ? widget.existingItem!.customizationNotes ?? '' : '');
    finalPriceController = TextEditingController();

    if (isEditing && customData['sub_items'] != null) {
      final subItems = customData['sub_items'] as List<dynamic>;
      for (var subItemData in subItems) {
        if (subItemData is Map) {
          final pName = subItemData['product_name']?.toString();
          final qty = int.tryParse(subItemData['quantity']?.toString() ?? '1') ?? 1;
          final variantName = subItemData['variant_name']?.toString();

          final product = mesaDulceProducts.firstWhereOrNull((p) => p.name == pName);
          if (product != null) {
            ProductVariant? variant;
            if (product.variants.isNotEmpty && variantName != null) {
              variant = product.variants.firstWhereOrNull((v) => v.variantName == variantName);
            }
            selectedMesaDulceItems.add(BoxMesaDulceSelection(product: product, quantity: qty, selectedVariant: variant));
          }
        }
      }
    }

    selectedBaseCake = customData['selected_base_cake'] != null
        ? _derivedSmallCakeProducts.firstWhereOrNull((p) => p.name == (customData['selected_base_cake'] as String?))
        : _derivedSmallCakeProducts.firstWhereOrNull((p) => p.name == 'Mini Torta Personalizada (Base)');

    selectedFillings = (customData['selected_fillings'] as List<dynamic>? ?? []).map((name) => allFillings.firstWhereOrNull((f) => f.name == name?.toString())).whereType<Filling>().toList();
    selectedExtraFillings = (customData['selected_extra_fillings'] as List<dynamic>? ?? []).map((data) {
      if (data is Map) return extraCostFillings.firstWhereOrNull((f) => f.name == data['name']?.toString());
      if (data is String) return extraCostFillings.firstWhereOrNull((f) => f.name == data);
      return null;
    }).whereType<Filling>().toList();
    
    selectedExtrasKg = (customData['selected_extras_kg'] as List<dynamic>? ?? []).map((data) {
      if (data is Map) return cakeExtras.firstWhereOrNull((ex) => ex.name == data['name']?.toString() && !ex.isPerUnit);
      if (data is String) return cakeExtras.firstWhereOrNull((ex) => ex.name == data && !ex.isPerUnit);
      return null;
    }).whereType<CakeExtra>().toList();

    selectedExtrasUnit = (customData['selected_extras_unit'] as List<dynamic>? ?? []).map((data) {
      if (data is Map) {
        final extra = cakeExtras.firstWhereOrNull((ex) => ex.name == data['name']?.toString() && ex.isPerUnit);
        if (extra != null) {
          final quantity = int.tryParse(data['quantity']?.toString() ?? '1') ?? 1;
          return UnitExtraSelection(extra: extra, quantity: quantity >= 1 ? quantity : 1);
        }
      }
      return null;
    }).whereType<UnitExtraSelection>().toList();

    final rawUrls = customData['photo_urls'] ?? (customData['photo_url'] != null ? [customData['photo_url']] : []);
    if (rawUrls is List) {
      existingImageUrls = rawUrls.whereType<String>().where((u) => !u.startsWith('placeholder_')).toList();
    }

    if (isEditing && widget.existingItem!.localFile != null && widget.existingItem!.localFile is List) {
      final files = widget.existingItem!.localFile as List;
      for (var f in files) {
        if (f is XFile) {
          selectedFiles.add(f);
        } else if (f is File) {
          selectedFiles.add(XFile(f.path));
        }
      }
    }
  }

  void calculatePrice() {
    if (selectedProduct == null) {
      finalPriceController.text = 'N/A';
      return;
    }

    double basePrice = selectedProduct!.price;
    if (selectedProduct!.variants.isNotEmpty && selectedVariant != null) {
      basePrice = selectedVariant!.price;
    }

    final isPersonalizedBox = selectedProduct?.name == 'Box Personalizado';
    calculatedExtrasCost = 0.0;
    calculatedSubItemsCost = 0.0;

    if (isPersonalizedBox) {
      calculatedTotalBasePrice = selectedBaseCake?.price ?? 0.0;
      for (var sel in selectedMesaDulceItems) {
        double unitPrice = 0.0;
        if (sel.product.variants.isNotEmpty) {
          unitPrice = sel.selectedVariant?.price ?? 0.0;
        } else if (sel.product.unit == ProductUnit.dozen) {
          unitPrice = sel.product.price / 12.0;
        } else {
          unitPrice = sel.product.price;
        }
        calculatedSubItemsCost += unitPrice * sel.quantity;
      }
      calculatedTotalBasePrice += calculatedSubItemsCost;
    } else {
      calculatedTotalBasePrice = basePrice;
    }
    for (var f in selectedExtraFillings) {
      calculatedExtrasCost += f.pricePerKg;
    }
    for (var ex in selectedExtrasKg) {
      calculatedExtrasCost += ex.price;
    }
    for (var exu in selectedExtrasUnit) {
      calculatedExtrasCost += (exu.extra.price * exu.quantity);
    }
    double unitAdjustments = double.tryParse(unitAdjustmentsController.text) ?? 0.0;
    calculatedTotalBasePrice += calculatedExtrasCost + unitAdjustments;

    int qty = int.tryParse(qtyController.text) ?? 1;
    double total = (calculatedTotalBasePrice * qty);

    finalPriceController.text = total.toStringAsFixed(0);
  }

  Widget buildFillingCheckbox(Filling filling, bool isExtraCost) {
    bool isSelected = isExtraCost ? selectedExtraFillings.contains(filling) : selectedFillings.contains(filling);
    return CheckboxListTile(
      dense: true,
      title: Text(isExtraCost ? '${filling.name} (+\$${filling.pricePerKg})' : filling.name),
      value: isSelected,
      onChanged: (val) => setState(() {
        if (val == true) {
          isExtraCost ? selectedExtraFillings.add(filling) : selectedFillings.add(filling);
        } else {
          isExtraCost ? selectedExtraFillings.remove(filling) : selectedFillings.remove(filling);
        }
        calculatePrice();
      }),
    );
  }

  Widget buildExtraKgCheckbox(CakeExtra extra) {
    bool isSelected = selectedExtrasKg.contains(extra);
    return CheckboxListTile(
      dense: true,
      title: Text('${extra.name} (+\$${extra.price})'),
      value: isSelected,
      onChanged: (val) => setState(() {
        if (val == true) {
          selectedExtrasKg.add(extra);
        } else {
          selectedExtrasKg.remove(extra);
        }
        calculatePrice();
      }),
    );
  }

  Widget buildExtraUnitSelector(CakeExtra extra) {
    UnitExtraSelection? selection = selectedExtrasUnit.firstWhereOrNull((s) => s.extra == extra);
    bool isSelected = selection != null;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
      child: Row(
        children: [
          Checkbox(
            value: isSelected,
            onChanged: (val) => setState(() {
              if (val == true) {
                selectedExtrasUnit.add(UnitExtraSelection(extra: extra));
              } else {
                selectedExtrasUnit.removeWhere((s) => s.extra == extra);
              }
              calculatePrice();
            }),
          ),
          Expanded(child: Text('${extra.name} (+\$${extra.price}/u)')),
          if (isSelected)
            Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.remove),
                  onPressed: () => setState(() {
                    if (selection.quantity > 1) {
                      selection.quantity--;
                      calculatePrice();
                    }
                  }),
                ),
                Text('${selection.quantity}'),
                IconButton(
                  icon: const Icon(Icons.add),
                  onPressed: () => setState(() {
                    selection.quantity++;
                    calculatePrice();
                  }),
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget buildMesaDulceItemSelector(Product product) {
    int totalQty = selectedMesaDulceItems.where((sel) => sel.product == product).fold(0, (sum, sel) => sum + sel.quantity);
    bool isSelected = totalQty > 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CheckboxListTile(
          dense: true,
          title: Text(product.name),
          subtitle: product.variants.isNotEmpty
              ? const Text('Múltiples variantes disponibles')
              : Text('Precio: \$${product.price}${product.unit == ProductUnit.dozen ? ' / docena' : ''}'),
          value: isSelected,
          onChanged: (val) => setState(() {
            if (val == true) {
              if (product.variants.isNotEmpty) {
                selectedMesaDulceItems.add(BoxMesaDulceSelection(product: product, selectedVariant: product.variants.first, quantity: 1));
              } else {
                selectedMesaDulceItems.add(BoxMesaDulceSelection(product: product, quantity: 1));
              }
            } else {
              selectedMesaDulceItems.removeWhere((sel) => sel.product == product);
            }
            calculatePrice();
          }),
        ),
        if (isSelected)
          ...selectedMesaDulceItems.where((sel) => sel.product == product).map((selection) {
            return Padding(
              padding: const EdgeInsets.only(left: 32.0, right: 16.0, bottom: 8.0),
              child: Row(
                children: [
                  if (product.variants.isNotEmpty)
                    Expanded(
                      flex: 2,
                      child: DropdownButton<ProductVariant>(
                        isExpanded: true,
                        value: selection.selectedVariant,
                        items: product.variants.map((v) => DropdownMenuItem(value: v, child: Text(v.variantName, overflow: TextOverflow.ellipsis))).toList(),
                        onChanged: (v) => setState(() {
                          selection.selectedVariant = v;
                          calculatePrice();
                        }),
                      ),
                    )
                  else
                    const Expanded(flex: 2, child: SizedBox.shrink()),
                  Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.remove_circle_outline),
                        onPressed: () => setState(() {
                          if (selection.quantity > 1) {
                            selection.quantity--;
                          } else {
                            selectedMesaDulceItems.remove(selection);
                          }
                          calculatePrice();
                        }),
                      ),
                      Text('${selection.quantity}', style: const TextStyle(fontWeight: FontWeight.bold)),
                      IconButton(
                        icon: const Icon(Icons.add_circle_outline),
                        onPressed: () => setState(() {
                          selection.quantity++;
                          calculatePrice();
                        }),
                      ),
                    ],
                  ),
                ],
              ),
            );
          }),
      ],
    );
  }

  void onSave() {
    if (selectedProduct == null) return;
    int qty = int.tryParse(qtyController.text) ?? 1;

    List<dynamic> finalLocalFiles = [];
    List<String> allImageUrls = [];

    if (selectedFiles.isNotEmpty) {
      finalLocalFiles.addAll(selectedFiles);
      for (var file in selectedFiles) {
        final matchingEntry = widget.filesToUpload.entries.firstWhereOrNull((e) => e.value == file);
        if (matchingEntry != null) {
          allImageUrls.add(matchingEntry.key);
        }
      }
    }
    if (existingImageUrls.isNotEmpty) {
      allImageUrls.addAll(existingImageUrls);
      finalLocalFiles.addAll(existingImageUrls);
    }

    final isPersonalizedBox = selectedProduct?.name == 'Box Personalizado';

    final customization = {
      'product_category': 'box',
      if (selectedVariant != null) ...{
        'variant_id': selectedVariant!.id,
        'variant_name': selectedVariant!.variantName,
      },
      if (itemNotesController.text.trim().isNotEmpty) 'item_notes': itemNotesController.text.trim(),
      if (double.tryParse(unitAdjustmentsController.text) != null &&
          double.parse(unitAdjustmentsController.text) != 0)
        'unit_adjustment': double.parse(unitAdjustmentsController.text),
      if (allImageUrls.isNotEmpty) 'photo_url': allImageUrls.first,
      if (allImageUrls.isNotEmpty) 'photo_urls': allImageUrls,
      if (isPersonalizedBox) ...{
        'selected_base_cake': selectedBaseCake?.name,
        'sub_items': selectedMesaDulceItems.map((sel) => {
          'product_name': sel.product.name,
          'quantity': sel.quantity,
          if (sel.selectedVariant != null) 'variant_name': sel.selectedVariant!.variantName,
        }).toList(),
        'selected_fillings': selectedFillings.map((f) => f.name).toList(),
        'selected_extra_fillings': selectedExtraFillings.map((f) => {'name': f.name, 'price': f.pricePerKg}).toList(),
        'selected_extras_kg': selectedExtrasKg.map((ex) => {'name': ex.name, 'price': ex.price}).toList(),
        'selected_extras_unit': selectedExtrasUnit.map((ex) => {'name': ex.extra.name, 'quantity': ex.quantity, 'price': ex.extra.price}).toList(),
      }
    };

    final newItem = OrderItem(
      id: isEditing ? widget.existingItem!.id : null,
      name: selectedProduct!.name,
      qty: qty,
      basePrice: calculatedTotalBasePrice,
      adjustments: 0.0,
      customizationNotes: adjustmentNotesController.text.trim().isEmpty ? null : adjustmentNotesController.text.trim(),
      customizationJson: customization,
      localFile: finalLocalFiles.isNotEmpty ? finalLocalFiles : null,
    );

    if (isEditing) {
      widget.onSaveEditing(newItem);
    } else {
      widget.onAddPending(newItem);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (finalPriceController.text.isEmpty) {
      calculatePrice();
    }
    final isCurrentPersonalizedBox = selectedProduct?.name == 'Box Personalizado';

    return AlertDialog(
      title: Text(isEditing ? 'Editar Box' : 'Agregar Box'),
      content: SizedBox(
        width: double.maxFinite,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<Product>(
                isExpanded: true,
                initialValue: selectedProduct,
                items: boxProducts.map((p) => DropdownMenuItem(value: p, child: Text(p.name))).toList(),
                onChanged: (p) => setState(() {
                  selectedProduct = p;
                  if (p != null && p.variants.isNotEmpty) {
                    selectedVariant = p.variants.first;
                  } else {
                    selectedVariant = null;
                  }
                  calculatePrice();
                }),
                decoration: const InputDecoration(labelText: 'Tipo de Box', isDense: true),
              ),
              const SizedBox(height: 10),
              if (selectedProduct != null && selectedProduct!.variants.isNotEmpty)
                DropdownButtonFormField<ProductVariant>(
                  initialValue: selectedVariant,
                  items: selectedProduct!.variants.map((v) => DropdownMenuItem(value: v, child: Text('${v.formattedName} (\$${v.price.toStringAsFixed(0)})'))).toList(),
                  onChanged: (v) => setState(() {
                    selectedVariant = v;
                    calculatePrice();
                  }),
                  decoration: const InputDecoration(labelText: 'Variante'),
                ),
              const SizedBox(height: 16),
              if (isCurrentPersonalizedBox)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Contenido del Box Personalizado:', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<Product>(
                      isExpanded: true,
                      initialValue: selectedBaseCake,
                      items: _derivedSmallCakeProducts.map((p) => DropdownMenuItem(value: p, child: Text('${p.name} (\$${p.price.toStringAsFixed(0)})'))).toList(),
                      onChanged: (p) => setState(() {
                        selectedBaseCake = p;
                        calculatePrice();
                      }),
                      decoration: const InputDecoration(labelText: 'Mini Torta Base', isDense: true),
                    ),
                    const SizedBox(height: 16),
                    Text('Productos de Mesa Dulce a Incluir:', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    ...mesaDulceProducts.map(buildMesaDulceItemSelector),
                    const SizedBox(height: 16),
                  ],
                )
              else
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Personalización de Mini Torta/Contenido:', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    Text('Rellenos Incluidos (Mini Torta)', style: Theme.of(context).textTheme.titleSmall),
                    ...freeFillings.map((f) => buildFillingCheckbox(f, false)),
                    const SizedBox(height: 8),
                    Text('Rellenos con Costo Extra (Mini Torta)', style: Theme.of(context).textTheme.titleSmall),
                    ...extraCostFillings.map((f) => buildFillingCheckbox(f, true)),
                    const SizedBox(height: 8),
                    Text('Extras por Peso (Costo Fijo/Box)', style: Theme.of(context).textTheme.titleSmall),
                    ...cakeExtras.where((ex) => !ex.isPerUnit).map(buildExtraKgCheckbox),
                    const SizedBox(height: 8),
                    Text('Extras por Unidad (Costo por Unidad/Box)', style: Theme.of(context).textTheme.titleSmall),
                    ...cakeExtras.where((ex) => ex.isPerUnit).map(buildExtraUnitSelector),
                  ],
                ),
              TextFormField(
                controller: itemNotesController,
                decoration: InputDecoration(
                  labelText: isCurrentPersonalizedBox ? 'Notas para los ítems seleccionados' : 'Notas Generales del Box (Sabores, temáticas)',
                  hintText: 'Ej: Detalles de decoración o personalización del box.',
                ),
                maxLines: 2,
                textCapitalization: TextCapitalization.sentences,
              ),
              const SizedBox(height: 16),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: unitAdjustmentsController,
                      decoration: const InputDecoration(labelText: 'Ajuste Fijo (\$)', isDense: true, prefixText: '\$'),
                      keyboardType: const TextInputType.numberWithOptions(signed: true, decimal: false),
                      inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^-?\d*'))],
                      onChanged: (_) => setState(calculatePrice),
                    ),
                  ),
                ],
              ),
              TextFormField(
                controller: adjustmentNotesController,
                decoration: const InputDecoration(labelText: 'Notas del Ajuste/Descuento', hintText: 'Ej: Descuento por promoción'),
                maxLines: 2,
                textCapitalization: TextCapitalization.sentences,
              ),
              const Divider(),
              TextFormField(
                controller: finalPriceController,
                readOnly: true,
                decoration: const InputDecoration(labelText: 'Precio Final Item (Total)', prefixText: '\$'),
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: qtyController,
                      decoration: const InputDecoration(labelText: 'Cantidad'),
                      keyboardType: TextInputType.number,
                      onChanged: (_) => setState(calculatePrice),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              if (selectedFiles.isNotEmpty || existingImageUrls.isNotEmpty)
                Container(
                  height: 90,
                  margin: const EdgeInsets.only(bottom: 10),
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    children: [
                      ...existingImageUrls.map((url) {
                        return Padding(
                          padding: const EdgeInsets.only(right: 8.0),
                          child: widget.buildImageThumbnail(url, true, () => setState(() {
                            existingImageUrls.remove(url);
                          })),
                        );
                      }),
                      ...selectedFiles.map((file) {
                        return Padding(
                          padding: const EdgeInsets.only(right: 8.0),
                          child: widget.buildImageThumbnail(file, false, () => setState(() {
                            selectedFiles.remove(file);
                          })),
                        );
                      }),
                    ],
                  ),
                ),
              TextButton.icon(
                icon: const Icon(Icons.photo_library),
                label: const Text('Añadir Fotos al Box'),
                onPressed: () async {
                  final pickedFiles = await picker.pickMultiImage();
                  if (pickedFiles.isNotEmpty) {
                    setState(() {
                      for (var file in pickedFiles) {
                        final String placeholderId = 'placeholder_${DateTime.now().millisecondsSinceEpoch}_${file.name.replaceAll(' ', '_')}';
                        widget.onFileAdded(placeholderId, file);
                        selectedFiles.add(file);
                      }
                    });
                  }
                },
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
        FilledButton(
          onPressed: () {
            onSave();
            Navigator.pop(context);
          },
          child: Text(isEditing ? 'Guardar Cambios' : 'AGREGAR BOX'),
        ),
      ],
    );
  }
}
