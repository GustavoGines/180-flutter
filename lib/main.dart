import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // 2. Agrega esta línea para inicializar los formatos de Argentina
  await initializeDateFormatting('es_AR', null);
  
  runApp(const ProviderScope(child: One80App()));
}