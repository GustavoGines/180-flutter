import 'dart:io';
import 'dart:convert';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:pasteleria_180_flutter/feature/auth/auth_repository.dart';
import 'package:pasteleria_180_flutter/feature/auth/auth_state.dart';

/// 📦 Provider global para leer el payload cuando el usuario toca una notificación
final notificationTapPayloadProvider = StateProvider<Map<String, dynamic>?>(
  (ref) => null,
);

/// 📦 Provider global para el token FCM actual del dispositivo
final fcmTokenProvider = StateProvider<String?>((ref) => null);

/// 🚀 Provider para el servicio principal de Firebase Messaging
final firebaseMessagingServiceProvider = Provider<FirebaseMessagingService>(
  (ref) => FirebaseMessagingService(ref),
);

/// 🧠 Handler global si llega un mensaje con la app cerrada completamente
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  debugPrint("📩 [Background] Mensaje recibido: ${message.messageId}");
}

class FirebaseMessagingService {
  final Ref ref;
  FirebaseMessagingService(this.ref);

  final FirebaseMessaging _fcm = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  static String? _lastToken;

  /// Inicializa permisos, listeners y registro del token
  Future<void> init() async {
    await _requestPermission();

    // ✅ Registrar solo si el usuario está autenticado
    final authState = ref.read(authStateProvider);
    if (authState.user != null) {
      await _getTokenAndRegister();
    } else {
      debugPrint("⚠️ [FCM] Usuario no autenticado → no se registra token.");
    }

    // 🔁 Escuchar cambios de token (por reinstalación o limpieza de caché)
    _fcm.onTokenRefresh.listen((token) async {
      final authState = ref.read(authStateProvider);
      if (authState.user != null) {
        await _registerTokenOnce(token);
      } else {
        debugPrint("⚠️ [FCM] Ignorando refresh: usuario no logueado.");
      }
    });

    // 🔔 Configurar listeners de notificaciones
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

    if (!kIsWeb && (Platform.isAndroid || Platform.isIOS)) {
      await _setupNotificationTapListeners();
      _listenForForegroundMessages();
    }

    debugPrint("✅ [FCM] Firebase Messaging Service inicializado.");
  }

  /// 🔐 Solicita permisos de notificación
  Future<void> _requestPermission() async {
    final settings = await _fcm.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    if (settings.authorizationStatus == AuthorizationStatus.authorized) {
      debugPrint('✅ Permiso de notificación concedido.');
    } else {
      debugPrint('🚫 Permiso de notificación denegado.');
    }
  }

  /// 📡 Obtiene el token FCM y lo registra si es nuevo
  Future<void> _getTokenAndRegister() async {
    try {
      final token = await _fcm.getToken();
      if (token != null && token.isNotEmpty) {
        await _registerTokenOnce(token);
      } else {
        debugPrint('⚠️ [FCM] No se pudo obtener token.');
      }
    } catch (e) {
      debugPrint('❌ [FCM] Error al obtener token: $e');
    }
  }

  /// 🧭 Registra el token solo si cambia
  Future<void> _registerTokenOnce(String token) async {
    // Guarda el token en el provider para que el resto de la app lo vea.
    ref.read(fcmTokenProvider.notifier).state = token;

    if (_lastToken == token) {
      debugPrint("ℹ️ [FCM] Token no cambió, no se vuelve a registrar.");
      return;
    }
    _lastToken = token;
    debugPrint('📲 [FCM] Token nuevo: $token');
    try {
      await ref.read(authRepoProvider).registerDevice(token);
      debugPrint('✅ [FCM] Token registrado correctamente en backend.');
    } catch (e) {
      debugPrint('❌ [FCM] Error al registrar token: $e');
    }
  }

  /// 💬 Listener para taps de notificaciones
  Future<void> _setupNotificationTapListeners() async {
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      debugPrint('🟢 [FCM] TAP (Background): ${message.data}');
      _handleTap(message.data);
    });

    FirebaseMessaging.instance.getInitialMessage().then((message) {
      if (message != null) {
        debugPrint('🟣 [FCM] TAP (Terminated): ${message.data}');
        _handleTap(message.data);
      }
    });

    const androidSettings = AndroidInitializationSettings(
      '@drawable/notification_icon',
    );
    const initSettings = InitializationSettings(android: androidSettings);

    await _localNotifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: (NotificationResponse response) {
        if (response.payload != null && response.payload!.isNotEmpty) {
          debugPrint('🟡 [FCM] TAP (Foreground): ${response.payload}');
          _handleTap(jsonDecode(response.payload!) as Map<String, dynamic>);
        }
      },
    );
  }

  /// 📤 Publica el payload del tap en Riverpod
  void _handleTap(Map<String, dynamic> data) {
    ref.read(notificationTapPayloadProvider.notifier).state = data;
  }

  /// 🔔 Listener para notificaciones en primer plano
  void _listenForForegroundMessages() {
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      debugPrint('💌 [FCM] Notificación recibida en primer plano');
      final notification = message.notification;
      final android = message.notification?.android;

      if (notification != null && (android != null || kIsWeb)) {
        _localNotifications.show(
          notification.hashCode,
          notification.title,
          notification.body,
          NotificationDetails(
            android: AndroidNotificationDetails(
              'high_importance_channel',
              'Notificaciones de Pedidos',
              channelDescription:
                  'Recordatorios de pedidos y actualizaciones de 180° Pastelería.',
              importance: Importance.max,
              priority: Priority.high,
              icon: '@drawable/notification_icon',
            ),
          ),
          payload: jsonEncode(message.data),
        );
      }
    });
  }

  /// Limpia el token cacheado y el provider al cerrar sesión.
  void clearTokenCache() {
    _lastToken = null;
    ref.read(fcmTokenProvider.notifier).state = null;
    debugPrint("🧼 [FCM] Cache de token local limpiado.");
  }
}
