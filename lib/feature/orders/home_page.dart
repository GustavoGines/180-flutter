// ignore: unnecessary_library_name
library orders_home;

import 'dart:async';
import 'dart:collection';
import 'dart:io' show Platform;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod/riverpod.dart' as rp;
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
  final Map<DateTime, int> _dayIndexMap = {}; // 👈 Nuevo mapa para días

  String _versionName = '';
  String _buildNumber = '';
  bool _isJumpingToMonth = false;
  bool _didPerformInitialScroll = false;

  Timer? _jumpCooldownTimer;

  @override
  void initState() {
    super.initState();
    _loadVersion();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _autoCheckForUpdateIfEnabled();
    });

    _itemPositionsListener.itemPositions.addListener(_onScrollPositionChanged);
  }

  // 👇 AÑADIR ESTE MÉTODO
  @override
  void dispose() {
    _jumpCooldownTimer?.cancel();
    _itemPositionsListener.itemPositions.removeListener(
      _onScrollPositionChanged,
    );
    super.dispose();
  }

  Future<void> _jumpToMonth(DateTime m) async {
    // 1. Si había un temporizador de "cooldown" anterior, ¡cancélalo!
    //    Esto permite que el nuevo clic "gane".
    _jumpCooldownTimer?.cancel();

    final monthKey = DateTime(m.year, m.month, 1);
    final index = _monthIndexMap[monthKey];

    if (index != null) {
      _isJumpingToMonth = true;
      ref.read(selectedMonthProvider.notifier).setTo(monthKey);

      // 2. Inicia la animación de scroll (dura 450ms)
      //    No usamos 'await' para que la UI se sienta instantánea.
      _itemScrollController.scrollTo(
        index: index,
        duration: const Duration(milliseconds: 450),
        curve: Curves.easeOut,
        alignment: 0.08,
      );

      // 3. Inicia un NUEVO temporizador. Debe durar MÁS que la
      //    animación (ej: 450ms + 100ms de colchón = 550ms).
      _jumpCooldownTimer = Timer(const Duration(milliseconds: 550), () {
        if (mounted) {
          _isJumpingToMonth = false; // Apaga la bandera SÓLO al final
        }
      });
    }
  }

  void _onScrollPositionChanged() {
    if (_isJumpingToMonth) return;

    final positions = _itemPositionsListener.itemPositions.value;
    if (positions.isEmpty) return;

    final topItemIndex = positions
        .where((pos) => pos.itemLeadingEdge >= 0)
        .reduce(
          (min, pos) => pos.itemLeadingEdge < min.itemLeadingEdge ? pos : min,
        )
        .index;

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

    if (currentMonth != null) {
      final selected = ref.read(selectedMonthProvider);
      if (selected.year != currentMonth.year ||
          selected.month != currentMonth.month) {
        ref.read(selectedMonthProvider.notifier).setTo(currentMonth);
      }
    }
  }

  final GlobalKey<_MonthTopBarState> _monthBarKey =
      GlobalKey<_MonthTopBarState>();

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authStateProvider);
    final ordersAsync = ref.watch(ordersWindowProvider);

    // Verifica si ya se está recargando
    final isRefreshing = ordersAsync is AsyncLoading;

    if (ordersAsync is AsyncData && !_didPerformInitialScroll) {
      _didPerformInitialScroll = true;

      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;

        final now = DateTime.now();
        final currentMonthKey = DateTime(now.year, now.month, 1);
        final todayKey = DateTime(now.year, now.month, now.day);

        final dayIndex = _dayIndexMap[todayKey];
        final monthIndex = _monthIndexMap[currentMonthKey];

        if (_itemScrollController.isAttached) {
          if (dayIndex != null) {
            _itemScrollController.jumpTo(index: dayIndex, alignment: 0.15);
          } else if (monthIndex != null) {
            _itemScrollController.jumpTo(index: monthIndex, alignment: 0.08);
          }
          ref.read(selectedMonthProvider.notifier).setTo(currentMonthKey);
        }
      });
    }

    return Scaffold(
      appBar: AppBar(
        // 👇 ¡AQUÍ ESTÁ EL CAMBIO!
        title: Row(
          children: [
            Image.asset(
              'assets/images/logo_180.png', // La ruta de tu logo
              height: 80, // 134.0 es muy grande, prueba con 36.0 o 40.0
            ),
            const SizedBox(width: 0), // Espacio entre logo y texto
            const Text('Pedidos'),
          ],
        ),

        // 2. AÑADE ESTA LÍNEA para alinear a la izquierda
        centerTitle: false,

        actions: [
          // El botón "moderno" de recarga
          IconButton(
            tooltip: 'Recargar pedidos',
            onPressed: isRefreshing
                ? null
                : () {
                    ref.invalidate(ordersWindowProvider);
                  },
            icon: isRefreshing
                ? SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      strokeWidth: 3,
                      color: Theme.of(context).colorScheme.onPrimary,
                    ),
                  )
                : const Icon(Icons.refresh),
          ),

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

        // La barra superior fija
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
              _MonthTopBar(
                key: _monthBarKey,
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
        dayIndexMap: _dayIndexMap,
      ),
    );
  }
}
