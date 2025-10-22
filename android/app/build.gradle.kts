plugins {
    id("com.android.application")
    id("org.jetbrains.kotlin.android")
    // El plugin de Flutter debe ir después
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.one80.pasteleria.pasteleria_180_flutter"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }
    kotlinOptions {
        jvmTarget = "17"
    }

    defaultConfig {
        applicationId = "com.one80.pasteleria.pasteleria_180_flutter"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

   buildTypes {
    getByName("release") {
        // Firma temporal
        signingConfig = signingConfigs.getByName("debug")

        // Para evitar el error:
        isMinifyEnabled = false
        isShrinkResources = false   // 👈 agrega esta línea

        // (opcional) si quedara algo previo, borrá cualquier shrinkResources true
    }
}

    // 👇 En KTS esto es una lista: usá add o +=
    flavorDimensions += "default"

    productFlavors {
        create("dev") {
            dimension = "default"
            applicationIdSuffix = ".dev"
            resValue("string", "app_name", "Pastelería 180 (Dev)")
        }
        create("prod") {
            dimension = "default"
            resValue("string", "app_name", "Pastelería 180")
        }
    }
}

flutter {
    source = "../.."
}
