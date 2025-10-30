plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.example.meteo_agro_app"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion
    //ndkVersion = "25.2.9519653"
    ndkVersion = "27.0.12077973"

    dexOptions {
        javaMaxHeapSize = "4g"
        preDexLibraries = true
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17  // ✅ Changer à VERSION_17
        targetCompatibility = JavaVersion.VERSION_17  // ✅ Changer à VERSION_17
    }

    kotlinOptions {
        jvmTarget = "17"  // ✅ Changer de "11" à "17"
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.example.meteo_agro_app"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        release {
            // TODO: Add your own signing config for the release build.
            // Signing with the debug keys for now, so `flutter run --release` works.
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}

flutter {
    source = "../.."
}