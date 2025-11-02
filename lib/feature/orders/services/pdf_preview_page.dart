import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pasteleria_180_flutter/feature/orders/order_detail_page.dart';
import 'package:printing/printing.dart'; // Importante para PdfPreview
import 'package:intl/intl.dart';

// Para orderByIdProvider
import '../services/pdf_generator.dart'; // Para la lógica de generación

class PdfPreviewPage extends ConsumerWidget {
  final int orderId;
  const PdfPreviewPage({super.key, required this.orderId});

  static const Color darkBrown = Color(0xFF7A4A4A);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // 1. Observa el pedido para obtener todos los detalles
    final orderAsync = ref.watch(orderByIdProvider(orderId));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Vista Previa de Pedido'),
        backgroundColor: Colors.white,
        iconTheme: const IconThemeData(color: darkBrown),
      ),
      body: orderAsync.when(
        loading: () =>
            const Center(child: CircularProgressIndicator(color: darkBrown)),
        error: (err, stack) => Center(
          child: Text(
            'Error al cargar pedido: $err',
            style: const TextStyle(color: Colors.red),
          ),
        ),
        data: (order) {
          if (order == null) {
            return const Center(child: Text('Pedido no encontrado.'));
          }

          // 2. Usamos PdfPreview para mostrar el documento
          return PdfPreview(
            // La función build debe devolver un Future<Uint8List>
            build: (format) => PdfGenerator().generatePdfBytes(order),

            // Opciones de estilo y botones (Solo las compatibles)
            allowSharing: true, // Permitir compartir
            allowPrinting: true, // Permitir imprimir
            canDebug: false, // Desactivar el debug de PDF
            // Corregido: Usar 'pdfFileName' o 'fileName' (preferimos fileName)
            // La opción pdfFileName fue eliminada en versiones recientes.
            pdfFileName:
                'Pedido_${order.id}_${DateFormat('yyyyMMdd').format(order.eventDate)}.pdf',

            // ❌ REMOVIDO: previewPagePageDecoration (No existe en el API de PdfPreview)
            // ❌ REMOVIDO: PdfTextAction (No existe directamente en PdfPreview)
            // ❌ REMOVIDO: maxPageWidth (No es una propiedad directa de PdfPreview)

            // Usar la opción 'pageFormats' si necesitas forzar el tamaño de la hoja (A4, Letter)
            // pageFormats: const {'A4': PdfPageFormat.a4},
          );
        },
      ),
    );
  }
}
