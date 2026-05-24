import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:collection/collection.dart';


import '../../../../core/models/order_item.dart';
import '../../../../core/models/catalog.dart';

import '../../product_catalog.dart';
import 'package:flutter/services.dart';
import 'package:pasteleria_180_flutter/core/json_utils.dart';

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

class OrderItemsSection extends ConsumerStatefulWidget {
  final List<OrderItem> items;
  final CatalogResponse? catalog;
  final Map<String, XFile> filesToUpload;
  final ValueChanged<List<OrderItem>> onItemsChanged;

  const OrderItemsSection({
    super.key,
    required this.items,
    this.catalog,
    required this.filesToUpload,
    required this.onItemsChanged,
  });

  @override
  ConsumerState<OrderItemsSection> createState() => _OrderItemsSectionState();
}

class _OrderItemsSectionState extends ConsumerState<OrderItemsSection> {
  final NumberFormat _currencyFormat = NumberFormat.currency(
    locale: 'es_AR',
    symbol: '\$',
    decimalDigits: 0,
    customPattern: '\u00a4#,##0',
  );

  final ImagePicker picker = ImagePicker();

  List<OrderItem> get _items => widget.items;
  Map<String, XFile> get _filesToUpload => widget.filesToUpload;

  List<Product> get boxProducts => widget.catalog?.products.where((p) => p.category == ProductCategory.box).toList() ?? [];
  List<Product> get cakeProducts => widget.catalog?.products.where((p) => p.category == ProductCategory.torta).toList() ?? [];
  List<Product> get _derivedSmallCakeProducts => cakeProducts.where((p) => p.name.contains('Base') || p.name.contains('Mini') || p.name.contains('Micro')).toList();
  List<Product> get mesaDulceProducts => widget.catalog?.products.where((p) => p.category == ProductCategory.mesaDulce).toList() ?? [];
  
  List<Filling> get allFillings => widget.catalog?.fillings ?? [];
  List<Filling> get freeFillings => allFillings.where((f) => f.isFree).toList();
  List<Filling> get extraCostFillings => allFillings.where((f) => !f.isFree).toList();
  
  List<Extra> get cakeExtras => widget.catalog?.extras ?? [];

