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

  // 🚨 ELIMINADO: Ya no necesitamos 'darkBrown' estático.
  // static const Color darkBrown = Color(0xFF7A4A4A);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // 1. Observa el pedido para obtener todos los detalles
    final orderAsync = ref.watch(orderByIdProvider(orderId));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Vista Previa de Pedido'),
        // 🚨 ELIMINADO: 'backgroundColor' y 'iconTheme'
        // Tu 'appBarTheme' global se encargará de esto
        // automáticamente para ambos modos (light y dark).
      ),
      body: orderAsync.when(
        loading: () => Center(
          // ✅ CAMBIO: Usar el color primario del tema actual
          child: CircularProgressIndicator(
            color: Theme.of(context).colorScheme.primary,
          ),
        ),
        error: (err, stack) => Center(
          child: Text(
            'Error al cargar pedido: $err',
            // ✅ CAMBIO: Usar el color de error del tema
            style: TextStyle(
              color: Theme.of(context).colorScheme.error,
            ), // TODO: Usar cs.error
          ),
        ),
        data: (order) {
          if (order == null) {
            return const Center(child: Text('Pedido no encontrado.'));
          }

          // El 'PdfPreview' en sí mismo tiene su propio tema (generalmente
          // gris) para el visor, pero el 'AppBar' y el fondo
          // de la página ahora están adaptados.
          return PdfPreview(
            build: (format) => PdfGenerator().generatePdfBytes(order),
            allowSharing: true,
            allowPrinting: true,
            canDebug: false,
            pdfFileName:
                'Pedido_${order.id}_${DateFormat('yyyyMMdd').format(order.eventDate)}.pdf',
          );
        },
      ),
    );
  }
}
