import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pasteleria_180_flutter/core/models/order.dart';
import 'package:pasteleria_180_flutter/core/enums/order_status.dart';
import 'package:pasteleria_180_flutter/feature/orders/home_page.dart';

/// Crea un Order de prueba con los valores mínimos requeridos.
Order _makeOrder({
  required int id,
  required DateTime eventDate,
  OrderStatus status = OrderStatus.confirmed,
  bool isPaid = false,
  double? total,
}) {
  return Order(
    id: id,
    clientId: 1,
    eventDate: eventDate,
    startTime: eventDate,
    endTime: eventDate,
    status: status,
    items: const [],
    isPaid: isPaid,
    total: total,
  );
}

void main() {
  group('OrdersWindowNotifier.addOrder()', () {
    test('agrega el pedido y la lista queda ordenada por fecha descendente', () async {
      // Usamos el provider real con AsyncData pre-cargado para evitar llamadas a la red.
      final container = ProviderContainer(
        overrides: [
          // Sobreescribimos el notifier para que build() devuelva datos inmediatamente.
          ordersWindowProvider.overrideWith(() => _FakeOrdersWindowNotifier()),
        ],
      );
      addTearDown(container.dispose);

      // Esperamos a que el estado inicial esté disponible.
      await container.read(ordersWindowProvider.future);

      final notifier = container.read(ordersWindowProvider.notifier);

      final pedidoNuevo = _makeOrder(
        id: 99,
        eventDate: DateTime(2025, 6, 20), // fecha intermedia
      );

      await notifier.addOrder(pedidoNuevo);

      final orders = await container.read(ordersWindowProvider.future);
      expect(orders.any((o) => o.id == 99), isTrue);
    });
  });

  group('selectedMonthOrdersProvider', () {
    test('filtra pedidos al mes seleccionado', () async {
      final mayo = DateTime(2025, 5, 1);

      final pedidoMayo = _makeOrder(id: 1, eventDate: DateTime(2025, 5, 15));
      final pedidoJunio = _makeOrder(id: 2, eventDate: DateTime(2025, 6, 10));

      final container = ProviderContainer(
        overrides: [
          ordersWindowProvider.overrideWith(
            () => _FakeOrdersWindowNotifier(
              initialOrders: [pedidoMayo, pedidoJunio],
            ),
          ),
          selectedMonthProvider.overrideWith(
            () => _FakeSelectedMonth(mayo),
          ),
        ],
      );
      addTearDown(container.dispose);

      // Wait for initial load
      await container.read(ordersWindowProvider.future);

      final result = container.read(selectedMonthOrdersProvider);
      expect(result.length, 1);
      expect(result.first.id, 1); // Solo el de mayo
    });

    test('devuelve lista vacía si no hay pedidos en el mes', () async {
      final container = ProviderContainer(
        overrides: [
          ordersWindowProvider.overrideWith(
            () => _FakeOrdersWindowNotifier(initialOrders: []),
          ),
          selectedMonthProvider.overrideWith(
            () => _FakeSelectedMonth(DateTime(2025, 1, 1)),
          ),
        ],
      );
      addTearDown(container.dispose);

      await container.read(ordersWindowProvider.future);

      expect(container.read(selectedMonthOrdersProvider), isEmpty);
    });
  });

  group('monthlyIncomeProvider', () {
    test('suma total solo de pedidos pagados y no cancelados', () async {
      final mes = DateTime(2025, 5, 1);

      final orders = [
        _makeOrder(id: 1, eventDate: DateTime(2025, 5, 1), isPaid: true, total: 10000, status: OrderStatus.delivered),
        _makeOrder(id: 2, eventDate: DateTime(2025, 5, 2), isPaid: false, total: 5000, status: OrderStatus.confirmed),
        _makeOrder(id: 3, eventDate: DateTime(2025, 5, 3), isPaid: true, total: 3000, status: OrderStatus.canceled),
      ];

      final container = ProviderContainer(
        overrides: [
          ordersWindowProvider.overrideWith(
            () => _FakeOrdersWindowNotifier(initialOrders: orders),
          ),
          selectedMonthProvider.overrideWith(
            () => _FakeSelectedMonth(mes),
          ),
        ],
      );
      addTearDown(container.dispose);

      await container.read(ordersWindowProvider.future);

      // Solo el pedido id:1 cuenta (pagado + no cancelado)
      expect(container.read(monthlyIncomeProvider), 10000);
    });

    test('pedido cancelado aunque esté pagado NO se suma', () async {
      final mes = DateTime(2025, 5, 1);

      final container = ProviderContainer(
        overrides: [
          ordersWindowProvider.overrideWith(
            () => _FakeOrdersWindowNotifier(
              initialOrders: [
                _makeOrder(
                  id: 1,
                  eventDate: DateTime(2025, 5, 10),
                  isPaid: true,
                  total: 8000,
                  status: OrderStatus.canceled,
                ),
              ],
            ),
          ),
          selectedMonthProvider.overrideWith(
            () => _FakeSelectedMonth(mes),
          ),
        ],
      );
      addTearDown(container.dispose);

      await container.read(ordersWindowProvider.future);

      expect(container.read(monthlyIncomeProvider), 0);
    });

    test('sin pedidos en el mes → ingreso es 0', () async {
      final container = ProviderContainer(
        overrides: [
          ordersWindowProvider.overrideWith(
            () => _FakeOrdersWindowNotifier(initialOrders: []),
          ),
          selectedMonthProvider.overrideWith(
            () => _FakeSelectedMonth(DateTime(2025, 3, 1)),
          ),
        ],
      );
      addTearDown(container.dispose);

      await container.read(ordersWindowProvider.future);

      expect(container.read(monthlyIncomeProvider), 0.0);
    });
  });
}

// ─── Fakes ───────────────────────────────────────────────────────────────────

/// Notifier falso que devuelve datos inmediatamente sin llamar a la red.
class _FakeOrdersWindowNotifier extends OrdersWindowNotifier {
  final List<Order> initialOrders;

  _FakeOrdersWindowNotifier({this.initialOrders = const []});

  @override
  Future<List<Order>> build() async => List.from(initialOrders);
}

/// SelectedMonth falso que devuelve un mes fijo.
class _FakeSelectedMonth extends SelectedMonth {
  final DateTime _fixed;
  _FakeSelectedMonth(this._fixed);

  @override
  DateTime build() => _fixed;
}
