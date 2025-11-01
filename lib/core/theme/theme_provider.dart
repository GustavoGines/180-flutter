import 'package:flutter_riverpod/flutter_riverpod.dart';

// Opciones disponibles para el usuario
enum AppThemeMode { system, light, dark }

// Notifier para manejar el estado del modo de tema
class ThemeModeNotifier extends Notifier<AppThemeMode> {
  // Aquí se podría cargar el valor guardado de SharedPreferences
  @override
  AppThemeMode build() {
    return AppThemeMode
        .system; // Por defecto, sigue la configuración del sistema
  }

  void setMode(AppThemeMode mode) {
    state = mode;
    // En una app real, aquí guardarías 'mode.name' en SharedPreferences
  }
}

final themeModeProvider = NotifierProvider<ThemeModeNotifier, AppThemeMode>(
  ThemeModeNotifier.new,
);
