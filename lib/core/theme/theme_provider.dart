import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pasteleria_180_flutter/core/providers/shared_preferences_provider.dart';

enum AppThemeMode { system, light, dark }

class ThemeModeNotifier extends Notifier<AppThemeMode> {
  static const _key = 'theme_mode';

  @override
  AppThemeMode build() {
    final prefs = ref.watch(sharedPreferencesProvider);
    final savedMode = prefs.getString(_key);
    if (savedMode != null) {
      return AppThemeMode.values.firstWhere(
        (e) => e.name == savedMode,
        orElse: () => AppThemeMode.system,
      );
    }
    return AppThemeMode.system;
  }

  void setMode(AppThemeMode mode) {
    state = mode;
    ref.read(sharedPreferencesProvider).setString(_key, mode.name);
  }
}

final themeModeProvider = NotifierProvider<ThemeModeNotifier, AppThemeMode>(
  ThemeModeNotifier.new,
);
