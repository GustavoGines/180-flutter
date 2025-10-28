part of '../home_page.dart';

DateTime _dayKey(DateTime d) => DateTime(d.year, d.month, d.day);
DateTime _monthKey(DateTime d) => DateTime(d.year, d.month, 1);

DateTime _weekStartSunday(DateTime d) {
  final k = _dayKey(d);
  final daysFromSunday = k.weekday % 7;
  return k.subtract(Duration(days: daysFromSunday));
}

DateTime _weekEndSunday(DateTime d) =>
    _weekStartSunday(d).add(const Duration(days: 6));

List<DateTime> _monthsBetween(DateTime from, DateTime to) {
  final start = DateTime(from.year, from.month, 1);
  final end = DateTime(to.year, to.month, 1);
  final list = <DateTime>[];
  var cur = start;
  while (!(cur.year == end.year && cur.month == end.month)) {
    list.add(cur);
    cur = DateTime(cur.year, cur.month + 1, 1);
  }
  list.add(end);
  return list;
}

List<DateTime> _weeksInsideMonth(DateTime monthFirstDay) {
  final firstOfMonth = DateTime(monthFirstDay.year, monthFirstDay.month, 1);
  final lastOfMonth = DateTime(monthFirstDay.year, monthFirstDay.month + 1, 0);
  var ws = _weekStartSunday(firstOfMonth);
  final list = <DateTime>[];
  while (ws.isBefore(lastOfMonth) || ws.isAtSameMomentAs(lastOfMonth)) {
    list.add(ws);
    ws = ws.add(const Duration(days: 7));
  }
  return list;
}

String _prettyDayLabel(DateTime d) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final target = DateTime(d.year, d.month, d.day);
  if (target == today) return 'Hoy';
  if (target == today.add(const Duration(days: 1))) return 'Mañana';
  final dow = DateFormat('EEEE', 'es_AR').format(d);
  final day = DateFormat('d', 'es_AR').format(d);
  return '${dow.toLowerCase()} $day';
}
