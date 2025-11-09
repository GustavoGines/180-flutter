// Define estructuras de datos para el catálogo de productos y precios.
// Basado en la lista de precios de 10/2025.

// Categorías principales
enum ProductCategory { torta, mesaDulce, box } // Añadido Box

// Unidades comunes
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

// --- RELLENOS ---
class Filling {
  final String name;
  final double extraCostPerKg; // 0.0 si es gratuito

  const Filling({required this.name, this.extraCostPerKg = 0.0});

  // Sobrescribimos == y hashCode para que funcionen correctamente en colecciones (Set, Map, búsquedas en List)
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Filling &&
          runtimeType == other.runtimeType &&
          name == other.name;

  @override
  int get hashCode => name.hashCode;

  // Cómo se mostrará el relleno en la UI (ej. Dropdown, Checkbox)
  @override
  String toString() =>
      name +
      (extraCostPerKg > 0
          ? ' (+\$${extraCostPerKg.toStringAsFixed(0)}/kg)'
          : ' (Gratis)');
}

const List<Filling> freeFillings = [
  Filling(name: 'Dulce de leche'),
  Filling(name: 'Dulce de leche con merenguitos'),
  Filling(name: 'Crema Chantilly'),
  Filling(name: 'Crema Cookie'),
  Filling(name: 'Crema Moka, con café'),
];

const List<Filling> extraCostFillings = [
  Filling(name: 'Mouse de chocolate', extraCostPerKg: 2000.0),
  Filling(name: 'Mouse de frutilla', extraCostPerKg: 2000.0),
];

// Lista combinada para facilitar la selección
final List<Filling> allFillings = [...freeFillings, ...extraCostFillings];

// --- EXTRAS PARA TORTAS ---
class CakeExtra {
  final String name;
  final double costPerKg;
  final bool
  isPerUnit; // True si el costo es por unidad (ej. alfajor), False si es por kg (ej. nueces)
  final double costPerUnit; // Costo si isPerUnit es true

  const CakeExtra({
    required this.name,
    this.costPerKg = 0.0,
    this.isPerUnit = false,
    this.costPerUnit = 0.0,
  });

  // Sobrescribimos == y hashCode
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CakeExtra &&
          runtimeType == other.runtimeType &&
          name == other.name;

  @override
  int get hashCode => name.hashCode;

  // Cómo se mostrará el extra en la UI
  @override
  String toString() {
    if (isPerUnit) {
      return '$name (+\$${costPerUnit.toStringAsFixed(0)} c/u)';
    } else {
      return '$name (+\$${costPerKg.toStringAsFixed(0)}/kg)';
    }
  }
}

const List<CakeExtra> cakeExtras = [
  CakeExtra(name: 'Nueces', costPerKg: 2000.0),
  CakeExtra(name: 'Oreos', costPerKg: 1000.0),
  CakeExtra(name: 'Chips de chocolate', costPerKg: 1000.0),
  CakeExtra(
    name: 'Cerezas',
    costPerKg: 1500.0,
  ), // Considerar disponibilidad/precio variable
  CakeExtra(name: 'Mani Tostado', costPerKg: 1000.0),
  // 🍫 NUEVO: BON O BON (Extra por Unidad)
  CakeExtra(
    name: 'Bon o Bon', // Nombre del extra
    isPerUnit: true, // Se cobra por unidad
    costPerUnit: 600.0, // Precio por unidad: $600
  ),
  CakeExtra(
    name: 'Alfajor Tatín triple (blanco)',
    isPerUnit: true,
    costPerUnit: 1000.0,
  ),
  CakeExtra(
    name: 'Alfajor Tatín triple (negro)',
    isPerUnit: true,
    costPerUnit: 1000.0,
  ),
  CakeExtra(name: 'Turrón Arcor', isPerUnit: true, costPerUnit: 500.0),
  CakeExtra(name: 'Obleas Opera', isPerUnit: true, costPerUnit: 1000.0),
  // Añadir aquí extras como "Lámina Comestible" o "Papel Fotográfico" si tienen costo base
  CakeExtra(
    name: 'Lámina Comestible (aprox)',
    costPerUnit: 2500.0,
    isPerUnit: true,
  ), // Ejemplo
  CakeExtra(
    name: 'Papel Fotográfico (aprox)',
    costPerUnit: 1500.0,
    isPerUnit: true,
  ), // Ejemplo
];

