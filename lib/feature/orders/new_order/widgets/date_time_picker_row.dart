import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class DateTimePickerRow extends StatelessWidget {
  final DateTime date;
  final TimeOfDay startTime;
  final TimeOfDay endTime;
  final VoidCallback onPickDate;
  final VoidCallback onPickStartTime;
  final VoidCallback onPickEndTime;

  const DateTimePickerRow({
    super.key,
    required this.date,
    required this.startTime,
    required this.endTime,
    required this.onPickDate,
    required this.onPickStartTime,
    required this.onPickEndTime,
  });

  @override
  Widget build(BuildContext context) {
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
              onTap: onPickDate,
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
                    onTap: onPickStartTime,
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
                    onTap: onPickEndTime,
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
