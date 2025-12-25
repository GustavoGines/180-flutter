// lib/core/models/order.dart
import 'package:flutter/foundation.dart';

import 'order_item.dart';
import 'client.dart';
import 'client_address.dart';

@immutable
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

  // --- 1. Renombrar variables ---
  final int? clientAddressId; // ANTES: deliveryAddressId
  final ClientAddress? clientAddress; // ANTES: deliveryAddress
  final bool isPaid;

  const Order({
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
    this.clientAddressId,
    this.clientAddress,
    this.isPaid = false,
  });

  factory Order.fromJson(Map<String, dynamic> json) {
    // ... (Tu lógica de parseDateTime está bien) ...
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
      // --- 2. Cambiar claves del JSON ---
      // Busca 'client_address_id' en el JSON
      clientAddressId: int.tryParse(
        json['client_address_id']?.toString() ?? '',
      ),
      // Busca la relación 'client_address' (que definimos en Laravel)
      clientAddress:
          json['client_address'] != null &&
              json['client_address'] is Map<String, dynamic>
          ? ClientAddress.fromJson(
              json['client_address'] as Map<String, dynamic>,
            )
          : null,

      // ---------------------------------
      client: json['client'] != null && json['client'] is Map<String, dynamic>
          ? Client.fromJson(json['client'] as Map<String, dynamic>)
          : null,
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
      isPaid: json['is_paid'] == 1 || json['is_paid'] == true,
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
    int? clientAddressId,
    ClientAddress? clientAddress,
    bool? isPaid,
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
      clientAddressId: clientAddressId ?? this.clientAddressId,
      clientAddress: clientAddress ?? this.clientAddress,
      isPaid: isPaid ?? this.isPaid,
    );
  }
}
