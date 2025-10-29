// ignore: unnecessary_library_name
library orders_home;

import 'dart:collection';
import 'dart:io' show Platform;

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

  // 👇 CAMBIO 1: Añadimos el "semáforo"
  bool _isJumpingToMonth = false;

  @override
  void initState() {
    super.initState();
    _loadVersion(); // Llama al método que ahora está en 'update_helpers.dart'
    WidgetsBinding.instance.addPostFrameCallback(
      (_) =>
          _autoCheckForUpdateIfEnabled(), // Llama al método de 'update_helpers.dart'
    );

    // 👇 MEJORA: Sincroniza el scroll de la lista con la barra de mes
    _itemPositionsListener.itemPositions.addListener(_onScrollPositionChanged);
  }

  // 👇 CAMBIO 2: Actualizamos _jumpToMonth
  Future<void> _jumpToMonth(DateTime m) async {
    final monthKey = DateTime(m.year, m.month, 1);
    final index = _monthIndexMap[monthKey];

    if (index != null) {
      // 1. Ponemos el semáforo en ROJO
      _isJumpingToMonth = true;

      // 2. Actualizamos el provider PRIMERO.
      // Esto le dice a _MonthTopBar que empiece a animarse
      ref.read(selectedMonthProvider.notifier).setTo(monthKey);

      // 3. Animamos la lista
      await _itemScrollController.scrollTo(
        index: index,
        duration: const Duration(milliseconds: 450),
        curve: Curves.easeOut,
        alignment: 0.08,
      );

      // 4. Ponemos el semáforo en VERDE
      _isJumpingToMonth = false;
    }
  }

  // 👇 CAMBIO 3: Actualizamos _onScrollPositionChanged
  void _onScrollPositionChanged() {
    // Si el semáforo está en ROJO (porque estamos saltando),
    // este listener no hace NADA.
    if (_isJumpingToMonth) return;

    // 1. Obtiene el item que está más arriba en la pantalla
    final positions = _itemPositionsListener.itemPositions.value;
    if (positions.isEmpty) return;

    final topItemIndex = positions
        .where((pos) => pos.itemLeadingEdge >= 0) // Filtra items que ya pasaron
        .reduce(
          (min, pos) => pos.itemLeadingEdge < min.itemLeadingEdge ? pos : min,
        ) // Encuentra el más cercano a 0.0
        .index;

    // 2. Busca a qué mes pertenece ese índice
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

    // 3. Si encontramos un mes, actualizamos el provider
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
        // 👇 AQUÍ ESTÁ EL CAMBIO MODERNO
        bottom: PreferredSize(
          // 1. Altura: Card(aprox 80) + Padding(12) + MonthBar(56) = 148
          preferredSize: const Size.fromHeight(148),
          child: Column(
            children: [
              // 2. Usamos un Consumer para escuchar los providers
              Consumer(
                builder: (context, ref, child) {
                  // 3. Obtenemos AMBOS valores
                  final totalIncome = ref.watch(monthlyIncomeProvider);
                  final totalOrders = ref.watch(monthlyOrdersCountProvider);
                  final cs = Theme.of(context).colorScheme;

                  // 4. Usamos un Row para ponerlos lado a lado
                  return Padding(
                    padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                    child: Row(
                      children: [
                        // Tarjeta de Ingresos
                        Expanded(
                          child: _SummaryCard(
                            title: 'Ingresos',
                            value: totalIncome,
                            isCurrency: true, // 👈 Formato de moneda
                            icon: Icons.trending_up,
                            color: cs.tertiary, // Verde/Azul de Material 3
                          ),
                        ),
                        const SizedBox(width: 12),
                        // Tarjeta de Pedidos
                        Expanded(
                          child: _SummaryCard(
                            title: 'Pedidos',
                            value: totalOrders
                                .toDouble(), // Convertir Int a Double
                            isCurrency: false, // 👈 Formato de número
                            icon:
                                Icons.shopping_bag_outlined, // Icono de pedidos
                            color: cs.tertiary, // Color primario
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
              // 5. Mantenemos el selector de mes
              _MonthTopBar(
                onSelect: (m) {
                  // Ahora SÓLO llama a _jumpToMonth.
                  // Ya no actualiza el provider aquí.
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
}
