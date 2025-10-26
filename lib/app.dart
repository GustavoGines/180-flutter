import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// Importa el provider de tu archivo de rutas
import 'router.dart'; // Asegúrate que esta ruta sea correcta

// Colores de la marca (opcional, pero bueno tenerlos centralizados)
const Color primaryPink = Color(0xFFF8B6B6);
const Color darkBrown = Color(0xFF7A4A4A);
const Color lightBrownText = Color(0xFFA57D7D);

// 1. ConsumerWidget ya está bien
class One80App extends ConsumerWidget {
  const One80App({super.key});

  @override
  // 2. WidgetRef ref ya está bien
  Widget build(BuildContext context, WidgetRef ref) {
    // 3. Obtener router ya está bien
    final router = ref.watch(routerProvider);

    return MaterialApp.router(
      title: '180 App', // <-- Cambiado el título según tu indicación anterior
      theme: ThemeData(
        // Usar los colores de tu marca en el tema
        colorScheme: ColorScheme.fromSeed(
          seedColor: darkBrown, // Usar darkBrown como color principal
          primary: darkBrown,
          secondary: primaryPink,
          // Puedes definir más colores aquí si quieres
        ),
        appBarTheme: const AppBarTheme(
          // Estilo consistente para AppBar
          backgroundColor: Colors.white,
          foregroundColor: darkBrown, // Color del título y los iconos
          elevation: 1,
          iconTheme: IconThemeData(color: darkBrown),
          titleTextStyle: TextStyle(
            color: darkBrown,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        filledButtonTheme: FilledButtonThemeData(
          // Estilo base para botones
          style: FilledButton.styleFrom(
            backgroundColor: darkBrown,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 24),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            textStyle: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          // Estilo base para inputs
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: primaryPink.withAlpha(128)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: darkBrown, width: 2),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: primaryPink.withAlpha(204)),
          ),
          labelStyle: const TextStyle(color: lightBrownText),
          // Estilos adicionales...
        ),

        useMaterial3: true,
      ),

      // --- AÑADIR LOCALIZACIONES ---
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale(
          'es',
          'AR',
        ), // Español (Argentina) como único soportado por ahora
        // Locale('en', ''), // Podrías añadir inglés si lo necesitas
      ],
      locale: const Locale(
        'es',
        'AR',
      ), // Forzar español Argentina como idioma por defecto
      // --- FIN LOCALIZACIONES ---

      // Asignar routerConfig
      routerConfig: router,
    );
  }
}
