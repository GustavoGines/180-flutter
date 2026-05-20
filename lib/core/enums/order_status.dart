enum OrderStatus {
  pending,
  confirmed,
  ready,
  delivered,
  canceled,
  unknown;

  static OrderStatus fromString(String? status) {
    switch (status?.toLowerCase()) {
      case 'pending':
        return OrderStatus.pending;
      case 'confirmed':
        return OrderStatus.confirmed;
      case 'ready':
        return OrderStatus.ready;
      case 'delivered':
        return OrderStatus.delivered;
      case 'canceled':
        return OrderStatus.canceled;
      default:
        return OrderStatus.unknown;
    }
  }

  String toJson() {
    return name;
  }
}
