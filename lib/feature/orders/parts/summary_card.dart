part of '../home_page.dart';

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.title, required this.value, required this.positive});
  final String title; final double value; final bool positive;

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat(r"'$' #,##0.00", 'es_AR');
    final show = (positive && value >= 0) ? '+${fmt.format(value)}' : fmt.format(value);
    final color = positive ? Colors.green : Colors.red;

    return Container(
      height: 72,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(18),
        boxShadow: const [BoxShadow(blurRadius: 10, offset: Offset(0, 4), color: Colors.black12)],
        border: Border.all(color: color.withOpacity(.25), width: 1),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Row(
        children: [
          Icon(positive ? Icons.trending_up : Icons.outbond_rounded, color: color),
          const SizedBox(width: 10),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, style: Theme.of(context).textTheme.labelLarge?.copyWith(color: Colors.white70)),
              const Spacer(),
              Text(show, style: TextStyle(fontWeight: FontWeight.w800, color: color, fontSize: 16)),
            ]),
          ),
        ],
      ),
    );
  }
}
