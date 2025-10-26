import 'dart:collection';
import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'orders_repository.dart';
import '../../core/models/order.dart';
import '../auth/auth_state.dart';
import 'package:pasteleria_180_flutter/core/app_distribution.dart';
import 'package:pasteleria_180_flutter/core/config.dart' show kFlavor;

// ========================== LÓGICA DE ESTADO ==========================

// Mes seleccionado para centrar la ventana y calcular totales del mes
final selectedMonthProvider = StateProvider<DateTime>((ref) {
  final now = DateTime.now();
  return DateTime(now.year, now.month, 1);
});

// Ventana alrededor del mes seleccionado
const _kBackMonths = 6;
const _kFwdMonths = 6;

DateTime _dayKey(DateTime d) => DateTime(d.year, d.month, d.day);
DateTime _monthKey(DateTime d) => DateTime(d.year, d.month, 1);

// Semana con inicio en DOMINGO
DateTime _weekStartSunday(DateTime d) {
  final k = _dayKey(d);
  final daysFromSunday = k.weekday % 7; // Dom=7 -> 0
  return k.subtract(Duration(days: daysFromSunday));
}

DateTime _weekEndSunday(DateTime d) =>
    _weekStartSunday(d).add(const Duration(days: 6));

// Listado de meses entre dos fechas (primer día de cada mes)
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

// Semanas que tocan al mes (domingo a sábado)
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

// Ventana única de pedidos para toda la lista
final ordersWindowProvider = FutureProvider.autoDispose<List<Order>>((
  ref,
) async {
  final repository = ref.watch(ordersRepoProvider);
  final sel = ref.watch(selectedMonthProvider);

  final from = DateTime(sel.year, sel.month - _kBackMonths, 1);
  final to = DateTime(sel.year, sel.month + _kFwdMonths + 1, 1); // exclusivo

  final orders = await repository.getOrders(from: from, to: to);

  // Orden ascendente: día ↑, hora ↑, estado como desempate
  const statusOrder = {
    'confirmed': 1,
    'ready': 2,
    'delivered': 3,
    'canceled': 4,
  };
  orders.sort((a, b) {
    final dayCmp = _dayKey(a.eventDate).compareTo(_dayKey(b.eventDate));
    if (dayCmp != 0) return dayCmp;
    final timeCmp = a.startTime.compareTo(b.startTime);
    if (timeCmp != 0) return timeCmp;
    final pa = statusOrder[a.status] ?? 99;
    final pb = statusOrder[b.status] ?? 99;
    return pa.compareTo(pb);
  });

  return orders;
});

// ============================== HOME ==============================

class HomePage extends ConsumerStatefulWidget {
  const HomePage({super.key});
  @override
  ConsumerState<HomePage> createState() => _HomePageState();
}

class _HomePageState extends ConsumerState<HomePage> {
  final _scrollCtrl = ScrollController();

  // anclas por mes para "saltar" desde el topbar
  final Map<DateTime, GlobalKey> _monthAnchors = {};

  String _versionName = '';
  String _buildNumber = '';

  Future<void> _loadVersion() async {
    final info = await PackageInfo.fromPlatform();
    if (!mounted) return;
    setState(() {
      _versionName = info.version;
      _buildNumber = info.buildNumber;
    });
  }

