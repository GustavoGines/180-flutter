package com.one80.pasteleria.pasteleria_180_flutter

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import android.content.Context // 👈 AÑADE ESTA LÍNEA

class MainActivity : FlutterActivity() {

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // Intentar cargar el hook solo si existe (en dev)
        try {
            val hookClass = Class.forName(
                "com.one80.pasteleria.pasteleria_180_flutter.AppDistHook"
            )
            // 👇 MODIFICADO: Pasa el 'applicationContext' al método init
            val method = hookClass.getMethod("init", FlutterEngine::class.java, Context::class.java)
            method.invoke(null, flutterEngine, applicationContext) 
        } catch (_: Throwable) {
            // En prod (o si no está el hook) no hace nada
        }
    }
}