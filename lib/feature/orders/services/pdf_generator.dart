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

  // ---
  // --- 👇 CORRECCIÓN 1: Formateador solo para NÚMEROS (sin moneda) ---
  // ---
  final currencyFormat = NumberFormat(
    r"#,##0", // Patrón para números enteros con separador de miles
    'es_AR',
  );
  // ---

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
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        theme: pw.ThemeData.withFont(base: customFont),
        header: (context) => _buildHeader(order, logoImage),
        footer: (context) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            _buildFooterInfo(),
            pw.Divider(color: PdfColors.grey),
            pw.Align(
              alignment: pw.Alignment.centerRight,
              child: pw.Text(
                'Página ${context.pageNumber} de ${context.pagesCount}',
                style: pw.TextStyle(
                  fontSize: 9,
                  color: PdfColors.grey700,
                  fontStyle: pw.FontStyle.italic,
                ),
              ),
            ),
          ],
        ),
        build: (pw.Context context) => [
          _buildClientSection(order),
          pw.SizedBox(height: 20),
          _buildEventDateSection(order),
          pw.SizedBox(height: 20),
          // Ponemos el título y el espaciado aquí,
          // antes de llamar a la tabla.
          _buildSectionTitle('Productos Incluidos'),
          pw.SizedBox(height: 8),
          _buildItemsTable(order), // Ahora esto es solo la tabla
          pw.SizedBox(height: 20),
          _buildNotesSection(order),
          pw.SizedBox(height: 20),
          _buildSummarySection(order),
        ],
      ),
    );

    return pdf.save();
  }

  // ... (El resto de _loadLogoImage y _loadCustomFont se mantiene igual) ...

  Future<pw.ImageProvider?> _loadLogoImage() async {
    try {
      final byteData = await rootBundle.load('assets/images/logo_180.png');
      return pw.MemoryImage(byteData.buffer.asUint8List());
    } catch (e) {
      if (kDebugMode) debugPrint('Error al cargar la imagen del logo: $e');
      return null;
    }
  }

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
  // --- Widgets del Documento (Header, Client, Event) ------------------------
  // --------------------------------------------------------------------------

  // ... (Header, Client, Event se mantienen igual) ...

  pw.Widget _buildHeader(Order order, pw.ImageProvider? logo) {
    // Define el tamaño deseado para el logo y el padding necesario
    const double logoHeight = 100.0; // Grande y visible
    const double logoWidth = 100.0;

    // Altura total necesaria para el Container exterior (Logo + Margen)
    const double headerHeight = logoHeight + 1;

    return pw.Container(
      height: headerHeight,
      child: pw.Stack(
        children: [
          // === 1. Contenedor principal de texto con línea inferior ===
          pw.Container(
            padding: pw.EdgeInsets.only(right: logoWidth + 20),
            decoration: pw.BoxDecoration(
              border: pw.Border(
                bottom: pw.BorderSide(
                  color: _primaryPink,
                  width: 2,
                ), // 👈 LÍNEA DIVISORIA
              ),
            ),
            child: pw.Column(
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
                pw.SizedBox(height: 10),
              ],
            ),
          ),

          // === 2. Logo a la derecha ===
          if (logo != null)
            pw.Positioned(
              right: 0,
              top: 0,
              child: pw.Container(
                width: logoWidth,
                height: logoHeight,
                child: pw.Image(logo, fit: pw.BoxFit.contain),
              ),
            )
          else
            pw.Positioned(
              right: 0,
              top: 0,
              child: pw.Text(
                '180°',
                style: pw.TextStyle(
                  fontSize: 36,
                  fontWeight: pw.FontWeight.bold,
                  color: _primaryPink,
                ),
              ),
            ),
        ],
      ),
    );
  }

  pw.Widget _buildClientSection(Order order) {
    final address = order.clientAddress;
    final isDelivery = (order.deliveryCost ?? 0) > 0 ||
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
                        _buildInfoRow('Ubicación:', address.label ?? 'N/A'),
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

    return pw.Table.fromTextArray(
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
          '\$${currencyFormat.format(item.finalUnitPrice)}',
          '\$${currencyFormat.format(itemTotal)}',
        ];
      }).toList(),
    );
  }

  // Reemplazar la función _getItemDetailsText completa

  String _getItemDetailsText(OrderItem item) {
    final custom = item.customizationJson ?? {};
    final parts = <String>[];

    final category = custom['product_category']?.toString() ?? '';

    // =======================================================
    // === CASO BOX
    // =======================================================
    if (category == 'box') {
      final String boxType = custom['box_type'] ?? '';
      final bool isPersonalizado = boxType == 'BOX DULCE Personalizado (Armar)';

      // Definir si es Torta Chica (Misma lógia que antes)
      const miniCakeName = 'Mini Torta Personalizada (Base)';
      const microCakeName = 'Micro Torta (Base)';
      final String? baseCakeName = custom['selected_base_cake'] as String?;

      bool isSmallCake;
      if (isPersonalizado) {
        isSmallCake =
            baseCakeName == miniCakeName || baseCakeName == microCakeName;
      } else {
        isSmallCake = true;
      }

      final double costMultiplier = isSmallCake ? 0.5 : 1.0;

      final List<dynamic> fillingsRaw = custom['selected_fillings'] ?? [];
      final List<dynamic> extraFillingsRaw =
          custom['selected_extra_fillings'] ?? [];
      final List<Map> extraFillingsData =
          extraFillingsRaw.whereType<Map>().toList();
      final List<dynamic> extrasKgRaw = custom['selected_extras_kg'] ?? [];
      final List<Map> extrasKgData = extrasKgRaw.whereType<Map>().toList();
      final List<Map<String, dynamic>> extrasUnitData =
          (custom['selected_extras_unit'] as List?)
                  ?.whereType<Map<String, dynamic>>()
                  .toList() ??
              [];
      final List<Map<String, dynamic>> mesaDulceItems =
          (custom['selected_mesa_dulce_items'] as List?)
                  ?.whereType<Map<String, dynamic>>()
                  .toList() ??
              [];
      final bool hasExtras = extraFillingsData.isNotEmpty ||
          extrasKgData.isNotEmpty ||
          extrasUnitData.isNotEmpty;

      if (isPersonalizado) {
        if (fillingsRaw.isNotEmpty) {
          parts.add('Rellenos Torta: ${_formatCustomizationList(fillingsRaw)}');
        }
        if (extraFillingsData.isNotEmpty) {
          parts.add(
            'Extras Torta: ${_formatCustomizationList(extraFillingsRaw, multiplier: costMultiplier)}',
          );
        }
        if (extrasKgData.isNotEmpty) {
          parts.add(
            'Extras Torta (x kg): ${_formatCustomizationList(extrasKgRaw, multiplier: costMultiplier)}',
          );
        }
        if (extrasUnitData.isNotEmpty) {
          parts.add(
            'Extras Torta (x ud): ${_formatCustomizationList(extrasUnitData, useQuantity: true)}',
          );
        }
        if (mesaDulceItems.isNotEmpty) {
          final text = mesaDulceItems.map((e) {
            final name = e['name'];
            final qty = e['quantity'];
            final size = e['selected_size'];
            return size != null
                ? '$name (${size.replaceAll('size', '')}) x$qty'
                : '$name x$qty';
          }).join(', ');
          parts.add('Mesa Dulce: $text');
        }
      } else {
        // BOX PREDEFINIDO
        if (hasExtras) {
          parts.add('Precio Box: \$${currencyFormat.format(item.basePrice)}');
        }
        if (fillingsRaw.isNotEmpty) {
          parts.add('Rellenos: ${_formatCustomizationList(fillingsRaw)}');
        }
        if (extraFillingsData.isNotEmpty) {
          parts.add(
            'Rellenos Extra: ${_formatCustomizationList(extraFillingsRaw, multiplier: costMultiplier)}',
          );
        }
        if (extrasKgData.isNotEmpty) {
          parts.add(
            'Extras (x kg): ${_formatCustomizationList(extrasKgRaw, multiplier: costMultiplier)}',
          );
        }
        if (extrasUnitData.isNotEmpty) {
          parts.add(
            'Extras (x unidad): ${_formatCustomizationList(extrasUnitData, useQuantity: true)}',
          );
        }
        final double manualAdjustment =
            (custom['manual_adjustment_value'] as num?)?.toDouble() ?? 0.0;
        if (manualAdjustment != 0) {
          parts.add(
            'Ajuste Adicional (fijo): \$${currencyFormat.format(manualAdjustment)}',
          );
        }
      }
    }

    // =======================================================
    // === CASO TORTA
    // =======================================================
    else if (category == 'torta') {
      const miniCakeName = 'Mini Torta Personalizada (Base)';
      const microCakeName = 'Micro Torta (Base)';

      final bool isSmallCake =
          item.name == miniCakeName || item.name == microCakeName;
      final double weight = (custom['weight_kg'] as num?)?.toDouble() ?? 1.0;
      final double extraMultiplier = isSmallCake ? 0.5 : weight;

      // Calcular precio base (inverso) para mostrar desglose
      // (Simplificado respecto al original para legibilidad)
      final List<dynamic> extraFillingsRaw =
          custom['selected_extra_fillings'] ?? [];
      final List<dynamic> extrasKgRaw = custom['selected_extras_kg'] ?? [];
      final List<dynamic> extrasUnitRaw = custom['selected_extras_unit'] ?? [];

      double calcExtras(List l, double mult, [bool useQty = false]) =>
          l.fold(0.0, (sum, data) {
            final price =
                (data is Map ? (data['price'] as num?)?.toDouble() : null) ??
                    0.0;
            final qty = useQty
                ? ((data is Map
                        ? (data['quantity'] as num?)?.toDouble()
                        : null) ??
                    1.0)
                : 1.0;
            return sum + (price * mult * qty);
          });

      final double costoExtras = calcExtras(extraFillingsRaw, extraMultiplier) +
          calcExtras(extrasKgRaw, extraMultiplier) +
          calcExtras(extrasUnitRaw, 1.0, true);

      final double precioBaseCalculado = item.basePrice - costoExtras;

      parts.add('Precio Base: \$${currencyFormat.format(precioBaseCalculado)}');

      final List<dynamic> fillingsRaw = custom['selected_fillings'] ?? [];
      if (fillingsRaw.isNotEmpty)
        parts.add('Rellenos: ${_formatCustomizationList(fillingsRaw)}');
      if (extraFillingsRaw.isNotEmpty)
        parts.add(
            'Rellenos Extra: ${_formatCustomizationList(extraFillingsRaw, multiplier: extraMultiplier)}');
      if (extrasKgRaw.isNotEmpty)
        parts.add(
            'Extras (x kg): ${_formatCustomizationList(extrasKgRaw, multiplier: extraMultiplier)}');
      if (extrasUnitRaw.isNotEmpty)
        parts.add(
            'Extras (x ud): ${_formatCustomizationList(extrasUnitRaw, useQuantity: true)}');

      if (custom['weight_kg'] != null && !isSmallCake) {
        parts.add('Peso: ${custom['weight_kg']} kg');
      }
    }

    // =======================================================
    // === CASO MESA DULCE / OTROS
    // =======================================================
    else {
      // 1. Variante / Tamaño / Unidad
      final String? variantName = custom['variant_name'];
      final String? selectedSize = custom['selected_size'];
      final bool isHalfDozen = custom['is_half_dozen'] == true;
      final String? productUnit = custom['product_unit'];
      final bool isUnitSaleForDozen = custom['is_unit_sale_for_dozen'] == true;

      if (variantName != null && variantName.isNotEmpty) {
        String formatted = variantName.startsWith('size')
            ? variantName.replaceFirst('size', '')
            : variantName;
        // Si es una variante con precio, a veces es útil mostrarla como "Variante: X"
        parts.add('Variante: $formatted');
      } else if (selectedSize != null && selectedSize.isNotEmpty) {
        String formatted = selectedSize.startsWith('size')
            ? selectedSize.replaceFirst('size', '')
            : selectedSize;
        parts.add('Tamaño: $formatted');
      } else if (isHalfDozen) {
        parts.add('Presentación: Media Docena');
      } else if (productUnit == 'dozen') {
        if (isUnitSaleForDozen) {
          parts.add('Presentación: Por Unidad (Suela)');
        } else {
          // Es docena completa
          final qty = item.qty;
          final label = qty == 1 ? '1 Docena' : '$qty Docenas';
          parts.add('Presentación: Docena ($label)');
        }
      }

      // 2. Rellenos (Mesa Dulce)
      final List<dynamic> fillingsRaw = custom['selected_fillings'] ?? [];
      if (fillingsRaw.isNotEmpty) {
        parts.add('Rellenos: ${_formatCustomizationList(fillingsRaw)}');
      }
    }

    // =======================================================
    // === COMUNES (Bottom)
    // =======================================================

    // Ajustes Manuales Generales
    // (En Torta/MesaDulce está en item.adjustments. En Box está en manual_adjustment_value y ya se sumó arriba, pero chequeamos por las dudas para no duplicar si la lógica cambia)
    if (category != 'box' && item.adjustments != 0) {
      parts.add(
          'Ajuste Adicional: \$${currencyFormat.format(item.adjustments)}');
    }

    // Notas de Ajuste (customizationNotes)
    if (item.customizationNotes != null &&
        item.customizationNotes!.trim().isNotEmpty) {
      parts.add('Notas de Ajuste: ${item.customizationNotes}');
    }

    // Notas del Item (item_notes)
    final String? itemNotes = custom['item_notes'];
    if (itemNotes != null && itemNotes.trim().isNotEmpty) {
      parts.add('Notas del Item: $itemNotes');
    }

    return parts.join('\n');
  }

  pw.Widget _buildNotesSection(Order order) {
    if (order.notes == null || order.notes!.isEmpty) {
      return pw.SizedBox.shrink();
    }
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        _buildSectionTitle('Notas Generales del Pedido'),
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
          pw.Divider(color: _darkBrown, thickness: 1.5),
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
  // --- Auxiliares ------------------------------------------------------------
  // --------------------------------------------------------------------------

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

    // --- 👇 CORRECCIÓN 8: Añadir '$' manualmente ---
    final value = '\$${currencyFormat.format(amount.abs())}';

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

  // Helper para formatear listas de customización (rellenos, extras)
  String _formatCustomizationList(
    List<dynamic> rawList, {
    double multiplier = 1.0, // <-- Acepta un multiplicador (default 1.0)
    bool useQuantity = false, // <-- Flag para saber si es "por unidad"
  }) {
    return rawList.map((e) {
      if (e is Map && e['name'] != null) {
        final name = e['name'];
        final qty = (e['quantity'] as num?) ?? 1;
        final price = (e['price'] as num?)?.toDouble() ?? 0.0;

        String priceText = '';
        if (price != 0) {
          // --- LÓGICA DE PRECIO CORREGIDA ---
          double totalCost;
          if (useQuantity) {
            // Es "Extra por Unidad" (ej: Flores x3) -> Multiplica por cantidad
            totalCost = price * (qty > 0 ? qty : 1);
          } else {
            // Es "Relleno Extra" o "Extra x Kg" -> Multiplica por el multiplicador (0.5 o peso)
            totalCost = price * multiplier;
          }
          // --- FIN LÓGICA ---
          priceText = ' (\$${currencyFormat.format(totalCost)})';
        }

        return (useQuantity && qty > 1)
            ? '$name x$qty$priceText'
            : '$name$priceText';
      } else {
        // Para Rellenos Base (que son List<String>)
        return e.toString();
      }
    }).join(', ');
  }
}
