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

    final bg = _statusPastelBg[order.status] ?? _kPastelSand;
    final ink =
        _statusInk[order.status] ?? _kInkSand; // Color de acento principal
    final textTheme = Theme.of(context).textTheme;

    // Color de texto principal (ligeramente más suave que negro puro)
    final primaryTextColor = Colors.black.withOpacity(0.8);
    // Color de texto secundario (para fecha/hora)
    final secondaryTextColor = Colors.black.withOpacity(0.6);

    // Formatear fecha y hora combinadas
    final String dateTimeString =
        '${DateFormat("E d MMM", 'es_AR').format(order.eventDate)}・${DateFormat.Hm().format(order.startTime)}';

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      elevation: 2.5, // Sombra sutil restaurada
      shadowColor: Colors.black.withOpacity(0.50), // Sombra aún más suave
      color: bg,
      surfaceTintColor:
          Colors.transparent, // Importante para que no tome tint del tema
      shape: RoundedRectangleBorder(
        // Sin borde explícito, confiamos en la sombra y el color de fondo
        // side: BorderSide(color: ink.withOpacity(0.25), width: 0.8),
        borderRadius: BorderRadius.circular(12), // Un poco más redondeado
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => context.push('/order/${order.id}'),
        splashColor: ink.withOpacity(0.1), // Splash con color de acento
        highlightColor: ink.withOpacity(0.05), // Highlight con color de acento
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: 14,
            vertical: 12,
          ), // Padding vertical aumentado ligeramente
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
                        fontWeight:
                            FontWeight.w600, // Un poco más bold que antes
                        color: primaryTextColor,
                        letterSpacing: 0.1, // Ligero espaciado
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
                      fontWeight: FontWeight.w600, // Consistente con el nombre
                      color: primaryTextColor,
                      letterSpacing: 0.1,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8), // Más espacio aquí
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
                        color: secondaryTextColor,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        dateTimeString,
                        style: textTheme.bodySmall?.copyWith(
                          color: secondaryTextColor,
                        ), // bodySmall es bueno aquí
                      ),
                    ],
                  ),

                  // Dropdown con apariencia de "Chip" sutil
                  Material(
                    // Necesario para InkWell y borde redondeado dentro de Card
                    color: Colors.transparent,
                    child: InkWell(
                      // Para que toda el área sea tappable, no solo el icono
                      borderRadius: BorderRadius.circular(8),
                      // splashColor: ink.withOpacity(0.1), // Opcional: splash en el dropdown
                      // highlightColor: ink.withOpacity(0.05),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ), // Padding interno
                        decoration: BoxDecoration(
                          //color: ink.withOpacity(0.05), // Fondo muy sutil opcional
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: ink.withOpacity(0.4),
                            width: 0.8,
                          ), // Borde sutil
                        ),
                        child: DropdownButtonHideUnderline(
                          // Quita la línea por defecto
                          child: DropdownButton<String>(
                            value: order.status,
                            icon: Icon(
                              Icons.arrow_drop_down,
                              size: 18,
                              color: ink.withOpacity(0.8),
                            ), // Icono más pequeño
                            isDense: true,
                            // Estilo del texto seleccionado en el botón
                            style: textTheme.labelSmall?.copyWith(
                              color: ink, // Color principal del estado
                              fontWeight: FontWeight.w600,
                              fontSize:
                                  10.5, // Ligeramente más grande que en el menú
                            ),
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
                                      // Estilo del texto en el menú desplegado
                                      style: textTheme.bodySmall?.copyWith(
                                        fontSize: 12,
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
