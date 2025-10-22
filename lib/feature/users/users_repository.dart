import 'package:dio/dio.dart';
import '../../core/network/dio_client.dart';

class UsersRepository {
  final Dio _dio = DioClient().dio;

  Future<Map<String, dynamic>> createUser({
    required String name,
    required String email,
    required String password,
    required String role, // 'admin' | 'staff'
  }) async {
    final res = await _dio.post('/users', data: {
      'name': name,
      'email': email,
      'password': password,
      'password_confirmation': password,
      'role': role,
    });
    return (res.data as Map<String, dynamic>);
  }
}
