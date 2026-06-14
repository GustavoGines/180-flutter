import 'package:flutter/material.dart';

extension SnackbarHelper on BuildContext {
  void showCustomSnackbar(String message, {bool isError = false}) {
    if (!mounted) return;

    final cs = Theme.of(this).colorScheme;
    
    // Verificamos si hay un ScaffoldMessenger en la jerarquía
    try {
      ScaffoldMessenger.of(this).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(
                isError ? Icons.error_outline : Icons.check_circle_outline,
                color: isError ? cs.onError : cs.onPrimary,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  message,
                  style: TextStyle(
                    color: isError ? cs.onError : cs.onPrimary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
          backgroundColor: isError ? cs.error : cs.primary,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          margin: const EdgeInsets.all(16),
          duration: const Duration(seconds: 3),
        ),
      );
    } catch (e) {
      // Ignorar si no hay ScaffoldMessenger (por ejemplo en diálogos flotantes sin Scaffold superior)
      debugPrint("No se pudo mostrar el snackbar: $e");
    }
  }
}
