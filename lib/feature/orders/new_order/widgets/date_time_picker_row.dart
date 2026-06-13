import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../new_order_controller.dart';

class DateTimePickerRow extends ConsumerWidget {
  const DateTimePickerRow({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(newOrderControllerProvider);
    final controller = ref.read(newOrderControllerProvider.notifier);

    // Fallback if null (should not be null if properly initialized, but just in case)
    final date = state.eventDate ?? DateTime.now();
    final startTime = state.startTime ?? const TimeOfDay(hour: 10, minute: 0);
    final endTime = state.endTime ?? const TimeOfDay(hour: 12, minute: 0);

    Future<void> pickDate() async {
      final picked = await showDatePicker(
        context: context,
        initialDate: date,
        firstDate: DateTime.now().subtract(const Duration(days: 365)),
        lastDate: DateTime.now().add(const Duration(days: 365 * 2)),
      );
      if (picked != null) {
        controller.updateDate(picked);
      }
    }

    Future<void> pickStartTime() async {
      final picked = await showTimePicker(
        context: context,
        initialTime: startTime,
      );
      if (picked != null) {
        controller.updateStartTime(picked);
      }
    }

    Future<void> pickEndTime() async {
      final picked = await showTimePicker(
        context: context,
        initialTime: endTime,
      );
      if (picked != null) {
        controller.updateEndTime(picked);
      }
    }

    return Card(
      elevation: 0,
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8.0),
        child: Column(
          children: [
            ListTile(
              dense: true,
              leading: Icon(
                Icons.calendar_today,
                color: Theme.of(context).colorScheme.primary,
              ),
              title: Text(
                'Fecha Evento: ${DateFormat('EEEE d \'de\' MMMM, y', 'es_AR').format(date)}',
              ),
              onTap: pickDate,
            ),
            Divider(
              height: 1,
              indent: 16,
              endIndent: 16,
              color: Theme.of(context).colorScheme.surfaceContainer,
            ),
            Row(
              children: [
                Expanded(
                  child: ListTile(
                    dense: true,
                    leading: Icon(
                      Icons.access_time,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    title: Text('Desde: ${startTime.format(context)}'),
                    onTap: pickStartTime,
                  ),
                ),
                Container(
                  height: 30,
                  width: 1,
                  color: Theme.of(context).colorScheme.surfaceContainer,
                ),
                Expanded(
                  child: ListTile(
                    dense: true,
                    leading: Icon(
                      Icons.update,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    title: Text('Hasta: ${endTime.format(context)}'),
                    onTap: pickEndTime,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
