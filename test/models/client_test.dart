import 'package:flutter_test/flutter_test.dart';
import 'package:pasteleria_180_flutter/core/models/client.dart';

void main() {
  group('Client.whatsappUrl', () {
    test('número con prefijo + genera URL correcta', () {
      const client = Client(id: 1, name: 'Ana', phone: '+5491155554444');
      expect(client.whatsappUrl, 'https://wa.me/5491155554444');
    });

    test('número sin prefijo + genera URL correcta', () {
      const client = Client(id: 1, name: 'Ana', phone: '5491155554444');
      expect(client.whatsappUrl, 'https://wa.me/5491155554444');
    });

    test('número con espacios se limpia correctamente', () {
      const client = Client(id: 1, name: 'Ana', phone: '+549 11 5555 4444');
      expect(client.whatsappUrl, 'https://wa.me/5491155554444');
    });

    test('número con guiones se limpia correctamente', () {
      const client = Client(id: 1, name: 'Ana', phone: '549-11-5555-4444');
      expect(client.whatsappUrl, 'https://wa.me/5491155554444');
    });

    test('número con paréntesis se limpia correctamente', () {
      const client = Client(id: 1, name: 'Ana', phone: '+549 (11) 5555-4444');
      expect(client.whatsappUrl, 'https://wa.me/5491155554444');
    });

    test('phone null → whatsappUrl es null', () {
      const client = Client(id: 1, name: 'Sin teléfono');
      expect(client.whatsappUrl, isNull);
    });

    test('phone vacío → whatsappUrl es null', () {
      const client = Client(id: 1, name: 'Vacío', phone: '');
      expect(client.whatsappUrl, isNull);
    });
  });

  group('Client.fromJson', () {
    test('parsea un cliente completo', () {
      final client = Client.fromJson(const {
        'id': 5,
        'name': 'María López',
        'phone': '+5491144443333',
        'email': 'maria@example.com',
        'notes': 'Alérgica al maní',
        'deleted_at': null,
        'addresses': [],
      });

      expect(client.id, 5);
      expect(client.name, 'María López');
      expect(client.phone, '+5491144443333');
      expect(client.deletedAt, isNull);
      expect(client.addresses, isEmpty);
    });

    test('deleted_at no nulo se parsea como DateTime', () {
      final client = Client.fromJson(const {
        'id': 1,
        'name': 'Eliminado',
        'deleted_at': '2024-06-15T10:00:00.000000Z',
      });
      expect(client.deletedAt, isNotNull);
      expect(client.deletedAt, isA<DateTime>());
    });

    test('addresses ausente en JSON da lista vacía', () {
      final client = Client.fromJson(const {'id': 1, 'name': 'Sin direcciones'});
      expect(client.addresses, isEmpty);
    });
  });
}
