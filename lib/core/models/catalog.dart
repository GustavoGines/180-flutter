// Defines structures for the product catalog.
// ignore_for_file: constant_identifier_names

enum ProductCategory { torta, mesaDulce, box }

enum ProductUnit {
  kg,
  dozen,
  halfDozen,
  unit,
  size12cm,
  size18cm,
  size20cm,
  size24cm,
}

class CatalogResponse {
  final List<Product> products;
  final List<Filling> fillings;
  final List<Extra> extras;

  CatalogResponse({
    required this.products,
    required this.fillings,
    required this.extras,
  });

  factory CatalogResponse.fromJson(Map<String, dynamic> json) {
    final data = json['data'] as Map<String, dynamic>;
    return CatalogResponse(
      products: (data['products'] as List)
          .map((e) => Product.fromJson(e))
          .toList(),
      fillings: (data['fillings'] as List)
          .map((e) => Filling.fromJson(e))
          .toList(),
      extras: (data['extras'] as List).map((e) => Extra.fromJson(e)).toList(),
    );
  }
}

class Product {
  final int id;
  final String name;
  final ProductCategory category;
  final String? description;
  final double basePrice; // Maps to 'price' in backend
  final ProductUnit unit;
  final bool allowHalfDozen;
  final double? halfDozenPrice;
  final double multiplierAdjustmentPerKg;
  final List<ProductVariant> variants;
  final Map<ProductUnit, double>? pricesBySize; // Computed from variants

  Product({
    required this.id,
    required this.name,
    required this.category,
    this.description,
    required this.basePrice,
    required this.unit,
    required this.allowHalfDozen,
    this.halfDozenPrice,
    required this.multiplierAdjustmentPerKg,
    required this.variants,
    this.pricesBySize,
  });

  factory Product.fromJson(Map<String, dynamic> json) {
    // Parse Category
    ProductCategory cat;
    switch (json['category']) {
      case 'torta':
        cat = ProductCategory.torta;
        break;
      case 'mesaDulce':
        cat = ProductCategory.mesaDulce;
        break;
      case 'box':
      default:
        cat = ProductCategory.box;
        break;
    }

    // Parse Unit
    ProductUnit parseUnit(String u) {
      if (u == 'size12cm') return ProductUnit.size12cm;
      // Fallback fuzzy match
      return ProductUnit.values.firstWhere(
        (e) => e.toString().split('.').last == u,
        orElse: () => ProductUnit.unit,
      );
    }

    final unit = parseUnit(json['unit_type']);

    // Parse Variants into pricesBySize map if applicable
    final variantsList = (json['variants'] as List? ?? [])
        .map((e) => ProductVariant.fromJson(e))
        .toList();
    if (json['variants'] != null && (json['variants'] as List).isNotEmpty) {
      print(
        'DEBUG: Product ${json['name']} has ${variantsList.length} variants.',
      );
    }

    Map<ProductUnit, double>? pricesMap;
    if (variantsList.isNotEmpty) {
      pricesMap = {};
      for (var v in variantsList) {
        // Asumiendo que variant_name coincide con el enum (ej: 'size20cm')
        final variantUnit = parseUnit(v.variantName);
        pricesMap[variantUnit] = v.price;
      }
    }

    return Product(
      id: json['id'],
      name: json['name'],
      category: cat,
      description: json['description'],
      basePrice: double.tryParse(json['base_price'].toString()) ?? 0.0,
      unit: unit,
      allowHalfDozen: json['allow_half_dozen'] ?? false,
      halfDozenPrice: json['half_dozen_price'] != null
          ? double.tryParse(json['half_dozen_price'].toString())
          : null,
      multiplierAdjustmentPerKg:
          double.tryParse(json['multiplier_adjustment_per_kg'].toString()) ??
          0.0,
      variants: variantsList,
      pricesBySize: pricesMap,
    );
  }

  // Compatibilidad con código viejo (get price -> basePrice)
  double get price => basePrice;
}

class ProductVariant {
  final int id;
  final String variantName;
  final double price;

  ProductVariant({
    required this.id,
    required this.variantName,
    required this.price,
  });

  factory ProductVariant.fromJson(Map<String, dynamic> json) {
    return ProductVariant(
      id: json['id'],
      variantName: json['variant_name'],
      price: double.tryParse(json['price'].toString()) ?? 0.0,
    );
  }

  String get formattedName {
    if (variantName.startsWith('size')) {
      return variantName.replaceAll('size', '');
    }
    return variantName;
  }
}

class Filling {
  final int id;
  final String name;
  final double pricePerKg; // maps to extraCostPerKg
  final bool isFree;

  Filling({
    required this.id,
    required this.name,
    required this.pricePerKg,
    required this.isFree,
  });

  factory Filling.fromJson(Map<String, dynamic> json) {
    return Filling(
      id: json['id'],
      name: json['name'],
      pricePerKg: double.tryParse(json['price_per_kg'].toString()) ?? 0.0,
      isFree: json['is_free'] ?? false,
    );
  }

  // Getter for compatibility
  double get extraCostPerKg => pricePerKg;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Filling && runtimeType == other.runtimeType && id == other.id; // Use ID for equality

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() =>
      name +
      (pricePerKg > 0
          ? ' (+\$${pricePerKg.toStringAsFixed(0)}/kg)'
          : ' (Gratis)');
}

class Extra {
  // mapped to CakeExtra usually
  final int id;
  final String name;
  final double price;
  final String priceType; // 'per_unit', 'per_kg'

  Extra({
    required this.id,
    required this.name,
    required this.price,
    required this.priceType,
  });

  factory Extra.fromJson(Map<String, dynamic> json) {
    return Extra(
      id: json['id'],
      name: json['name'],
      price: double.tryParse(json['price'].toString()) ?? 0.0,
      priceType: json['price_type'],
    );
  }

  // Compatibilidad
  double get costPerKg => priceType == 'per_kg' ? price : 0.0;
  double get costPerUnit => priceType == 'per_unit' ? price : 0.0;
  bool get isPerUnit => priceType == 'per_unit';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Extra && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() {
    if (isPerUnit) {
      return '$name (+\$${price.toStringAsFixed(0)} c/u)';
    } else {
      return '$name (+\$${price.toStringAsFixed(0)}/kg)';
    }
  }
}

// Adapters for CakeExtra compatibility if needed
typedef CakeExtra = Extra;

// Helper para obtener texto de unidad más descriptivo para la UI
String getUnitText(ProductUnit unit, {bool plural = false}) {
  switch (unit) {
    case ProductUnit.kg:
      return plural ? 'kgs' : 'kg';
    case ProductUnit.dozen:
      return plural ? 'docenas' : 'docena';
    case ProductUnit.halfDozen:
      return plural ? 'medias docenas' : 'media docena';
    case ProductUnit.unit:
      return plural ? 'unidades' : 'unidad';
    case ProductUnit.size12cm:
      return '12 cm';
    case ProductUnit.size18cm:
      return '18 cm';
    case ProductUnit.size20cm:
      return '20 cm';
    case ProductUnit.size24cm:
      return '24 cm';
  }
}

// Helper para obtener precio final de tarta/pastafrola/brownie redondo por tamaño
double? getPriceBySize(Product product, ProductUnit size) {
  // Asegurarse de que el producto realmente tenga precios por tamaño
  if (product.pricesBySize == null) return null;
  return product.pricesBySize![size];
}
