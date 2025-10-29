// lib/core/models/order.dart
import 'package:flutter/foundation.dart';

import 'order_item.dart';
import 'client.dart';

class Order {
  final int id;
  final int clientId;
  final DateTime eventDate;
  final DateTime startTime;
  final DateTime endTime;
  final String status;
  final double? total;
  final double? deposit;
  final double? deliveryCost; // <-- NUEVO CAMPO
  final String? notes;
  final List<OrderItem> items;
  final Client? client;

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
    this.deliveryCost, // <-- AÑADIDO AL CONSTRUCTOR
    this.notes,
    this.client,
  });

  factory Order.fromJson(Map<String, dynamic> json) {
    // ---- LÓGICA DE PARSEO DE FECHA Y HORA MEJORADA ----

    // Función auxiliar para combinar fecha y hora de forma segura
    DateTime parseDateTime(String dateStr, String timeStr) {
      try {
        // Asume que dateStr viene como YYYY-MM-DD
        final date = DateTime.parse(dateStr).toLocal();
        // Asume que timeStr viene como HH:MM
        final timeParts = timeStr.split(':');
        final hour = int.tryParse(timeParts[0]) ?? 0;
        final minute = int.tryParse(timeParts[1]) ?? 0;
        // Combina fecha con hora/minuto parseados
        return DateTime(date.year, date.month, date.day, hour, minute);
      } catch (e) {
        // Fallback robusto: si algo falla, devuelve solo la fecha a medianoche
        try {
          return DateTime.parse(dateStr).toLocal();
        } catch (_) {
          // Si incluso la fecha falla, devuelve ahora como último recurso
          return DateTime.now();
        }
      }
    }

    // Usar '' como default si son null para evitar errores en parseDateTime
    final eventDateString =
        json['event_date'] as String? ??
        DateTime.now().toIso8601String().substring(
          0,
          10,
        ); // Asegurar solo YYYY-MM-DD
    final startTimeString = json['start_time'] as String? ?? '00:00';
    final endTimeString = json['end_time'] as String? ?? '00:00';

    final itemsJson = (json['items'] as List?) ?? const [];

    return Order(
      // Usar int.tryParse para más seguridad con IDs
      id: int.tryParse(json['id']?.toString() ?? '0') ?? 0,
      clientId: int.tryParse(json['client_id']?.toString() ?? '0') ?? 0,

      // Parseo de fechas y horas
      eventDate:
          DateTime.tryParse(eventDateString)?.toLocal() ??
          DateTime.now(), // Usar tryParse
      startTime: parseDateTime(eventDateString, startTimeString),
      endTime: parseDateTime(eventDateString, endTimeString),

      // Parseo de otros campos, asegurando tipos correctos y defaults
      status: (json['status'] ?? 'unknown')
          .toString(), // Default a 'unknown' si es null
      total: double.tryParse(
        json['total']?.toString() ?? '',
      ), // tryParse maneja null o string vacío
      deposit: double.tryParse(json['deposit']?.toString() ?? ''),
      deliveryCost: double.tryParse(
        json['delivery_cost']?.toString() ?? '',
      ), // <-- PARSEAR NUEVO CAMPO
      notes: json['notes']?.toString(), // Permite null
      items: itemsJson
          .map((e) {
            try {
              return OrderItem.fromJson(e as Map<String, dynamic>);
            } catch (itemError) {
              if (kDebugMode) {
                print("Error parsing order item: $itemError \nItem JSON: $e");
              }
              // Decide qué hacer: retornar un item inválido, null, o lanzar error?
              // Por ahora, lo omitimos para no crashear
              return null;
            }
          })
          .whereType<OrderItem>() // Filtra los nulos si hubo error en el item
          .toList(),
      client:
          json['client'] != null &&
              json['client']
                  is Map<String, dynamic> // Chequeo extra
          ? Client.fromJson(json['client'] as Map<String, dynamic>)
          : null,
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
    );
  }
}
