// ignore: unnecessary_library_name
library orders_home;

import 'dart:async';

import 'package:flutter/material.dart';

import 'dart:collection';
import 'dart:io' show Platform;
import 'dart:ui' as ui;
import 'package:flutter_riverpod/flutter_riverpod.dart';
// Importamos tu AppThemeMode y themeModeProvider
import 'package:pasteleria_180_flutter/core/theme/theme_provider.dart';
import 'package:riverpod/riverpod.dart' as rp;
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';

import 'package:flutter_speed_dial/flutter_speed_dial.dart';

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
  final Map<DateTime, int> _dayIndexMap = {};

  String _versionName = '';
  String _buildNumber = '';
  bool _isJumpingToMonth = false;
  bool _didPerformInitialScroll = false;

  Timer? _jumpCooldownTimer;
  ImageProvider? _logoImageProvider;

  @override
  void initState() {
    super.initState();
    _loadVersion();
    _loadLogo();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _autoCheckForUpdateIfEnabled();
    });

    _itemPositionsListener.itemPositions.addListener(_onScrollPositionChanged);
  }

  @override
  void dispose() {
    _jumpCooldownTimer?.cancel();
    _itemPositionsListener.itemPositions.removeListener(
      _onScrollPositionChanged,
    );
    super.dispose();
  }

  void _loadLogo() {
    // Usamos AssetImage, que maneja el precaching
    const logo = AssetImage('assets/images/launch_image_solo.png');
    // Guardamos el provider en el estado
    setState(() {
      _logoImageProvider = logo;
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    // Llamamos a precacheImage aquí, donde el 'context' SÍ está disponible.
    if (_logoImageProvider != null) {
      precacheImage(_logoImageProvider!, context);
    }
  }

  Future<void> _jumpToMonth(DateTime m) async {
    _jumpCooldownTimer?.cancel();

    final monthKey = DateTime(m.year, m.month, 1);
    final index = _monthIndexMap[monthKey];

    if (index != null) {
      _isJumpingToMonth = true;
      ref.read(selectedMonthProvider.notifier).setTo(monthKey);

      _itemScrollController.scrollTo(
        index: index,
        duration: const Duration(milliseconds: 450),
        curve: Curves.easeOut,
        alignment: 0.08,
      );

      _jumpCooldownTimer = Timer(const Duration(milliseconds: 550), () {
        if (mounted) {
          _isJumpingToMonth = false;
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
        }

        ref.read(selectedMonthProvider.notifier).setTo(currentMonthKey);

        _monthBarKey.currentState?.scrollToCurrentMonth(
          currentMonthKey,
          animate: true,
        );
      });
    }

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Image.asset('assets/images/logo_180.png', height: 80.0),
            const SizedBox(width: 0),
            const Text('Pedidos'),
          ],
        ),
        centerTitle: false,

        actions: [
          // Botón de recarga
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

          // POPUPMENUBUTTON (3 PUNTOS)
          PopupMenuButton<String>(
            onSelected: (value) async {
              switch (value) {
                case 'logout':
                  ref.read(authStateProvider.notifier).logout();
                  break;
                // Casos del tema eliminados ya que la lógica está en el itemBuilder
              }
            },
            itemBuilder: (BuildContext context) {
              final currentMode = ref.watch(themeModeProvider);
              final cs = Theme.of(context).colorScheme;

              // Helper para construir los 3 iconos del tema en una fila
              Widget buildThemeIcon(AppThemeMode mode, IconData icon) {
                final isSelected = currentMode == mode;
                final tooltip = switch (mode) {
                  AppThemeMode.system => 'Sistema',
                  AppThemeMode.light => 'Claro',
                  AppThemeMode.dark => 'Oscuro',
                };

                return Tooltip(
                  message: tooltip,
                  child: IconButton(
                    icon: Icon(
                      icon,
                      size: 20,
                      color: isSelected ? cs.primary : cs.onSurfaceVariant,
                    ),
                    onPressed: () {
                      Navigator.pop(context); // Cierra el menú al seleccionar
                      ref.read(themeModeProvider.notifier).setMode(mode);
                    },
                  ),
                );
              }

              return <PopupMenuEntry<String>>[
                // --- 1. TÍTULO 'TEMA' ---
                const PopupMenuItem(
                  enabled: false,
                  child: Text(
                    'Tema',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),

                // --- 2. FILA DE ICONOS DE TEMA (en un solo PopupMenuItem) ---
                PopupMenuItem<String>(
                  // Un valor ficticio para cumplir con el tipo
                  value: 'theme_selector_row',
                  enabled:
                      false, // La fila en sí no se selecciona, solo los botones
                  padding: EdgeInsets.zero,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8.0,
                      vertical: 0,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        buildThemeIcon(
                          AppThemeMode.system,
                          Icons.auto_mode_outlined,
                        ),
                        buildThemeIcon(
                          AppThemeMode.light,
                          Icons.light_mode_outlined,
                        ),
                        buildThemeIcon(
                          AppThemeMode.dark,
                          Icons.dark_mode_outlined,
                        ),
                      ],
                    ),
                  ),
                ),

                const PopupMenuDivider(),

                // --- FIN SELECCIÓN DE TEMA ---
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
              ];
            },
          ),
        ],

        // Barra inferior fija con Resumen y Meses
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
                            title: 'Ingreso Mes',
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

      // SpeedDial para acciones flotantes
      floatingActionButton: SpeedDial(
        icon: Icons.add,
        activeIcon: Icons.close,
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Theme.of(context).colorScheme.onPrimary,
        overlayColor: Colors.black,
        overlayOpacity: 0.4,
        spacing: 12,
        childrenButtonSize: const Size(60.0, 60.0),

        children: [
          // Botón 1: Nuevo Pedido
          SpeedDialChild(
            child: const Icon(Icons.add_shopping_cart),
            label: 'Nuevo Pedido',
            labelStyle: const TextStyle(fontSize: 16),
            backgroundColor: Colors.white,
            foregroundColor: Theme.of(context).colorScheme.primary,
            onTap: () => context.push('/new_order'),
          ),

          // Botón 2: Clientes
          SpeedDialChild(
            child: const Icon(Icons.people_outline),
            label: 'Clientes',
            labelStyle: const TextStyle(fontSize: 16),
            backgroundColor: Colors.white,
            foregroundColor: Theme.of(context).colorScheme.primary,
            onTap: () => context.push('/clients'),
          ),

          // Botón 3: Usuarios (Solo visible si es Admin)
          if (authState.user?.isAdmin ?? false)
            SpeedDialChild(
              child: const Icon(Icons.people_alt_outlined),
              label: 'Usuarios',
              labelStyle: const TextStyle(fontSize: 16),
              backgroundColor: Colors.white,
              foregroundColor: Theme.of(context).colorScheme.primary,
              onTap: () => context.push('/users'),
            ),
        ],
      ),

      body: _UnifiedOrdersList(
        itemScrollController: _itemScrollController,
        itemPositionsListener: _itemPositionsListener,
        monthIndexMap: _monthIndexMap,
        dayIndexMap: _dayIndexMap,
        logoImageProvider: _logoImageProvider,
      ),
    );
  }
}
