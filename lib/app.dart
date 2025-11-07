import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// Importa el router y los temas
import 'router.dart';
import 'core/theme/theme_data.dart';
import 'core/theme/theme_provider.dart';

// 🎨 Constantes de color y estilo
const Color primaryPink = Color(0xFFF8B6B6);
const Color darkBrown = Color(0xFF7A4A4A);
const Color lightBrownText = Color(0xFFA57D7D);

const Map<AppThemeMode, IconData> themeModeIcons = {
  AppThemeMode.system: Icons.brightness_auto_outlined,
  AppThemeMode.light: Icons.light_mode_outlined,
  AppThemeMode.dark: Icons.dark_mode_outlined,
};

class One80App extends ConsumerWidget {
  const One80App({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // ✅ Router estable, sin re-crearse en cada cambio
    final router = ref.watch(routerProvider);

    // ✅ Modo de tema actual (light/dark/system)
    final themeModeOption = ref.watch(themeModeProvider);
    final themeMode = switch (themeModeOption) {
      AppThemeMode.system => ThemeMode.system,
      AppThemeMode.light => ThemeMode.light,
      AppThemeMode.dark => ThemeMode.dark,
    };

    return MaterialApp.router(
      title: '180° Pastelería',
      debugShowCheckedModeBanner: false,
      theme: lightTheme,
      darkTheme: darkTheme,
      themeMode: themeMode,

      // ✅ Localización
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [Locale('es', 'AR')],
      locale: const Locale('es', 'AR'),

      // ✅ Nuevo router con GoRouter estable
      routerConfig: router,
    );
  }
}
