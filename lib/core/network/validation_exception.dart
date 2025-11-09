// Archivo sugerido: core/network/validation_exception.dart

class ValidationException implements Exception {
  // Mapa de errores: {"campo": ["mensaje1", "mensaje2"]}
  final Map<String, List<String>> errors;

  ValidationException(Map<String, dynamic> rawErrors)
    : errors = rawErrors.map(
        (k, v) => MapEntry(
          k.toString(),
          (v as List).map((i) => i.toString()).toList(),
        ),
      );

  @override
  String toString() {
    String message = 'Errores de Validación:';
    errors.forEach((field, messages) {
      // Intentamos capitalizar la primera letra del campo para mejor lectura
      final fieldName = field[0].toUpperCase() + field.substring(1);
      message += '\n- $fieldName: ${messages.join(", ")}';
    });
    return message;
  }
}