// --- DEFINICIÓN GENERAL DE PRODUCTO ---
class Product {
  final String name;
  final ProductCategory category;
  // La 'unit' define cómo se vende/cobra principalmente (kg, docena, etc.)
  final ProductUnit unit;
  final double price; // Precio base (por kg, por docena, por unidad base, etc.)
  // Para productos con múltiples tamaños/precios (ej. Tartas)
  final Map<ProductUnit, double>? pricesBySize;
  // Para productos que se venden por docena pero también media docena
  final bool allowHalfDozen;
  final double? halfDozenPrice; // Precio si allowHalfDozen es true
  // ⬅️ NUEVO: Ajuste multiplicador por kg para tortas (ej: para forzar precio por encima de base)
  final double multiplierAdjustmentPerKg;

  const Product({
    required this.name,
    required this.category,
    required this.unit,
    required this.price,
    this.pricesBySize,
    this.allowHalfDozen = false,
    this.halfDozenPrice,
    this.multiplierAdjustmentPerKg = 0.0,
  });
}

// --- PRODUCTOS ESPECÍFICOS ---

// Boxs
const List<Product> boxProducts = [
  // ⬅️ NUEVO: Opción de Box Personalizado
  Product(
    name: 'BOX DULCE Personalizado (Armar)',
    category: ProductCategory.box,
    unit: ProductUnit.unit,
    price: 0.0, // El precio se calcula en base a los ítems seleccionados
  ),
  // Box Dulce con Tartas Frutales (Imagen 1)
  Product(
    name: 'BOX DULCE: Tartas Frutales (Solo Duraznos)',
    category: ProductCategory.box,
    unit: ProductUnit.unit,
    price: 13350.0,
  ),
  Product(
    name: 'BOX DULCE: Tartas Frutales (Frutillas y Duraznos)',
    category: ProductCategory.box,
    unit: ProductUnit.unit,
    price: 16350.0,
  ),
  // Box Romántico (Imagen 3)
  Product(
    name: 'BOX DULCE: Romántico (Torta Corazones/Te Amo)',
    category: ProductCategory.box,
    unit: ProductUnit.unit,
    price: 18700.0,
  ),
  // Box Temático/Drip Cake Azul (Imagen 4)
  Product(
    name: 'BOX DULCE: Drip Cake Temático (Choc. Azules)',
    category: ProductCategory.box,
    unit: ProductUnit.unit,
    price: 19000.0,
  ),
  // Box Drip Cake Oreo (Imagen 2) y Cumpleañero (Imagen 5)
  // Ambos comparten el mismo precio base de $21800, se listan separados por su contenido.
  Product(
    name: 'BOX DULCE: Drip Cake (Oreo/Rosado) + Jugo',
    category: ProductCategory.box,
    unit: ProductUnit.unit,
    price: 21800.0,
  ),
  Product(
    name: 'BOX DULCE: Cumpleañero (Torta/Taza)',
    category: ProductCategory.box,
    unit: ProductUnit.unit,
    price: 21800.0,
  ),
];

// --- Nueva lista de Tortas de Tamaño Pequeño/Base para Boxes ---
const List<Product> smallCakeProducts = [
  Product(
    name: 'Micro Torta (Base)',
    category: ProductCategory.torta,
    unit: ProductUnit.kg,
    price: 4500.0,
    multiplierAdjustmentPerKg: 0.0,
  ),
  Product(
    name: 'Mini Torta Personalizada (Base)',
    category: ProductCategory.torta,
    unit: ProductUnit.kg,
    price: 8500.0,
    multiplierAdjustmentPerKg: 0.0,
  ),
  // Nota: Una torta de 1kg tiene un precio por kg mayor, que se puede seleccionar aquí como opción base si es necesario, pero manteniendo 1kg fijo.
  Product(
    name: 'Torta Base (1 kg)',
    category: ProductCategory.torta,
    unit: ProductUnit.kg,
    price: 15500.0,
    multiplierAdjustmentPerKg: 0.0,
  ),
];

