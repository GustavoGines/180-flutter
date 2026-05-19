import 'package:pasteleria_180_flutter/core/models/order.dart';

extension OrderListExtension on List<Order> {
  void sortedByDateAndStatus() {
    const statusOrder = {
      'pending': 0,
      'confirmed': 1,
      'ready': 2,
      'delivered': 3,
      'canceled': 4,
    };
    sort((a, b) {
      final dayCmp = DateTime(
        a.eventDate.year,
        a.eventDate.month,
        a.eventDate.day,
      ).compareTo(
        DateTime(b.eventDate.year, b.eventDate.month, b.eventDate.day),
      );
      if (dayCmp != 0) return dayCmp;
      final timeCmp = a.startTime.compareTo(b.startTime);
      if (timeCmp != 0) return timeCmp;
      final pa = statusOrder[a.status] ?? 99;
      final pb = statusOrder[b.status] ?? 99;
      return pa.compareTo(pb);
    });
  }
}
