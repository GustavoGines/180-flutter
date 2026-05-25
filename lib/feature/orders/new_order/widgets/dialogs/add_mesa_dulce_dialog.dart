import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:collection/collection.dart';
import '../../../../../../core/models/order_item.dart';
import '../../../../../../core/models/catalog.dart';
import '../../../product_catalog.dart';

class AddMesaDulceDialog extends StatefulWidget {
  final CatalogResponse? catalog;
  final OrderItem? existingItem;
  final int? itemIndex;
  final Map<String, XFile> filesToUpload;
  final void Function(String placeholderId, XFile file) onFileAdded;
  final void Function(OrderItem newItem) onSaveEditing;
  final void Function(List<OrderItem> pendingItems) onAddPending;
  final Widget Function(dynamic imageSource, bool isNetwork, VoidCallback onRemove) buildImageThumbnail;
  final List<Widget> Function(BuildContext context, List<dynamic> allImages, int qty) buildCompactImageRow;

  const AddMesaDulceDialog({
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
  State<AddMesaDulceDialog> createState() => _AddMesaDulceDialogState();
}

class _AddMesaDulceDialogState extends State<AddMesaDulceDialog> {
  late bool isEditing;
  List<OrderItem> pendingItems = [];
  Product? selectedProduct;
  ProductVariant? selectedVariant;
  double basePrice = 0.0;
  double adjustments = 0.0;
  bool isHalfDozen = false;
  late TextEditingController qtyController;
  late TextEditingController adjustmentsController;
  late TextEditingController notesController;
  late TextEditingController itemNotesController;
  late TextEditingController unitAdjustmentsController;
  late TextEditingController finalPriceController;
  bool isUnitSaleForDozen = false;
  
  final ImagePicker picker = ImagePicker();
  List<XFile> selectedFiles = [];
  List<String> existingRemoteUrls = [];

  List<Product> get mesaDulceProducts => widget.catalog?.products.where((p) => p.category == ProductCategory.mesaDulce).toList() ?? [];

  @override
  void initState() {
    super.initState();
    isEditing = widget.existingItem != null;
    final existingItem = widget.existingItem;

    selectedProduct = isEditing
        ? mesaDulceProducts.firstWhereOrNull((p) => p.name == existingItem?.name)
        : mesaDulceProducts.firstWhereOrNull(
              (p) => p.category == ProductCategory.mesaDulce,
            ) ??
            (mesaDulceProducts.isNotEmpty ? mesaDulceProducts.first : null);

    adjustments = isEditing ? existingItem!.adjustments : 0.0;

    if (isEditing) {
      final custom = existingItem!.customizationJson ?? {};
      isHalfDozen = custom['is_half_dozen'] as bool? ?? false;
      final vId = custom['variant_id'];
      if (vId != null && selectedProduct != null) {
        selectedVariant = selectedProduct!.variants.firstWhereOrNull(
          (v) => v.id == vId,
        );
      }
    }

    qtyController = TextEditingController(
      text: isEditing ? existingItem!.qty.toString() : '1',
    );
    adjustmentsController = TextEditingController(
      text: adjustments.toStringAsFixed(0),
    );
    notesController = TextEditingController(
      text: isEditing ? existingItem!.customizationNotes ?? '' : '',
    );
    itemNotesController = TextEditingController(
      text: isEditing
          ? (existingItem!.customizationJson?['item_notes'] ?? '')
          : '',
    );
    unitAdjustmentsController = TextEditingController(
      text: isEditing
          ? (existingItem!.customizationJson?['unit_adjustment']?.toString() ?? '0')
          : '0',
    );
    finalPriceController = TextEditingController();
    isUnitSaleForDozen = isEditing
        ? (existingItem!.customizationJson?['is_unit_sale_for_dozen'] == true)
        : false;

    if (isEditing) {
      if (existingItem!.localFile != null &&
          (existingItem.localFile is List) &&
          (existingItem.localFile as List).isNotEmpty) {
        final files = existingItem.localFile as List;
        for (var f in files) {
          if (f is XFile) {
            selectedFiles.add(f);
          } else if (f is File) {
            selectedFiles.add(XFile(f.path));
          }
        }
      }

      if (existingItem.customizationJson?['photo_urls'] != null) {
        final urls = existingItem.customizationJson!['photo_urls'];
        if (urls is List) {
          existingRemoteUrls.addAll(urls.whereType<String>().where((u) => !u.startsWith('placeholder_')));
        }
      } else if (existingItem.customizationJson?['photo_url'] != null) {
        final url = existingItem.customizationJson!['photo_url'];
        if (!url.startsWith('placeholder_')) {
          existingRemoteUrls.add(url);
        }
      }
    }
  }

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

  void _smartMergeItem(OrderItem newItem) {
    final index = pendingItems.indexWhere((item) {
      if (item.name != newItem.name) return false;
      if (item.basePrice != newItem.basePrice) return false;
      if (item.adjustments != newItem.adjustments) return false;
      if (item.customizationNotes != newItem.customizationNotes) return false;
      if (!const DeepCollectionEquality().equals(item.customizationJson, newItem.customizationJson)) return false;
      if (item.localFile != null || newItem.localFile != null) return false;
      return true;
    });

    if (index != -1) {
      final existing = pendingItems[index];
      pendingItems[index] = existing.copyWith(qty: existing.qty + newItem.qty);
    } else {
      pendingItems.add(newItem);
    }
  }

  void addToPendingList() {
    if (selectedProduct == null) { return; }
    int qty = int.tryParse(qtyController.text) ?? 0;
    if (qty <= 0) { return; }
    if (selectedProduct!.variants.isNotEmpty &&
        selectedVariant == null) { return; }

    List<dynamic> finalLocalFiles = [];
    List<String> allPhotoUrls = [];

    if (selectedFiles.isNotEmpty) {
      finalLocalFiles.addAll(selectedFiles);
      for (var file in selectedFiles) {
        final matchingEntry = widget.filesToUpload.entries.firstWhereOrNull((e) => e.value == file);
        if (matchingEntry != null) {
          allPhotoUrls.add(matchingEntry.key);
        }
      }
    }
    if (existingRemoteUrls.isNotEmpty) {
      allPhotoUrls.addAll(existingRemoteUrls);
      finalLocalFiles.addAll(existingRemoteUrls);
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
      if (allPhotoUrls.isNotEmpty) 'photo_url': allPhotoUrls.first,
      if (allPhotoUrls.isNotEmpty) 'photo_urls': allPhotoUrls,
      if (double.tryParse(unitAdjustmentsController.text) != null &&
          double.parse(unitAdjustmentsController.text) != 0)
        'unit_adjustment': double.parse(
          unitAdjustmentsController.text,
        ),
    };

    final newItem = OrderItem(
      id: isEditing ? widget.existingItem!.id : null,
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

    setState(() {
      if (isEditing) {
        widget.onSaveEditing(newItem);
        Navigator.pop(context);
      } else {
        _smartMergeItem(newItem);
        qtyController.text = '1';
        adjustmentsController.text = '0';
        notesController.clear();
        itemNotesController.clear();
        unitAdjustmentsController.text = '0';
        selectedFiles.clear();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (finalPriceController.text.isEmpty) {
      calculateCurrentItemPrice();
    }
    
    return AlertDialog(
      title: Row(
        children: [
          if (!isEditing)
            IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () {
                  Navigator.pop(context);
                }),
          Expanded(
            child: Text(
              isEditing ? 'Editar Item Mesa Dulce' : 'Mesa Dulce (Carrito)',
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
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (ctx, idx) {
                      final it = pendingItems[idx];
                      final vName = it.customizationJson?['variant_name'] ??
                          (it.customizationJson?['is_half_dozen'] == true ? 'Media Docena' : 'Unidad');
                      final formattedVName = vName.startsWith('size') ? vName.replaceAll('size', '') : vName;

                      return Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  if (it.localFile != null && (it.localFile as List).isNotEmpty)
                                    Container(
                                      margin: const EdgeInsets.only(right: 8),
                                      constraints: const BoxConstraints(maxWidth: 130),
                                      child: Wrap(
                                        spacing: 4,
                                        runSpacing: 4,
                                        children: widget.buildCompactImageRow(context, it.localFile as List<dynamic>, it.qty),
                                      ),
                                    ),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text('${it.name} ($formattedVName)', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                                        Text('${it.qty} x \$${it.basePrice.toStringAsFixed(0)}', style: TextStyle(fontSize: 12, color: Colors.grey[700])),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete, size: 20, color: Colors.red),
                              onPressed: () {
                                setState(() {
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
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.blueGrey),
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
                      initialValue: selectedProduct,
                      items: mesaDulceProducts
                          .map((p) => DropdownMenuItem(value: p, child: Text(p.name)))
                          .toList(),
                      onChanged: (p) => setState(() {
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
                      decoration: const InputDecoration(labelText: 'Producto', isDense: true, contentPadding: EdgeInsets.symmetric(vertical: 8, horizontal: 10)),
                    ),
                    const SizedBox(height: 10),
                    if (selectedProduct != null) ...[
                      if (selectedProduct!.variants.isNotEmpty)
                        DropdownButtonFormField<ProductVariant>(
                          initialValue: selectedVariant,
                          items: selectedProduct!.variants
                              .map((v) => DropdownMenuItem(value: v, child: Text('${v.formattedName} (\$${v.price.toStringAsFixed(0)})')))
                              .toList(),
                          onChanged: (v) => setState(() {
                            selectedVariant = v;
                            calculateCurrentItemPrice();
                          }),
                          decoration: const InputDecoration(labelText: 'Variante'),
                        )
                      else if (selectedProduct!.allowHalfDozen || selectedProduct!.unit == ProductUnit.dozen)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8.0),
                          child: Row(
                            children: [
                              if (selectedProduct!.allowHalfDozen) ...[
                                const Text('Media Doc.', style: TextStyle(fontSize: 14)),
                                Transform.scale(
                                  scale: 0.8,
                                  child: Switch(
                                    value: isHalfDozen,
                                    onChanged: (v) => setState(() {
                                      isHalfDozen = v;
                                      if (v) isUnitSaleForDozen = false;
                                      calculateCurrentItemPrice();
                                    }),
                                  ),
                                ),
                                const SizedBox(width: 8),
                              ],
                              if (selectedProduct!.unit == ProductUnit.dozen && !isHalfDozen) ...[
                                const Text('Unidad', style: TextStyle(fontSize: 14)),
                                Transform.scale(
                                  scale: 0.8,
                                  child: Switch(
                                    value: isUnitSaleForDozen,
                                    onChanged: (v) => setState(() {
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
                            decoration: const InputDecoration(labelText: 'Cant.', isDense: true),
                            onChanged: (_) => setState(() {
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
                            decoration: const InputDecoration(labelText: '\$ Unit.', isDense: true, prefixText: '\$'),
                            onChanged: (_) => setState(() {
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
                            decoration: const InputDecoration(labelText: '\$ Tot.', isDense: true, prefixText: '\$'),
                            onChanged: (_) => setState(() {
                              calculateCurrentItemPrice();
                            }),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    TextFormField(
                      controller: notesController,
                      decoration: const InputDecoration(labelText: 'Notas del Ajuste (Opcional)', hintText: 'Ej: Diseño especial, etc.'),
                    ),
                    const SizedBox(height: 10),
                    TextFormField(
                      controller: itemNotesController,
                      decoration: const InputDecoration(labelText: 'Notas del Item (Sabor, etc)'),
                      maxLines: 2,
                    ),
                    const SizedBox(height: 10),
                    if (selectedFiles.isNotEmpty || existingRemoteUrls.isNotEmpty)
                      Container(
                        height: 90,
                        margin: const EdgeInsets.only(bottom: 10),
                        child: ListView(
                          scrollDirection: Axis.horizontal,
                          children: [
                            ...existingRemoteUrls.map((url) {
                              return Padding(
                                padding: const EdgeInsets.only(right: 8.0),
                                child: widget.buildImageThumbnail(
                                  url,
                                  true,
                                  () => setState(() {
                                    existingRemoteUrls.remove(url);
                                  }),
                                ),
                              );
                            }),
                            ...selectedFiles.map((file) {
                              return Padding(
                                padding: const EdgeInsets.only(right: 8.0),
                                child: widget.buildImageThumbnail(
                                  file,
                                  false,
                                  () => setState(() {
                                    selectedFiles.remove(file);
                                  }),
                                ),
                              );
                            }),
                          ],
                        ),
                      ),
                    TextButton.icon(
                      icon: const Icon(Icons.photo_library),
                      label: const Text('Añadir Fotos al Item/Box'),
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
                    const Divider(),
                    const SizedBox(height: 10),
                    Align(
                      alignment: Alignment.centerRight,
                      child: Text(
                        'Subtotal Item: \$${finalPriceController.text}',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.green),
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
        if (pendingItems.isNotEmpty || isEditing || (int.tryParse(qtyController.text) ?? 0) > 0)
          FilledButton(
            onPressed: () {
              if (isEditing) {
                addToPendingList();
              } else {
                bool formHasData = (int.tryParse(qtyController.text) ?? 0) != 1 ||
                    notesController.text.isNotEmpty ||
                    itemNotesController.text.isNotEmpty ||
                    (double.tryParse(adjustmentsController.text) ?? 0) != 0 ||
                    (double.tryParse(unitAdjustmentsController.text) ?? 0) != 0 ||
                    selectedFiles.isNotEmpty ||
                    existingRemoteUrls.isNotEmpty;
                if (pendingItems.isEmpty || formHasData) {
                  addToPendingList();
                }
                if (pendingItems.isNotEmpty) {
                  widget.onAddPending(pendingItems);
                }
                if (mounted && Navigator.canPop(context)) {
                  Navigator.pop(context);
                }
              }
            },
            child: Text(isEditing ? 'Guardar Cambios' : 'AGREGAR TODO (${pendingItems.length + ((pendingItems.isEmpty || ((int.tryParse(qtyController.text) ?? 0) != 1 || notesController.text.isNotEmpty || itemNotesController.text.isNotEmpty || (double.tryParse(adjustmentsController.text) ?? 0) != 0 || (double.tryParse(unitAdjustmentsController.text) ?? 0) != 0 || selectedFiles.isNotEmpty || existingRemoteUrls.isNotEmpty)) ? 1 : 0)})'),
          ),
      ],
    );
  }
}
