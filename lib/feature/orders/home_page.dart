// ignore: unnecessary_library_name
library orders_home;

import 'dart:collection';
import 'dart:io' show Platform;
// ignore: unnecessary_import
import 'dart:ui'
    as ui; // Asegúrate de que esta línea NO esté si no la necesitas explícitamente

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod/riverpod.dart'
    as rp; // 👈 alias para providers modernos (usado en los parts)
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';

import 'orders_repository.dart';
import '../../core/models/order.dart';
import '../auth/auth_state.dart';
import 'package:pasteleria_180_flutter/core/app_distribution.dart';
import 'package:pasteleria_180_flutter/core/config.dart' show kFlavor;

// ============================ PARTS ============================
part 'parts/state_providers.dart';
part 'parts/date_utils.dart';
part 'parts/month_top_bar.dart';
part 'parts/unified_orders_list.dart';
part 'parts/delegates_and_sections.dart';
part 'parts/summary_card.dart';
part 'parts/order_card.dart';
part 'parts/update_helpers.dart';

// ============================== HOME ==============================

class HomePage extends ConsumerStatefulWidget {
  const HomePage({super.key});
  @override
  ConsumerState<HomePage> createState() => _HomePageState();
}

class _HomePageState extends ConsumerState<HomePage> {
  final ItemScrollController _itemScrollController = ItemScrollController();
  final ItemPositionsListener _itemPositionsListener =
      ItemPositionsListener.create();

  final Map<DateTime, int> _monthIndexMap = {};

  // Estas variables se quedan aquí, son usadas por el 'part' update_helpers
  String _versionName = '';
  String _buildNumber = '';

  // 👇 Semáforo para controlar el scroll programático vs. manual
  bool _isJumpingToMonth = false;

  // 👇 Bandera para asegurar que el scroll inicial solo ocurra una vez
  bool _didPerformInitialScroll = false;

  @override
  void initState() {
    super.initState();
    _loadVersion(); // Llama al método que ahora está en 'update_helpers.dart'
    // Llama al método de 'update_helpers.dart' después del primer frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _autoCheckForUpdateIfEnabled();
    });

    // Sincroniza el scroll de la lista con la barra de mes
    _itemPositionsListener.itemPositions.addListener(_onScrollPositionChanged);
  }

  // Función para saltar a un mes (llamada por _MonthTopBar)
  Future<void> _jumpToMonth(DateTime m) async {
    final monthKey = DateTime(m.year, m.month, 1);
    final index = _monthIndexMap[monthKey];

    if (index != null) {
      // 1. Activar semáforo
      _isJumpingToMonth = true;

      // 2. Actualizar provider seleccionado
      ref.read(selectedMonthProvider.notifier).setTo(monthKey);

      // 3. Animar la lista
      await _itemScrollController.scrollTo(
        index: index,
        duration: const Duration(milliseconds: 450),
        curve: Curves.easeOut,
        alignment: 0.08,
      );

      // 4. Desactivar semáforo (usamos Future.delayed para asegurar que termine después de la animación)
      Future.delayed(const Duration(milliseconds: 500), () {
        _isJumpingToMonth = false;
      });
    }
  }

  // Función que escucha el scroll manual de la lista
  void _onScrollPositionChanged() {
    // Si estamos saltando programáticamente, no hacer nada
    if (_isJumpingToMonth) return;

    // Obtiene el item más visible arriba
    final positions = _itemPositionsListener.itemPositions.value;
    if (positions.isEmpty) return;

    final topItemIndex = positions
        .where((pos) => pos.itemLeadingEdge >= 0)
        .reduce(
          (min, pos) => pos.itemLeadingEdge < min.itemLeadingEdge ? pos : min,
        )
        .index;

    // Busca a qué mes pertenece ese índice
    DateTime? currentMonth;
    int closestIndex = -1;
    for (final entry in _monthIndexMap.entries) {
      final month = entry.key;
      final index = entry.value;
      if (index <= topItemIndex && index > closestIndex) {
        closestIndex = index;
        currentMonth = month;
      }
    }

    // Actualiza el provider si el mes cambió
    if (currentMonth != null) {
      final selected = ref.read(selectedMonthProvider);
      if (selected.year != currentMonth.year ||
          selected.month != currentMonth.month) {
        ref.read(selectedMonthProvider.notifier).setTo(currentMonth);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authStateProvider);

    // Escucha la carga inicial de datos para hacer el scroll al mes actual
    final ordersAsync = ref.watch(ordersWindowProvider);

    // Si tenemos datos Y AÚN NO hemos hecho el scroll inicial...
    if (ordersAsync is AsyncData && !_didPerformInitialScroll) {
      // Marcamos la bandera INMEDIATAMENTE
      _didPerformInitialScroll = true;

      // Hacemos el scroll DESPUÉS de que este build termine
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;

        final now = DateTime.now();
        final currentMonthKey = DateTime(now.year, now.month, 1);
        final initialIndex = _monthIndexMap[currentMonthKey];

        if (initialIndex != null && _itemScrollController.isAttached) {
          _itemScrollController.jumpTo(index: initialIndex, alignment: 0.08);
          ref.read(selectedMonthProvider.notifier).setTo(currentMonthKey);
        }
      });
    }
    // --- FIN LÓGICA SCROLL INICIAL ---

    return Scaffold(
      appBar: AppBar(
        title: const Text('Resumen de Pedidos'),
        actions: [
          _versionPillMenu(), // Llama al método que ahora está en 'update_helpers.dart'
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
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(148),
          child: Column(
            children: [
              Consumer(
                builder: (context, ref, child) {
                  final totalIncome = ref.watch(monthlyIncomeProvider);
                  final totalOrders = ref.watch(monthlyOrdersCountProvider);
                  final cs = Theme.of(context).colorScheme;
                  return Padding(
                    padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                    child: Row(
                      children: [
                        Expanded(
                          child: _SummaryCard(
                            title: 'Ingresos',
                            value: totalIncome,
                            isCurrency: true,
                            icon: Icons.trending_up,
                            color: cs.tertiary,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _SummaryCard(
                            title: 'Pedidos',
                            value: totalOrders.toDouble(),
                            isCurrency: false,
                            icon: Icons.shopping_bag_outlined,
                            color: cs.tertiary,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
              // Pasa la función _jumpToMonth a la barra superior
              _MonthTopBar(
                onSelect: (m) {
                  _jumpToMonth(m);
                },
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.push('/new_order'),
        child: const Icon(Icons.add),
      ),
      body: _UnifiedOrdersList(
        itemScrollController: _itemScrollController,
        itemPositionsListener: _itemPositionsListener,
        monthIndexMap: _monthIndexMap,
      ),
    );
  }

  // (El método _loadVersion y toda la lógica de Update Checker
  // están ahora en 'parts/update_helpers.dart')
} // Fin _HomePageState
