plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.example.royalclinic"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        // ✅ Aktifkan desugaring
        isCoreLibraryDesugaringEnabled = true
        // ✅ Naikkan ke Java 17
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        // ✅ jvmTarget 17
        jvmTarget = "17"
    }

    defaultConfig {
        applicationId = "com.example.royalclinic"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}

flutter {
    source = "../.."
}

dependencies {
    // ✅ Update ke versi yang diminta plugin (≥ 2.1.4)
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}
