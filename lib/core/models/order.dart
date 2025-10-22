// lib/core/models/order.dart
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
    this.notes,
    this.client,
  });

  factory Order.fromJson(Map<String, dynamic> json) {
    // ---- LÓGICA DE PARSEO DE FECHA Y HORA MEJORADA ----

    // Función auxiliar para combinar fecha y hora de forma segura
    DateTime parseDateTime(String dateStr, String timeStr) {
      try {
        final date = DateTime.parse(dateStr).toLocal();
        final timeParts = timeStr.split(':');
        final hour = int.tryParse(timeParts[0]) ?? 0;
        final minute = int.tryParse(timeParts[1]) ?? 0;
        return DateTime(date.year, date.month, date.day, hour, minute);
      } catch (e) {
        // Si algo falla (formato inesperado), devuelve la fecha base para no crashear
        return DateTime.parse(dateStr).toLocal();
      }
    }

    final eventDateString =
        json['event_date'] as String? ?? DateTime.now().toIso8601String();
    final startTimeString = json['start_time'] as String? ?? '00:00';
    final endTimeString = json['end_time'] as String? ?? '00:00';

    final itemsJson = (json['items'] as List?) ?? const [];

    return Order(
      id: int.tryParse(json['id'].toString()) ?? 0,
      clientId: int.tryParse(json['client_id'].toString()) ?? 0,

      eventDate: DateTime.parse(eventDateString).toLocal(),
      startTime: parseDateTime(eventDateString, startTimeString),
      endTime: parseDateTime(eventDateString, endTimeString),

      status: (json['status'] ?? 'draft').toString(),
      total: double.tryParse(json['total'].toString()),
      deposit: double.tryParse(json['deposit'].toString()),
      notes: json['notes']?.toString(),
      items: itemsJson
          .map((e) => OrderItem.fromJson(e as Map<String, dynamic>))
          .toList(),
      client: json['client'] != null
          ? Client.fromJson(json['client'] as Map<String, dynamic>)
          : null,
    );
  }
}
