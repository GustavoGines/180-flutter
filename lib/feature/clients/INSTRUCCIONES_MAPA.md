Guía de Instalación para Google Maps en Flutter

¡IMPORTANTE! La nueva pantalla de mapa (map_picker_page.dart) no funcionará hasta que sigas estos 3 pasos manuales para configurar la API de Google Maps.

Paso 1: Añadir Paquete

Abre tu archivo pubspec.yaml y añade la dependencia de Google Maps:

dependencies:
flutter:
sdk: flutter

# ... (tus otros paquetes)

google_maps_flutter: ^2.6.1 # Puedes usar la versión más reciente

# ... (asegúrate de tener geolocator y permission_handler también)

Luego, ejecuta flutter pub get en tu terminal.

Paso 2: Obtener Clave de API de Google Maps

Esta es la parte más importante.

Ve a la Google Cloud Console.

Crea un proyecto nuevo (ej: "180 Pastelería App").

En el buscador de APIs, busca y ACTIVA las siguientes dos (2) APIs:

Maps SDK for Android

Maps SDK for iOS

Ve a la sección "Credenciales" (Credentials) en el menú.

Haz clic en "Crear Credenciales" -> "Clave de API".

Copia la clave que se genera (ej: AIzaSy...). ¡Esta es tu clave!

(Opcional pero recomendado) Haz clic en "Restringir clave" y restringe el uso a "Apps de Android" y "Apps de iOS" para que nadie más pueda usarla.

Paso 3: Configuración Nativa (Pegar la clave)

Debes pegar la clave que copiaste en los archivos de configuración nativos.

Para Android:

Abre el archivo: android/app/src/main/AndroidManifest.xml

Pega tu clave dentro de la etiqueta <application>:

<manifest ...>
<application ...>

    <!-- 👇 PEGA ESTE BLOQUE CON TU CLAVE 👇 -->
    <meta-data
      android:name="com.google.android.geo.API_KEY"
      android:value="AQUI_VA_TU_CLAVE_DE_API_DE_GOOGLE"/>
    <!-- 👆 FIN DEL BLOQUE 👆 -->

    <activity ...>
      ...
    </activity>

  </application>
</manifest>

Para iOS:

Abre el archivo: ios/Runner/AppDelegate.swift

Importante: Si tu archivo se llama AppDelegate.m, avísame y te doy las instrucciones para Objective-C.

Pega tu clave dentro de la función didFinishLaunchingWithOptions:

import UIKit
import Flutter
import GoogleMaps // 👈 1. AÑADE ESTE IMPORT

@UIApplicationMain
@objc class AppDelegate: FlutterAppDelegate {
override func application(
\_ application: UIApplication,
didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
) -> Bool {

    // 👇 2. AÑADE ESTA LÍNEA CON TU CLAVE 👇
    GMSServices.provideAPIKey("AQUI_VA_TU_CLAVE_DE_API_DE_GOOGLE")

    GeneratedPluginRegistrant.register(with: self)
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)

}
}

Paso 4: ¡Reiniciar la App!

Después de hacer todos estos cambios (Paso 1, 2 y 3), debes detener la aplicación por completo y volver a ejecutarla (flutter run). Un "Hot Reload" no es suficiente.

¡Después de esto, el botón "Ver Mapa" debería funcionar!
