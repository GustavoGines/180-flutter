import 'dart:io';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pasteleria_180_flutter/feature/auth/auth_repository.dart';

// 1. Provider para nuestro nuevo servicio
final firebaseMessagingServiceProvider = Provider<FirebaseMessagingService>((
  ref,
) {
  // El servicio "observa" el repositorio de auth para poder usarlo
  final authRepo = ref.watch(authRepoProvider);
  return FirebaseMessagingService(authRepo);
});

// Esta función se llama si la app está terminada y se abre por una notificación
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  debugPrint("Handling a background message: ${message.messageId}");
}

class FirebaseMessagingService {
  final AuthRepository _authRepository;
  FirebaseMessagingService(this._authRepository);

  final FirebaseMessaging _fcm = FirebaseMessaging.instance;

  // (Opcional) Instancia para notificaciones locales (en primer plano)
  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  /// Inicializa todo el servicio de notificaciones
  Future<void> init() async {
    // 1. Pide permiso (iOS y Android 13+)
    await _requestPermission();

    // 2. Obtiene el token y lo registra en nuestro backend (Laravel)
    await _getTokenAndRegister();

    // 3. Configura el listener de token (si el token cambia, lo re-registra)
    _fcm.onTokenRefresh.listen(_authRepository.registerDevice);

    // 4. Configura el handler para notificaciones en background/terminado
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

    // 5. (Opcional) Configura notificaciones en primer plano
    if (!kIsWeb && (Platform.isAndroid || Platform.isIOS)) {
      await _initLocalNotifications();
      _listenForForegroundMessages();
    }
  }

  /// Pide permiso al usuario
  Future<void> _requestPermission() async {
    NotificationSettings settings = await _fcm.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    if (settings.authorizationStatus == AuthorizationStatus.authorized) {
      debugPrint('Permiso de notificación concedido.');
    } else {
      debugPrint('Permiso de notificación denegado.');
    }
  }

  /// Obtiene el token y lo envía al AuthRepository
  Future<void> _getTokenAndRegister() async {
    try {
      final String? fcmToken = await _fcm.getToken();
      if (fcmToken != null) {
        debugPrint('Mi FCM Token es: $fcmToken');
        // ¡Aquí es donde llamamos a tu API de Laravel!
        await _authRepository.registerDevice(fcmToken);
      } else {
        debugPrint('No se pudo obtener el token FCM.');
      }
    } catch (e) {
      debugPrint('Error al obtener el token FCM: $e');
    }
  }

  // --- Lógica Opcional para Notificaciones en Primer Plano ---

  Future<void> _initLocalNotifications() async {
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings(
          '@drawable/notification_icon',
        ); // Usa tu ícono

    // (Añadir config de iOS si es necesario)
    const InitializationSettings initializationSettings =
        InitializationSettings(android: initializationSettingsAndroid);

    await _localNotifications.initialize(initializationSettings);
  }

  void _listenForForegroundMessages() {
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      debugPrint('¡Notificación recibida en primer plano!');
      RemoteNotification? notification = message.notification;
      AndroidNotification? android = message.notification?.android;

      if (notification != null && (android != null || kIsWeb)) {
        // Muestra la notificación local
        _localNotifications.show(
          notification.hashCode,
          notification.title,
          notification.body,
          NotificationDetails(
            android: AndroidNotificationDetails(
              'high_importance_channel', // ID del Canal
              'Notificaciones de Pedidos', // Nombre del Canal
              channelDescription: 'Recordatorios de pedidos y actualizaciones.',
              importance: Importance.max,
              priority: Priority.high,
              icon: '@mipmap/ic_launcher', // Tu ícono
            ),
          ),
        );
      }
    });
  }
}
