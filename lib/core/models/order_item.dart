import '../json_utils.dart';

class OrderItem {
  final int? id;
  final String name;
  final int qty;
  final double unitPrice;
  final Map<String, dynamic>? customizationJson;

  OrderItem({
    this.id, // El id es opcional, ya no está duplicado ni es requerido.
    required this.name,
    required this.qty,
    required this.unitPrice,
    this.customizationJson,
  });

  factory OrderItem.fromJson(Map<String, dynamic> j) => OrderItem(
    // Añadimos la lectura del id desde el JSON
    id: j['id'] != null ? toInt(j['id']) : null,
    name: j['name'] ?? '',
    qty: toInt(j['qty']),
    unitPrice: toNum(j['unit_price']).toDouble(),
    customizationJson: j['customization_json'] as Map<String, dynamic>?,
  );

  // La línea 'get id => null;' se ha eliminado.

  Map<String, dynamic> toJson() => {
    // Si el id existe (al editar), lo enviamos. Si no (al crear), no.
    if (id != null) 'id': id,
    'name': name,
    'qty': qty,
    'unit_price': unitPrice,
    'customization_json': customizationJson,
  };
}
