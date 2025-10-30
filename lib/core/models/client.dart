class Client {
  final int id;
  final String name;
  final String? phone;
  final String? email;
  final String? address;
  final String? notes;
  final DateTime? deletedAt;

  Client({
    required this.id,
    required this.name,
    this.phone,
    this.email,
    this.address,
    this.notes,
    this.deletedAt,
  });

  factory Client.fromJson(Map<String, dynamic> j) => Client(
    id: j['id'],
    name: j['name'] ?? '',
    phone: j['phone'],
    email: j['email'],
    address: j['address'],
    notes: j['notes'],
    deletedAt: j['deleted_at'] != null
        ? DateTime.parse(j['deleted_at'] as String)
        : null,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'phone': phone,
    'email': email,
    'address': address,
    'notes': notes,
  };
}
