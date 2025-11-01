package com.one80.pasteleria.pasteleria_180_flutter

import android.content.Context
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import com.google.firebase.appdistribution.FirebaseAppDistribution
import com.google.firebase.appdistribution.FirebaseAppDistributionException
import com.google.firebase.appdistribution.AppDistributionRelease

object AppDistHook {

    private const val CHANNEL = "app_distribution"

    @JvmStatic
    fun init(flutterEngine: FlutterEngine, context: Context) {
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "checkForUpdate" -> {
                        checkForUpdate(
                            context = context,
                            onSuccess = { result.success(true) },      // Update encontrado y descargando
                            onNoUpdate = { result.success(false) },   // No hay update
                            onError = { msg -> result.error("APPDIST_ERROR", msg, null) }
                        )
                    }
                    else -> result.notImplemented()
                }
            }
    }

    // 👇 ESTA ES LA FUNCIÓN TOTALMENTE CORREGIDA
    private fun checkForUpdate(
        context: Context,
        onSuccess: () -> Unit,
        onNoUpdate: () -> Unit,
        onError: (String) -> Unit
    ) {
        // 1. Obtener la instancia
        val appDistribution = FirebaseAppDistribution.getInstance()

        // 2. 🌟 ¡EL PASO CLAVE FALTANTE! 🌟
        //    Intentar loguear al tester. Si es la primera vez,
        //    mostrará la UI de login de Google.
        appDistribution.signInTester()
            .addOnSuccessListener {
                // 3. SI EL LOGIN ES EXITOSO (o ya estaba logueado),
                //    procedemos a buscar el update.
                
                // 3a. Obtener la versión local
                val localVersionCode = try {
                    val pInfo = context.packageManager.getPackageInfo(context.packageName, 0)
                    @Suppress("DEPRECATION")
                    pInfo.versionCode.toLong()
                } catch (e: Exception) {
                    onError("No se pudo leer la versión local: ${e.message}")
                    return@addOnSuccessListener // Salir del listener de signInTester
                }
                
                // 3b. Usar 'checkForNewRelease' (solo comprueba)
                appDistribution.checkForNewRelease()
                    .addOnSuccessListener { release: AppDistributionRelease? ->
                        if (release == null) {
                            // No hay ninguna versión en el servidor
                            onNoUpdate()
                            return@addOnSuccessListener
                        }

                        // 3c. ¡LA COMPARACIÓN MANUAL!
                        val remoteVersionCode = release.versionCode
                        if (remoteVersionCode > localVersionCode) {
                            
                            // 4. 🌟 ¡EL OTRO PASO CLAVE! 🌟
                            //    Si hay update, ¡iniciar la descarga!
                            //    Esto mostrará la notificación.
                            appDistribution.updateIfNewReleaseAvailable()
                            
                            // 5. Avisar a Dart que el update está en progreso
                            onSuccess()
                        } else {
                            // Si son iguales o menor, no hay update
                            onNoUpdate()
                        }
                    }
                    .addOnFailureListener { e -> // Error de checkForNewRelease
                        val msg = if (e is FirebaseAppDistributionException) e.message ?: "Unknown" else e.toString()
                        onError(msg)
                    }
            }
            .addOnFailureListener { e -> // Error de signInTester
                val msg = if (e is FirebaseAppDistributionException) e.message ?: "Unknown" else e.toString()
                onError(msg)
            }
    }
}