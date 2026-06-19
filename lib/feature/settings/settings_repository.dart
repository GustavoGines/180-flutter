import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/network/dio_client.dart';

class AppSetting {
  final String key;
  final dynamic value;
  final String type;

  AppSetting({required this.key, required this.value, required this.type});

  factory AppSetting.fromJson(Map<String, dynamic> json) {
    return AppSetting(
      key: json['key'],
      value: json['value'],
      type: json['type'] ?? 'string',
    );
  }
}

final settingsRepoProvider = Provider<SettingsRepository>((ref) => SettingsRepository());

class SettingsRepository {
  final Dio _dio = DioClient().dio;

  Future<Map<String, dynamic>> getAllSettings() async {
    final res = await _dio.get('/settings');
    final data = res.data['data'];
    if (data is List) {
      return {};
    }
    return data as Map<String, dynamic>;
  }

  Future<void> updateSettings(List<Map<String, dynamic>> settings) async {
    await _dio.post('/settings', data: {'settings': settings});
  }
}

// Global provider for accessing remote settings in the app
final remoteSettingsProvider = FutureProvider<Map<String, dynamic>>((ref) async {
  return ref.watch(settingsRepoProvider).getAllSettings();
});
