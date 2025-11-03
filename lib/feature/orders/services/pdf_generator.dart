import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:intl/intl.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter/foundation.dart'; // Necesario para Uint8List

import '../../../core/models/order.dart';
import '../../../core/models/order_item.dart';

class PdfGenerator {
  static final PdfGenerator _instance = PdfGenerator._internal();
  factory PdfGenerator() => _instance;
  PdfGenerator._internal();

  final currencyFormat = NumberFormat.currency(locale: 'es_AR', symbol: '\$');

  /// Genera los bytes del PDF que utiliza el PdfPreviewPage.
  Future<Uint8List> generatePdfBytes(Order order) async {
    final pdf = pw.Document();

    // 1. Carga el logo de forma segura (para evitar errores en PDF)
    pw.ImageProvider? logoImage = await _loadLogoImage();

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // 2. _buildHeader ahora acepta pw.ImageProvider?
              _buildHeader(order, logoImage),
              pw.SizedBox(height: 20),
              _buildClientSection(order),
              pw.SizedBox(height: 20),
              _buildItemsTable(order),
              pw.SizedBox(height: 20),
              _buildNotesSection(order),
              pw.Spacer(),
              _buildSummarySection(order),
            ],
          );
        },
      ),
    );

    return pdf.save();
  }

  // --- WIDGETS Y HELPERS ---

  /// Helper para cargar la imagen del logo como asset.
  Future<pw.ImageProvider?> _loadLogoImage() async {
    try {
      final byteData = await rootBundle.load('assets/images/logo_180.png');
      return pw.MemoryImage(byteData.buffer.asUint8List());
    } catch (_) {
      // Si la carga falla (ej: ruta incorrecta), devuelve null.
      return null;
    }
  }

  // 3. CORRECCIÓN: Ahora acepta pw.ImageProvider? (nullable)
  pw.Widget _buildHeader(Order order, pw.ImageProvider? logo) {
    final PdfColor darkBrown = PdfColor.fromInt(0xFF7A4A4A);
    final PdfColor primaryPink = PdfColor.fromInt(0xFFF8B6B6);

    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      // ✅ CAMBIO CLAVE: Alinear verticalmente al centro
      crossAxisAlignment: pw.CrossAxisAlignment.center,
      children: [
        // 1. Columna de Texto
        pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(
              '180° Pastelería - Detalle del Pedido',
              style: pw.TextStyle(
                fontSize: 20,
                fontWeight: pw.FontWeight.bold,
                color: darkBrown,
              ),
            ),
            pw.SizedBox(height: 5),
            pw.Text(
              'Fecha del Pedido: ${DateFormat('dd/MM/yyyy').format(DateTime.now())}',
              style: const pw.TextStyle(fontSize: 12),
            ),
            pw.SizedBox(height: 2),
            pw.Text(
              'Pedido N°: ${order.id}',
              style: const pw.TextStyle(fontSize: 12),
            ),
          ],
        ),

        // 2. Logo Container (este código está perfecto como lo dejamos)
        if (logo != null)
          pw.Container(
            width: 230,
            height: 230,
            child: pw.Image(logo, fit: pw.BoxFit.contain),
          )
        else
          // Fallback
          pw.Container(
            width: 150,
            height: 150,
            alignment: pw.Alignment.center,
            child: pw.Text(
              '180°',
              style: pw.TextStyle(
                fontSize: 32,
                fontWeight: pw.FontWeight.bold,
                color: primaryPink,
              ),
            ),
          ),
      ],
    );
  }

  pw.Widget _buildClientSection(Order order) {
    final address = order.clientAddress;
    final isDelivery = (order.deliveryCost ?? 0) > 0;

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          'Detalles del Cliente',
          style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold),
        ),
        pw.SizedBox(height: 5),
        pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Expanded(
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text('Cliente: ${order.client?.name ?? 'N/A'}'),
                  pw.Text('Teléfono: ${order.client?.phone ?? 'N/A'}'),
                  pw.Text('Email: ${order.client?.email ?? 'N/A'}'),
                  pw.SizedBox(height: 5),
                  pw.Text(
                    'Fecha del Evento: ${DateFormat('dd/MM/yyyy').format(order.eventDate)}',
                  ),
                  pw.Text(
                    'Horario: ${DateFormat.Hm('es_AR').format(order.startTime)} - ${DateFormat.Hm('es_AR').format(order.endTime)}',
                  ),
                ],
              ),
            ),
            pw.SizedBox(width: 20),
            pw.Expanded(
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    'Entrega / Retiro',
                    style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                  ),
                  pw.SizedBox(height: 2),
                  if (address != null && isDelivery)
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text('Tipo: Envío a Domicilio'),
                        pw.Text('Etiqueta: ${address.label ?? 'N/A'}'),
                        pw.Text('Dirección: ${address.addressLine1 ?? 'N/A'}'),
                        if (address.notes != null && address.notes!.isNotEmpty)
                          pw.Text('Notas: ${address.notes}'),
                      ],
                    )
                  else if (!isDelivery)
                    pw.Text('Tipo: Retiro en local')
                  else
                    pw.Text('Tipo: Envío (Dirección no seleccionada)'),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  pw.Widget _buildItemsTable(Order order) {
    const PdfColor headerColor = PdfColor.fromInt(0xFFF8B6B6); // primaryPink

    final tableHeaders = [
      'Producto',
      'Detalles',
      'Cant.',
      'Precio Unit.',
      'Total Item',
    ];

    return pw.Table.fromTextArray(
      cellAlignment: pw.Alignment.centerLeft,
      headerStyle: pw.TextStyle(
        fontWeight: pw.FontWeight.bold,
        fontSize: 11,
        color: PdfColor.fromInt(0xFF7A4A4A), // darkBrown
      ),
      cellStyle: const pw.TextStyle(fontSize: 11, color: PdfColors.black),
      headerDecoration: const pw.BoxDecoration(color: headerColor),
      headers: tableHeaders,
      columnWidths: {
        0: const pw.FlexColumnWidth(2), // Producto
        1: const pw.FlexColumnWidth(3), // Detalles
        2: const pw.FlexColumnWidth(1), // Cantidad
        3: const pw.FlexColumnWidth(1.5), // Precio Unitario
        4: const pw.FlexColumnWidth(1.5), // Total Item
      },
      data: order.items.map((item) {
        final itemTotal = item.finalUnitPrice * item.qty;
        final details = _getItemDetailsText(item);

        return [
          item.name,
          details,
          item.qty.toString(),
          currencyFormat.format(item.finalUnitPrice),
          currencyFormat.format(itemTotal),
        ];
      }).toList(),
    );
  }

  String _getItemDetailsText(OrderItem item) {
    final custom = item.customizationJson ?? {};
    final parts = <String>[];

    // Notas de ajuste manual (lo más importante)
    if (item.customizationNotes != null &&
        item.customizationNotes!.isNotEmpty) {
      parts.add('Ajuste: ${item.customizationNotes}');
    }

    // Precio base con ajuste manual (si aplica)
    if (item.adjustments != 0) {
      parts.add(
        'Base: ${currencyFormat.format(item.basePrice)} Ajuste: ${currencyFormat.format(item.adjustments)}',
      );
    }

    // Notas generales del item (sabor/temática)
    final itemNotes = custom['item_notes'] as String?;
    if (itemNotes != null && itemNotes.isNotEmpty) {
      parts.add('Notas Item: $itemNotes');
    }

    // Detalles específicos de la Torta
    if (custom['weight_kg'] != null) {
      parts.add('Peso: ${custom['weight_kg']} kg');
    }
    if (custom['selected_fillings'] is List &&
        (custom['selected_fillings'] as List).isNotEmpty) {
      parts.add(
        'Rellenos: ${(custom['selected_fillings'] as List).join(', ')}',
      );
    }

    return parts.join(' | ');
  }

  pw.Widget _buildNotesSection(Order order) {
    if (order.notes == null || order.notes!.isEmpty) {
      return pw.SizedBox.shrink();
    }
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          'Notas Generales del Pedido',
          style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold),
        ),
        pw.SizedBox(height: 5),
        pw.Container(
          padding: const pw.EdgeInsets.all(8),
          decoration: pw.BoxDecoration(
            border: pw.Border.all(color: PdfColors.grey400),
            borderRadius: pw.BorderRadius.circular(5),
            color: PdfColors.grey100,
          ),
          child: pw.Text(order.notes!, style: const pw.TextStyle(fontSize: 12)),
        ),
      ],
    );
  }

  pw.Widget _buildSummarySection(Order order) {
    final itemsSubtotal = order.items.fold<double>(
      0.0,
      (sum, item) => sum + (item.finalUnitPrice * item.qty),
    );
    final deliveryCost = order.deliveryCost ?? 0.0;
    final total = order.total ?? (itemsSubtotal + deliveryCost);
    final deposit = order.deposit ?? 0.0;
    final balance = total - deposit;

    return pw.Container(
      alignment: pw.Alignment.centerRight,
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.end,
        children: [
          _buildSummaryRow('Subtotal Productos:', itemsSubtotal),
          if (deliveryCost > 0) _buildSummaryRow('Costo Envío:', deliveryCost),
          pw.Divider(color: PdfColors.grey500),
          _buildSummaryRow('TOTAL PEDIDO:', total, isTotal: true),
          if (deposit > 0)
            _buildSummaryRow('Seña Recibida:', deposit, isDeposit: true),
          if (total > 0 && balance != 0)
            _buildSummaryRow(
              'SALDO PENDIENTE:',
              balance,
              isTotal: true,
              isBalance: true,
            ),
        ],
      ),
    );
  }

  pw.Widget _buildSummaryRow(
    String label,
    double amount, {
    bool isTotal = false,
    bool isDeposit = false,
    bool isBalance = false,
  }) {
    final style = isTotal
        ? pw.TextStyle(
            fontWeight: pw.FontWeight.bold,
            fontSize: 14,
            color: isBalance ? PdfColors.red : PdfColors.black,
          )
        : const pw.TextStyle(fontSize: 12, color: PdfColors.black);

    final value = currencyFormat.format(amount.abs());

    return pw.Padding(
      padding: const pw.EdgeInsets.only(top: 2, bottom: 2),
      child: pw.Row(
        mainAxisSize: pw.MainAxisSize.min,
        children: [
          pw.Container(width: 130, child: pw.Text(label, style: style)),
          pw.Container(
            width: 80,
            alignment: pw.Alignment.centerRight,
            child: pw.Text(value, style: style),
          ),
        ],
      ),
    );
  }
}
