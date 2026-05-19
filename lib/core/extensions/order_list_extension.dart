import 'package:pasteleria_180_flutter/core/models/order.dart';
import 'package:pasteleria_180_flutter/core/enums/order_status.dart';

extension OrderListExtension on List<Order> {
  void sortedByDateAndStatus() {
    const statusOrder = {
      OrderStatus.pending: 0,
      OrderStatus.confirmed: 1,
      OrderStatus.ready: 2,
      OrderStatus.delivered: 3,
      OrderStatus.canceled: 4,
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
