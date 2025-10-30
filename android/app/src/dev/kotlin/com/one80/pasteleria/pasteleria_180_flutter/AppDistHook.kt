package com.one80.pasteleria.pasteleria_180_flutter

import android.content.Context // 👈 AÑADE ESTA LÍNEA
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import com.google.firebase.appdistribution.FirebaseAppDistribution
// import com.google.firebase.appdistribution.UpdateProgress // Ya no lo usamos
import com.google.firebase.appdistribution.FirebaseAppDistributionException
import com.google.firebase.appdistribution.AppDistributionRelease // 👈 AÑADE ESTA LÍNEA

object AppDistHook {

    private const val CHANNEL = "app_distribution"

    // 👇 MODIFICADO: Acepta el 'Context'
    @JvmStatic
    fun init(flutterEngine: FlutterEngine, context: Context) { 
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "checkForUpdate" -> {
                        // 👇 MODIFICADO: Pasa el 'context' a la función
                        checkForUpdate(
                            context = context, 
                            onSuccess = { result.success(true) },
                            onNoUpdate = { result.success(false) },
                            onError = { msg -> result.error("APPDIST_ERROR", msg, null) }
                        )
                    }
                    else -> result.notImplemented()
                }
            }
    }

    // 👇 MODIFICADO: Esta es la nueva función con la lógica de comparación
    private fun checkForUpdate(
        context: Context, // 👈 Acepta el 'Context'
        onSuccess: () -> Unit,
        onNoUpdate: () -> Unit,
        onError: (String) -> Unit
    ) {
        // 1. Obtener la versión local (build number)
        val localVersionCode = try {
            val pInfo = context.packageManager.getPackageInfo(context.packageName, 0)
            // Usa 'versionCode' (el número de build), no 'versionName' (el string)
            // Para SDK 28+ se usa 'longVersionCode', pero 'versionCode' es seguro
            @Suppress("DEPRECATION")
            pInfo.versionCode.toLong() 
        } catch (e: Exception) {
            onError("No se pudo leer la versión local: ${e.message}")
            return
        }
        
        // 2. Usar 'checkForNewRelease' (solo comprueba, no actualiza)
        FirebaseAppDistribution.getInstance()
            .checkForNewRelease()
            .addOnSuccessListener { release: AppDistributionRelease? ->
                if (release == null) {
                    // No hay ninguna versión en el servidor
                    onNoUpdate()
                    return@addOnSuccessListener
                }

                // 3. ✅ ¡LA COMPARACIÓN MANUAL!
                // Compara el build number del servidor con el local
                val remoteVersionCode = release.versionCode
                if (remoteVersionCode > localVersionCode) {
                    // Solo si la remota es ESTRICTAMENTE MAYOR
                    onSuccess()
                } else {
                    // Si son iguales (2 > 2 es false) o menor, no hay update
                    onNoUpdate()
                }
            }
            .addOnFailureListener { e ->
                val msg = if (e is FirebaseAppDistributionException) e.message ?: "Unknown" else e.toString()
                onError(msg)
            }
    }
}