import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pasteleria_180_flutter/core/providers/shared_preferences_provider.dart';

class BoolSettingNotifier extends Notifier<bool> {
  BoolSettingNotifier(this.prefKey, this.defaultValue);

  final String prefKey;
  final bool defaultValue;

  @override
  bool build() {
    final prefs = ref.watch(sharedPreferencesProvider);
    return prefs.getBool(prefKey) ?? defaultValue;
  }

  void toggle(bool value) {
    state = value;
    ref.read(sharedPreferencesProvider).setBool(prefKey, value);
  }
}

final pushNotificationsProvider = NotifierProvider<BoolSettingNotifier, bool>(
  () => BoolSettingNotifier('setting_push_notifs', true),
);

final vibrationProvider = NotifierProvider<BoolSettingNotifier, bool>(
  () => BoolSettingNotifier('setting_vibration', true),
);

final defaultViewProvider = NotifierProvider<BoolSettingNotifier, bool>(
  () => BoolSettingNotifier('setting_default_view', false),
);
