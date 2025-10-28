part of '../home_page.dart';

class _DateHeaderDelegate extends SliverPersistentHeaderDelegate {
  _DateHeaderDelegate({required this.date});
  final DateTime date;
  @override
  double get minExtent => 44;
  @override
  double get maxExtent => 44;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    final surface = Theme.of(context).colorScheme.surface;
    return Container(
      color: surface,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      alignment: Alignment.centerLeft,
      child: Row(
        children: [
          const Icon(Icons.calendar_today, size: 16),
          const SizedBox(width: 8),
          Text(
            _prettyDayLabel(date),
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
              letterSpacing: .2,
            ),
          ),
        ],
      ),
    );
  }

  @override
  bool shouldRebuild(covariant _DateHeaderDelegate old) => old.date != date;
}

class _WeekSeparator extends StatelessWidget {
  const _WeekSeparator({
    required this.weekStart,
    required this.weekEnd,
    required this.total,
    this.muted = false,
  });
  final DateTime weekStart;
  final DateTime weekEnd;
  final double total;
  final bool muted;

  @override
  Widget build(BuildContext context) {
    final monthShort = DateFormat('MMM', 'es_AR');
    final range =
        '${monthShort.format(weekStart).toLowerCase()} ${weekStart.day} - ${weekEnd.day}';
    final fmt = NumberFormat(r"'$' #,##0.00", 'es_AR');
    final txt = total >= 0 ? '+${fmt.format(total)}' : fmt.format(total);
    final color = total >= 0 ? Colors.green : Colors.red;
    final txtStyle = muted
        ? Theme.of(
            context,
          ).textTheme.labelLarge?.copyWith(color: Colors.white24)
        : Theme.of(
            context,
          ).textTheme.labelLarge?.copyWith(color: Colors.white70);

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 16, 12, 6),
      child: Row(
        children: [
          Expanded(
            child: Text(range, textAlign: TextAlign.center, style: txtStyle),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: muted ? Colors.white10 : color.withOpacity(.12),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(
                color: muted ? Colors.white12 : color.withOpacity(.35),
              ),
            ),
            child: Text(
              muted ? '—' : txt,
              style: TextStyle(
                color: muted ? Colors.white38 : color,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MonthBanner extends StatelessWidget {
  const _MonthBanner({required this.date});
  final DateTime date;

  @override
  Widget build(BuildContext context) {
    final label = DateFormat("MMMM yyyy", 'es_AR').format(date);
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 16, 12, 8),
      child: Container(
        height: 88,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: LinearGradient(
            colors: [
              Theme.of(context).colorScheme.primary.withOpacity(.65),
              Theme.of(context).colorScheme.secondary.withOpacity(.45),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(.35),
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text(
            _cap(label),
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: Colors.white,
            ),
          ),
        ),
      ),
    );
  }

  String _cap(String s) =>
      s.isEmpty ? s : (s[0].toUpperCase() + s.substring(1));
}
