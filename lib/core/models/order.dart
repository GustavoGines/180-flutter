// lib/core/models/order.dart
import 'package:flutter/foundation.dart';

import 'order_item.dart';
import 'client.dart';
import 'client_address.dart'; // <-- IMPORTAR EL MODELO QUE FALTA

class Order {
  final int id;
  final int clientId;
  final DateTime eventDate;
  final DateTime startTime;
  final DateTime endTime;
  final String status;
  final double? total;
  final double? deposit;
  final double? deliveryCost;
  final String? notes;
  final List<OrderItem> items;
  final Client? client;

  // ---- INICIO DE CAMPOS NUEVOS ----
  final int? deliveryAddressId; // El ID de la dirección seleccionada
  final ClientAddress?
  deliveryAddress; // El objeto dirección (si viene cargado)
  // ---- FIN DE CAMPOS NUEVOS ----

  Order({
    required this.id,
    required this.clientId,
    required this.eventDate,
    required this.startTime,
    required this.endTime,
    required this.status,
    required this.items,
    this.total,
    this.deposit,
    this.deliveryCost,
    this.notes,
    this.client,
    this.deliveryAddressId, // <-- AÑADIR AL CONSTRUCTOR
    this.deliveryAddress, // <-- AÑADIR AL CONSTRUCTOR
  });

  factory Order.fromJson(Map<String, dynamic> json) {
    // ... (toda tu lógica de parseDateTime está perfecta) ...
    DateTime parseDateTime(String dateStr, String timeStr) {
      try {
        final date = DateTime.parse(dateStr).toLocal();
        final timeParts = timeStr.split(':');
        final hour = int.tryParse(timeParts[0]) ?? 0;
        final minute = int.tryParse(timeParts[1]) ?? 0;
        return DateTime(date.year, date.month, date.day, hour, minute);
      } catch (e) {
        try {
          return DateTime.parse(dateStr).toLocal();
        } catch (_) {
          return DateTime.now();
        }
      }
    }

    final eventDateString =
        json['event_date'] as String? ??
        DateTime.now().toIso8601String().substring(0, 10);
    final startTimeString = json['start_time'] as String? ?? '00:00';
    final endTimeString = json['end_time'] as String? ?? '00:00';
    final itemsJson = (json['items'] as List?) ?? const [];

    return Order(
      id: int.tryParse(json['id']?.toString() ?? '0') ?? 0,
      clientId: int.tryParse(json['client_id']?.toString() ?? '0') ?? 0,
      eventDate:
          DateTime.tryParse(eventDateString)?.toLocal() ?? DateTime.now(),
      startTime: parseDateTime(eventDateString, startTimeString),
      endTime: parseDateTime(eventDateString, endTimeString),
      status: (json['status'] ?? 'unknown').toString(),
      total: double.tryParse(json['total']?.toString() ?? ''),
      deposit: double.tryParse(json['deposit']?.toString() ?? ''),
      deliveryCost: double.tryParse(json['delivery_cost']?.toString() ?? ''),
      notes: json['notes']?.toString(),

      // ---- INICIO DE AJUSTES EN FROMJSON ----

      // Parsear la dirección de entrega si viene (eager-loaded)
      deliveryAddressId: int.tryParse(
        json['delivery_address_id']?.toString() ?? '',
      ),
      deliveryAddress:
          json['delivery_address'] != null &&
              json['delivery_address'] is Map<String, dynamic>
          ? ClientAddress.fromJson(
              json['delivery_address'] as Map<String, dynamic>,
            )
          : null,

      // Parsear el cliente si viene (eagler-loaded)
      client: json['client'] != null && json['client'] is Map<String, dynamic>
          ? Client.fromJson(json['client'] as Map<String, dynamic>)
          : null,

      // Parsear items (tu lógica estaba bien)
      items: itemsJson
          .map((e) {
            try {
              return OrderItem.fromJson(e as Map<String, dynamic>);
            } catch (itemError) {
              if (kDebugMode) {
                print("Error parsing order item: $itemError \nItem JSON: $e");
              }
              return null;
            }
          })
          .whereType<OrderItem>()
          .toList(),

      // ---- FIN DE AJUSTES EN FROMJSON ----
    );
  }

  Order copyWith({
    int? id,
    int? clientId,
    DateTime? eventDate,
    DateTime? startTime,
    DateTime? endTime,
    String? status,
    double? total,
    double? deposit,
    double? deliveryCost,
    String? notes,
    List<OrderItem>? items,
    Client? client,
    int? deliveryAddressId, // <-- AÑADIR A COPYWITH
    ClientAddress? deliveryAddress, // <-- AÑADIR A COPYWITH
  }) {
    return Order(
      id: id ?? this.id,
      clientId: clientId ?? this.clientId,
      eventDate: eventDate ?? this.eventDate,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      status: status ?? this.status,
      total: total ?? this.total,
      deposit: deposit ?? this.deposit,
      deliveryCost: deliveryCost ?? this.deliveryCost,
      notes: notes ?? this.notes,
      items: items ?? this.items,
      client: client ?? this.client,
      deliveryAddressId: deliveryAddressId ?? this.deliveryAddressId, // <--
      deliveryAddress: deliveryAddress ?? this.deliveryAddress, // <--
    );
  }
}
