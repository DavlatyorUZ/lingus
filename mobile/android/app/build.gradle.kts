import java.util.Properties

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

val releaseProperties = Properties().apply {
    val privateEnv = rootProject.file("../.env")
    if (privateEnv.exists()) privateEnv.inputStream().use { load(it) }
}
fun releaseValue(name: String): String? =
    providers.environmentVariable(name).orNull ?: releaseProperties.getProperty(name)
val releaseStore = releaseValue("ANDROID_KEYSTORE")
val releaseAlias = releaseValue("ANDROID_KEY_ALIAS")
val releaseStorePassword = releaseValue("ANDROID_KEYSTORE_PASSWORD")
val releaseKeyPassword = releaseValue("ANDROID_KEY_PASSWORD")
val releaseConfigured = listOf(releaseStore, releaseAlias, releaseStorePassword, releaseKeyPassword)
    .all { !it.isNullOrBlank() }
if (gradle.startParameter.taskNames.any { it.contains("release", ignoreCase = true) } && !releaseConfigured) {
    throw GradleException("Release signing is required. Configure mobile/.env using mobile/.env.example.")
}

android {
    namespace = "uz.lexora.lexora"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        applicationId = "uz.lingoy.offline"
        minSdk = 24
        targetSdk = flutter.targetSdkVersion
        // Uses the version code from pubspec.yaml. When using split APKs, 1000 * ABI_VERSION
        // is added automatically by Flutter. (https://developer.android.com/studio/build/configure-apk-splits#configure-APK-versions)
        // You can force using the value of versionCode by specifying the `-P force-version-code-ignoring-abi=true`
        // flag during build.
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        if (releaseConfigured) {
            create("lingoyRelease") {
                storeFile = file(releaseStore!!)
                storePassword = releaseStorePassword
                keyAlias = releaseAlias
                keyPassword = releaseKeyPassword
            }
        }
    }
    buildTypes {
        release {
            isMinifyEnabled = true
            isShrinkResources = true
            signingConfig = if (releaseConfigured) signingConfigs.getByName("lingoyRelease") else null
        }
    }
    packaging {
        // Compress native libraries in the downloadable APK; Android extracts
        // them once during installation. No runtime decompression is required.
        jniLibs.useLegacyPackaging = true
    }
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

flutter {
    source = "../.."
}
