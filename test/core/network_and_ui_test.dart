import 'package:flutter_test/flutter_test.dart';
import 'package:pasteleria_180_flutter/core/network/dio_client.dart';
import 'package:pasteleria_180_flutter/core/network/auth_interceptor.dart';
import 'package:intl/intl.dart';

void main() {
  test('DioClient preserves onUnauthorized callback across init calls', () async {
    final client = DioClient();
    bool callbackFired = false;
    void onUnauthorized() {
      callbackFired = true;
    }

    await client.init(onUnauthorized: onUnauthorized);

    // Segunda llamada a init() sin argumento
    await client.init();

    // Verifica que el interceptor conserva el callback original
    final interceptor = client.dio.interceptors.whereType<AuthInterceptor>().first;
    interceptor.onUnauthorized?.call();
    expect(callbackFired, isTrue);
  });

  test('NumberFormat no crashea al recibir total nulo gracias al fallback seguro', () {
    final fmt = NumberFormat(r"'$' #,##0", 'es_AR');
    double? nullTotal;
    final totalString = fmt.format(nullTotal ?? 0.0);
    expect(totalString, isNotEmpty);
  });
}
