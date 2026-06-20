// ignore: unnecessary_library_name
library orders_home;

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'dart:collection';
import 'dart:io' show Platform;
import 'dart:ui' as ui;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:riverpod/riverpod.dart' as rp;
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';

import 'package:flutter_speed_dial/flutter_speed_dial.dart';
import '../copilot/copilot_bottom_sheet.dart';
import 'orders_repository.dart';
import '../../core/models/order.dart';
import '../../core/extensions/order_list_extension.dart';
import '../../core/enums/order_status.dart';
import '../auth/auth_state.dart';
import 'order_search_modal.dart';
import 'widgets/voice_assistant_fab.dart';
import 'package:pasteleria_180_flutter/core/app_distribution.dart';
import 'package:pasteleria_180_flutter/core/config.dart' show kFlavor;
import 'package:pasteleria_180_flutter/core/theme/order_status_colors.dart';

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
      _promptToEnableTesterModeOnFirstLoad();
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

  Future<void> _loadVersion() async {
    final info = await PackageInfo.fromPlatform();
    if (!mounted) return;
    setState(() {
      _versionName = info.version;
      _buildNumber = info.buildNumber;
    });
  }

  /// Comprueba si el modo tester debe activarse, pero solo
  /// la primera vez que se carga el Home.
  Future<void> _promptToEnableTesterModeOnFirstLoad() async {
    if (!Platform.isAndroid || (kFlavor != 'dev' && !kDebugMode)) return;

    final prefs = await SharedPreferences.getInstance();
    const key = 'fad_explainer_shown';
    final alreadyShown = prefs.getBool(key) ?? false;

    // Si el usuario ya vio este aviso (ya sea que aceptó o
    // lo vio en el login), no hacemos NADA al iniciar el Home.
    if (alreadyShown) {
      debugPrint(
        'ℹ️ Modo de prueba ya gestionado. No se mostrará el aviso de carga.',
      );
      // Aquí sí podemos llamar al chequeo silencioso
      _autoCheckForUpdateIfEnabled();
      return;
    }

    // --- ES LA PRIMERA VEZ ---
    // Esperamos 2s a que la UI de Home cargue (como pediste)
    await Future.delayed(const Duration(seconds: 2));
    if (!mounted) return;

    // Llamamos al flujo interactivo COMPLETO.
    // Esto mostrará el diálogo (porque la pref es false)
    debugPrint('✨ Mostrando aviso de "Modo de Prueba" por primera vez...');
    await _checkForUpdate(interactive: true);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    // Llamamos a precacheImage aquí, donde el 'context' SÍ está disponible.
    if (_logoImageProvider != null) {
      precacheImage(_logoImageProvider!, context);
    }
  }

  Future<void> _jumpToSpecificDate(DateTime date) async {
    final monthKey = DateTime(date.year, date.month, 1);
    final dayKey = DateTime(date.year, date.month, date.day);

    // 1. Si el mes no está en caché, esperamos a que se cargue PRIMERO
    final notifier = ref.read(ordersWindowProvider.notifier);
    await notifier.fetchMonthIfNeeded(monthKey);

    // 2. Navegar al mes en la barra de meses
    ref.read(selectedMonthProvider.notifier).setTo(monthKey);
    _monthBarKey.currentState?.scrollToCurrentMonth(monthKey, animate: true);

    // 3. Esperar un tiempo suficiente para que la lista se reconstruya con el nuevo mes.
    //    500ms (en lugar de 300ms) cubre meses recién cargados de red (BUG-04).
    if (!mounted) return;
    await Future.delayed(const Duration(milliseconds: 500));
    if (!mounted) return;

    // 4. Buscar el índice de ese día y hacer scroll
    final index = _dayIndexMap[dayKey];
    if (index != null) {
      // Caso nominal: el día exacto tiene pedidos y está en el mapa
      _itemScrollController.scrollTo(
        index: index,
        duration: const Duration(milliseconds: 450),
        curve: Curves.easeOut,
      );
    } else {
      // Fallback (BUG-05): el día no tiene pedidos (no está en _dayIndexMap),
      // pero igual saltamos al inicio del mes para que el usuario vea la zona correcta.
      final monthIndex = _monthIndexMap[monthKey];
      if (monthIndex != null) {
        _itemScrollController.scrollTo(
          index: monthIndex,
          duration: const Duration(milliseconds: 450),
          curve: Curves.easeOut,
          alignment: 0.08,
        );
      }
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

  // Agrega una función que centralice la actualización de la barra de meses:
  void _scrollToCurrentMonthBar() {
    final now = DateTime.now();
    final currentMonthKey = DateTime(now.year, now.month, 1);

    // Usamos un pequeño retraso para asegurar que el jumpTo de la lista
    // principal ya se ejecutó en el microtask.
    Future.delayed(const Duration(milliseconds: 100), () {
      if (!mounted) return;
      ref.read(selectedMonthProvider.notifier).setTo(currentMonthKey);
      _monthBarKey.currentState?.scrollToCurrentMonth(
        currentMonthKey,
        animate: true,
      );
    });
  }

  final GlobalKey<_MonthTopBarState> _monthBarKey =
      GlobalKey<_MonthTopBarState>();

  @override
  Widget build(BuildContext context) {
    ref.listen<DateTime?>(jumpToDateProvider, (prev, date) {
      if (date != null) {
        Future.microtask(() => ref.read(jumpToDateProvider.notifier).state = null);
        _jumpToSpecificDate(date);
      }
    });

    final authState = ref.watch(authStateProvider);
    final cs = Theme.of(context).colorScheme;
    final ordersAsync = ref.watch(ordersWindowProvider);
    final isRefreshing = ref.watch(ordersWindowProvider).isLoading ||
        ref.watch(ordersWindowProvider).isRefreshing;

    // --- LÓGICA DE INICIALIZACIÓN Y SALTO EN BARRA DE MESES ---
    if (ordersAsync is AsyncData && !_didPerformInitialScroll) {
      _didPerformInitialScroll = true; // Marca la bandera

      // Llama a la función de actualización de la barra de meses
      // (la lista principal se encarga del scroll de pedidos)
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _scrollToCurrentMonthBar();
      });
    }

    return Scaffold(
      drawer: Drawer(
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: EdgeInsets.zero,
                children: [
                  Container(
                    padding: const EdgeInsets.only(top: 60, bottom: 24, left: 24, right: 24),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          cs.primaryContainer.withOpacity(0.7),
                          cs.surfaceContainerHighest,
                        ],
                      ),
                    ),
                    child: Center(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Container(
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(color: cs.primary.withOpacity(0.2), width: 3),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.1),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: CircleAvatar(
                            radius: 42,
                            backgroundColor: cs.surface,
                            backgroundImage: authState.user?.avatarUrl != null
                                ? CachedNetworkImageProvider(authState.user!.avatarUrl!)
                                : const AssetImage('assets/images/logo_180.png') as ImageProvider,
                          ),
                        ),
                        const SizedBox(height: 20),
                        Text(
                          authState.user?.name ?? 'Usuario',
                          style: TextStyle(
                            color: cs.onSurface,
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.5,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          authState.user?.email ?? '',
                          style: TextStyle(
                            color: cs.onSurfaceVariant,
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  ),
                  ListTile(
                    leading: const Icon(Icons.bookmark_border),
                    title: const Text('Notas 180 IA'),
                    onTap: () {
                      Navigator.pop(context); // Close drawer
                      context.push('/copilot/notes');
                    },
                  ),

                  const Divider(),
                  ListTile(
                    leading: const Icon(Icons.settings),
                    title: const Text('Configuración'),
                    onTap: () {
                      Navigator.pop(context);
                      context.push('/settings');
                    },
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            ListTile(
              leading: const Icon(Icons.logout, color: Colors.red),
              title: const Text('Cerrar Sesión', style: TextStyle(color: Colors.red)),
              onTap: () {
                Navigator.pop(context);
                ref.read(authStateProvider.notifier).logout();
              },
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
      appBar: AppBar(
        leading: Builder(
          builder: (context) {
            return Padding(
              padding: const EdgeInsets.all(6.0),
              child: InkWell(
                customBorder: const CircleBorder(),
                onTap: () => Scaffold.of(context).openDrawer(),
                child: CircleAvatar(
                  radius: 20,
                  backgroundColor: Colors.transparent,
                  backgroundImage: authState.user?.avatarUrl != null
                      ? CachedNetworkImageProvider(authState.user!.avatarUrl!)
                      : const AssetImage('assets/images/logo_180.png') as ImageProvider,
                ),
              ),
            );
          },
        ),
        title: const Text('Pedidos'),
        centerTitle: false,

        actions: [
          // Analytics
          IconButton(
            tooltip: 'Analíticas',
            icon: const Icon(Icons.bar_chart_rounded),
            onPressed: () => context.push('/analytics'),
          ),
          // Copiloto
          IconButton(
            tooltip: '180 IA',
            icon: const Icon(Icons.auto_awesome),
            onPressed: () {
              showCopilotSheet(context);
            },
          ),
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



          PopupMenuButton<String>(
            onSelected: (value) async {
              switch (value) {
                case 'search':
                  showGlobalOrderSearch(
                    context,
                    onJumpToDate: _jumpToSpecificDate,
                  );
                  break;
                // Casos del tema eliminados ya que la lógica está en el itemBuilder
              }
            },
            itemBuilder: (BuildContext context) {
              return <PopupMenuEntry<String>>[
                // --- 1. VERSIÓN ---
                PopupMenuItem(
                  enabled: false,
                  value: 'version_info',
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Versión',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      GestureDetector(
                        onTap: () {
                          Navigator.pop(context); // Cierra el menú manualmente
                          _checkForUpdate(interactive: true);
                        },
                        child: ShimmerVersionBadge(
                          versionText: _versionName.isEmpty && _buildNumber.isEmpty ? 'v—' : 'v$_versionName',
                        ),
                      ),
                    ],
                  ),
                ),

                const PopupMenuDivider(),

                const PopupMenuItem(
                  value: 'search',
                  child: ListTile(
                    leading: Icon(Icons.search),
                    title: Text('Buscar'),
                  ),
                ),
              ];
            },
          ),
        ],
      ),

      // SpeedDial para acciones flotantes y VoiceAssistant
      floatingActionButton: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          const VoiceAssistantFab(),
          const SizedBox(width: 16),
          SpeedDial(
            icon: Icons.add,
        activeIcon: Icons.close,
        // El botón principal ya está bien adaptado (usa primary/onPrimary)
        backgroundColor: cs.primary,
        foregroundColor: cs.onPrimary,

        // --- 👇 ADAPTACIÓN DEL TEMA 👇 ---

        // 1. Usa el color 'scrim' del tema para el fondo
        overlayColor: cs.scrim,
        // 2. Deja que el 'scrim' controle la opacidad
        overlayOpacity: 0.4,

        // --- 👆 FIN DE ADAPTACIÓN 👆 ---
        spacing: 12,
        childrenButtonSize: const Size(60.0, 60.0),
        children: [
          // Botón 1: Nuevo Pedido
          SpeedDialChild(
            child: const Icon(Icons.add_shopping_cart),
            label: 'Nuevo Pedido',
            labelStyle: const TextStyle(fontSize: 16),

            // --- 👇 ADAPTACIÓN DEL TEMA 👇 ---
            // 3. Usa un color de "contenedor" que se adapte
            backgroundColor: cs.secondaryContainer,
            // 4. Usa el color de contenido que va "sobre" ese contenedor
            foregroundColor: cs.onSecondaryContainer,

            // --- 👆 FIN DE ADAPTACIÓN 👆 ---
            onTap: () => context.push('/new_order'),
          ),

          // Botón 2: Clientes
          SpeedDialChild(
            child: const Icon(Icons.people_outline),
            label: 'Clientes',
            labelStyle: const TextStyle(fontSize: 16),

            // --- 👇 ADAPTACIÓN DEL TEMA 👇 ---
            backgroundColor: cs.secondaryContainer,
            foregroundColor: cs.onSecondaryContainer,

            // --- 👆 FIN DE ADAPTACIÓN 👆 ---
            onTap: () => context.push('/clients'),
          ),

          // Botón 3: Usuarios (Solo visible si es Admin)
          if (authState.user?.isAdmin ?? false)
            SpeedDialChild(
              child: const Icon(Icons.people_alt_outlined),
              label: 'Usuarios',
              labelStyle: const TextStyle(fontSize: 16),

              // --- 👇 ADAPTACIÓN DEL TEMA 👇 ---
              backgroundColor: cs.secondaryContainer,
              foregroundColor: cs.onSecondaryContainer,

              // --- 👆 FIN DE ADAPTACIÓN 👆 ---
              onTap: () => context.push('/users'),
            ),

          if (authState.user?.isAdmin ?? false)
            SpeedDialChild(
              child: const Icon(Icons.inventory_2_outlined),
              label: 'Catálogo',
              labelStyle: const TextStyle(fontSize: 16),
              backgroundColor: cs.secondaryContainer,
              foregroundColor: cs.onSecondaryContainer,
              onTap: () => context.push('/admin/catalog'),
            ),
        ],
      ),
      ],
      ),

      // EL CUERPO (BODY) DE LA PÁGINA
      body: Column(
        children: [
          // Barra superior flexible con Resumen y Meses (Antes estaba en AppBar.bottom)
          Consumer(
            builder: (context, ref, child) {
              final cs = Theme.of(context).colorScheme;
              return Padding(
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
                child: Row(
                  children: [
                    Expanded(
                      child: _SummaryCard(
                        title: 'Ingreso Mes',
                        valueProvider: monthlyIncomeProvider,
                        icon: Icons.trending_up,
                        color: cs.tertiary,
                        pendingValueProvider: monthlyPendingIncomeProvider,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _SummaryCard(
                        title: 'Pedidos',
                        valueProvider: monthlyOrdersCountProvider,
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
          
          Expanded(
            child: ordersAsync.when(
              // 1. MIENTRAS CARGA: Muestra un spinner centrado.
        loading: () => Center(
          child: CircularProgressIndicator(
            color: Theme.of(context).colorScheme.primary,
          ),
        ),

        // 2. SI HAY ERROR: Muestra un mensaje de error.
        error: (error, stackTrace) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 48, color: Colors.red),
              const SizedBox(height: 12),
              const Text(
                'Error al cargar pedidos',
                style: TextStyle(fontSize: 16),
              ),
              Text('$error', textAlign: TextAlign.center),
            ],
          ),
        ),

        // 3. SI HAY DATOS: Muestra la lista INSTANTÁNEAMENTE en la posición actual.
        data: (orders) => _UnifiedOrdersList(
          itemScrollController: _itemScrollController,
          itemPositionsListener: _itemPositionsListener,
          monthIndexMap: _monthIndexMap,
          dayIndexMap: _dayIndexMap,
          logoImageProvider: _logoImageProvider,
        ),
            ),
          ),
        ],
      ),
    );
  }
}

// ======================= SHIMMER BADGE =======================
class ShimmerVersionBadge extends StatefulWidget {
  final String versionText;
  const ShimmerVersionBadge({super.key, required this.versionText});

  @override
  State<ShimmerVersionBadge> createState() => _ShimmerVersionBadgeState();
}

class _ShimmerVersionBadgeState extends State<ShimmerVersionBadge> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(seconds: 3))..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return ShaderMask(
          blendMode: BlendMode.srcATop,
          shaderCallback: (bounds) {
            final x = -1.0 + (_controller.value * 3.0); // Barrido de luz
            return LinearGradient(
              colors: [
                Colors.transparent, 
                Colors.white.withValues(alpha: 0.8), 
                Colors.transparent
              ],
              stops: const [0.0, 0.5, 1.0],
              begin: Alignment(x - 0.5, -0.5),
              end: Alignment(x + 0.5, 0.5),
            ).createShader(bounds);
          },
          child: child,
        );
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [
              Color(0xFF74ACDF), // Celeste bandera Argentina
              Colors.white,      // Blanco bandera
              Color(0xFF74ACDF), // Celeste bandera Argentina
            ],
            stops: [0.0, 0.5, 1.0],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF74ACDF).withValues(alpha: 0.5), // Resplandor celeste
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Text(
          widget.versionText,
          style: const TextStyle(
             fontSize: 12,
             color: Color(0xFF003366), // Azul oscuro para alto contraste y legibilidad
             fontWeight: FontWeight.w900,
             letterSpacing: 0.5,
          ),
        ),
      ),
    );
  }
}