// Tortas (Precio por KG base)
const List<Product> cakeProducts = [
  // ⬅️ NUEVO: Micro Torta (Menor precio base, menor complejidad)
  Product(
    name: 'Micro Torta (Base)',
    category: ProductCategory.torta,
    unit: ProductUnit.kg,
    price: 4500.0,
    multiplierAdjustmentPerKg: 0.0,
  ),
  // ⬅️ CAMBIO: La mini torta ahora es un tipo de torta con precio base
  Product(
    name: 'Mini Torta Personalizada (Base)',
    category: ProductCategory.torta,
    unit: ProductUnit.kg,
    price: 8500.0, // ⬅️ Precio Base de 8500
    multiplierAdjustmentPerKg: 0.0, // No aplica
  ),
  Product(
    name: 'Torta Decorada con Crema Chantilly',
    category: ProductCategory.torta,
    unit: ProductUnit.kg,
    price: 15500.0,
  ),
  Product(
    name: 'Torta con Galletitas/Chocolates/Cerezas',
    category: ProductCategory.torta,
    unit: ProductUnit.kg,
    price: 18500.0,
  ), // Frutillas consultar
  Product(
    name: 'Torta con Ganache (Negro/Blanco)',
    category: ProductCategory.torta,
    unit: ProductUnit.kg,
    price: 19000.0,
  ),
  Product(
    name: 'Torta Cubierta de Fondant',
    category: ProductCategory.torta,
    unit: ProductUnit.kg,
    price: 20000.0,
  ),
  // Se podría añadir un tipo "Torta Modelo Específico" con precio 0 y que se ingrese manualmente? O manejarlo con notas y ajuste manual del precio total del item.
];

