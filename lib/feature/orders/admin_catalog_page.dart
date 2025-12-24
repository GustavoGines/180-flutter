import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/models/catalog.dart';
import 'catalog_repository.dart';
import 'admin/simple_forms.dart';

class AdminCatalogPage extends ConsumerStatefulWidget {
  const AdminCatalogPage({super.key});

  @override
  ConsumerState<AdminCatalogPage> createState() => _AdminCatalogPageState();
}

class _AdminCatalogPageState extends ConsumerState<AdminCatalogPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final catalogAsync = ref.watch(catalogProvider);
    final theme = Theme.of(context);
    // Removed unused isDark

    // Colores premium
    final primaryColor = theme.colorScheme.primary;
    // Removed unused surfaceColor

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      body: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) {
          return [
            SliverAppBar(
              title: const Text('Gestión de Catálogo'),
              centerTitle: true,
              pinned: true,
              floating: true,
              bottom: TabBar(
                controller: _tabController,
                isScrollable: true,
                indicatorColor: primaryColor,
                labelColor: primaryColor,
                unselectedLabelColor: theme.colorScheme.onSurfaceVariant,
                tabs: const [
                  Tab(text: 'Tortas'),
                  Tab(text: 'Mesa Dulce'),
                  Tab(text: 'Boxes'),
                  Tab(text: 'Rellenos'),
                  Tab(text: 'Extras'),
                ],
              ),
            ),
          ];
        },
        body: catalogAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (err, stack) => Center(child: Text('Error: $err')),
          data: (catalog) {
            return TabBarView(
              controller: _tabController,
              children: [
                _ProductList(
                  products: catalog.products,
                  category: ProductCategory.torta,
                ),
                _ProductList(
                  products: catalog.products,
                  category: ProductCategory.mesaDulce,
                ),
                _ProductList(
                  products: catalog.products,
                  category: ProductCategory.box,
                ),
                _FillingList(fillings: catalog.fillings),
                _ExtraList(extras: catalog.extras),
              ],
            );
          },
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          _handleCreateAction(_tabController.index);
        },
        icon: const Icon(Icons.add),
        label: const Text('Nuevo Item'),
        backgroundColor: primaryColor,
        foregroundColor: theme.colorScheme.onPrimary,
      ),
    );
  }

  void _handleCreateAction(int index) {
    if (index < 3) {
      // Crear Producto
      context.push('/admin/catalog/product/new');
    } else if (index == 3) {
      // Crear Relleno
      showDialog(context: context, builder: (_) => const FillingFormDialog());
    } else {
      // Crear Extra
      showDialog(context: context, builder: (_) => const ExtraFormDialog());
    }
  }
}

class _ProductList extends ConsumerWidget {
  final List<Product> products;
  final ProductCategory category;

  const _ProductList({required this.products, required this.category});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filtered = products.where((p) => p.category == category).toList();

    if (filtered.isEmpty) {
      return const Center(
        child: Text(
          'No hay productos en esta categoría',
          style: TextStyle(color: Colors.grey),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: filtered.length,
      itemBuilder: (context, index) {
        final product = filtered[index];
        return Card(
          elevation: 2,
          margin: const EdgeInsets.only(bottom: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: ListTile(
            title: Text(
              product.name,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Text('\$${product.basePrice.toStringAsFixed(0)}'),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.edit_outlined),
                  onPressed: () {
                    context.push('/admin/catalog/product/edit', extra: product);
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline, color: Colors.red),
                  onPressed: () async {
                    final confirm = await showDialog<bool>(
                      context: context,
                      builder: (context) => AlertDialog(
                        title: const Text('Eliminar Producto'),
                        content: Text(
                          '¿Estás seguro de eliminar "${product.name}"?',
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(context, false),
                            child: const Text('Cancelar'),
                          ),
                          TextButton(
                            onPressed: () => Navigator.pop(context, true),
                            child: const Text('Eliminar'),
                          ),
                        ],
                      ),
                    );

                    if (confirm == true) {
                      try {
                        await ref
                            .read(catalogRepoProvider)
                            .deleteProduct(product.id);
                        ref.invalidate(catalogProvider);
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Producto eliminado')),
                          );
                        }
                      } catch (e) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(
                            context,
                          ).showSnackBar(SnackBar(content: Text('Error: $e')));
                        }
                      }
                    }
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _FillingList extends ConsumerWidget {
  final List<Filling> fillings;
  const _FillingList({required this.fillings});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: fillings.length,
      itemBuilder: (context, index) {
        final f = fillings[index];
        return Card(
          child: ListTile(
            title: Text(f.name),
            subtitle: Text(f.isFree ? 'Gratis' : '+\$${f.pricePerKg}/kg'),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.edit_outlined),
                  onPressed: () => showDialog(
                    context: context,
                    builder: (_) => FillingFormDialog(fillingToEdit: f),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline, color: Colors.red),
                  onPressed: () async {
                    final confirm = await showDialog<bool>(
                      context: context,
                      builder: (context) => AlertDialog(
                        title: const Text('Eliminar Relleno'),
                        content: Text('¿Estás seguro de eliminar "${f.name}"?'),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(context, false),
                            child: const Text('Cancelar'),
                          ),
                          TextButton(
                            onPressed: () => Navigator.pop(context, true),
                            child: const Text('Eliminar'),
                          ),
                        ],
                      ),
                    );

                    if (confirm == true) {
                      try {
                        await ref
                            .read(catalogRepoProvider)
                            .deleteFilling(f.id);
                        ref.invalidate(catalogProvider);
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Relleno eliminado')),
                          );
                        }
                      } catch (e) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(
                            context,
                          ).showSnackBar(SnackBar(content: Text('Error: $e')));
                        }
                      }
                    }
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _ExtraList extends ConsumerWidget {
  final List<Extra> extras;
  const _ExtraList({required this.extras});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: extras.length,
      itemBuilder: (context, index) {
        final e = extras[index];
        return Card(
          child: ListTile(
            title: Text(e.name),
            subtitle: Text(
              '+\$${e.price.toStringAsFixed(0)} ${e.priceType == 'per_unit' ? '(c/u)' : '(/kg)'}',
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.edit_outlined),
                  onPressed: () => showDialog(
                    context: context,
                    builder: (_) => ExtraFormDialog(extraToEdit: e),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline, color: Colors.red),
                  onPressed: () async {
                    final confirm = await showDialog<bool>(
                      context: context,
                      builder: (context) => AlertDialog(
                        title: const Text('Eliminar Extra'),
                        content: Text('¿Estás seguro de eliminar "${e.name}"?'),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(context, false),
                            child: const Text('Cancelar'),
                          ),
                          TextButton(
                            onPressed: () => Navigator.pop(context, true),
                            child: const Text('Eliminar'),
                          ),
                        ],
                      ),
                    );

                    if (confirm == true) {
                      try {
                        await ref.read(catalogRepoProvider).deleteExtra(e.id);
                        ref.invalidate(catalogProvider);
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Extra eliminado')),
                          );
                        }
                      } catch (err) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Error: $err')),
                          );
                        }
                      }
                    }
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
