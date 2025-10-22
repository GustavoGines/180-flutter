import '../json_utils.dart';

class OrderItem {
  final String name;
  final int qty;
  final double unitPrice;
  final Map<String, dynamic>? customizationJson;

  OrderItem({
    required this.name,
    required this.qty,
    required this.unitPrice,
    this.customizationJson,
  });

  factory OrderItem.fromJson(Map<String, dynamic> j) => OrderItem(
    name: j['name'] ?? '',
    qty: toInt(j['qty']),
    unitPrice: toNum(j['unit_price']).toDouble(),
    customizationJson: j['customization_json'] as Map<String, dynamic>?,
  );

  Map<String, dynamic> toJson() => {
    'name': name,
    'qty': qty,
    'unit_price': unitPrice,
    'customization_json': customizationJson,
  };
}
