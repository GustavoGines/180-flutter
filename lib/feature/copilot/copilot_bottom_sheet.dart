import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // Añadido para HapticFeedback
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:go_router/go_router.dart';
import '../orders/home_page.dart'; // Para jumpToDateProvider
import 'copilot_controller.dart';
import 'models/chat_message.dart';

Future<void> showCopilotSheet(BuildContext context, {String? initialMessage}) {
  HapticFeedback.mediumImpact(); // Respuesta táctil profesional al abrir
  
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    barrierColor: Colors.black.withValues(alpha: 0.7), // Fondo más inmersivo
    builder: (context) {
      return Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: CopilotBottomSheet(initialMessage: initialMessage),
      );
    },
  );
}

class CopilotBottomSheet extends ConsumerStatefulWidget {
  final String? initialMessage;

  const CopilotBottomSheet({super.key, this.initialMessage});

  @override
  ConsumerState<CopilotBottomSheet> createState() => _CopilotBottomSheetState();
}

class _CopilotBottomSheetState extends ConsumerState<CopilotBottomSheet> {
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _focusNode = FocusNode();

  final List<Map<String, dynamic>> _suggestedPrompts = [
    {
      'icon': Icons.receipt_long,
      'text': '¿Cuántos pedidos faltan entregar hoy?',
    },
    {
      'icon': Icons.attach_money,
      'text': 'Resumen de facturación de este mes',
    },
    {
      'icon': Icons.cake,
      'text': '¿Qué tenemos que producir mañana?',
    },
    {
      'icon': Icons.search,
      'text': '¿Hay algún pedido pendiente de pago?',
    },
    {
      'icon': Icons.help_outline,
      'text': '¿Qué podés hacer?',
    },
  ];

