part of '../home_page.dart';

// Paleta pastel (SIN CAMBIOS)
const _kPastelBabyBlue = Color(0xFFDFF1FF);
const _kPastelMint = Color(0xFFD8F6EC);
const _kPastelSand = Color(0xFFF6EEDF);

const _kInkBabyBlue = Color(0xFF8CC5F5);
const _kInkMint = Color(0xFF83D1B9);
const _kInkSand = Color(0xFFC9B99A);

// Fondos pastel por estado (SIN CAMBIOS)
const _statusPastelBg = <String, Color>{
  'confirmed': _kPastelMint,
  'ready': Color(0xFFFFE6EF),
  'delivered': _kPastelBabyBlue,
  'canceled': Color(0xFFFFE0E0),
};

// Acento/borde por estado (SIN CAMBIOS)
const _statusInk = <String, Color>{
  'confirmed': _kInkMint,
  'ready': Color(0xFFF3A9B9),
  'delivered': _kInkBabyBlue,
  'canceled': Color(0xFFE57373),
};

// Traducciones visibles (SIN CAMBIOS)
const _statusTranslations = {
  'confirmed': 'Confirmado',
  'ready': 'Listo',
  'delivered': 'Entregado',
  'canceled': 'Cancelado',
};

class OrderCard extends ConsumerWidget {
  const OrderCard({super.key, required this.order});
  final Order order;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final fmt = NumberFormat(r"'$' #,##0.00", 'es_AR');
    final totalString = fmt.format(order.total); // Usando order.total

    // --- 👇 ADAPTACIÓN TEMA 👇 ---
    // 1. Obtenemos el tema y el ColorScheme
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final textTheme = theme.textTheme;
    final isDarkMode = theme.brightness == Brightness.dark;

    // 2. Obtenemos los colores semánticos (esto no cambia)
    final bg = _statusPastelBg[order.status] ?? _kPastelSand;
    final ink =
        _statusInk[order.status] ?? _kInkSand; // Color de acento principal

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
      shadowColor: isDarkMode
          ? Colors.transparent
          : Colors.black.withOpacity(0.50),
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
        splashColor: ink.withOpacity(0.1), // Splash con color de acento
        highlightColor: ink.withOpacity(0.05), // Highlight con color de acento
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
                            color: ink.withOpacity(0.4),
                            width: 0.8,
                          ),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: order.status,
                            icon: Icon(
                              Icons.arrow_drop_down,
                              size: 18,
                              color: ink.withOpacity(0.8),
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
                            items: _statusTranslations.keys.map((String value) {
                              final c = _statusInk[value] ?? _kInkSand;
                              return DropdownMenuItem<String>(
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
                                      _statusTranslations[value]!,
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
                            onChanged: (String? newValue) async {
                              if (newValue != null &&
                                  newValue != order.status) {
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
