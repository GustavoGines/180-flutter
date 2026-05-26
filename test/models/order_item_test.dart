import 'package:flutter_test/flutter_test.dart';
import 'package:pasteleria_180_flutter/core/models/order_item.dart';

void main() {
  group('OrderItem.finalUnitPrice', () {
    test('es la suma de basePrice + adjustments', () {
      final item = OrderItem(
        name: 'Torta de cumpleaños',
        qty: 1,
        basePrice: 10000,
        adjustments: 1500,
      );
      expect(item.finalUnitPrice, 11500);
    });

    test('sin ajustes, finalUnitPrice == basePrice', () {
      final item = OrderItem(
        name: 'Box dulce',
        qty: 2,
        basePrice: 5000,
      );
      expect(item.finalUnitPrice, 5000);
    });

    test('con ajuste negativo (descuento), finalUnitPrice < basePrice', () {
      final item = OrderItem(
        name: 'Mesa dulce',
        qty: 1,
        basePrice: 20000,
        adjustments: -2000,
      );
      expect(item.finalUnitPrice, 18000);
    });
  });

  group('OrderItem.toJson', () {
    test('incluye calculated_final_unit_price dentro de customization_json', () {
      final item = OrderItem(
        name: 'Torta',
        qty: 1,
        basePrice: 8000,
        adjustments: 500,
      );
      final json = item.toJson();

      expect(json['base_price'], 8000);
      expect(json['adjustments'], 500);
      expect(json['customization_json']['calculated_final_unit_price'], 8500);
    });

    test('no incluye id si el item es nuevo (id == null)', () {
      final item = OrderItem(name: 'Nuevo', qty: 1, basePrice: 1000);
      expect(item.toJson().containsKey('id'), false);
    });

    test('incluye id si el item ya existe', () {
      final item = OrderItem(id: 99, name: 'Existente', qty: 1, basePrice: 1000);
      expect(item.toJson()['id'], 99);
    });

    test('preserva customizationJson previo y agrega calculated_final_unit_price', () {
      final item = OrderItem(
        name: 'Torta',
        qty: 1,
        basePrice: 5000,
        customizationJson: {'sabor': 'chocolate', 'relleno': 'dulce de leche'},
      );
      final json = item.toJson();
      expect(json['customization_json']['sabor'], 'chocolate');
      expect(json['customization_json']['calculated_final_unit_price'], 5000);
    });
  });

  group('OrderItem.fromJson', () {
    test('usa base_price si está presente', () {
      final item = OrderItem.fromJson({
        'name': 'Torta',
        'qty': 2,
        'base_price': 9000,
        'adjustments': 1000,
      });
      expect(item.basePrice, 9000);
      expect(item.adjustments, 1000);
      expect(item.finalUnitPrice, 10000);
    });

    test('fallback a unit_price si base_price no existe', () {
      final item = OrderItem.fromJson({
        'name': 'Box',
        'qty': 1,
        'unit_price': 7500,
      });
      expect(item.basePrice, 7500);
      expect(item.adjustments, 0);
    });

    test('qty por defecto es 1 si falta en el JSON', () {
      final item = OrderItem.fromJson({
        'name': 'Item sin qty',
        'base_price': 1000,
      });
      expect(item.qty, 1);
    });
  });
}
