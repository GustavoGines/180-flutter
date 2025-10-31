import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import '../../core/models/client.dart';
import 'clients_repository.dart';
import 'package:go_router/go_router.dart';

class ClientsPage extends ConsumerStatefulWidget {
  const ClientsPage({super.key});
  @override
  ConsumerState<ClientsPage> createState() => _ClientsPageState();
}

class _ClientsPageState extends ConsumerState<ClientsPage> {
  final _q = TextEditingController();
  List<Client> _items = [];
  bool _loading = false;

  Future<void> _search() async {
    setState(() => _loading = true);
    final r = await ref.read(clientsRepoProvider).searchClients(_q.text.trim());
    setState(() {
      _items = r;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Clientes'),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_outline),
            tooltip: 'Ver papelera',
            onPressed: () => context.push('/clients/trashed'),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _q,
                    decoration: const InputDecoration(labelText: 'Buscar'),
                    onSubmitted: (_) => _search(), // Opcional: buscar con Enter
                  ),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: _loading ? null : _search,
                  child: const Text('Buscar'),
                ),
              ],
            ),
          ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : ListView.separated(
                    itemCount: _items.length,
                    separatorBuilder: (_, _) => const Divider(height: 1),
                    itemBuilder: (_, i) {
                      final c = _items[i];
                      return ListTile(
                        title: Text(c.name),
                        subtitle: Text('${c.phone ?? "-"} • ${c.email ?? "-"}'),
                        onTap: () =>
                            context.push('/clients/${c.id}'), // Va al detalle
                        trailing: const Icon(Icons.chevron_right),
                      );
                    },
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.push('/clients/new'),
        child: const Icon(Icons.add),
      ),
    );
  }
}