  void _updateItemsAndRecalculate(VoidCallback updateLogic) {
    setState(() {
      updateLogic();
    });
    widget.onItemsChanged(_items);
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
                          initialValue: selection.selectedVariant,
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
                            initialValue: selectedBaseCake,
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
                            ],
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
                              .map(buildMesaDulceItemSelector),
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
                          }),
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
                    if (selectedProduct == null) { return; }

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
                      initialValue: selectedCakeType,
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
                          }),
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
                    if (selectedCakeType == null) { return; }

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
    List<XFile> selectedFiles = [];
    String? existingRemoteUrl;

    if (isEditing) {
      if (existingItem.localFile != null &&
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

      if (existingItem.customizationJson?['photo_url'] != null) {
        final url = existingItem.customizationJson!['photo_url'];
        if (!url.startsWith('placeholder_')) {
          existingRemoteUrl = url;
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
              if (selectedProduct == null) { return; }
              int qty = int.tryParse(qtyController.text) ?? 0;
              if (qty <= 0) { return; }
              if (selectedProduct!.variants.isNotEmpty &&
                  selectedVariant == null) { return; }

              List<XFile> finalLocalFiles = [];
              String? finalPhotoUrl;

              if (selectedFiles.isNotEmpty) {
                finalLocalFiles.addAll(selectedFiles);
              }
              if (existingRemoteUrl != null) {
                finalPhotoUrl = existingRemoteUrl;
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
                  selectedFiles.clear();
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
                                                  it.qty,
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
                              initialValue: selectedProduct,
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
                                  initialValue: selectedVariant,
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
                            if (selectedFiles.isNotEmpty ||
                                existingRemoteUrl != null)
                              Container(
                                height: 90,
                                margin: const EdgeInsets.only(bottom: 10),
                                child: ListView(
                                  scrollDirection: Axis.horizontal,
                                  children: [
                                    if (existingRemoteUrl != null)
                                      Padding(
                                        padding: const EdgeInsets.only(
                                          right: 8.0,
                                        ),
                                        child: _buildImageThumbnail(
                                          existingRemoteUrl!,
                                          true,
                                          () => setDialogState(() {
                                            existingRemoteUrl = null;
                                          }),
                                        ),
                                      ),
                                    ...selectedFiles.map((file) {
                                      return Padding(
                                        padding: const EdgeInsets.only(
                                          right: 8.0,
                                        ),
                                        child: _buildImageThumbnail(
                                          file,
                                          false,
                                          () => setDialogState(() {
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
                                final pickedFiles =
                                    await picker.pickMultiImage();
                                if (pickedFiles.isNotEmpty) {
                                  setDialogState(() {
                                    selectedFiles.addAll(pickedFiles);
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
  List<Widget> _buildCompactImageRow(
      BuildContext context, List<Object> images, int qty) {
    // Máximo 3 elementos visibles (2 fotos + 1 indicador, o 3 fotos)
    const int maxVisible = 3;
    final int totalCount = images.length;
    final List<Widget> widgets = [];

    for (int i = 0; i < totalCount; i++) {
      if (widgets.length >= maxVisible) break;

      final isLastSlot = widgets.length == maxVisible - 1 && totalCount > maxVisible;
      final imageSource = images[i];

      widgets.add(
        GestureDetector(
          onTap: () => _showImagePreview(context, imageSource),
          child: SizedBox(
            width: 40,
            height: 40,
            child: Stack(
              fit: StackFit.expand,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: _buildSafeImageWidget(imageSource, 40, 40),
                ),
                if (i == 0)
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.primary,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        'x$qty',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onPrimary,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                if (isLastSlot)
                  Positioned.fill(
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.5),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        '+${totalCount - 2}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      );
    }
    return widgets;
  }

  // --- SMART MERGE LOGIC (Centralized) ---
  // Returns TRUE if merged, FALSE if added as new (caller might not care, but useful)
  // This modifies 'targetList' in place.
  bool _smartMergeItem(List<OrderItem> targetList, OrderItem newItem) {
    int existingIndex = targetList.indexWhere((item) {
      // 1. Core Identity (Name & Variant)
      if (item.name != newItem.name) { return false; }
      if (item.customizationJson?['variant_id'] !=
          newItem.customizationJson?['variant_id']) { return false; }

      // 2. Adjustments & Price (Must match exactly to merge)
      // Check if Unit Price is effectively the same
      double itemUnit = item.qty > 0 ? item.basePrice / item.qty : 0;
      double newUnit = newItem.qty > 0 ? newItem.basePrice / newItem.qty : 0;
      if ((itemUnit - newUnit).abs() > 0.01) { return false; }

      if (item.adjustments != newItem.adjustments) { return false; }

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

      if (!listEquals(c1['selected_fillings'], c2['selected_fillings'])) {
        return false;
      }
      if (!listEquals(
          c1['selected_extra_fillings'], c2['selected_extra_fillings'])) {
        return false;
      }
      if (!listEquals(c1['selected_extras_kg'], c2['selected_extras_kg'])) {
        return false;
      }
      if (!listEquals(c1['selected_extras_unit'], c2['selected_extras_unit'])) {
        return false;
      }
      if (!listEquals(
          c1['selected_mesa_dulce_items'], c2['selected_mesa_dulce_items'])) {
        return false;
      }

      // is_half_dozen check (FIX: Safe boolean compare)
      if ((c1['is_half_dozen'] ?? false) != (c2['is_half_dozen'] ?? false)) {
        return false;
      }

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

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
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
              padding: const EdgeInsets.symmetric(vertical: 24.0),
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

                final bool isSmallCake =
                    item.name == miniCakeName || item.name == microCakeName;

                final double weight =
                    (custom['weight_kg'] as num?)?.toDouble() ?? 1.0;
                final double extraMultiplier = isSmallCake ? 0.5 : weight;

                final List<dynamic> extraFillingsRaw =
                    custom['selected_extra_fillings'] ?? [];
                final List<dynamic> extrasKgRaw = custom['selected_extras_kg'] ?? [];
                final List<dynamic> extrasUnitRaw =
                    custom['selected_extras_unit'] ?? [];

                final double extraFillingsPrice = extraFillingsRaw.fold(0.0, (
                  sum,
                  data,
                ) {
                  final price = (data is Map
                          ? (data['price'] as num?)?.toDouble()
                          : null) ??
                      0.0;
                  return sum + (price * extraMultiplier);
                });
                final double extrasKgPrice = extrasKgRaw.fold(0.0, (sum, data) {
                  final price = (data is Map
                          ? (data['price'] as num?)?.toDouble()
                          : null) ??
                      0.0;
                  return sum + (price * extraMultiplier);
                });
                final double extrasUnitPrice = extrasUnitRaw.fold(0.0, (sum, data) {
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

                final double costoExtrasTotal =
                    extraFillingsPrice + extrasKgPrice + extrasUnitPrice;
                final double subItemsCost =
                    (custom['calculated_sub_items_cost'] as num?)?.toDouble() ?? 0.0;
                final double totalCostoExtrasYSubItems =
                    costoExtrasTotal + subItemsCost;

                if (custom['selected_base_cake'] != null) {
                  parts.add('Base: ${custom['selected_base_cake']}');
                }
                if (custom['weight_kg'] != null) {
                  parts.add('Peso: ${custom['weight_kg']} kg');
                }
                if (custom['selected_fillings'] != null) {
                  parts.add(
                      'Rellenos: ${(custom['selected_fillings'] as List).join(', ')}');
                }
                if (extraFillingsRaw.isNotEmpty) {
                  final names = extraFillingsRaw.map((e) => e['name']).join(', ');
                  parts.add('Rellenos Extra: $names');
                }
                if (extrasKgRaw.isNotEmpty || extrasUnitRaw.isNotEmpty) {
                  final kgNames = extrasKgRaw.map((e) => e['name']);
                  final unitNames =
                      extrasUnitRaw.map((e) => "${e['quantity']}x ${e['name']}");
                  parts.add('Extras: ${[...kgNames, ...unitNames].join(', ')}');
                }
                if (totalCostoExtrasYSubItems > 0) {
                  parts.add(
                    'Costo Extras: +${_currencyFormat.format(totalCostoExtrasYSubItems)}',
                  );
                }
              } else if (category == ProductCategory.mesaDulce) {
                final List<dynamic> selectedItems =
                    custom['selected_mesa_dulce_items'] ?? [];
                for (var sel in selectedItems) {
                  final qty = sel['quantity'] ?? 1;
                  final name = sel['name'];
                  final variantName = sel['variant_name'];
                  if (variantName != null && variantName.toString().isNotEmpty) {
                    parts.add('${qty}x $name ($variantName)');
                  } else {
                    parts.add('${qty}x $name');
                  }
                }
              }

              if (custom['item_notes'] != null &&
                  custom['item_notes'].toString().isNotEmpty) {
                parts.add('Notas: ${custom['item_notes']}');
              }

              if (custom['manual_adjustment_value'] != null &&
                  custom['manual_adjustment_value'] != 0) {
                final adj = (custom['manual_adjustment_value'] as num).toDouble();
                parts.add('Ajuste: ${_currencyFormat.format(adj)}');
              }

              final details = parts.join(' | ');
              // Si tiene archivos locales, los mostramos directamente.
              // Si no, usamos las URLs remotas guardadas.
              final allImages = <Object>[];
              if (item.localFile != null) {
                if (item.localFile is List) {
                  final locals = (item.localFile as List).where((f) => f != null).toList();
                  allImages.addAll(locals.cast<Object>());
                } else {
                  allImages.add(item.localFile!);
                }
              } else {
                final imageUrls =
                    (custom['photo_urls'] as List?)?.cast<String>() ?? [];
                allImages.addAll(imageUrls);
              }

              return Card(
                elevation: 0,
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                margin: const EdgeInsets.only(bottom: 8.0),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () => _editItemDialogRouter(index),
                  child: Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (allImages.isEmpty)
                          Container(
                            width: 24,
                            height: 24,
                            decoration: BoxDecoration(
                              color: Theme.of(context).colorScheme.primary,
                              shape: BoxShape.circle,
                            ),
                            child: Center(
                              child: Text(
                                '${item.qty}',
                                style: TextStyle(
                                  color: Theme.of(context).colorScheme.onPrimary,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          )
                        else
                          ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 148),
                            child: Wrap(
                              spacing: 4,
                              runSpacing: 4,
                              children: _buildCompactImageRow(context, allImages, item.qty),
                            ),
                          ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                item.name,
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                              if (details.isNotEmpty)
                                Padding(
                                  padding: const EdgeInsets.only(top: 4.0),
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
                                  padding: const EdgeInsets.only(top: 4.0),
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
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
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
                              onPressed: () {
                                WidgetsBinding.instance.addPostFrameCallback((_) {
                                  _updateItemsAndRecalculate(
                                    () => _items.removeAt(index),
                                  );
                                });
                              },
                              tooltip: 'Eliminar item',
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
      ],
    );
  }
}
