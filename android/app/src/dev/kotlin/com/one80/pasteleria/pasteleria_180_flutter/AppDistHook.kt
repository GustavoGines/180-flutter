package com.one80.pasteleria.pasteleria_180_flutter

import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import com.google.firebase.appdistribution.FirebaseAppDistribution
import com.google.firebase.appdistribution.UpdateProgress
import com.google.firebase.appdistribution.FirebaseAppDistributionException

object AppDistHook {

    private const val CHANNEL = "app_distribution"

    @JvmStatic
    fun init(flutterEngine: FlutterEngine) {
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "checkForUpdate" -> {
                        checkForUpdate(
                            onSuccess = { result.success(true) },
                            onNoUpdate = { result.success(false) },
                            onError = { msg -> result.error("APPDIST_ERROR", msg, null) }
                        )
                    }
                    else -> result.notImplemented()
                }
            }
    }

    private fun checkForUpdate(
        onSuccess: () -> Unit,
        onNoUpdate: () -> Unit,
        onError: (String) -> Unit
    ) {
        FirebaseAppDistribution.getInstance()
            .updateIfNewReleaseAvailable()
            .addOnProgressListener { _: UpdateProgress -> /* opcional */ }
            .addOnSuccessListener { release -> if (release != null) onSuccess() else onNoUpdate() }
            .addOnFailureListener { e ->
                val msg = if (e is FirebaseAppDistributionException) e.message ?: "Unknown" else e.toString()
                onError(msg)
            }
    }
}
