import java.util.Properties

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// --- Release signing -------------------------------------------------------
// Real release keystore details live in android/key.properties, which is
// git-ignored and never committed (copy android/key.properties.example and
// fill it in). Nothing in this repo contains a keystore or passwords.
val keystoreProperties = Properties().apply {
    val file = rootProject.file("key.properties")
    if (file.exists()) file.inputStream().use { load(it) }
}
val hasReleaseKeystore =
    listOf("storeFile", "storePassword", "keyAlias", "keyPassword")
        .all { !keystoreProperties.getProperty(it).isNullOrBlank() }

// Local-only escape hatch for demo APKs on a machine without the keystore:
//   SENTECH_ALLOW_DEBUG_SIGNING=true flutter build apk --release
// (or -Psentech.allowDebugSigning=true). Debug-signed builds must never be
// distributed or uploaded to the Play Store.
val allowDebugSigning =
    providers.gradleProperty("sentech.allowDebugSigning").orNull == "true" ||
        System.getenv("SENTECH_ALLOW_DEBUG_SIGNING") == "true"

val isReleaseBuild =
    gradle.startParameter.taskNames.any { it.contains("release", ignoreCase = true) }

if (isReleaseBuild && !hasReleaseKeystore) {
    if (!allowDebugSigning) {
        throw GradleException(
            """
            |
            |Release signing is not configured.
            |  * Copy android/key.properties.example to android/key.properties and fill in
            |    storeFile / storePassword / keyAlias / keyPassword for the Sentech upload key, or
            |  * for a throwaway LOCAL demo build only, set SENTECH_ALLOW_DEBUG_SIGNING=true
            |    (the APK is then signed with the debug key and must not be distributed).
            |""".trimMargin()
        )
    }
    logger.warn("WARNING: release build signed with the DEBUG key (SENTECH_ALLOW_DEBUG_SIGNING). Do not distribute.")
}

android {
    namespace = "za.co.sentech.sentech_connect_app"
    // permission_handler_android 14.1 needs compile SDK 37; never go below Flutter's default.
    compileSdk = maxOf(flutter.compileSdkVersion, 37)
    ndkVersion = flutter.ndkVersion

    // JDK 17, matching Flutter's own Gradle template and the README.
    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    signingConfigs {
        if (hasReleaseKeystore) {
            create("release") {
                keyAlias = keystoreProperties.getProperty("keyAlias")
                keyPassword = keystoreProperties.getProperty("keyPassword")
                storeFile = rootProject.file(keystoreProperties.getProperty("storeFile"))
                storePassword = keystoreProperties.getProperty("storePassword")
            }
        }
    }

    defaultConfig {
        // The application id is a BUSINESS DECISION (it cannot change after the
        // first Play Store publish). It is defined in exactly one place:
        // android/gradle.properties (`sentech.applicationId`), overridable per
        // build with -Psentech.applicationId=... and -Psentech.applicationIdSuffix=.demo
        // (e.g. to install a demo build alongside production). The Kotlin
        // package/namespace above is independent of it and does not need to move.
        applicationId =
            providers.gradleProperty("sentech.applicationId").get() +
                providers.gradleProperty("sentech.applicationIdSuffix").getOrElse("")
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        release {
            signingConfig =
                if (hasReleaseKeystore) signingConfigs.getByName("release")
                else signingConfigs.getByName("debug") // only reachable with the explicit opt-in above
        }
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
