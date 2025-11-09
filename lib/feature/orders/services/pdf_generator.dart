import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:intl/intl.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter/foundation.dart'; // Contiene Uint8List

import '../../../core/models/order.dart';
import '../../../core/models/order_item.dart';

/// 🧁 Clase generadora de documentos PDF para pedidos (facturas/detalles).
/// Implementa el patrón Singleton.
class PdfGenerator {
  static final PdfGenerator _instance = PdfGenerator._internal();
  factory PdfGenerator() => _instance;
  PdfGenerator._internal();

  // --- Constantes y Estilos Centralizados ---
  static final PdfColor _darkBrown = PdfColor.fromInt(0xFF7A4A4A);
  static final PdfColor _primaryPink = PdfColor.fromInt(0xFFF8B6B6);
  static final PdfColor _lightPinkBackground = PdfColor(
    0xF8 / 255,
    0xB6 / 255,
    0xB6 / 255,
    0.3,
  );
  static const double _defaultFontSize = 10.0;
  static const String _locale = 'es_AR';

  final currencyFormat = NumberFormat.currency(locale: _locale, symbol: '\$');

  /// 📦 Punto de entrada principal: genera los bytes del documento PDF.
  Future<Uint8List> generatePdfBytes(Order order) async {
    final pdf = pw.Document(
      title: 'Pedido N° ${order.id}',
      author: '180° Pastelería',
    );

    // Carga la fuente TTF y el logo
    final pw.Font? customFont = await _loadCustomFont();
    final pw.ImageProvider? logoImage = await _loadLogoImage();

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        theme: pw.ThemeData.withFont(
          base: customFont,
        ), // Aplica la fuente globalmente
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              _buildHeader(order, logoImage),
              pw.SizedBox(height: 20),
              _buildClientSection(order),
              pw.SizedBox(height: 20),
              // Incluimos la sección de fecha destacada
              _buildEventDateSection(order),
              pw.SizedBox(height: 20),
              _buildItemsTable(order),
              pw.SizedBox(height: 20),
              _buildNotesSection(order),
              pw.Spacer(),
              _buildFooterInfo(),
              pw.SizedBox(height: 10),
              _buildSummarySection(order),
            ],
          );
        },
      ),
    );

    return pdf.save();
  }

  // --------------------------------------------------------------------------
  // --- Lógica de Carga de Assets y Fuentes ----------------------------------
  // --------------------------------------------------------------------------

  /// Helper para cargar la imagen del logo como asset de forma segura.
  Future<pw.ImageProvider?> _loadLogoImage() async {
    try {
      final byteData = await rootBundle.load('assets/images/logo_180.png');
      return pw.MemoryImage(byteData.buffer.asUint8List());
    } catch (e) {
      if (kDebugMode) debugPrint('Error al cargar la imagen del logo: $e');
      return null;
    }
  }

  /// Carga la fuente TTF para soporte Unicode amplio (necesita el asset).
  Future<pw.Font?> _loadCustomFont() async {
    try {
      final fontData = await rootBundle.load(
        'assets/fonts/NotoSans-Regular.ttf',
      );
      return pw.Font.ttf(fontData);
    } catch (e) {
      if (kDebugMode) {
        debugPrint(
          'Error al cargar la fuente custom (usando fuente por defecto): $e',
        );
      }
      return null;
    }
  }

  // --------------------------------------------------------------------------
  // --- Widgets del Documento ------------------------------------------------
  // --------------------------------------------------------------------------

  pw.Widget _buildHeader(Order order, pw.ImageProvider? logo) {
    return pw.Container(
      decoration: pw.BoxDecoration(
        border: pw.Border(bottom: pw.BorderSide(color: _primaryPink, width: 2)),
      ),
      padding: const pw.EdgeInsets.only(bottom: 10),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        crossAxisAlignment: pw.CrossAxisAlignment.center,
        children: [
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                'Detalle del Pedido',
                style: pw.TextStyle(
                  fontSize: 24,
                  fontWeight: pw.FontWeight.bold,
                  color: _darkBrown,
                ),
              ),
              // Aviso de No Factura (Prominente)
              pw.SizedBox(height: 5),
              pw.Text(
                'Documento No Válido Como Factura ni Comprobante Fiscal',
                style: pw.TextStyle(
                  fontSize: 10,
                  color: PdfColors.red700,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.SizedBox(height: 8),

              _buildInfoRow('Pedido N°:', '${order.id}', fontSize: 12),
              _buildInfoRow(
                'Fecha de Emisión:',
                DateFormat('dd/MM/yyyy').format(DateTime.now()),
                fontSize: 12,
              ),
            ],
          ),
          if (logo != null)
            pw.Container(
              width:
                  200, // Reducido el tamaño para que quepa mejor en A4 con el texto
              height: 20300,
              child: pw.Image(logo, fit: pw.BoxFit.contain),
            )
          else
            pw.Text(
              '180°',
              style: pw.TextStyle(
                fontSize: 36,
                fontWeight: pw.FontWeight.bold,
                color: _primaryPink,
              ),
            ),
        ],
      ),
    );
  }

  pw.Widget _buildClientSection(Order order) {
    final address = order.clientAddress;
    // Se mantiene la lógica para determinar si es envío
    final isDelivery =
        (order.deliveryCost ?? 0) > 0 ||
        (address?.addressLine1?.isNotEmpty ?? false);

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        _buildSectionTitle('Detalles del Cliente y Entrega'),
        pw.SizedBox(height: 8),
        pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Expanded(
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  _buildInfoRow('Cliente:', order.client?.name ?? 'N/A'),
                  _buildInfoRow('Teléfono:', order.client?.phone ?? 'N/A'),
                  _buildInfoRow('Email:', order.client?.email ?? 'N/A'),
                ],
              ),
            ),
            pw.Expanded(
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  _buildSubSectionTitle('Entrega / Retiro'),
                  pw.SizedBox(height: 4),
                  if (address != null && isDelivery)
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        _buildInfoRow('Tipo:', 'Envío a Domicilio'),
                        _buildInfoRow('Etiqueta:', address.label ?? 'N/A'),
                        _buildInfoRow(
                          'Dirección:',
                          address.addressLine1 ?? 'N/A',
                        ),
                        if (address.notes != null && address.notes!.isNotEmpty)
                          _buildInfoRow('Notas de Envío:', address.notes!),
                      ],
                    )
                  else
                    pw.Text(
                      'Tipo: Retiro en local',
                      style: const pw.TextStyle(fontSize: _defaultFontSize),
                    ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  /// Sección destacada de fecha y hora del evento.
  pw.Widget _buildEventDateSection(Order order) {
    final String eventDateFormatted = DateFormat(
      'EEEE d \'de\' MMMM, yyyy',
      _locale,
    ).format(order.eventDate);
    final String timeRangeFormatted =
        '${DateFormat.Hm(_locale).format(order.startTime)} - ${DateFormat.Hm(_locale).format(order.endTime)}';

    final pw.TextStyle eventTitleStyle = pw.TextStyle(
      fontSize: 14,
      fontWeight: pw.FontWeight.bold,
      color: _darkBrown,
    );

    return pw.Container(
      padding: const pw.EdgeInsets.all(10),
      decoration: pw.BoxDecoration(
        color: _lightPinkBackground,
        borderRadius: pw.BorderRadius.circular(5),
        border: pw.Border.all(color: _primaryPink, width: 0.5),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            '* Fecha y Horario de Evento/Entrega (Compromiso)',
            style: eventTitleStyle,
          ),
          pw.SizedBox(height: 5),
          pw.Row(
            children: [
              _buildInfoRow(
                'Fecha:',
                eventDateFormatted,
                fontSize: _defaultFontSize + 1,
                boldLabel: true,
              ),
              pw.SizedBox(width: 30),
              _buildInfoRow(
                'Horario:',
                timeRangeFormatted,
                fontSize: _defaultFontSize + 1,
                boldLabel: true,
              ),
            ],
          ),
        ],
      ),
    );
  }

  pw.Widget _buildItemsTable(Order order) {
    final tableHeaders = [
      'Producto',
      'Detalles/Ajustes',
      'Cant.',
      'Precio Unit.',
      'Total Item',
    ];

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        _buildSectionTitle('Productos Incluidos'),
        pw.SizedBox(height: 8),
        pw.Table.fromTextArray(
          cellAlignment: pw.Alignment.centerLeft,
          headerStyle: pw.TextStyle(
            fontWeight: pw.FontWeight.bold,
            fontSize: 11,
            color: _darkBrown,
          ),
          cellStyle: const pw.TextStyle(fontSize: 10, color: PdfColors.black),
          headerDecoration: pw.BoxDecoration(color: _primaryPink),
          headers: tableHeaders,
          columnWidths: {
            0: const pw.FlexColumnWidth(2),
            1: const pw.FlexColumnWidth(3.5),
            2: const pw.FlexColumnWidth(1),
            3: const pw.FlexColumnWidth(1.5),
            4: const pw.FlexColumnWidth(1.5),
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
        ),
      ],
    );
  }

  /// ✅ Lógica COMPLETA y CORRECTA para los detalles del ítem (incluye la parte de 'Box').
  String _getItemDetailsText(OrderItem item) {
    final custom = item.customizationJson ?? {};
    final parts = <String>[];

    // 1. Notas de ajuste manual (lo más importante)
    if (item.customizationNotes != null &&
        item.customizationNotes!.isNotEmpty) {
      parts.add('Ajuste: ${item.customizationNotes}');
    }

    // 2. Precio base con ajuste manual (si aplica)
    if (item.adjustments != 0) {
      parts.add(
        'Base: ${currencyFormat.format(item.basePrice)} Ajuste: ${currencyFormat.format(item.adjustments)}',
      );
    }

    // 3. Notas generales del item (sabor/temática)
    final itemNotes = custom['item_notes'] as String?;
    if (itemNotes != null && itemNotes.isNotEmpty) {
      parts.add('Notas Item: $itemNotes');
    }

    // 4. Detalles específicos de la Torta
    if (custom['weight_kg'] != null) {
      parts.add('Peso: ${custom['weight_kg']} kg');
    }

    if (custom['selected_fillings'] is List &&
        (custom['selected_fillings'] as List).isNotEmpty) {
      parts.add(
        'Rellenos: ${(custom['selected_fillings'] as List).join(', ')}',
      );
    }

    // 5. Lógica para Box (combinación de base y ítems de mesa dulce)
    final selectedBaseCake = custom['selected_base_cake'] as String?;
    final selectedMesaDulceItems = custom['selected_mesa_dulce_items'] as List?;

    if (selectedBaseCake != null ||
        (selectedMesaDulceItems != null && selectedMesaDulceItems.isNotEmpty)) {
      final cakeText = selectedBaseCake != null ? 'Torta Base' : '';
      final itemsCount = selectedMesaDulceItems?.length ?? 0;
      final itemsText = itemsCount > 0
          ? '+ $itemsCount ítems de Mesa Dulce'
          : '';
      // Agrega el nombre del box si existe, de lo contrario solo los contenidos
      parts.add('Contenido del Box: $cakeText $itemsText'.trim());
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
        _buildSectionTitle('Notas Generales del Pedido '), // Emoji aquí
        pw.SizedBox(height: 5),
        pw.Container(
          padding: const pw.EdgeInsets.all(8),
          decoration: pw.BoxDecoration(
            border: pw.Border.all(color: PdfColors.grey400),
            borderRadius: pw.BorderRadius.circular(5),
            color: PdfColors.grey100,
          ),
          child: pw.Text(
            order.notes!,
            style: pw.TextStyle(
              fontSize: _defaultFontSize,
              fontStyle: pw.FontStyle.italic,
            ),
          ),
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
          pw.Divider(
            color: _darkBrown,
            thickness: 1.5,
          ), // Separador profesional
          _buildSummaryRow('TOTAL PEDIDO:', total, isTotal: true),
          if (deposit > 0)
            _buildSummaryRow('Seña Recibida:', deposit, isDeposit: true),
          if (balance > 0)
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

  pw.Widget _buildFooterInfo() {
    return pw.Container(
      alignment: pw.Alignment.centerLeft,
      padding: const pw.EdgeInsets.symmetric(vertical: 10),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          // Aviso de no factura en el pie (refuerzo)
          pw.Text(
            'AVISO: Este documento es un detalle de pedido/proforma y no tiene validez como Factura A, B o C.',
            style: pw.TextStyle(
              fontSize: 9,
              color: PdfColors.red700,
              fontStyle: pw.FontStyle.italic,
            ),
          ),
          pw.SizedBox(height: 5),

          pw.Text(
            'Términos y Condiciones Breves:',
            style: pw.TextStyle(
              fontSize: _defaultFontSize,
              fontWeight: pw.FontWeight.bold,
              color: _darkBrown,
            ),
          ),
          pw.Text(
            '* Los cambios o cancelaciones del pedido están sujetos a disponibilidad y deben ser notificados con un mínimo de 48 horas de anticipación. \n'
            '* El saldo pendiente (si aplica) debe abonarse al momento de la entrega o retiro del pedido.',
            style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700),
          ),
        ],
      ),
    );
  }

  // --------------------------------------------------------------------------
  // --- Funciones Auxiliares (Añadidas para la compilación y estilo) ---------
  // --------------------------------------------------------------------------

  /// 🛠️ Construye una fila para los totales.
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
            color: isBalance ? PdfColors.red : _darkBrown,
          )
        : const pw.TextStyle(fontSize: 12, color: PdfColors.black);

    final value = currencyFormat.format(amount.abs());

    return pw.Padding(
      padding: const pw.EdgeInsets.only(top: 2, bottom: 2),
      child: pw.Row(
        mainAxisSize: pw.MainAxisSize.min,
        children: [
          pw.Container(width: 140, child: pw.Text(label, style: style)),
          pw.Container(
            width: 90,
            alignment: pw.Alignment.centerRight,
            child: pw.Text(value, style: style),
          ),
        ],
      ),
    );
  }

  /// 🛠️ Construye el título de una sección.
  pw.Widget _buildSectionTitle(String title) {
    return pw.Text(
      title,
      style: pw.TextStyle(
        fontSize: 16,
        fontWeight: pw.FontWeight.bold,
        color: _darkBrown,
      ),
    );
  }

  /// 🛠️ Construye el título de una sub-sección.
  pw.Widget _buildSubSectionTitle(String title) {
    return pw.Text(
      title,
      style: pw.TextStyle(
        fontSize: _defaultFontSize + 1,
        fontWeight: pw.FontWeight.bold,
        color: PdfColors.black,
      ),
    );
  }

  /// 🛠️ Construye una fila simple de información (Label: Value).
  pw.Widget _buildInfoRow(
    String label,
    String value, {
    double fontSize = _defaultFontSize,
    bool boldLabel = false,
  }) {
    return pw.Row(
      children: [
        pw.Text(
          label,
          style: pw.TextStyle(
            fontSize: fontSize,
            fontWeight: boldLabel ? pw.FontWeight.bold : pw.FontWeight.normal,
          ),
        ),
        pw.SizedBox(width: 5),
        pw.Text(value, style: pw.TextStyle(fontSize: fontSize)),
      ],
    );
  }
}
