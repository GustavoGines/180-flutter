part of '../home_page.dart';

// Paleta pastel
const _kPastelBabyBlue = Color(0xFFDFF1FF);
const _kPastelMint     = Color(0xFFD8F6EC);
const _kPastelSand     = Color(0xFFF6EEDF);

const _kInkBabyBlue = Color(0xFF8CC5F5);
const _kInkMint     = Color(0xFF83D1B9);
const _kInkSand     = Color(0xFFC9B99A);

// Fondos pastel por estado
const _statusPastelBg = <String, Color>{
  'confirmed': _kPastelMint,
  'ready'    : Color(0xFFFFE6EF),
  'delivered': _kPastelBabyBlue,
  'canceled' : Color(0xFFFFE0E0),
};

// Acento/borde por estado
const _statusInk = <String, Color>{
  'confirmed': _kInkMint,
  'ready'    : Color(0xFFF3A9B9),
  'delivered': _kInkBabyBlue,
  'canceled' : Color(0xFFE57373),
};

// Traducciones visibles
const _statusTranslations = {
  'confirmed': 'Confirmado',
  'ready'    : 'Listo',
  'delivered': 'Entregado',
  'canceled' : 'Cancelado',
};

class OrderCard extends ConsumerWidget {
  const OrderCard({super.key, required this.order});
  final Order order;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final fmt = NumberFormat(r"'$' #,##0.00", 'es_AR');
    final totalString = fmt.format(order.total);

    final bg = _statusPastelBg[order.status] ?? _kPastelSand;
    final ink = _statusInk[order.status] ?? _kInkSand;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      elevation: 2,
      color: bg,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        side: BorderSide(color: ink.withValues(alpha: 0.45), width: 1.4),
        borderRadius: BorderRadius.circular(16),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => context.push('/order/${order.id}'),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Expanded(
                child: Text(
                  order.client?.name ?? 'Cliente no especificado',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18, color: Colors.black.withValues(alpha: 0.85)),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Text(totalString, style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18, color: Colors.black.withValues(alpha: 0.9))),
            ]),
            const SizedBox(height: 8),
            _InfoRow(icon: Icons.calendar_today, text: DateFormat("EEEE d 'de' MMMM", 'es_AR').format(order.eventDate)),
            const SizedBox(height: 4),
            _InfoRow(icon: Icons.access_time, text: '${DateFormat.Hm().format(order.startTime)} - ${DateFormat.Hm().format(order.endTime)}'),
            const Divider(height: 24),
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: ink.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(99),
                  border: Border.all(color: ink.withValues(alpha: 0.35)),
                ),
                child: Text(
                  _statusTranslations[order.status] ?? order.status,
                  style: TextStyle(color: ink.withValues(alpha: 0.95), fontWeight: FontWeight.w600, letterSpacing: .2),
                ),
              ),
              DropdownButton<String>(
                value: order.status,
                underline: const SizedBox(),
                icon: const Icon(Icons.arrow_drop_down_rounded),
                items: _statusTranslations.keys.map((String value) {
                  final c = _statusInk[value] ?? _kInkSand;
                  return DropdownMenuItem<String>(
                    value: value,
                    child: Row(children: [
                      Container(width: 12, height: 12, decoration: BoxDecoration(color: c, shape: BoxShape.circle)),
                      const SizedBox(width: 8),
                      Text(_statusTranslations[value]!),
                    ]),
                  );
                }).toList(),
                onChanged: (String? newValue) async {
                  if (newValue != null && newValue != order.status) {
                    await ref.read(ordersWindowProvider.notifier).updateOrderStatus(order.id, newValue);
                  }
                },
              ),
            ]),
          ]),
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String text;
  const _InfoRow({required this.icon, required this.text});
  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Icon(icon, size: 16, color: Colors.black54),
      const SizedBox(width: 8),
      Expanded(child: Text(text, style: const TextStyle(fontSize: 15, color: Colors.black87))),
    ]);
  }
}
