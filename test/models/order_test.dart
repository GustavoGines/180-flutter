import 'package:flutter_test/flutter_test.dart';
import 'package:pasteleria_180_flutter/core/models/order.dart';
import 'package:pasteleria_180_flutter/core/models/order_item.dart';
import 'package:pasteleria_180_flutter/core/enums/order_status.dart';

void main() {
  group('Order.fromJson', () {
    Map<String, dynamic> baseJson() => {
          'id': 42,
          'client_id': 7,
          'event_date': '2024-12-25',
          'start_time': '14:00',
          'end_time': '17:00',
          'status': 'confirmed',
          'is_paid': false,
          'items': [],
        };

    test('parsea un pedido completo correctamente', () {
      final order = Order.fromJson(baseJson());

      expect(order.id, 42);
      expect(order.clientId, 7);
      expect(order.status, OrderStatus.confirmed);
      expect(order.isPaid, false);
      expect(order.eventDate, DateTime(2024, 12, 25));
    });

    test('event_date nulo no lanza excepción y usa fecha cercana a now', () {
      final json = baseJson()..remove('event_date');
      expect(() => Order.fromJson(json), returnsNormally);
    });

    test('is_paid: 1 (int) → isPaid == true', () {
      final order = Order.fromJson(baseJson()..['is_paid'] = 1);
      expect(order.isPaid, true);
    });

    test('is_paid: "1" (string) → isPaid == true', () {
      final order = Order.fromJson(baseJson()..['is_paid'] = '1');
      expect(order.isPaid, true);
    });

    test('is_paid: true (bool) → isPaid == true', () {
      final order = Order.fromJson(baseJson()..['is_paid'] = true);
      expect(order.isPaid, true);
    });

    test('is_paid: "true" (string) → isPaid == true', () {
      final order = Order.fromJson(baseJson()..['is_paid'] = 'true');
      expect(order.isPaid, true);
    });

    test('is_paid: false → isPaid == false', () {
      final order = Order.fromJson(baseJson()..['is_paid'] = false);
      expect(order.isPaid, false);
    });

    test('status desconocido → fallback a OrderStatus.pending', () {
      final order = Order.fromJson(baseJson()..['status'] = 'flying_saucer');
      expect(order.status, OrderStatus.pending);
    });

    test('status "canceled" → OrderStatus.canceled', () {
      final order = Order.fromJson(baseJson()..['status'] = 'canceled');
      expect(order.status, OrderStatus.canceled);
    });

    test('items malformados se descartan sin tirar excepción', () {
      final json = baseJson()
        ..['items'] = [
          {'id': 1, 'name': 'Torta', 'qty': 1, 'base_price': 5000},
          'esto_no_es_un_mapa', // item malformado
        ];
      final order = Order.fromJson(json);
      // Solo debe parsear el item válido
      expect(order.items.length, 1);
      expect(order.items.first, isA<OrderItem>());
    });

    test('total y deposit se parsean desde strings numéricos', () {
      final json = baseJson()
        ..['total'] = '15000.50'
        ..['deposit'] = '5000.00';
      final order = Order.fromJson(json);
      expect(order.total, 15000.50);
      expect(order.deposit, 5000.00);
    });
  });
}
