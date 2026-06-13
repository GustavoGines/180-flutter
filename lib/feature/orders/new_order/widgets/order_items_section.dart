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


import '../new_order_controller.dart';


import 'dialogs/add_box_dialog.dart';
import 'dialogs/add_cake_dialog.dart';
import 'dialogs/add_mesa_dulce_dialog.dart';

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
  final CatalogResponse? catalog;

  const OrderItemsSection({
    super.key,
    this.catalog,
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

  // Referencias mutables para que la lógica existente funcione sin reescribir todo
  late List<OrderItem> _itemsMutableRef;
  late Map<String, XFile> _filesMutableRef;

  List<OrderItem> get _items => _itemsMutableRef;

  List<Product> get boxProducts => widget.catalog?.products.where((p) => p.category == ProductCategory.box).toList() ?? [];
  List<Product> get cakeProducts => widget.catalog?.products.where((p) => p.category == ProductCategory.torta).toList() ?? [];
  List<Product> get mesaDulceProducts => widget.catalog?.products.where((p) => p.category == ProductCategory.mesaDulce).toList() ?? [];
  
  List<Filling> get allFillings => widget.catalog?.fillings ?? [];
  List<Filling> get freeFillings => allFillings.where((f) => f.isFree).toList();
  List<Filling> get extraCostFillings => allFillings.where((f) => !f.isFree).toList();
  
  List<Extra> get cakeExtras => widget.catalog?.extras ?? [];

  void _updateItemsAndRecalculate(VoidCallback updateLogic) {
    // Tomamos la copia actual del estado, aplicamos mutaciones y lo enviamos al controller
    _itemsMutableRef = List<OrderItem>.from(ref.read(newOrderControllerProvider).items);
    
    // Conservamos las fotos locales agregadas en el diálogo y sumamos las del controller
    final currentControllerFiles = ref.read(newOrderControllerProvider).filesToUpload;
    final mergedFiles = Map<String, XFile>.from(currentControllerFiles);
    mergedFiles.addAll(_filesMutableRef);
    _filesMutableRef = mergedFiles;
    
    updateLogic();
    
    ref.read(newOrderControllerProvider.notifier).updateItems(_itemsMutableRef);
    ref.read(newOrderControllerProvider.notifier).updateFilesToUpload(_filesMutableRef);
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
    showDialog(
      context: context,
      builder: (context) => AddBoxDialog(
        catalog: widget.catalog,
        existingItem: existingItem,
        itemIndex: itemIndex,
        filesToUpload: _filesMutableRef,
        onFileAdded: (placeholderId, file) {
          _filesMutableRef[placeholderId] = file;
        },
        onSaveEditing: (newItem) {
          _updateItemsAndRecalculate(() {
            _items[itemIndex!] = newItem;
          });
        },
        onAddPending: (newItem) {
          _updateItemsAndRecalculate(() {
            _smartMergeItem(_items, newItem);
          });
        },
        buildImageThumbnail: _buildImageThumbnail,
        buildCompactImageRow: _buildCompactImageRow,
      ),
    );
  }

  void _addCakeDialog({OrderItem? existingItem, int? itemIndex}) {
    showDialog(
      context: context,
      builder: (context) => AddCakeDialog(
        catalog: widget.catalog,
        existingItem: existingItem,
        itemIndex: itemIndex,
        filesToUpload: _filesMutableRef,
        onFileAdded: (placeholderId, file) {
          _filesMutableRef[placeholderId] = file;
        },
        onSaveEditing: (newItem) {
          _updateItemsAndRecalculate(() {
            _items[itemIndex!] = newItem;
          });
        },
        onAddPending: (newItem) {
          _updateItemsAndRecalculate(() {
            _smartMergeItem(_items, newItem);
          });
        },
        buildImageThumbnail: _buildImageThumbnail,
        buildCompactImageRow: _buildCompactImageRow,
      ),
    );
  }

  void _addMesaDulceDialog({OrderItem? existingItem, int? itemIndex}) {
    showDialog(
      context: context,
      builder: (context) => AddMesaDulceDialog(
        catalog: widget.catalog,
        existingItem: existingItem,
        itemIndex: itemIndex,
        filesToUpload: _filesMutableRef,
        onFileAdded: (placeholderId, file) {
          _filesMutableRef[placeholderId] = file;
        },
        onSaveEditing: (newItem) {
          _updateItemsAndRecalculate(() {
            _items[itemIndex!] = newItem;
          });
        },
        onAddPending: (pendingItems) {
          _updateItemsAndRecalculate(() {
            for (var newItem in pendingItems) {
              _smartMergeItem(_items, newItem);
            }
          });
        },
        buildImageThumbnail: _buildImageThumbnail,
        buildCompactImageRow: _buildCompactImageRow,
      ),
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
      BuildContext context, List<dynamic> images, double qty) {
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
        basePrice: existing.basePrice,
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
    _itemsMutableRef = List<OrderItem>.from(ref.watch(newOrderControllerProvider).items);
    _filesMutableRef = Map<String, XFile>.from(ref.watch(newOrderControllerProvider).filesToUpload);
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
                                item.finalLinePrice,
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