  @override
  void initState() {
    super.initState();
    if (widget.initialMessage != null && widget.initialMessage!.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ref.read(copilotControllerProvider.notifier).sendMessage(widget.initialMessage!);
      });
    }
  }

  void _handleSend([String? text]) {
    final message = text ?? _textController.text;
    if (message.trim().isEmpty) return;
    
    ref.read(copilotControllerProvider.notifier).sendMessage(message);
    if (text == null) {
      _textController.clear();
    }
    
    _focusNode.requestFocus();
  }

  @override
  void dispose() {
    _textController.dispose();
    _scrollController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final messages = ref.watch(copilotControllerProvider);
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    
    // Si solo está el mensaje de bienvenida y no hay carga, mostramos prompts
    final showPrompts = messages.length <= 1 && !messages.any((m) => m.isLoading);

    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      minChildSize: 0.25,
      maxChildSize: 0.95,
      builder: (context, scrollController) {
        return TweenAnimationBuilder<double>(
          duration: const Duration(milliseconds: 400),
          curve: Curves.easeOutQuart,
          tween: Tween(begin: 0.0, end: 1.0),
          builder: (context, value, child) {
            return Transform.translate(
              offset: Offset(0, 40 * (1 - value)), // Deslizamiento interno suave
              child: Opacity(
                opacity: value, // Fade in
                child: child,
              ),
            );
          },
          child: Container(
            decoration: BoxDecoration(
            color: colorScheme.surfaceContainerHighest,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            children: [
              // Cabecera (Handle de arrastre)
              SingleChildScrollView(
                controller: scrollController,
                physics: const ClampingScrollPhysics(),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    border: Border(bottom: BorderSide(color: colorScheme.outlineVariant.withValues(alpha: 0.5))),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.auto_awesome, size: 20, color: Colors.amber),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Chat 180 IA',
                          style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                          textAlign: TextAlign.center,
                        ),
                      ),
                      PopupMenuButton<String>(
                        icon: const Icon(Icons.more_vert),
                        tooltip: 'Opciones del chat',
                        onSelected: (value) {
                          if (value == 'clear') {
                            ref.read(copilotControllerProvider.notifier).clearChat();
                          } else if (value == 'copy') {
                            final msgs = ref.read(copilotControllerProvider);
                            final lastAssistant = msgs.lastWhere(
                              (m) => m.role == ChatRole.assistant && !m.isLoading,
                              orElse: () => msgs.first,
                            );
                            Clipboard.setData(ClipboardData(text: lastAssistant.content));
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Última respuesta copiada')),
                            );
                          }
                        },
                        itemBuilder: (context) => [
                          const PopupMenuItem(
                            value: 'clear',
                            child: Row(
                              children: [
                                Icon(Icons.delete_sweep, size: 20),
                                SizedBox(width: 8),
                                Text('Vaciar chat'),
                              ],
                            ),
                          ),
                          const PopupMenuItem(
                            value: 'copy',
                            child: Row(
                              children: [
                                Icon(Icons.copy, size: 20),
                                SizedBox(width: 8),
                                Text('Copiar respuesta'),
                              ],
                            ),
                          ),
                        ],
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.of(context).pop(),
                        style: IconButton.styleFrom(
                          backgroundColor: colorScheme.surface,
                          padding: const EdgeInsets.all(8),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              
              // Área de Mensajes
              Expanded(
                child: showPrompts
                    ? _buildSuggestedPrompts(colorScheme)
                    : ListView.builder(
                        // Removido: controller: scrollController para que el cuerpo NO arrastre el modal, solo haga scroll interno
                        reverse: true,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                        itemCount: messages.length,
                        itemBuilder: (context, index) {
                          final msg = messages[messages.length - 1 - index];
                          return _buildChatBubble(context, msg, colorScheme);
                        },
                      ),
              ),
              
              // Input inferior
              _buildInputArea(context, colorScheme),
            ],
          ),
        ), // Cierra Container
        ); // Cierra TweenAnimationBuilder
      },
    );
  }

  Widget _buildSuggestedPrompts(ColorScheme colorScheme) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 20),
          Center(
            child: Text(
              '¡Hola! Soy 180 IA.',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: colorScheme.onSurface),
            ),
          ),
          const SizedBox(height: 8),
          Center(
            child: Text(
              '¿En qué te puedo ayudar hoy?',
              style: TextStyle(fontSize: 14, color: colorScheme.onSurfaceVariant),
            ),
          ),
          const SizedBox(height: 32),
          ..._suggestedPrompts.map((prompt) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: InkWell(
                onTap: () => _handleSend(prompt['text'] as String),
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: colorScheme.surface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: colorScheme.outlineVariant.withValues(alpha: 0.5)),
                  ),
                  child: Row(
                    children: [
                      Icon(prompt['icon'] as IconData, color: colorScheme.primary, size: 24),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Text(
                          prompt['text'] as String,
                          style: TextStyle(color: colorScheme.onSurface),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildChatBubble(BuildContext context, ChatMessage message, ColorScheme colorScheme) {
    final isUser = message.role == ChatRole.user;
    
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.75,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: isUser 
              ? colorScheme.primary 
              : colorScheme.surface,
          borderRadius: BorderRadius.circular(20).copyWith(
            bottomRight: isUser ? const Radius.circular(0) : const Radius.circular(20),
            bottomLeft: !isUser ? const Radius.circular(0) : const Radius.circular(20),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 5,
              offset: const Offset(0, 2),
            )
          ]
        ),
        child: message.isLoading 
            ? SizedBox(
                width: 40,
                height: 20,
                child: Center(
                  child: SizedBox(
                    width: 15,
                    height: 15,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: colorScheme.primary,
                    ),
                  ),
                ),
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    message.content,
                    style: TextStyle(
                      color: isUser 
                          ? colorScheme.onPrimary 
                          : colorScheme.onSurface,
                      fontSize: 15,
                    ),
                  ),
                  if (message.uiWidget != null) ...[
                    const SizedBox(height: 12),
                    _buildServerDrivenWidget(context, message.uiWidget!),
                  ]
                ],
              ),
      ),
    );
  }

  Widget _buildServerDrivenWidget(BuildContext context, Map<String, dynamic> widgetData) {
    final type = widgetData['type'];
    final data = widgetData['data'];

    switch (type) {
      case 'order_card':
        return _buildServerDrivenOrderCard(context, data);
      case 'order_list':
        return _buildServerDrivenOrderList(context, data);
      case 'production_list':
        return _buildServerDrivenProductionList(context, data);
      case 'revenue_card':
        return _buildServerDrivenRevenueCard(context, data);
      case 'client_card':
        return _buildServerDrivenClientCard(context, data);
      case 'navigate_calendar':
        return _buildServerDrivenNavigateCalendar(context, data);
      case 'whatsapp_dispatch_card':
        return _buildWhatsappDispatchCard(context, data);
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildServerDrivenNavigateCalendar(BuildContext context, dynamic data) {
    if (data == null || data is! Map) return const SizedBox.shrink();
    
    final dateStr = data['date'];
    if (dateStr == null) return const SizedBox.shrink();

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 8),
      child: FilledButton.icon(
        onPressed: () {
          final date = DateTime.tryParse(dateStr.toString());
          if (date != null) {
            ref.read(jumpToDateProvider.notifier).state = date;
            final router = GoRouter.of(context);
            Navigator.of(context).pop(); // Cerramos el bottom sheet
            router.go('/');
          }
        },
        icon: const Icon(Icons.calendar_month),
        label: Text('Ir al Calendario ($dateStr)'),
        style: FilledButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    );
  }

  Widget _buildWhatsappDispatchCard(BuildContext context, dynamic data) {
    if (data == null || data is! Map) return const SizedBox.shrink();

    final phone       = data['phone']?.toString() ?? '';
    final message     = data['message']?.toString() ?? '';
    final clientName  = data['client_name']?.toString() ?? 'el cliente';

    if (phone.isEmpty || message.isEmpty) return const SizedBox.shrink();

    Future<void> openWhatsApp() async {
      // Codificar correctamente el mensaje para la URL de WhatsApp
      final encoded  = Uri.encodeQueryComponent(message);
      final whatsUrl = Uri.parse('https://wa.me/$phone?text=$encoded');
      if (await canLaunchUrl(whatsUrl)) {
        await launchUrl(whatsUrl, mode: LaunchMode.externalApplication);
      } else {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No se pudo abrir WhatsApp.')),
          );
        }
      }
    }

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 10),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1B5E20), Color(0xFF2E7D32)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF25D366).withValues(alpha: 0.35),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: const Color(0xFF25D366),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.chat, color: Colors.white, size: 18),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Mensaje para $clientName',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Container(
            margin: const EdgeInsets.all(12),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              message,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
                height: 1.5,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 14),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: openWhatsApp,
                icon: const Icon(Icons.send, size: 18),
                label: const Text(
                  'Enviar por WhatsApp',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF25D366),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildServerDrivenOrderCard(BuildContext context, dynamic data) {
    if (data == null || data is! Map) return const SizedBox.shrink();
    
    final title = data['title']?.toString() ?? 'Pedido';
    final subtitle = data['subtitle']?.toString() ?? 'Detalle no disponible';
    final total = data['total']?.toString() ?? '\$0';
    final orderId = data['order_id'];

    final card = Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Text(
                total,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.primary,
                  fontSize: 14,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: TextStyle(
              fontSize: 13,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );

    if (orderId != null) {
      return Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () {
            final router = GoRouter.of(context);
            Navigator.of(context).pop();
            router.push('/order/$orderId');
          },
          child: card,
        ),
      );
    }
    return card;
  }

  Widget _buildServerDrivenOrderList(BuildContext context, dynamic data) {
    List<dynamic> orders = [];
    if (data is List) orders = data;
    if (data is Map && data['orders'] is List) orders = data['orders'];
    if (data is Map && data['items'] is List) orders = data['items'];

    if (orders.isEmpty) return const Text('No se encontraron pedidos.');

    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
      ),
      child: ListView.separated(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: orders.length,
        separatorBuilder: (_, __) => const Divider(height: 1),
        itemBuilder: (context, index) {
          final order = orders[index];
          if (order is! Map) return const SizedBox.shrink();
          final orderId = order['id'];
          final clientName = order['client']?['name'] ?? order['client_name'] ?? 'Cliente Desconocido';
          // Formatear fecha ISO → DD/MM/YYYY
          final rawDate = order['event_date']?.toString() ?? '';
          String date = 'Sin fecha';
          try {
            if (rawDate.isNotEmpty) {
              final dt = DateTime.parse(rawDate).toLocal();
              date = '${dt.day.toString().padLeft(2,'0')}/${dt.month.toString().padLeft(2,'0')}/${dt.year}';
            }
          } catch (_) { date = rawDate; }

          final rawStatus = order['status'] ?? 'pending';
          String status;
          switch (rawStatus) {
            case 'pending':    status = 'Pendiente';  break;
            case 'confirmed':  status = 'Confirmado'; break;
            case 'in_process': status = 'En Proceso'; break;
            case 'ready':      status = 'Listo';       break;
            case 'completed':  status = 'Terminado';  break;
            case 'delivered':  status = 'Entregado';  break;
            case 'cancelled':  status = 'Cancelado';  break;
            case 'canceled':   status = 'Cancelado';  break;
            default:           status = rawStatus;    break;
          }

          return ListTile(
            leading: const Icon(Icons.receipt_long),
            title: Text(clientName, style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Text('$date  •  $status'),
            isThreeLine: true,
            visualDensity: VisualDensity.compact,
            trailing: const Icon(Icons.chevron_right, size: 16),
            onTap: orderId != null 
                ? () {
                    final router = GoRouter.of(context);
                    Navigator.of(context).pop();
                    router.push('/order/$orderId');
                  } 
                : null,
          );
        },
      ),
    );
  }

  Widget _buildServerDrivenProductionList(BuildContext context, dynamic data) {
    List<dynamic> items = [];
    if (data is List) items = data;
    if (data is Map && data['summary'] is List) items = data['summary'];
    if (data is Map && data['items'] is List) items = data['items'];

    if (items.isEmpty) return const Text('Sin producción para mostrar.');

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.secondaryContainer.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Theme.of(context).colorScheme.secondary),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.cake, color: Theme.of(context).colorScheme.onSecondaryContainer),
              const SizedBox(width: 8),
              Text('Resumen de Producción', style: TextStyle(fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.onSecondaryContainer)),
            ],
          ),
          const SizedBox(height: 8),
          ...items.map((item) {
            if (item is! Map) return const SizedBox.shrink();
            final name = item['name'] ?? 'Producto';
            final qty = item['total_quantity'] ?? item['qty'] ?? item['quantity'] ?? 0;
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(child: Text(name)),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.secondary,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(qty.toString(), style: TextStyle(color: Theme.of(context).colorScheme.onSecondary, fontWeight: FontWeight.bold)),
                  )
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildServerDrivenRevenueCard(BuildContext context, dynamic data) {
    if (data == null || data is! Map) return const SizedBox.shrink();
    
    final period = data['period']?.toString() ?? 'Facturación';
    String totalStr = data['total']?.toString() ?? data['revenue']?.toString() ?? '0';
    if (!totalStr.startsWith('\$')) {
      totalStr = '\$$totalStr';
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.green.shade800,
            Colors.green.shade600,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.green.withValues(alpha: 0.3),
            blurRadius: 8,
            offset: const Offset(0, 4),
          )
        ]
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.attach_money, color: Colors.white70),
              const SizedBox(width: 8),
              Text(
                period.toUpperCase(),
                style: const TextStyle(
                  color: Colors.white70,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1.2,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            totalStr,
            style: const TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildServerDrivenClientCard(BuildContext context, dynamic data) {
    if (data == null || data is! Map) return const SizedBox.shrink();
    
    final name = data['name']?.toString() ?? 'Cliente';
    final phone = data['phone']?.toString() ?? 'Sin teléfono';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.tertiaryContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: Theme.of(context).colorScheme.tertiary,
            child: Icon(Icons.person, color: Theme.of(context).colorScheme.onTertiary),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: TextStyle(fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.onTertiaryContainer)),
                Text(phone, style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onTertiaryContainer.withValues(alpha: 0.8))),
              ],
            ),
          ),
          GestureDetector(
            onTap: () async {
              // Limpiar el número: quitar todo lo que no sea dígito
              final cleanPhone = phone.replaceAll(RegExp(r'\D'), '');
              if (cleanPhone.isNotEmpty) {
                // wa.me abre directamente WhatsApp con ese número
                final url = Uri.parse('https://wa.me/$cleanPhone');
                if (await canLaunchUrl(url)) {
                  await launchUrl(url, mode: LaunchMode.externalApplication);
                }
              }
            },
            child: Container(
              width: 42,
              height: 42,
              decoration: const BoxDecoration(
                color: Color(0xFF25D366), // Verde WhatsApp
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.chat, color: Colors.white, size: 22),
            ),
          )
        ],
      ),
    );
  }

  Widget _buildInputArea(BuildContext context, ColorScheme colorScheme) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            offset: const Offset(0, -2),
            blurRadius: 10,
          )
        ]
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _textController,
              focusNode: _focusNode,
              textInputAction: TextInputAction.send,
              onSubmitted: (_) => _handleSend(),
              decoration: InputDecoration(
                hintText: 'Pregúntale a 180 IA...',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(30),
                  borderSide: BorderSide.none,
                ),
                filled: true,
                fillColor: colorScheme.surfaceContainerHighest,
                contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              ),
            ),
          ),
          const SizedBox(width: 12),
          CircleAvatar(
            backgroundColor: colorScheme.primary,
            radius: 24,
            child: IconButton(
              icon: const Icon(Icons.send, color: Colors.white),
              onPressed: () => _handleSend(),
            ),
          ),
        ],
      ),
    );
  }
}
