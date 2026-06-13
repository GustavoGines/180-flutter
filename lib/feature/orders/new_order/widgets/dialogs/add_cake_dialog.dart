import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:image_picker/image_picker.dart';
import 'package:collection/collection.dart';
import '../../../../../../core/models/order_item.dart';
import '../../../../../../core/models/catalog.dart';
import '../../../product_catalog.dart';
import '../order_items_section.dart';

class AddCakeDialog extends StatefulWidget {
  final CatalogResponse? catalog;
  final OrderItem? existingItem;
  final int? itemIndex;
  final Map<String, XFile> filesToUpload;
  final void Function(String placeholderId, XFile file) onFileAdded;
  final void Function(OrderItem newItem) onSaveEditing;
  final void Function(OrderItem newItem) onAddPending;
  final Widget Function(dynamic imageSource, bool isNetwork, VoidCallback onRemove) buildImageThumbnail;
  final List<Widget> Function(BuildContext context, List<dynamic> allImages, double qty) buildCompactImageRow;

  const AddCakeDialog({
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
  State<AddCakeDialog> createState() => _AddCakeDialogState();
}

class _AddCakeDialogState extends State<AddCakeDialog> {
  late bool isEditing;
  late Map<String, dynamic> customData;

  Product? selectedCakeType;
  double cakeWeight = 1.0;
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
  late TextEditingController kgAdjustmentsController;
  late TextEditingController adjustmentNotesController;
  late TextEditingController calculatedBasePriceController;
  late TextEditingController finalPriceController;

  double calculatedBasePrice = 0.0;
  double multiplierAdjustment = 0.0;

  bool _freeFillingsExpanded = true;
  bool _extraFillingsExpanded = false;
  bool _extraKgExpanded = false;
  bool _extraUnitExpanded = false;

  List<Product> get cakeProducts => widget.catalog?.products.where((p) => p.category == ProductCategory.torta).toList() ?? [];
  List<Filling> get allFillings => widget.catalog?.fillings ?? [];
  List<Filling> get freeFillings => allFillings.where((f) => f.isFree).toList();
  List<Filling> get extraCostFillings => allFillings.where((f) => !f.isFree).toList();
  List<Extra> get cakeExtras => widget.catalog?.extras ?? [];

  @override
  void initState() {
    super.initState();
    _loadPreferences();
    isEditing = widget.existingItem != null;
    customData = isEditing ? (widget.existingItem!.customizationJson ?? {}) : {};

    selectedCakeType = isEditing
        ? cakeProducts.firstWhereOrNull((p) => p.name == widget.existingItem!.name)
        : (cakeProducts.isNotEmpty ? cakeProducts.first : null);

    cakeWeight = (customData['weight_kg'] as num?)?.toDouble() ?? 1.0;

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

    qtyController = TextEditingController(text: isEditing ? widget.existingItem!.qty.toString() : '1');
    itemNotesController = TextEditingController(text: customData['item_notes'] ?? '');
    unitAdjustmentsController = TextEditingController(text: isEditing ? (customData['unit_adjustment']?.toString() ?? '0') : '0');
    kgAdjustmentsController = TextEditingController(text: isEditing ? (customData['kg_adjustment']?.toString() ?? '0') : '0');
    adjustmentNotesController = TextEditingController(text: isEditing ? widget.existingItem!.customizationNotes ?? '' : '');
    calculatedBasePriceController = TextEditingController();
    finalPriceController = TextEditingController();
  }

  Future<void> _loadPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _freeFillingsExpanded = prefs.getBool('cake_free_fillings_exp') ?? true;
      _extraFillingsExpanded = prefs.getBool('cake_extra_fillings_exp') ?? false;
      _extraKgExpanded = prefs.getBool('cake_extra_kg_exp') ?? false;
      _extraUnitExpanded = prefs.getBool('cake_extra_unit_exp') ?? false;
    });
  }

  void _savePreference(String key, bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(key, value);
  }

  void calculateCakePrice() {
    if (selectedCakeType == null) {
      calculatedBasePriceController.text = 'N/A';
      finalPriceController.text = 'N/A';
      return;
    }

    final bool isSmallCake = selectedCakeType?.name == 'Mini Torta Personalizada (Base)' || selectedCakeType?.name == 'Micro Torta (Base)';
    double extraMultiplier = isSmallCake ? 0.5 : cakeWeight;

    double kgAdj = double.tryParse(kgAdjustmentsController.text) ?? 0.0;
    calculatedBasePrice = (selectedCakeType!.price + kgAdj) * extraMultiplier;

    double calculatedExtrasCost = 0.0;

    for (var f in selectedExtraFillings) {
      calculatedExtrasCost += (f.pricePerKg * extraMultiplier);
    }

    for (var ex in selectedExtrasKg) {
      calculatedExtrasCost += (ex.price * extraMultiplier);
    }

    for (var exu in selectedExtrasUnit) {
      calculatedExtrasCost += (exu.extra.price * exu.quantity);
    }

    double unitAdjustments = double.tryParse(unitAdjustmentsController.text) ?? 0.0;
    calculatedBasePrice += calculatedExtrasCost + unitAdjustments;
    
    double qty = double.tryParse(qtyController.text) ?? 1.0;

    double total = (calculatedBasePrice * qty);

    calculatedBasePriceController.text = calculatedBasePrice.toStringAsFixed(0);
    finalPriceController.text = total.toStringAsFixed(0);
  }

  Widget buildFillingCheckbox(Filling filling, bool isExtraCost) {
    bool isSelected = isExtraCost ? selectedExtraFillings.contains(filling) : selectedFillings.contains(filling);
    return CheckboxListTile(
      dense: true,
      title: Text(isExtraCost ? '${filling.name} (+\$${filling.pricePerKg}/kg)' : filling.name),
      value: isSelected,
      onChanged: (val) => setState(() {
        if (val == true) {
          isExtraCost ? selectedExtraFillings.add(filling) : selectedFillings.add(filling);
        } else {
          isExtraCost ? selectedExtraFillings.remove(filling) : selectedFillings.remove(filling);
        }
        calculateCakePrice();
      }),
    );
  }

  Widget buildFreeFillingChip(Filling filling) {
    bool isSelected = selectedFillings.contains(filling);
    return FilterChip(
      label: Text(filling.name),
      selected: isSelected,
      onSelected: (val) => setState(() {
        if (val) {
          selectedFillings.add(filling);
        } else {
          selectedFillings.remove(filling);
        }
        calculateCakePrice();
      }),
    );
  }

  Widget buildExtraKgCheckbox(CakeExtra extra) {
    bool isSelected = selectedExtrasKg.contains(extra);
    return CheckboxListTile(
      dense: true,
      title: Text('${extra.name} (+\$${extra.price}/kg)'),
      value: isSelected,
      onChanged: (val) => setState(() {
        if (val == true) {
          selectedExtrasKg.add(extra);
        } else {
          selectedExtrasKg.remove(extra);
        }
        calculateCakePrice();
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
              calculateCakePrice();
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
                      calculateCakePrice();
                    }
                  }),
                ),
                Text('${selection.quantity}'),
                IconButton(
                  icon: const Icon(Icons.add),
                  onPressed: () => setState(() {
                    selection.quantity++;
                    calculateCakePrice();
                  }),
                ),
              ],
            ),
        ],
      ),
    );
  }

  void onSave() {
    if (selectedCakeType == null) return;
    double qty = double.tryParse(qtyController.text) ?? 1.0;

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

    final customization = {
      'product_category': 'torta',
      'weight_kg': cakeWeight,
      'selected_fillings': selectedFillings.map((f) => f.name).toList(),
      'selected_extra_fillings': selectedExtraFillings.map((f) => {'name': f.name, 'price': f.pricePerKg}).toList(),
      'selected_extras_kg': selectedExtrasKg.map((ex) => {'name': ex.name, 'price': ex.price}).toList(),
      'selected_extras_unit': selectedExtrasUnit.map((ex) => {'name': ex.extra.name, 'quantity': ex.quantity, 'price': ex.extra.price}).toList(),
      if (itemNotesController.text.trim().isNotEmpty) 'item_notes': itemNotesController.text.trim(),
      if (double.tryParse(unitAdjustmentsController.text) != null &&
          double.parse(unitAdjustmentsController.text) != 0)
        'unit_adjustment': double.parse(unitAdjustmentsController.text),
      if (double.tryParse(kgAdjustmentsController.text) != null &&
          double.parse(kgAdjustmentsController.text) != 0)
        'kg_adjustment': double.parse(kgAdjustmentsController.text),
      if (allImageUrls.isNotEmpty) 'photo_url': allImageUrls.first,
      if (allImageUrls.isNotEmpty) 'photo_urls': allImageUrls,
    };

    final newItem = OrderItem(
      id: isEditing ? widget.existingItem!.id : null,
      name: selectedCakeType!.name,
      qty: qty,
      basePrice: calculatedBasePrice,
      adjustments: 0.0, // Ya no se usa $ Tot.
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
      calculateCakePrice();
    }

    return AlertDialog(
      title: Text(isEditing ? 'Editar Torta' : 'Agregar Torta'),
      content: SizedBox(
        width: double.maxFinite,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<Product>(
                isExpanded: true,
                initialValue: selectedCakeType,
                items: cakeProducts.map((p) => DropdownMenuItem(value: p, child: Text(p.name))).toList(),
                onChanged: (p) => setState(() {
                  selectedCakeType = p;
                  calculateCakePrice();
                }),
                decoration: const InputDecoration(labelText: 'Tipo de Torta', isDense: true),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  const Text('Peso Base (Kg): '),
                  IconButton(
                    icon: const Icon(Icons.remove),
                    onPressed: () => setState(() {
                      if (cakeWeight > 0.5) {
                        cakeWeight -= 0.5;
                        calculateCakePrice();
                      }
                    }),
                  ),
                  Text(cakeWeight.toStringAsFixed(1), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  IconButton(
                    icon: const Icon(Icons.add),
                    onPressed: () => setState(() {
                      cakeWeight += 0.5;
                      calculateCakePrice();
                    }),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Theme(
                data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                child: ExpansionTile(
                  initiallyExpanded: _freeFillingsExpanded,
                  onExpansionChanged: (val) {
                    _freeFillingsExpanded = val;
                    _savePreference('cake_free_fillings_exp', val);
                  },
                  title: const Text('Rellenos Incluidos', style: TextStyle(fontWeight: FontWeight.bold)),
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                      child: Wrap(
                        spacing: 8.0,
                        runSpacing: 4.0,
                        alignment: WrapAlignment.start,
                        children: freeFillings.map((f) => buildFreeFillingChip(f)).toList(),
                      ),
                    ),
                  ],
                ),
              ),
              Theme(
                data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                child: ExpansionTile(
                  initiallyExpanded: _extraFillingsExpanded,
                  onExpansionChanged: (val) {
                    _extraFillingsExpanded = val;
                    _savePreference('cake_extra_fillings_exp', val);
                  },
                  title: const Text('Rellenos con Costo Extra', style: TextStyle(fontWeight: FontWeight.bold)),
                  children: extraCostFillings.map((f) => buildFillingCheckbox(f, true)).toList(),
                ),
              ),
              Theme(
                data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                child: ExpansionTile(
                  initiallyExpanded: _extraKgExpanded,
                  onExpansionChanged: (val) {
                    _extraKgExpanded = val;
                    _savePreference('cake_extra_kg_exp', val);
                  },
                  title: const Text('Extras por Peso (Kg)', style: TextStyle(fontWeight: FontWeight.bold)),
                  children: cakeExtras.where((ex) => !ex.isPerUnit).map(buildExtraKgCheckbox).toList(),
                ),
              ),
              Theme(
                data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                child: ExpansionTile(
                  initiallyExpanded: _extraUnitExpanded,
                  onExpansionChanged: (val) {
                    _extraUnitExpanded = val;
                    _savePreference('cake_extra_unit_exp', val);
                  },
                  title: const Text('Extras por Unidad', style: TextStyle(fontWeight: FontWeight.bold)),
                  children: cakeExtras.where((ex) => ex.isPerUnit).map(buildExtraUnitSelector).toList(),
                ),
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: itemNotesController,
                decoration: const InputDecoration(labelText: 'Notas Generales (Detalles, diseño)', hintText: 'Ej: Bizcochuelo de vainilla, diseño de flores...'),
                maxLines: 2,
                textCapitalization: TextCapitalization.sentences,
              ),
              const SizedBox(height: 10),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 3,
                    child: TextFormField(
                      controller: kgAdjustmentsController,
                      decoration: const InputDecoration(labelText: '\$ / Kg', isDense: true, prefixText: '\$'),
                      keyboardType: const TextInputType.numberWithOptions(signed: true, decimal: false),
                      inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^-?\d*'))],
                      onChanged: (_) => setState(calculateCakePrice),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    flex: 3,
                    child: TextFormField(
                      controller: unitAdjustmentsController,
                      decoration: const InputDecoration(labelText: 'Ajuste Fijo (\$)', isDense: true, prefixText: '\$'),
                      keyboardType: const TextInputType.numberWithOptions(signed: true, decimal: false),
                      inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^-?\d*'))],
                      onChanged: (_) => setState(calculateCakePrice),
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
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: qtyController,
                      decoration: const InputDecoration(labelText: 'Cantidad'),
                      keyboardType: TextInputType.number,
                      onChanged: (_) => setState(calculateCakePrice),
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
                label: const Text('AÃ±adir Fotos de Referencia'),
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
      actionsPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      actions: [
        SizedBox(
          width: double.maxFinite,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('Precio Final:', style: TextStyle(fontSize: 12)),
                    Text(
                      '\$${finalPriceController.text}',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
                  const SizedBox(width: 8),
                  FilledButton(
                    onPressed: () {
                      onSave();
                      Navigator.pop(context);
                    },
                    child: Text(isEditing ? 'Guardar' : 'Agregar'),
                  ),
                ],
              ),
            ],
          ),
        )
      ],
    );
  }
}
