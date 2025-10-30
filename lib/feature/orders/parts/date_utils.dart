// ignore: use_string_in_part_of_directives
part of orders_home; // 👈 ASUMO QUE ESTA ES LA DIRECTIVA CORRECTA

DateTime _dayKey(DateTime d) => DateTime(d.year, d.month, d.day);

// 👇 MODIFICADO: Ahora calcula el inicio de semana en Lunes
DateTime _weekStartMonday(DateTime d) {
  final k = _dayKey(d);
  // Monday.weekday = 1 -> 1 - 1 = 0 (no resta)
  // Sunday.weekday = 7 -> 7 - 1 = 6 (resta 6 días)
  final daysFromMonday = k.weekday - 1;
  return k.subtract(Duration(days: daysFromMonday));
}

// 👇 MODIFICADO: Ahora usa _weekStartMonday como base
DateTime _weekEndSunday(DateTime d) =>
    _weekStartMonday(d).add(const Duration(days: 6));

// 👇 NUEVA FUNCIÓN (Movida desde month_top_bar.dart)
// Genera la lista estática de 49 meses
List<DateTime> _monthsAroundWindow(DateTime center) {
  final centerMonth = DateTime(center.year, center.month, 1);
  final start = DateTime(centerMonth.year, centerMonth.month - _kBackMonths, 1);
  // Total de meses: 24 atrás + 24 adelante + 1 (actual) = 49
  final total = _kBackMonths + _kFwdMonths + 1;

  return List.generate(total, (i) => DateTime(start.year, start.month + i, 1));
}

// 👇 MODIFICADO: Ahora usa _weekStartMonday
List<DateTime> _weeksInsideMonth(DateTime monthFirstDay) {
  final firstOfMonth = DateTime(monthFirstDay.year, monthFirstDay.month, 1);
  final lastOfMonth = DateTime(monthFirstDay.year, monthFirstDay.month + 1, 0);

  // Usa la nueva función de inicio en Lunes
  var ws = _weekStartMonday(firstOfMonth);

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
