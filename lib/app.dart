import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// Importa el provider de tu archivo de rutas
import 'router.dart';

// 1. Cambia StatelessWidget por ConsumerWidget
class One80App extends ConsumerWidget {
  const One80App({super.key});

  @override
  // 2. Agrega "WidgetRef ref" al método build
  Widget build(BuildContext context, WidgetRef ref) {
    // 3. Usa ref.watch para obtener el router desde el provider
    final router = ref.watch(routerProvider);

    return MaterialApp.router(
      title: '180° Pastelería',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.pinkAccent),
        useMaterial3: true,
      ),
      // Ahora la variable "router" sí existe y está correctamente asignada
      routerConfig: router,
    );
  }
}