  @override
  void initState() {
    super.initState();
    _loadVersion();
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => _autoCheckForUpdateIfEnabled(),
    );
  }

  void _jumpToMonth(DateTime m) {
    final key = _monthAnchors[DateTime(m.year, m.month, 1)];
    final ctx = key?.currentContext;
    if (ctx != null) {
      Scrollable.ensureVisible(
        ctx,
        duration: const Duration(milliseconds: 450),
        curve: Curves.easeOut,
        alignment: 0.08,
      );
    } else {
      WidgetsBinding.instance.addPostFrameCallback((_) => _jumpToMonth(m));
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authStateProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Resumen de Pedidos'),
        actions: [
          _versionPillMenu(),
          PopupMenuButton<String>(
            onSelected: (value) async {
              switch (value) {
                case 'clients':
                  context.push('/clients');
                  break;
                case 'create_user':
                  context.push('/create_user');
                  break;
                case 'logout':
                  ref.read(authStateProvider.notifier).logout();
                  break;
              }
            },
            itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
              const PopupMenuItem(
                value: 'clients',
                child: ListTile(
                  leading: Icon(Icons.people_outline),
                  title: Text('Clientes'),
                ),
              ),
              if (authState.user?.isAdmin ?? false)
                const PopupMenuItem(
                  value: 'create_user',
                  child: ListTile(
                    leading: Icon(Icons.person_add_alt_1),
                    title: Text('Crear Usuario'),
                  ),
                ),
              const PopupMenuDivider(),
              const PopupMenuItem(
                value: 'logout',
                child: ListTile(
                  leading: Icon(Icons.logout, color: Colors.red),
                  title: Text(
                    'Cerrar Sesión',
                    style: TextStyle(color: Colors.red),
                  ),
                ),
              ),
            ],
          ),
        ],
        // Topbar de meses con scroll (reemplaza tabs)
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(56),
          child: _MonthTopBar(
            onSelect: (m) {
              ref.read(selectedMonthProvider.notifier).state = DateTime(
                m.year,
                m.month,
                1,
              );
              _jumpToMonth(m);
            },
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.push('/new_order'),
        child: const Icon(Icons.add),
      ),
      body: _UnifiedOrdersList(
        scrollController: _scrollCtrl,
        monthAnchors: _monthAnchors,
      ),
    );
  }

  // --------------------- Update Checker + Sheets ---------------------

  Future<void> _checkForUpdate({bool interactive = false}) async {
    if (!Platform.isAndroid || kFlavor != 'dev') return;

    if (interactive) {
      final proceed = await _maybeShowTesterExplainerOnce();
      if (!proceed) return;
    }

    if (interactive) {
      final current = await Permission.notification.status;
      if (current.isDenied || current.isRestricted) {
        final granted = await Permission.notification.request();
        if (!granted.isGranted) {
          if (!mounted) return;
          await _showResultSheet(
            icon: Icons.notifications_off_outlined,
            title: 'Notificaciones desactivadas',
            message:
                'Activá las notificaciones para recibir avisos de actualización.',
          );
          return;
        }
      }
      if (await Permission.notification.isPermanentlyDenied) {
        if (!mounted) return;
        await _showResultSheet(
          icon: Icons.notifications_off_outlined,
          title: 'Permiso bloqueado',
          message: 'Abrí Ajustes y activá las notificaciones para esta app.',
        );
        return;
      }
    }

    VoidCallback? close;
    if (interactive) {
      close = _showProgressSheet(message: 'Buscando actualización…');
    }

    try {
      final hasUpdate = await checkTesterUpdate();
      if (interactive && close != null) close();
      if (!mounted) return;

      if (hasUpdate) {
        if (interactive) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Nueva versión encontrada. Iniciando actualización…',
              ),
            ),
          );
        }
      } else {
        if (interactive) {
          await _showResultSheet(
            icon: Icons.check_circle_outline,
            title: 'Estás al día',
            message: 'No hay actualizaciones disponibles por ahora.',
          );
        }
      }
    } catch (e) {
      if (interactive && close != null) close();
      if (interactive && mounted) {
        await _showResultSheet(
          icon: Icons.error_outline,
          title: 'No pudimos buscar',
          message: 'Reintentá en unos minutos.\nDetalle: $e',
        );
      }
    }
  }

  Future<bool> _maybeShowTesterExplainerOnce() async {
    final prefs = await SharedPreferences.getInstance();
    const key = 'fad_explainer_shown';
    final alreadyShown = prefs.getBool(key) ?? false;
    if (alreadyShown && mounted) return true;

    if (!mounted) return false;
    final ok = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Text('Habilitar alertas de pruebas'),
        content: const Text(
          'Para avisarte cuando haya una nueva versión de la app, necesitamos habilitar '
          'las alertas de pruebas UNA sola vez. Se te pedirá iniciar sesión con tu cuenta '
          'de Google y aceptar notificaciones.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Ahora no'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Continuar'),
          ),
        ],
      ),
    );

    if (ok == true) {
      await prefs.setBool(key, true);
      return true;
    }
    return false;
  }

  VoidCallback _showProgressSheet({
    String message = 'Buscando actualización...',
  }) {
    showModalBottomSheet(
      context: context,
      isDismissible: false,
      enableDrag: false,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 4),
            const Icon(Icons.system_update_alt, size: 28),
            const SizedBox(height: 12),
            Text(
              message,
              style: Theme.of(context).textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            const LinearProgressIndicator(),
          ],
        ),
      ),
    );

    return () {
      if (mounted && Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      }
    };
  }

  Future<void> _showResultSheet({
    required IconData icon,
    required String title,
    required String message,
  }) async {
    if (!mounted) return;
    await showModalBottomSheet(
      context: context,
      isDismissible: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 28),
            const SizedBox(height: 12),
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(
              message,
              style: Theme.of(context).textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Aceptar'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _versionPillMenu() {
    return PopupMenuButton<String>(
      tooltip: 'Versión',
      onSelected: (value) async {
        if (value == 'check_update') {
          await _checkForUpdate(interactive: true);
        }
      },
      itemBuilder: (context) => <PopupMenuEntry<String>>[
        PopupMenuItem<String>(
          enabled: false,
          child: ListTile(
            leading: const Icon(Icons.info_outline),
            title: const Text('Versión instalada'),
            subtitle: Text(
              (_versionName.isEmpty && _buildNumber.isEmpty)
                  ? '—'
                  : _versionName,
            ),
          ),
        ),
        if (kFlavor == 'dev') const PopupMenuDivider(),
        if (kFlavor == 'dev')
          const PopupMenuItem<String>(
            value: 'check_update',
            child: ListTile(
              leading: Icon(Icons.system_update_alt),
              title: Text('Buscar actualización'),
            ),
          ),
      ],
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 8),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF4A4A4A), Color(0xFF6A6A6A)],
          ),
          borderRadius: BorderRadius.circular(999),
          boxShadow: const [
            BoxShadow(
              blurRadius: 8,
              offset: Offset(0, 2),
              color: Colors.black12,
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.bolt_rounded, size: 16, color: Colors.white70),
            const SizedBox(width: 6),
            Text(
              _versionName.isEmpty ? 'versión' : 'v$_versionName',
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _autoCheckForUpdateIfEnabled() async {
    if (!Platform.isAndroid || kFlavor != 'dev') return;

    final prefs = await SharedPreferences.getInstance();
    const key = 'fad_explainer_shown';
    final enabled = prefs.getBool(key) ?? false;
    if (!enabled) return;

    final granted = await Permission.notification.isGranted;
    if (!granted) return;

    try {
      await checkTesterUpdate();
    } catch (_) {}
  }
}

// ======================== LISTA UNIFICADA ========================

class _UnifiedOrdersList extends ConsumerWidget {
  const _UnifiedOrdersList({
    required this.scrollController,
    required this.monthAnchors,
  });

  final ScrollController scrollController;
  final Map<DateTime, GlobalKey> monthAnchors;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ordersAsync = ref.watch(ordersWindowProvider);
    final selMonth = ref.watch(selectedMonthProvider);

    return ordersAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, _) => Center(child: Text('Error al cargar pedidos: $err')),
      data: (orders) {
        final from = DateTime(selMonth.year, selMonth.month - _kBackMonths, 1);
        final to = DateTime(selMonth.year, selMonth.month + _kFwdMonths, 1);
        final months = _monthsBetween(from, to);

        final byDay = SplayTreeMap<DateTime, List<Order>>(
          (a, b) => a.compareTo(b),
        );
        for (final o in orders) {
          final k = _dayKey(o.eventDate);
          byDay.putIfAbsent(k, () => []).add(o);
        }

        final weekTotals = <DateTime, double>{};
        for (final o in orders) {
          final ws = _weekStartSunday(o.eventDate);
          weekTotals.update(
            ws,
            (v) => v + (o.total ?? 0),
            ifAbsent: () => (o.total ?? 0),
          );
        }

        // Totales del mes seleccionado para los summary cards
        double ingresosMes = 0, gastosMes = 0;
        final mesFrom = DateTime(selMonth.year, selMonth.month, 1);
        final mesTo = DateTime(
          selMonth.year,
          selMonth.month + 1,
          1,
        ).subtract(const Duration(seconds: 1));
        for (final o in orders) {
          final d = _dayKey(o.eventDate);
          if (d.isBefore(mesFrom) || d.isAfter(mesTo)) continue;
          final v = o.total ?? 0;
          if (v >= 0) {
            ingresosMes += v;
          } else {
            gastosMes += v;
          }
        }

        final slivers = <Widget>[
          const SliverToBoxAdapter(child: SizedBox(height: 8)),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Row(
                children: [
                  Expanded(
                    child: _SummaryCard(
                      title: 'Ingresos',
                      value: ingresosMes,
                      positive: true,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _SummaryCard(
                      title: 'Gastos',
                      value: gastosMes,
                      positive: false,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 8)),
        ];

        for (final month in months) {
          monthAnchors.putIfAbsent(month, () => GlobalKey());

          slivers.add(
            SliverToBoxAdapter(
              key: monthAnchors[month],
              child: _MonthBanner(date: month),
            ),
          );

          final weeks = _weeksInsideMonth(month);

          for (final ws in weeks) {
            final we = _weekEndSunday(ws);

            final total = weekTotals[ws] ?? 0;

            // ¿hay pedidos en la semana dentro de este mes?
            bool weekHasOrders = false;
            for (int i = 0; i < 7; i++) {
              final d = ws.add(Duration(days: i));
              if (d.month != month.month) continue;
              if (byDay[_dayKey(d)]?.isNotEmpty == true) {
                weekHasOrders = true;
                break;
              }
            }

            slivers.add(
              SliverToBoxAdapter(
                child: _WeekSeparator(
                  weekStart: ws,
                  weekEnd: we,
                  total: total,
                  muted: !weekHasOrders, // gris si no hubo pedidos
                ),
              ),
            );

            // Días con pedidos
            for (int i = 0; i < 7; i++) {
              final day = ws.add(Duration(days: i));
              if (day.month != month.month) continue;

              final list = byDay[_dayKey(day)];
              if (list == null || list.isEmpty) continue;

              slivers.add(
                SliverPersistentHeader(
                  pinned: true,
                  delegate: _DateHeaderDelegate(date: day),
                ),
              );

              slivers.add(
                SliverList(
                  delegate: SliverChildBuilderDelegate((context, index) {
                    final order = list[index];
                    return Dismissible(
                      key: ValueKey(order.id),
                      direction: DismissDirection.endToStart,
                      background: Container(
                        color: Colors.red.shade700,
                        alignment: Alignment.centerRight,
                        padding: const EdgeInsets.symmetric(horizontal: 20.0),
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            Text(
                              'ELIMINAR',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            SizedBox(width: 8),
                            Icon(Icons.delete_forever, color: Colors.white),
                          ],
                        ),
                      ),
                      confirmDismiss: (direction) async {
                        final bool? didConfirm = await showDialog<bool>(
                          context: context,
                          builder: (BuildContext context) {
                            return AlertDialog(
                              title: const Text('Confirmar Eliminación'),
                              content: const Text(
                                '¿Estás seguro de que quieres eliminar este pedido?',
                              ),
                              actions: <Widget>[
                                TextButton(
                                  onPressed: () =>
                                      Navigator.of(context).pop(false),
                                  child: const Text('Cancelar'),
                                ),
                                FilledButton(
                                  style: FilledButton.styleFrom(
                                    backgroundColor: Colors.red.shade700,
                                  ),
                                  onPressed: () =>
                                      Navigator.of(context).pop(true),
                                  child: const Text('Eliminar'),
                                ),
                              ],
                            );
                          },
                        );

                        if (didConfirm == true) {
                          try {
                            await ref
                                .read(ordersRepoProvider)
                                .deleteOrder(order.id);
                            ref.invalidate(ordersWindowProvider);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Pedido #${order.id} eliminado.'),
                                backgroundColor: Colors.green,
                              ),
                            );
                            return true;
                          } catch (e) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Error al eliminar: $e'),
                                backgroundColor: Colors.red,
                              ),
                            );
                            return false;
                          }
                        }
                        return false;
                      },
                      child: OrderCard(order: order),
                    );
                  }, childCount: list.length),
                ),
              );
            }
          }
        }

        slivers.add(
          const SliverToBoxAdapter(child: SizedBox(height: 80)),
        ); // espacio FAB

        return RefreshIndicator(
          onRefresh: () => ref.refresh(ordersWindowProvider.future),
          child: CustomScrollView(
            controller: scrollController,
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: slivers,
          ),
        );
      },
    );
  }
}

