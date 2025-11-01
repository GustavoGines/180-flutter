import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// Importa los temas y el provider
import 'router.dart';
import 'core/theme/theme_data.dart';
import 'core/theme/theme_provider.dart';

// Colores de la marca (opcional, pero bueno tenerlos centralizados)
const Color primaryPink = Color(0xFFF8B6B6);
const Color darkBrown = Color(0xFF7A4A4A);
const Color lightBrownText = Color(0xFFA57D7D);

// 👇 LISTA DE ÍCONOS PARA EL SELECTOR DE TEMA EN EL MENÚ
const Map<AppThemeMode, IconData> themeModeIcons = {
  AppThemeMode.system: Icons.brightness_auto_outlined,
  AppThemeMode.light: Icons.light_mode_outlined,
  AppThemeMode.dark: Icons.dark_mode_outlined,
};

class One80App extends ConsumerWidget {
  const One80App({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    // 👇 1. Observa el modo seleccionado por el usuario
    final themeModeOption = ref.watch(themeModeProvider);

    // 2. Traduce la opción de usuario a la propiedad de Flutter
    final themeMode = switch (themeModeOption) {
      AppThemeMode.system => ThemeMode.system,
      AppThemeMode.light => ThemeMode.light,
      AppThemeMode.dark => ThemeMode.dark,
    };

    return MaterialApp.router(
      title: '180 App',
      debugShowCheckedModeBanner: false,

      // 👇 3. ASIGNA LOS TRES TEMAS
      theme: lightTheme, // Usa el tema claro definido
      darkTheme: darkTheme, // Usa el tema oscuro definido
      themeMode: themeMode, // Usa el valor del provider (system, light, dark)
      // --- LOCALIZACIONES (Sin cambios) ---
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [Locale('es', 'AR')],
      locale: const Locale('es', 'AR'),

      // --- FIN LOCALIZACIONES ---
      routerConfig: router,
    );
  }
}
