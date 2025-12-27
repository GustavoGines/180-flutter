plugins {
    id("com.android.application")
    id("com.google.gms.google-services")
    id("org.jetbrains.kotlin.android")
    // El plugin de Flutter debe ir después del de Android/Kotlin
    id("dev.flutter.flutter-gradle-plugin")
    // Plugin Gradle de Firebase App Distribution (para subir builds)
    id("com.google.firebase.appdistribution")
}

android {
    namespace = "com.one80.pasteleria.pasteleria_180_flutter"
    compileSdk = 34
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
        isCoreLibraryDesugaringEnabled = true
    }

    kotlinOptions {
        jvmTarget = "17"
    }

    defaultConfig {
        applicationId = "com.one80.pasteleria.pasteleria_180_flutter"
        minSdk = 23
        targetSdk = 34
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    // --- BUILD TYPES ---
    buildTypes {
        getByName("release") {
            // Firma debug para simplificar (cuando quieras, cambiá a tu keystore propia)
            signingConfig = signingConfigs.getByName("debug")
            isMinifyEnabled = false
            isShrinkResources = false
            // Fallbacks por si alguna lib solo publica 'profile' o 'debug'
            matchingFallbacks += listOf("release", "profile", "debug")
        }
        // (debug y profile los maneja Flutter por defecto)
    }

    // --- FLAVOR DIMENSIONS + PRODUCT FLAVORS ---
    // El módulo de App Distribution usa 'staging'/'production'.
    // Mapeamos nuestros flavors: dev -> staging, prod -> production.
    flavorDimensions += listOf("default")

    productFlavors {
        create("dev") {
            dimension = "default"
            applicationIdSuffix = ".dev"
            resValue("string", "app_name", "Pastelería 180 (Dev)")
            matchingFallbacks += listOf("staging")
        }
        create("prod") {
            dimension = "default"
            resValue("string", "app_name", "Pastelería 180")
            matchingFallbacks += listOf("production")
        }
    }
}

// Config básica de Flutter
flutter {
    source = "../.."
}

// --- DEPENDENCIAS ---
// API en todas las variantes (compila en prod sin traer el SDK completo)
// SDK completo SOLO en dev (muestra el diálogo de actualización a testers)
dependencies {
    // Soporte de temas AppCompat / Material
    implementation("androidx.appcompat:appcompat:1.7.0")
    implementation("com.google.android.material:material:1.12.0")
    // Firebase
    implementation("com.google.firebase:firebase-appdistribution-api:16.0.0-beta17")
    add("devImplementation", "com.google.firebase:firebase-appdistribution:16.0.0-beta17")

    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}

/*
Opcional: configuración del plugin para subir builds (no afecta runtime)
firebaseAppDistribution {
    // serviceCredentialsFile = file("path/a/tu-service-account.json")
    // appId = "1:xxx:android:yyy"
    // testers = "correo1@...,correo2@..."
    // releaseNotes = "Cambios..."
}
*/
