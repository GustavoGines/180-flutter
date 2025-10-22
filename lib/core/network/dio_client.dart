import 'package:dio/dio.dart';
import 'package:pretty_dio_logger/pretty_dio_logger.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'auth_interceptor.dart';

// Lee la variable 'API_BASE' que se inyecta en la compilación desde launch.json
const String _apiBase = String.fromEnvironment(
  'API_BASE',
  defaultValue: 'http://localhost:8000/api', // Un valor por defecto por si acaso
);

class DioClient {
  static final DioClient _instance = DioClient._internal();
  factory DioClient() => _instance;

  late final Dio dio;

  DioClient._internal() {
    dio = Dio(
      BaseOptions(
        // Usa la variable que lee de la configuración de compilación
        baseUrl: _apiBase,
        connectTimeout: const Duration(seconds: 60),
        receiveTimeout: const Duration(seconds: 60),
        headers: {'Accept': 'application/json'},
      ),
    );
  }

  final storage = const FlutterSecureStorage();

  Future<void> init() async {
    dio.interceptors.clear();
    dio.interceptors.add(AuthInterceptor(storage));
    dio.interceptors.add(
      PrettyDioLogger(
        requestHeader: true,
        requestBody: true,
        responseHeader: false,
        responseBody: true,
        error: true,
        compact: true,
      ),
    );
  }
}