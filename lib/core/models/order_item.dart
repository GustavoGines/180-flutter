// lib/core/models/order_item.dart
import '../json_utils.dart'; // Asumo que tienes este archivo para toInt/toNum

class OrderItem {
  final int? id; // El id es opcional (para items nuevos vs. existentes)
  final String name;
  final int qty;
  // final double unitPrice; // <-- ELIMINADO del constructor y guardado directo

  // --- NUEVOS CAMPOS ---
  final double basePrice; // Precio base del producto antes de ajustes
  final double adjustments; // Suma de ajustes (+/-) sobre el precio base
  final String? customizationNotes; // Descripción opcional de los ajustes
  // --- FIN NUEVOS CAMPOS ---

  final Map<String, dynamic>? customizationJson;

  // --- CAMPO TRANSITORIO PARA CARTA / UI (No se envía en toJson explícitamente) ---
  final dynamic localFile; // Puede ser XFile (Flutter) o File (Dart IO)

  // Constructor actualizado
  OrderItem({
    this.id,
    required this.name,
    required this.qty,
    // required this.unitPrice, // <-- ELIMINADO del constructor y guardado directo
    required this.basePrice, // <-- Se requiere el precio base
    this.adjustments = 0.0, // <-- Ajuste opcional, default 0
    this.customizationNotes, // <-- Notas opcionales
    this.customizationJson,
    this.localFile,
  });

  // --- GETTER PARA PRECIO FINAL ---
  // Calcula el precio unitario final sumando base + ajustes
  double get finalUnitPrice => basePrice + adjustments;
  // --- FIN GETTER ---

  // Factory fromJson actualizado
  factory OrderItem.fromJson(Map<String, dynamic> j) {
    // Intenta leer 'base_price'. Si no existe, usa 'unit_price' como fallback.
    double base =
        (j['base_price'] != null ? toNum(j['base_price']) : null)?.toDouble() ??
        (j['unit_price'] != null ? toNum(j['unit_price']) : 0.0)
            .toDouble(); // Fallback final a 0.0

    // Si 'base_price' no existía pero 'unit_price' sí, asumimos que 'adjustments' es 0.
    // Si 'base_price' existía, leemos 'adjustments' o usamos 0.
    double adjust = (j['adjustments'] != null ? toNum(j['adjustments']) : 0.0)
        .toDouble();

    // Si unit_price era la única fuente y base_price no existía,
    // podría ser que el unit_price ya incluía ajustes. En ese caso,
    // podríamos querer poner adjust = 0 y base = unit_price.
    // Opcionalmente: si 'base_price' no existe y 'adjustments' tampoco,
    // pero 'unit_price' sí, podríamos inferir que unit_price es el final
    // y calcular adjustments (adjust = unit_price - base), pero esto es más complejo.
    // La lógica de arriba (base = unit_price, adjust = 0) es más simple si migras la API.

    return OrderItem(
      id: j['id'] != null ? toInt(j['id']) : null,
      name: j['name'] ?? 'Item Desconocido',
      qty: toInt(j['qty'] ?? 1), // Default qty a 1 si falta
      basePrice: base,
      adjustments: adjust,
      customizationNotes: j['customization_notes'] as String?,
      customizationJson: j['customization_json'] as Map<String, dynamic>?,
      // localFile no se recupera del JSON (es solo local)
    );
  }

  // toJson actualizado
  Map<String, dynamic> toJson() => {
    // Si el id existe (al editar), lo enviamos. Si no (al crear), no.
    if (id != null) 'id': id,
    'name': name,
    'qty': qty,
    // Decide qué enviar a tu API:
    // Opción 1: Enviar base y ajustes separados (recomendado si controlas la API)
    'base_price': basePrice,
    'adjustments': adjustments,
    // Opción 2: Enviar solo el precio final calculado (si la API solo espera 'unit_price')
    // 'unit_price': finalUnitPrice,
    'customization_notes': customizationNotes,
    'customization_json': {
      // Guarda detalles calculados DENTRO del JSON
      ...?customizationJson,
      // Es bueno guardar esto para referencia, pero no son campos principales
      'calculated_final_unit_price': finalUnitPrice,
    },
  };

  // --- MÉTODO COPYWITH ---
  OrderItem copyWith({
    int? id,
    String? name,
    int? qty,
    double? basePrice,
    double? adjustments,
    String? customizationNotes,
    Map<String, dynamic>? customizationJson,
    dynamic localFile,
    bool clearCustomizationNotes = false, // Flag para borrar notas
  }) {
    return OrderItem(
      id: id ?? this.id,
      name: name ?? this.name,
      qty: qty ?? this.qty,
      basePrice: basePrice ?? this.basePrice,
      adjustments: adjustments ?? this.adjustments,
      // Si clearCustomizationNotes es true, pone null, si no, usa el nuevo o el viejo
      customizationNotes: clearCustomizationNotes
          ? null
          : (customizationNotes ?? this.customizationNotes),
      customizationJson: customizationJson ?? this.customizationJson,
      localFile: localFile ?? this.localFile,
      // Nota: orderId no está aquí porque usualmente no cambia al copiar un item DENTRO de una orden
    );
  }

  // --- FIN COPYWITH ---
}
