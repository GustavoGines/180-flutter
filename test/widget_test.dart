// test/widget_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pasteleria_180_flutter/app.dart';

void main() {
  testWidgets('Carga LoginPage', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: One80App()));
    await tester.pumpAndSettle(); // espera router y primer frame
    expect(find.text('Ingresar'), findsOneWidget); // AppBar del login
  });
}
