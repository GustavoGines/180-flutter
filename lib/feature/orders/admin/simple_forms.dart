import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/models/catalog.dart';
import '../catalog_repository.dart';

// --- FILLING FORM DIALOG ---
class FillingFormDialog extends ConsumerStatefulWidget {
  final Filling? fillingToEdit;
  const FillingFormDialog({super.key, this.fillingToEdit});

  @override
  ConsumerState<FillingFormDialog> createState() => _FillingFormDialogState();
}

class _FillingFormDialogState extends ConsumerState<FillingFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameCtrl;
  late TextEditingController _priceCtrl;
  bool _isFree = false;

  @override
  void initState() {
    super.initState();
    final f = widget.fillingToEdit;
    _nameCtrl = TextEditingController(text: f?.name ?? '');
    _priceCtrl = TextEditingController(
      text: f?.pricePerKg.toStringAsFixed(0) ?? '0',
    );
    _isFree = f?.isFree ?? false;
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(
        widget.fillingToEdit == null ? 'Nuevo Relleno' : 'Editar Relleno',
      ),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              controller: _nameCtrl,
              decoration: const InputDecoration(labelText: 'Nombre'),
              validator: (v) => v!.isEmpty ? 'Requerido' : null,
            ),
            const SizedBox(height: 12),
            SwitchListTile(
              title: const Text('Es Gratis?'),
              value: _isFree,
              onChanged: (v) => setState(() {
                _isFree = v;
                if (v) _priceCtrl.text = '0';
              }),
            ),
            if (!_isFree)
              TextFormField(
                controller: _priceCtrl,
                decoration: const InputDecoration(
                  labelText: 'Precio por Kg',
                  prefixText: '\$',
                ),
                keyboardType: TextInputType.number,
                validator: (v) => v!.isEmpty ? 'Requerido' : null,
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => context.pop(),
          child: const Text('Cancelar'),
        ),
        ElevatedButton(
          onPressed: () async {
            if (_formKey.currentState!.validate()) {
              final data = {
                'name': _nameCtrl.text,
                'price_per_kg': double.tryParse(_priceCtrl.text) ?? 0,
                'is_free': _isFree,
              };
              try {
                if (widget.fillingToEdit == null) {
                  await ref.read(catalogRepoProvider).createFilling(data);
                } else {
                  await ref
                      .read(catalogRepoProvider)
                      .updateFilling(widget.fillingToEdit!.id, data);
                }
                ref.invalidate(catalogProvider);
                if (context.mounted) context.pop();
              } catch (e) {
                // error
              }
            }
          },
          child: const Text('Guardar'),
        ),
      ],
    );
  }
}

// --- EXTRA FORM DIALOG ---
class ExtraFormDialog extends ConsumerStatefulWidget {
  final Extra? extraToEdit;
  const ExtraFormDialog({super.key, this.extraToEdit});

  @override
  ConsumerState<ExtraFormDialog> createState() => _ExtraFormDialogState();
}

class _ExtraFormDialogState extends ConsumerState<ExtraFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameCtrl;
  late TextEditingController _priceCtrl;
  String _priceType = 'per_unit'; // per_unit, per_kg

  @override
  void initState() {
    super.initState();
    final e = widget.extraToEdit;
    _nameCtrl = TextEditingController(text: e?.name ?? '');
    _priceCtrl = TextEditingController(
      text: e?.price.toStringAsFixed(0) ?? '0',
    );
    _priceType = e?.priceType ?? 'per_unit';
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.extraToEdit == null ? 'Nuevo Extra' : 'Editar Extra'),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              controller: _nameCtrl,
              decoration: const InputDecoration(labelText: 'Nombre'),
              validator: (v) => v!.isEmpty ? 'Requerido' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _priceCtrl,
              decoration: const InputDecoration(
                labelText: 'Precio',
                prefixText: '\$',
              ),
              keyboardType: TextInputType.number,
              validator: (v) => v!.isEmpty ? 'Requerido' : null,
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: _priceType,
              decoration: const InputDecoration(labelText: 'Tipo de Precio'),
              items: const [
                DropdownMenuItem(value: 'per_unit', child: Text('Por Unidad')),
                DropdownMenuItem(value: 'per_kg', child: Text('Por Kg')),
              ],
              onChanged: (v) => setState(() => _priceType = v!),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => context.pop(),
          child: const Text('Cancelar'),
        ),
        ElevatedButton(
          onPressed: () async {
            if (_formKey.currentState!.validate()) {
              final data = {
                'name': _nameCtrl.text,
                'price': double.tryParse(_priceCtrl.text) ?? 0,
                'price_type': _priceType,
              };
              try {
                if (widget.extraToEdit == null) {
                  await ref.read(catalogRepoProvider).createExtra(data);
                } else {
                  await ref
                      .read(catalogRepoProvider)
                      .updateExtra(widget.extraToEdit!.id, data);
                }
                ref.invalidate(catalogProvider);
                if (context.mounted) context.pop();
              } catch (e) {
                // error
              }
            }
          },
          child: const Text('Guardar'),
        ),
      ],
    );
  }
}
