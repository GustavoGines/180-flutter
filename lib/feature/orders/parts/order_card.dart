part of '../home_page.dart';

// Colores locales removidos, usa shared themes


class OrderCard extends ConsumerWidget {
  const OrderCard({super.key, required this.order});
  final Order order;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final fmt = NumberFormat(r"'$' #,##0", 'es_AR');
    final totalString = fmt.format(order.total); // Usando order.total

    // --- 👇 ADAPTACIÓN TEMA 👇 ---
    // 1. Obtenemos el tema y el ColorScheme
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final textTheme = theme.textTheme;
    final isDarkMode = theme.brightness == Brightness.dark;

    // 2. Obtenemos los colores semánticos (esto no cambia)
    final bg = kStatusPastelBg[order.status] ?? kStatusBgFallback;
    final ink =
        kStatusInk[order.status] ?? kStatusInkFallback; // Color de acento principal

    // 3. Los colores de texto AHORA dependen del tema
    final primaryTextColor = cs.onSurface; // (Negro en light, Blanco en dark)
    final secondaryTextColor = cs.onSurfaceVariant; // (Gris en light y dark)
    // --- 👆 FIN ADAPTACIÓN 👆 ---

    // Formatear fecha y hora combinadas
    final String dateTimeString =
        '${DateFormat("E d MMM", 'es_AR').format(order.eventDate)}・${DateFormat.Hm().format(order.startTime)}';

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      elevation: 2.5,
      // --- 👇 ADAPTACIÓN TEMA 👇 ---
      // 4. La sombra solo se aplica en modo claro
      shadowColor:
          isDarkMode ? Colors.transparent : Colors.black.withValues(alpha: 0.50),
      // 5. El color de fondo de la tarjeta depende del tema
      color: isDarkMode
          ? cs.surface
          : bg, // (DarkSurface en dark, Pastel en light)
      // --- 👆 FIN ADAPTACIÓN 👆 ---
      surfaceTintColor:
          Colors.transparent, // Importante para que no tome tint del tema
      shape: RoundedRectangleBorder(
        // --- 👇 ADAPTACIÓN TEMA 👇 ---
        // 6. Añadimos un borde lateral en modo oscuro para mostrar el estado
        side: isDarkMode
            ? BorderSide(color: ink, width: 2.0)
            : BorderSide.none, // En modo claro, el fondo 'bg' es suficiente
        // --- 👆 FIN ADAPTACIÓN 👆 ---
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => context.push('/order/${order.id}'),
        splashColor: ink.withValues(alpha: 0.1), // Splash con color de acento
        highlightColor: ink.withValues(alpha: 0.05), // Highlight con color de acento
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // --- Fila 1: Cliente y Total ---
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      order.client?.name ?? 'Cliente no especificado',
                      style: textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                        // --- 👇 ADAPTADO 👇 ---
                        color: primaryTextColor,
                        // --- 👆 FIN 👆 ---
                        letterSpacing: 0.1,
                      ),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                      softWrap: false,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Row(
                    children: [
                      // Contador de ítems
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: isDarkMode ? cs.surfaceContainerHighest : cs.primary.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '${order.items.length} ítems',
                          style: textTheme.labelSmall?.copyWith(
                            color: isDarkMode ? cs.onSurfaceVariant : cs.primary,
                            fontWeight: FontWeight.bold,
                            fontSize: 10,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      // 👇 NUEVO: Icono de "Pagado"
                      if (order.isPaid)
                        Padding(
                          padding: const EdgeInsets.only(right: 6.0),
                          child: Icon(
                            Icons.monetization_on,
                            size: 16,
                            color: Colors
                                .green.shade600, // Color distintivo para pagado
                          ),
                        ),
                      Text(
                        totalString,
                        style: textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                          // --- 👇 ADAPTADO 👇 ---
                          color: primaryTextColor,
                          // --- 👆 FIN 👆 ---
                          letterSpacing: 0.1,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              // 👇 NUEVO: Desglose financiero si hay seña
              if (order.paidAmount > 0) ...[
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: isDarkMode ? cs.surfaceContainerHighest.withValues(alpha: 0.5) : Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: isDarkMode ? cs.outlineVariant : Colors.grey.shade300),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Total: $totalString',
                        style: textTheme.labelSmall?.copyWith(color: secondaryTextColor),
                      ),
                      Row(
                        children: [
                          Text(
                            'Seña: ${fmt.format(order.paidAmount)}',
                            style: textTheme.labelSmall?.copyWith(
                              color: isDarkMode ? Colors.green.shade400 : Colors.green.shade700,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(width: 8),
                          if (order.paidAmount >= (order.total ?? 0))
                            Text(
                              'Pagado en su totalidad',
                              style: textTheme.labelSmall?.copyWith(
                                color: isDarkMode ? Colors.green.shade400 : Colors.green.shade700,
                                fontWeight: FontWeight.bold,
                              ),
                            )
                          else
                            Text(
                              'Saldo: ${fmt.format((order.total ?? 0) - order.paidAmount)}',
                              style: textTheme.labelSmall?.copyWith(
                                color: isDarkMode ? Colors.orange.shade400 : Colors.orange.shade800,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 8),
              // --- Fila 2: Fecha/Hora y Dropdown de Estado ---
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Fecha y Hora combinadas
                  Row(
                    children: [
                      Icon(
                        Icons.calendar_today_outlined,
                        size: 13,
                        // --- 👇 ADAPTADO 👇 ---
                        color: secondaryTextColor,
                        // --- 👆 FIN 👆 ---
                      ),
                      const SizedBox(width: 4),
                      Text(
                        dateTimeString,
                        style: textTheme.bodySmall?.copyWith(
                          // --- 👇 ADAPTADO 👇 ---
                          color: secondaryTextColor,
                          // --- 👆 FIN 👆 ---
                        ),
                      ),
                    ],
                  ),

                  // Dropdown con apariencia de "Chip" sutil
                  Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: ink.withValues(alpha: 0.4),
                            width: 0.8,
                          ),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<OrderStatus>(
                            value: order.status,
                            icon: Icon(
                              Icons.arrow_drop_down,
                              size: 18,
                              color: ink.withValues(alpha: 0.8),
                            ),
                            isDense: true,
                            // Estilo del texto seleccionado (ya usa 'ink', está perfecto)
                            style: textTheme.labelSmall?.copyWith(
                              color: ink,
                              fontWeight: FontWeight.w600,
                              fontSize: 10.5,
                            ),
                            // --- 👇 ADAPTACIÓN TEMA 👇 ---
                            // 7. El fondo del menú desplegable debe usar el tema
                            dropdownColor: cs.surface,
                            // --- 👆 FIN ADAPTACIÓN 👆 ---
                            items: kStatusTranslations.keys
                                .map((OrderStatus value) {
                              final c = kStatusInk[value] ?? kStatusInkFallback;
                              return DropdownMenuItem<OrderStatus>(
                                value: value,
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Container(
                                      width: 8,
                                      height: 8,
                                      decoration: BoxDecoration(
                                        color: c,
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      kStatusTranslations[value]!,
                                      // Estilo en el menú desplegado (ya es dinámico)
                                      style: textTheme.bodySmall?.copyWith(
                                        fontSize: 12,
                                        // 8. Aseguramos el color del texto en el menú
                                        color: cs.onSurface,
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }).toList(),
                            onChanged: (OrderStatus? newValue) async {
                              if (newValue != null && newValue != order.status) {
                                if (newValue == OrderStatus.canceled) {
                                  final confirm = await showDialog<bool>(
                                    context: context,
                                    builder: (context) => AlertDialog(
                                      title: const Text('Confirmar Cancelación'),
                                      content: const Text('¿Estás seguro de que deseas cancelar este pedido?'),
                                      actions: [
                                        TextButton(
                                          onPressed: () => Navigator.of(context).pop(false),
                                          child: const Text('No'),
                                        ),
                                        ElevatedButton(
                                          onPressed: () => Navigator.of(context).pop(true),
                                          style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                                          child: const Text('Sí, cancelar', style: TextStyle(color: Colors.white)),
                                        ),
                                      ],
                                    ),
                                  );
                                  if (confirm != true) return;
                                }

                                await ref
                                    .read(ordersWindowProvider.notifier)
                                    .updateOrderStatus(order.id, newValue);
                              }
                            },
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
} // Fin OrderCard