// ====================== TOPBAR DE MESES (AppBar) ======================

class _MonthTopBar extends ConsumerStatefulWidget {
  const _MonthTopBar({required this.onSelect, super.key});
  final void Function(DateTime) onSelect;

  @override
  ConsumerState<_MonthTopBar> createState() => _MonthTopBarState();
}

class _MonthTopBarState extends ConsumerState<_MonthTopBar> {
  final _ctrl = ScrollController();
  bool _scrolled = false;

  List<DateTime> _monthsAround(DateTime center, {int back = 6, int fwd = 12}) {
    final start = DateTime(center.year, center.month - back, 1);
    return List.generate(
      back + fwd + 1,
      (i) => DateTime(start.year, start.month + i, 1),
    );
  }

  String _label(DateTime m) {
    final s = DateFormat('MMM yy', 'es_AR').format(m); // ej: "oct 25"
    return s.replaceAll('.', '').toUpperCase(); // "OCT 25"
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final selected = ref.watch(selectedMonthProvider);
    final months = _monthsAround(selected);

    if (!_scrolled && months.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final idx = months.indexWhere(
          (m) => m.year == selected.year && m.month == selected.month,
        );
        if (idx >= 0 && _ctrl.hasClients) {
          _ctrl.jumpTo((idx * 100).toDouble());
        }
        _scrolled = true;
      });
    }

    return Container(
      height: 56,
      alignment: Alignment.centerLeft,
      child: ListView.separated(
        controller: _ctrl,
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        itemBuilder: (context, i) {
          final m = months[i];
          final isSel = m.year == selected.year && m.month == selected.month;

          final bg = isSel
              ? Theme.of(context).colorScheme.primary.withOpacity(.22)
              : Theme.of(context).colorScheme.surface;
          final brd = isSel
              ? Theme.of(context).colorScheme.primary.withOpacity(.55)
              : Colors.white12;
          final txt = isSel
              ? Theme.of(context).colorScheme.primary
              : Colors.white70;

          return InkWell(
            borderRadius: BorderRadius.circular(999),
            onTap: () {
              ref.read(selectedMonthProvider.notifier).state = DateTime(
                m.year,
                m.month,
                1,
              );
              widget.onSelect(m);
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: bg,
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: brd, width: 1),
                boxShadow: const [
                  BoxShadow(
                    blurRadius: 8,
                    offset: Offset(0, 2),
                    color: Colors.black12,
                  ),
                ],
              ),
              child: Text(
                _label(m),
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  letterSpacing: .6,
                  color: txt,
                ),
              ),
            ),
          );
        },
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemCount: months.length,
      ),
    );
  }
}

