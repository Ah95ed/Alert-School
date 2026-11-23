import java.util.Properties

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}
val releaseKeyPropertiesFile = rootProject.file("D:/Android_Keys/key.properties")
val releaseKeyProperties = Properties().apply {
    if (releaseKeyPropertiesFile.exists()) {
        releaseKeyPropertiesFile.inputStream().use { load(it) }
    }
}

android {
    namespace = "com.Alertschool.alert_school"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        applicationId = "com.Alertschool.alert_school"
        minSdk = 24
        targetSdk = 35
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        create("release") {
            storeFile = releaseKeyProperties.getProperty("storeFile")?.let { rootProject.file(it) }
            storePassword = releaseKeyProperties.getProperty("storePassword")
            keyAlias = releaseKeyProperties.getProperty("keyAlias")
            keyPassword = releaseKeyProperties.getProperty("keyPassword")
        }
    }
     buildTypes {
        release {
            // TODO: Add your own signing config for the release build.
             isMinifyEnabled = false
            isShrinkResources = false
            // Signing with the debug keys for now, so `flutter run --release` works.
            signingConfig = signingConfigs.getByName("release")
        }
    }

    // buildTypes {
    //     release {
    //         // WorkManager creates its Room database implementation reflectively.
           
    //     }
    // }
}

dependencies {
    implementation("androidx.work:work-runtime-ktx:2.10.1")
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

flutter {
    source = "../.."
}