// Mesa Dulce
const List<Product> mesaDulceProducts = [
  // ⬅️ NUEVO: Bizcochuelos
  Product(
    name: 'Bizcochuelo Vainilla',
    category: ProductCategory.mesaDulce,
    unit: ProductUnit.unit,
    price: 0,
    pricesBySize: {
      ProductUnit.size20cm: 4000.0,
      ProductUnit.size24cm: 5800.0, // Calculado: 4000 * 1.44
    },
  ),
  Product(
    name: 'Bizcochuelo Chocolate',
    category: ProductCategory.mesaDulce,
    unit: ProductUnit.unit,
    price: 0,
    pricesBySize: {
      ProductUnit.size20cm: 4500.0,
      ProductUnit.size24cm: 6500.0, // Calculado: 4500 * 1.44
    },
  ),
  // Alfajores (Precios estimados para media docena)
  Product(
    name: 'Alfajores de Maicena Común',
    category: ProductCategory.mesaDulce,
    unit: ProductUnit.dozen,
    price: 6000.0,
    allowHalfDozen: true,
    halfDozenPrice: 3000.0,
  ),
  Product(
    name: 'Alfajores de Maicena de Colores',
    category: ProductCategory.mesaDulce,
    unit: ProductUnit.dozen,
    price: 7000.0,
    allowHalfDozen: true,
    halfDozenPrice: 3500.0,
  ),
  Product(
    name: 'Alfajores Bañados',
    category: ProductCategory.mesaDulce,
    unit: ProductUnit.dozen,
    price: 8000.0,
    allowHalfDozen: true,
    halfDozenPrice: 4000.0,
  ),
  // Brownies
  Product(
    name: 'Brownies 5x5cm',
    category: ProductCategory.mesaDulce,
    unit: ProductUnit.dozen,
    price: 14200.0,
    allowHalfDozen: true,
    halfDozenPrice: 7100.0,
  ),
  Product(
    name: 'Brownies 6x6cm',
    category: ProductCategory.mesaDulce,
    unit: ProductUnit.dozen,
    price: 20400.0,
    allowHalfDozen: true,
    halfDozenPrice: 10200.0,
  ),
  Product(
    name: 'Brownie Redondo',
    category: ProductCategory.mesaDulce,
    unit: ProductUnit.unit,
    price: 0,
    pricesBySize: {
      // Precio base 0, precios reales en el mapa
      ProductUnit.size18cm: 12000.0, ProductUnit.size24cm: 21200.0,
    },
  ),
  // Postres en Vasitos
  Product(
    name: 'Postres en Vasitos (Surtidos)',
    category: ProductCategory.mesaDulce,
    unit: ProductUnit.dozen,
    price: 17000.0,
    allowHalfDozen: true,
    halfDozenPrice: 8500.0,
  ), // Asume un precio único, ajustar si varía por sabor
  // Cupcakes
  Product(
    name: 'Cupcakes Personalizados',
    category: ProductCategory.mesaDulce,
    unit: ProductUnit.dozen,
    price: 12000.0,
    allowHalfDozen: true,
    halfDozenPrice: 6000.0,
  ),
  // Chocooreos
  Product(
    name: 'Chocooreos',
    category: ProductCategory.mesaDulce,
    unit: ProductUnit.dozen,
    price: 12000.0,
    allowHalfDozen: true,
    halfDozenPrice: 6000.0,
  ),
  // Galletitas Decoradas
  Product(
    name: 'Galletitas Decoradas Fondant',
    category: ProductCategory.mesaDulce,
    unit: ProductUnit.dozen,
    price: 18000.0,
    allowHalfDozen: true,
    halfDozenPrice: 9000.0,
  ), // Puede variar según diseño
  // Tartas Durazno
  Product(
    name: 'Tarta con Durazno',
    category: ProductCategory.mesaDulce,
    unit: ProductUnit.unit,
    price: 0,
    pricesBySize: {
      ProductUnit.size12cm: 3500.0,
      ProductUnit.size18cm: 8000.0,
      ProductUnit.size24cm: 14000.0,
    },
  ),
  // Tartas Durazno y Frutillas
  Product(
    name: 'Tarta con Durazno y Frutillas',
    category: ProductCategory.mesaDulce,
    unit: ProductUnit.unit,
    price: 0,
    pricesBySize: {
      ProductUnit.size12cm: 4500.0,
      ProductUnit.size18cm: 10000.0,
      ProductUnit.size24cm: 18000.0,
    },
  ),
  // Tartas Frutillas
  Product(
    name: 'Tarta con Frutillas',
    category: ProductCategory.mesaDulce,
    unit: ProductUnit.unit,
    price: 0,
    pricesBySize: {
      // Consultar disponibilidad
      ProductUnit.size12cm: 6000.0,
      ProductUnit.size18cm: 13500.0,
      ProductUnit.size24cm: 24000.0,
    },
  ),
  // Tartas Toffi
  Product(
    name: 'Tarta Toffi',
    category: ProductCategory.mesaDulce,
    unit: ProductUnit.unit,
    price: 0,
    pricesBySize: {
      ProductUnit.size12cm: 3500.0,
      ProductUnit.size18cm: 8000.0,
      ProductUnit.size24cm: 14000.0,
    },
  ),
  // Pastafrola
  Product(
    name: 'Pastafrola',
    category: ProductCategory.mesaDulce,
    unit: ProductUnit.unit,
    price: 0,
    pricesBySize: {
      ProductUnit.size12cm: 2500.0,
      ProductUnit.size18cm: 5600.0,
      ProductUnit.size24cm: 10000.0,
    },
  ),
  Product(
    name: 'Frolitas (10cm)',
    category: ProductCategory.mesaDulce,
    unit: ProductUnit.dozen,
    price: 20400.0,
    allowHalfDozen: true,
    halfDozenPrice: 10200.0,
  ),
  // ⬅️ NUEVO: Bandejas para Box Personalizado
  Product(
    name: 'Bandeja 25x25 cm',
    category: ProductCategory.mesaDulce,
    unit: ProductUnit.unit,
    price: 1800.0,
  ),
  Product(
    name: 'Bandeja 30x30 cm',
    category: ProductCategory.mesaDulce,
    unit: ProductUnit.unit,
    price: 2000.0,
  ),
];

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

// Lista combinada para facilitar la búsqueda inicial o selección general si fuera necesario
final List<Product> allProducts = [
  ...boxProducts,
  ...cakeProducts,
  ...mesaDulceProducts,
];
