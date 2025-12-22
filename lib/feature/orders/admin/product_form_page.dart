import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/models/catalog.dart';
import '../catalog_repository.dart';

class ProductFormPage extends ConsumerStatefulWidget {
  final Product? productToEdit; // If null, creating new

  const ProductFormPage({super.key, this.productToEdit});

  @override
  ConsumerState<ProductFormPage> createState() => _ProductFormPageState();
}

class _ProductFormPageState extends ConsumerState<ProductFormPage> {
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _nameController;
  late TextEditingController _descriptionController;
  late TextEditingController _priceController;

  ProductCategory _selectedCategory = ProductCategory.torta;
  ProductUnit _selectedUnit = ProductUnit.unit;
  bool _allowHalfDozen = false;

  // Variants
  List<ProductVariant> _variants = [];

  @override
  void initState() {
    super.initState();
    final p = widget.productToEdit;
    _nameController = TextEditingController(text: p?.name ?? '');
    _descriptionController = TextEditingController(text: p?.description ?? '');
    _priceController = TextEditingController(
      text: p?.basePrice.toStringAsFixed(0) ?? '',
    );

    if (p != null) {
      _selectedCategory = p.category;
      _selectedUnit = p.unit; // FIXED: p.unit, not unitType
      _allowHalfDozen = p.allowHalfDozen;
      _variants = List.from(p.variants);
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _priceController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    final name = _nameController.text.trim();
    final description = _descriptionController.text.trim();
    final price = double.tryParse(_priceController.text.trim()) ?? 0;

    final data = {
      'name': name,
      'description': description,
      'base_price': price,
      'category': _selectedCategory.name, // Enum to string
      'unit_type': _selectedUnit.name,
      'allow_half_dozen': _allowHalfDozen,
      // Map variants to JSON
      'variants': _variants
          .map(
            (v) => {
              if (v.id != 0) 'id': v.id, // Only send ID if it's existing
              'variant_name': v.variantName,
              'price': v.price,
            },
          )
          .toList(),
    };

    try {
      if (widget.productToEdit == null) {
        await ref.read(catalogRepoProvider).createProduct(data);
        if (mounted)
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('Producto creado')));
      } else {
        await ref
            .read(catalogRepoProvider)
            .updateProduct(widget.productToEdit!.id, data);
        if (mounted)
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('Producto actualizado')));
      }
      if (mounted) {
        ref.invalidate(catalogProvider); // Refresh catalog
        context.pop();
      }
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final isUnitDozen = _selectedUnit == ProductUnit.dozen;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.productToEdit == null ? 'Nuevo Producto' : 'Editar Producto',
        ),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Nombre del Producto',
                border: OutlineInputBorder(),
              ),
              validator: (v) => v!.isEmpty ? 'Requerido' : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _priceController,
              decoration: const InputDecoration(
                labelText: 'Precio Base / Precio Lista',
                border: OutlineInputBorder(),
                prefixText: '\$ ',
              ),
              keyboardType: TextInputType.number,
              validator: (v) => v!.isEmpty ? 'Requerido' : null,
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<ProductCategory>(
              value: _selectedCategory,
              decoration: const InputDecoration(
                labelText: 'Categoría',
                border: OutlineInputBorder(),
              ),
              items: ProductCategory.values
                  .map(
                    (c) => DropdownMenuItem(
                      value: c,
                      child: Text(c.name.toUpperCase()),
                    ),
                  )
                  .toList(),
              onChanged: (v) => setState(() => _selectedCategory = v!),
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<ProductUnit>(
              value: _selectedUnit,
              decoration: const InputDecoration(
                labelText: 'Unidad',
                border: OutlineInputBorder(),
              ),
              items: ProductUnit.values
                  .map(
                    (u) => DropdownMenuItem(
                      value: u,
                      child: Text(u.name.toUpperCase()),
                    ),
                  )
                  .toList(),
              onChanged: (v) => setState(() => _selectedUnit = v!),
            ),

            if (isUnitDozen)
              SwitchListTile(
                title: const Text('Permitir Media Docena'),
                value: _allowHalfDozen,
                onChanged: (v) => setState(() => _allowHalfDozen = v),
              ),

            const SizedBox(height: 24),
            const Divider(),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Variantes / Tamaños',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                IconButton(
                  icon: const Icon(Icons.add_circle),
                  onPressed: _addVariant,
                ),
              ],
            ),
            if (_variants.isEmpty)
              const Text('Sin variantes (Usa precio base)'),

            ..._variants.asMap().entries.map((entry) {
              final idx = entry.key;
              final variant = entry.value;
              return Card(
                margin: const EdgeInsets.symmetric(vertical: 4),
                child: Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          initialValue: variant.variantName,
                          decoration: const InputDecoration(
                            labelText: 'Nombre Variante',
                          ),
                          onChanged: (v) => _variants[idx] = _variants[idx]
                              .copyWith(variantName: v),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextFormField(
                          initialValue: variant.price.toStringAsFixed(0),
                          decoration: const InputDecoration(
                            labelText: 'Precio',
                            prefixText: '\$',
                          ),
                          keyboardType: TextInputType.number,
                          onChanged: (v) => _variants[idx] = _variants[idx]
                              .copyWith(price: double.tryParse(v) ?? 0),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete, color: Colors.red),
                        onPressed: () =>
                            setState(() => _variants.removeAt(idx)),
                      ),
                    ],
                  ),
                ),
              );
            }),

            const SizedBox(height: 40),
            ElevatedButton(
              onPressed: _save,
              style: ElevatedButton.styleFrom(
                minimumSize: const Size.fromHeight(50),
              ),
              child: const Text('GUARDAR'),
            ),
          ],
        ),
      ),
    );
  }

  void _addVariant() {
    setState(() {
      // FIXED: Removed productId, ensure constructor call matches model
      _variants.add(ProductVariant(id: 0, variantName: '', price: 0));
    });
  }
}

// Extension to help with copyWith since it might not be in the model
extension ProductVariantExtension on ProductVariant {
  // FIXED: Removed productId
  ProductVariant copyWith({int? id, String? variantName, double? price}) {
    return ProductVariant(
      id: id ?? this.id,
      variantName: variantName ?? this.variantName,
      price: price ?? this.price,
    );
  }
}
