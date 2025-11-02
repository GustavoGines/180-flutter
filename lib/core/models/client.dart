import 'package:flutter/foundation.dart';
import 'client_address.dart';

@immutable // Usar @immutable si la clase es inmutable
class Client {
  final int id;
  final String name;
  final String? phone;
  final String? email;
  final String? notes;
  final DateTime? deletedAt;
  final List<ClientAddress> addresses; // Esta es la lista clave

  const Client({
    // Usar const constructor
    required this.id,
    required this.name,
    this.phone,
    this.email,
    this.notes,
    this.deletedAt,
    this.addresses = const [], // Default a lista vacía
  });

  // 👇 NUEVO GETTER QUE GENERA EL ENLACE CORRECTO
  String? get whatsappUrl {
    if (phone == null || phone!.isEmpty) {
      return null;
    }

    // 1. Limpiamos cualquier cosa que no sea número o el signo '+'
    String cleanedPhone = phone!.replaceAll(RegExp(r'[^\d+]'), '');

    // 2. Si el número ya tiene el código internacional (+549), usamos el substring después del +
    // Si no, asumimos que está estandarizado por Laravel a 549 y solo quitamos el '+' si existe.
    if (cleanedPhone.startsWith('+')) {
      cleanedPhone = cleanedPhone.substring(1);
    }

    // El backend debe asegurar que el número es 549...
    return 'https://wa.me/$cleanedPhone';
  }

  factory Client.fromJson(Map<String, dynamic> j) {
    // Parsear la lista de direcciones si viene en el JSON
    final addressesList = (j['addresses'] as List?) ?? [];
    final parsedAddresses = addressesList
        .map(
          (addressJson) =>
              ClientAddress.fromJson(addressJson as Map<String, dynamic>),
        )
        .toList();

    return Client(
      id: j['id'],
      name: j['name'] ?? '',
      phone: j['phone'] as String?,
      email: j['email'] as String?,
      notes: j['notes'] as String?,
      deletedAt: j['deleted_at'] != null
          ? DateTime.parse(j['deleted_at'] as String)
          : null,
      addresses: parsedAddresses, // <-- USAR LA LISTA PARSEADA
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'phone': phone,
    'email': email,
    'notes': notes,
    // No incluimos 'addresses' aquí,
    // ya que probablemente se gestionen en su propio endpoint
    // (ej: POST /api/clients/1/addresses)
  };

  // copyWith para inmutabilidad (¡muy buena práctica!)
  Client copyWith({
    int? id,
    String? name,
    String? phone,
    String? email,
    String? notes,
    DateTime? deletedAt,
    List<ClientAddress>? addresses,
  }) {
    return Client(
      id: id ?? this.id,
      name: name ?? this.name,
      phone: phone ?? this.phone,
      email: email ?? this.email,
      notes: notes ?? this.notes,
      deletedAt: deletedAt ?? this.deletedAt,
      addresses: addresses ?? this.addresses,
    );
  }
}
