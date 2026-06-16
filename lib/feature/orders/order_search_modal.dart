import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'dart:async';

import '../../core/models/order.dart';
import 'orders_repository.dart';

class OrderSearchModal extends ConsumerStatefulWidget {
  final void Function(DateTime)? onJumpToDate;

  const OrderSearchModal({super.key, this.onJumpToDate});

  @override
  ConsumerState<OrderSearchModal> createState() => _OrderSearchModalState();
}

class _OrderSearchModalState extends ConsumerState<OrderSearchModal> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  Timer? _debounce;
  List<Order> _cachedResults = [];
  bool _isLoading = false;
  // Token para evitar race conditions: si llega un resultado viejo, lo descartamos
  int _searchToken = 0;

  @override
  void initState() {
    super.initState();
    _focusNode.requestFocus();
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  Future<void> _performSearch(String q) async {
    final trimmed = q.trim();
    if (trimmed.isEmpty) {
      if (mounted) {
        setState(() {
          _cachedResults = [];
          _isLoading = false;
        });
      }
      return;
    }

    // Requiere al menos 2 caracteres para buscar
    if (trimmed.length < 2) return;

    // Incrementar el token ANTES del await para detectar búsquedas obsoletas
    final token = ++_searchToken;

    if (mounted) {
      setState(() {
        _isLoading = true;
      });
    }

    try {
      final repository = ref.read(ordersRepoProvider);
      final results = await repository.searchOrders(trimmed);
      // Solo aplicar resultados si este request sigue siendo el más reciente
      if (mounted && token == _searchToken) {
        setState(() {
          _cachedResults = results;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted && token == _searchToken) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _onSearchChanged(String query) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () {
      _performSearch(query);
    });
  }

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('dd MMM yyyy', 'es_ES');
    final colorScheme = Theme.of(context).colorScheme;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: Container(
        width: 600, // Max width for tablet/desktop feeling
        height: MediaQuery.of(context).size.height * 0.8,
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.2),
              blurRadius: 20,
              offset: const Offset(0, 10),
            )
          ],
        ),
        child: Column(
          children: [
            // Search Input Header
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: colorScheme.surface,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                border: Border(
                  bottom: BorderSide(color: colorScheme.outlineVariant.withValues(alpha: 0.5)),
                ),
              ),
              child: Row(
                children: [
                  const Icon(Icons.search, color: Colors.grey),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      focusNode: _focusNode,
                      onChanged: _onSearchChanged,
                      style: const TextStyle(fontSize: 18),
                      decoration: const InputDecoration(
                        hintText: 'Buscar cliente o pedido...',
                        border: InputBorder.none,
                        isDense: true,
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                  ),
                  if (_controller.text.isNotEmpty)
                    IconButton(
                      icon: const Icon(Icons.close, size: 20),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      onPressed: () {
                        _controller.clear();
                        _onSearchChanged('');
                      },
                    )
                  else
                    IconButton(
                      icon: const Icon(Icons.close, size: 20),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                ],
              ),
            ),
            // Results Area
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _controller.text.trim().isEmpty
                      ? Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.search, size: 48, color: colorScheme.outlineVariant),
                              const SizedBox(height: 16),
                              Text(
                                'Escribe para buscar...',
                                style: TextStyle(color: colorScheme.onSurfaceVariant),
                              ),
                            ],
                          ),
                        )
                      : _cachedResults.isEmpty
                          ? Center(
                              child: Text(
                                'No se encontraron pedidos',
                                style: TextStyle(color: colorScheme.onSurfaceVariant),
                              ),
                            )
                          : ListView.separated(
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              itemCount: _cachedResults.length,
                              separatorBuilder: (context, index) => const Divider(height: 1),
                              itemBuilder: (context, index) {
                                final order = _cachedResults[index];
                                final clientName = order.client?.name ?? 'Sin Cliente';
                                final dateStr = dateFormat.format(order.eventDate);
                                final timeStr = DateFormat('HH:mm').format(order.startTime);
                                final formatter = NumberFormat.currency(locale: 'es_AR', symbol: '\$', decimalDigits: 0);

                                return Card(
                                  margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                  elevation: 0,
                                  color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    side: BorderSide(color: colorScheme.outlineVariant.withValues(alpha: 0.5)),
                                  ),
                                  child: Padding(
                                    padding: const EdgeInsets.all(12),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            CircleAvatar(
                                              backgroundColor: colorScheme.primaryContainer,
                                              child: Icon(Icons.shopping_bag,
                                                  size: 18, color: colorScheme.onPrimaryContainer),
                                            ),
                                            const SizedBox(width: 12),
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    clientName,
                                                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
                                                  ),
                                                  const SizedBox(height: 4),
                                                  Row(
                                                    children: [
                                                      Icon(Icons.calendar_today, size: 14, color: colorScheme.onSurfaceVariant),
                                                      const SizedBox(width: 4),
                                                      Text('$dateStr - $timeStr', style: TextStyle(color: colorScheme.onSurfaceVariant, fontSize: 13)),
                                                    ],
                                                  ),
                                                ],
                                              ),
                                            ),
                                            Text(
                                              formatter.format(order.total),
                                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                                            ),
                                          ],
                                        ),
                                        if (order.notes?.isNotEmpty ?? false) ...[
                                          const SizedBox(height: 8),
                                          Text(
                                            order.notes!,
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                            style: TextStyle(color: colorScheme.onSurfaceVariant, fontSize: 13, fontStyle: FontStyle.italic),
                                          ),
                                        ],
                                        const SizedBox(height: 12),
                                        Row(
                                          mainAxisAlignment: MainAxisAlignment.end,
                                          children: [
                                            if (widget.onJumpToDate != null) ...[
                                              TextButton.icon(
                                                onPressed: () {
                                                  Navigator.of(context).pop();
                                                  widget.onJumpToDate!(order.eventDate);
                                                },
                                                icon: const Icon(Icons.event, size: 16),
                                                label: const Text('En Calendario'),
                                                style: TextButton.styleFrom(
                                                  visualDensity: VisualDensity.compact,
                                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                                ),
                                              ),
                                              const SizedBox(width: 8),
                                            ],
                                            FilledButton.icon(
                                              onPressed: () {
                                                Navigator.of(context).pop();
                                                context.push('/order/${order.id}');
                                              },
                                              icon: const Icon(Icons.visibility, size: 16),
                                              label: const Text('Ver Detalles'),
                                              style: FilledButton.styleFrom(
                                                visualDensity: VisualDensity.compact,
                                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
            ),
          ],
        ),
      ),
    );
  }
}

Future<void> showGlobalOrderSearch(BuildContext context, {void Function(DateTime)? onJumpToDate}) {
  return showDialog(
    context: context,
    barrierColor: Colors.black.withValues(alpha: 0.5),
    builder: (context) => OrderSearchModal(onJumpToDate: onJumpToDate),
  );
}
