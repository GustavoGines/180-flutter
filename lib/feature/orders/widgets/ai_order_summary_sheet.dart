import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class AiOrderSummarySheet extends StatefulWidget {
  final Map<String, dynamic> aiData;
  final void Function(int? selectedClientId) onConfirm;
  final VoidCallback onCancel;

  const AiOrderSummarySheet({
    super.key,
    required this.aiData,
    required this.onConfirm,
    required this.onCancel,
  });

  @override
  State<AiOrderSummarySheet> createState() => _AiOrderSummarySheetState();
}

class _AiOrderSummarySheetState extends State<AiOrderSummarySheet> {
  int? _selectedSuggestedClientId;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    
    final data = widget.aiData['data'] as Map<String, dynamic>? ?? {};
    final clientName = data['client_name'] as String? ?? 'No especificado';
    final deliveryDateStr = data['event_date'];
    
    final suggestedClients = (data['suggested_clients'] as List<dynamic>?)?.cast<Map<String, dynamic>>() ?? [];

    DateTime? deliveryDate;
    if (deliveryDateStr != null) {
      deliveryDate = DateTime.tryParse(deliveryDateStr);
    }
    
    final formattedDate = deliveryDate != null 
        ? DateFormat('EEEE d \'de\' MMMM, yyyy', 'es').format(deliveryDate)
        : 'Sin fecha';
        
    final startTime = data['start_time'] as String?;

    final items = data['items'] as List<dynamic>? ?? [];

    return Container(
      padding: const EdgeInsets.all(24.0),
      decoration: BoxDecoration(
        color: theme.scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Icon(Icons.auto_awesome, color: colorScheme.primary),
                  const SizedBox(width: 8),
                  Text(
                    'Pedido interpretado por IA',
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: colorScheme.primary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              
              // Chips de info general
              Wrap(
                spacing: 8.0,
                runSpacing: 8.0,
                children: [
                  Chip(
                    avatar: const Icon(Icons.person, size: 16),
                    label: Text(clientName),
                    backgroundColor: colorScheme.surfaceContainerHighest,
                  ),
                  Chip(
                    avatar: const Icon(Icons.calendar_today, size: 16),
                    label: Text(formattedDate),
                    backgroundColor: colorScheme.surfaceContainerHighest,
                  ),
                ],
              ),
              if (startTime != null && startTime.isNotEmpty) ...[
                const SizedBox(height: 8),
                Wrap(
                  children: [
                    Chip(
                      avatar: const Icon(Icons.access_time, size: 16),
                      label: Text(startTime),
                      backgroundColor: colorScheme.surfaceContainerHighest,
                    ),
                  ],
                ),
              ],
              
              if (suggestedClients.isNotEmpty) ...[
                const SizedBox(height: 16),
                Text(
                  '¿Te refieres a alguno de estos clientes?',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: colorScheme.primary,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8.0,
                  runSpacing: 8.0,
                  children: suggestedClients.map((suggested) {
                    final id = suggested["id"] as int;
                    final isSelected = _selectedSuggestedClientId == id;
                    return FilterChip(
                      avatar: const Icon(Icons.person_search, size: 16),
                      label: Text('${suggested["name"]} (${suggested["phone"] ?? "Sin tel"})'),
                      selected: isSelected,
                      onSelected: (selected) {
                        setState(() {
                          if (selected) {
                            _selectedSuggestedClientId = id;
                          } else {
                            _selectedSuggestedClientId = null;
                          }
                        });
                      },
                    );
                  }).toList(),
                ),
              ],
              
              const SizedBox(height: 16),
              
              Text('Productos detectados:', style: theme.textTheme.titleMedium),
              const SizedBox(height: 8),
              
              // Lista de productos
              ListView.separated(
                physics: const NeverScrollableScrollPhysics(),
                shrinkWrap: true,
                itemCount: items.length,
                separatorBuilder: (context, index) => const Divider(),
                itemBuilder: (context, index) {
                  final item = items[index];
                  final product = item['product_name'] ?? item['original_name'] ?? 'Producto';
                  final notes = item['notes']?.toString() ?? '';
                  final quantity = item['quantity'] ?? 1;
                  
                  final fillings = (item['fillings'] as List<dynamic>?)?.cast<String>() ?? [];
                  final extras = (item['extras'] as List<dynamic>?)?.cast<String>() ?? [];
                  final weight = item['weight_kg'];
                  final isUnit = item['is_unit_sale'] == true;

                  List<String> details = [];
                  if (weight != null) details.add('$weight kg');
                  if (fillings.isNotEmpty) details.add('Rellenos: ${fillings.join(', ')}');
                  if (extras.isNotEmpty) details.add('Extras: ${extras.join(', ')}');
                  if (notes.isNotEmpty) details.add('Notas: $notes');

                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: CircleAvatar(
                      backgroundColor: colorScheme.primaryContainer,
                      child: Icon(Icons.cake, color: colorScheme.onPrimaryContainer),
                    ),
                    title: Text('$quantity${isUnit ? 'u' : ''} x $product', style: const TextStyle(fontWeight: FontWeight.w600)),
                    subtitle: details.isNotEmpty 
                        ? Text(details.join('\n')) 
                        : null,
                  );
                },
              ),
              const SizedBox(height: 24),
              
              // Botones
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: widget.onCancel,
                    child: const Text('Cancelar'),
                  ),
                  const SizedBox(width: 12),
                  FilledButton.icon(
                    onPressed: () => widget.onConfirm(_selectedSuggestedClientId),
                    icon: const Icon(Icons.check),
                    label: const Text('Confirmar Pedido'),
                  ),
                ],
              )
            ],
          ),
        ),
      ),
    );
  }
}
