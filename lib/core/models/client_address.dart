import 'package:flutter/foundation.dart';

@immutable
class ClientAddress {
  final int id;
  final int clientId;
  final String? label;
  final String? addressLine1;
  final double? latitude;
  final double? longitude;
  final String? googleMapsUrl;
  final String? notes;

  const ClientAddress({
    required this.id,
    required this.clientId,
    this.label,
    this.addressLine1,
    this.latitude,
    this.longitude,
    this.googleMapsUrl,
    this.notes,
  });

  /// Helper para mostrar la dirección en la UI.
  /// Da prioridad al 'label', luego a la 'address_line_1', luego a las 'coords'.
  String get displayAddress {
    if (label != null && label!.isNotEmpty) {
      return label!;
    }
    if (addressLine1 != null && addressLine1!.isNotEmpty) {
      return addressLine1!;
    }
    if (latitude != null && longitude != null) {
      return '$latitude, $longitude';
    }
    if (googleMapsUrl != null && googleMapsUrl!.isNotEmpty) {
      return 'Ver en Google Maps';
    }
    return 'Dirección #$id'; // Fallback
  }

  factory ClientAddress.fromJson(Map<String, dynamic> json) {
    // Helper para parsear doubles de forma segura
    double? tryParseDouble(dynamic value) {
      if (value == null) return null;
      if (value is double) return value;
      if (value is int) return value.toDouble();
      if (value is String) return double.tryParse(value);
      return null;
    }

    return ClientAddress(
      id: json['id'] as int,
      clientId: json['client_id'] as int,
      label: json['label'] as String?,
      addressLine1: json['address_line_1'] as String?,
      latitude: tryParseDouble(json['latitude']),
      longitude: tryParseDouble(json['longitude']),
      googleMapsUrl: json['google_maps_url'] as String?,
      notes: json['notes'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'client_id': clientId,
      'label': label,
      'address_line_1': addressLine1,
      'latitude': latitude,
      'longitude': longitude,
      'google_maps_url': googleMapsUrl,
      'notes': notes,
    };
  }

  // CopyWith para facilitar las actualizaciones en Riverpod
  ClientAddress copyWith({
    int? id,
    int? clientId,
    String? label,
    String? addressLine1,
    double? latitude,
    double? longitude,
    String? googleMapsUrl,
    String? notes,
  }) {
    return ClientAddress(
      id: id ?? this.id,
      clientId: clientId ?? this.clientId,
      label: label ?? this.label,
      addressLine1: addressLine1 ?? this.addressLine1,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      googleMapsUrl: googleMapsUrl ?? this.googleMapsUrl,
      notes: notes ?? this.notes,
    );
  }
}