// =================== DELEGATES + WIDGETS AUXILIARES ===================

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
    final label = _prettyDayLabel(date);

    return Container(
      color: surface,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      alignment: Alignment.centerLeft,
      child: Row(
        children: [
          const Icon(Icons.calendar_today, size: 16),
          const SizedBox(width: 8),
          Text(
            label,
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
  bool shouldRebuild(covariant _DateHeaderDelegate oldDelegate) =>
      oldDelegate.date != date;
}

String _prettyDayLabel(DateTime d) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final target = DateTime(d.year, d.month, d.day);

  if (target == today) return 'Hoy';
  if (target == today.add(const Duration(days: 1))) return 'Mañana';
  final dow = DateFormat('EEEE', 'es_AR').format(d); // lunes, martes...
  final day = DateFormat('d', 'es_AR').format(d);
  return '${dow.toLowerCase()} $day';
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

  String _cap(String s) => s[0].toUpperCase() + s.substring(1);
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.title,
    required this.value,
    required this.positive,
  });
  final String title;
  final double value;
  final bool positive;

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat(r"'$' #,##0.00", 'es_AR');
    final show = (positive && value >= 0)
        ? '+${fmt.format(value)}'
        : fmt.format(value);
    final color = positive ? Colors.green : Colors.red;

    return Container(
      height: 72,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(18),
        boxShadow: const [
          BoxShadow(
            blurRadius: 10,
            offset: Offset(0, 4),
            color: Colors.black12,
          ),
        ],
        border: Border.all(color: color.withOpacity(.25), width: 1),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Row(
        children: [
          Icon(
            positive ? Icons.trending_up : Icons.outbond_rounded,
            color: color,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(
                    context,
                  ).textTheme.labelLarge?.copyWith(color: Colors.white70),
                ),
                const Spacer(),
                Text(
                  show,
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    color: color,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ======================= TARJETA PASTEL DEL PEDIDO =======================

// Paleta pastel
const _kPastelBabyBlue = Color(0xFFDFF1FF);
const _kPastelMint = Color(0xFFD8F6EC);
const _kPastelSand = Color(0xFFF6EEDF);

const _kInkBabyBlue = Color(0xFF8CC5F5);
const _kInkMint = Color(0xFF83D1B9);
const _kInkSand = Color(0xFFC9B99A);

// Fondos pastel por estado
const _statusPastelBg = <String, Color>{
  'confirmed': _kPastelMint,
  'ready': Color(0xFFFFE6EF),
  'delivered': _kPastelBabyBlue,
  'canceled': Color(0xFFFFE0E0),
};

// Acento/borde por estado
const _statusInk = <String, Color>{
  'confirmed': _kInkMint,
  'ready': Color(0xFFF3A9B9),
  'delivered': _kInkBabyBlue,
  'canceled': Color(0xFFE57373),
};

// Traducciones visibles
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
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Cliente y Total
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      order.client?.name ?? 'Cliente no especificado',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 18,
                        color: Colors.black.withValues(alpha: 0.85),
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Text(
                    totalString,
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 18,
                      color: Colors.black.withValues(alpha: 0.9),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              // Fecha y Hora
              _InfoRow(
                icon: Icons.calendar_today,
                text: DateFormat(
                  "EEEE d 'de' MMMM",
                  'es_AR',
                ).format(order.eventDate),
              ),
              const SizedBox(height: 4),
              _InfoRow(
                icon: Icons.access_time,
                text:
                    '${DateFormat.Hm().format(order.startTime)} - ${DateFormat.Hm().format(order.endTime)}',
              ),
              const Divider(height: 24),

              // Estado + selector
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: ink.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(99),
                      border: Border.all(color: ink.withValues(alpha: 0.35)),
                    ),
                    child: Text(
                      _statusTranslations[order.status] ?? order.status,
                      style: TextStyle(
                        color: ink.withValues(alpha: 0.95),
                        fontWeight: FontWeight.w600,
                        letterSpacing: .2,
                      ),
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
                        child: Row(
                          children: [
                            Container(
                              width: 12,
                              height: 12,
                              decoration: BoxDecoration(
                                color: c,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(_statusTranslations[value]!),
                          ],
                        ),
                      );
                    }).toList(),
                    onChanged: (String? newValue) async {
                      if (newValue != null && newValue != order.status) {
                        await ref
                            .read(ordersRepoProvider)
                            .updateStatus(order.id, newValue);
                        ref.invalidate(ordersWindowProvider);
                      }
                    },
                  ),
                ],
              ),
            ],
          ),
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
    return Row(
      children: [
        Icon(icon, size: 16, color: Colors.black54),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(fontSize: 15, color: Colors.black87),
          ),
        ),
      ],
    );
  }
}
