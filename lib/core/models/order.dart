// lib/core/models/order.dart
import 'order_item.dart';
import '../json_utils.dart';
import 'client.dart';
// La importación de 'intl' ha sido eliminada.

class Order {
  final int id;
  final int clientId;
  final DateTime eventDate;
  final DateTime startTime;
  final DateTime endTime;
  final String status;
  final double total;
  final double deposit;
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
    required this.total,
    required this.deposit,
    required this.items,
    this.notes,
    this.client,
  });

  factory Order.fromJson(Map<String, dynamic> json) {
    // 1. Leemos la fecha base del evento.
    final DateTime eventDateBase = DateTime.parse(json['event_date'] as String);

    // 2. Leemos las horas como texto simple.
    final String startTimeString = json['start_time'] as String;
    final String endTimeString = json['end_time'] as String;

    // 3. Separamos las horas y los minutos.
    final startTimeParts = startTimeString.split(':');
    final endTimeParts = endTimeString.split(':');

    // 4. Creamos los objetos DateTime finales combinando las partes.
    final DateTime finalStartTime = DateTime(
      eventDateBase.year,
      eventDateBase.month,
      eventDateBase.day,
      int.parse(startTimeParts[0]), // Hora
      int.parse(startTimeParts[1]), // Minuto
    ).toLocal();

    final DateTime finalEndTime = DateTime(
      eventDateBase.year,
      eventDateBase.month,
      eventDateBase.day,
      int.parse(endTimeParts[0]), // Hora
      int.parse(endTimeParts[1]), // Minuto
    ).toLocal();

    final itemsJson = (json['items'] as List?) ?? const [];

    return Order(
      id: toInt(json['id']),
      clientId: toInt(json['client_id']),
      eventDate: eventDateBase.toLocal(),
      startTime: finalStartTime,
      endTime: finalEndTime,
      status: (json['status'] ?? 'draft').toString(),
      total: toNum(json['total']).toDouble(),
      deposit: toNum(json['deposit']).toDouble(),
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
