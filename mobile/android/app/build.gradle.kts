import java.io.File
import java.io.FileInputStream
import java.util.Properties
import org.gradle.api.GradleException

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

val keyPropertiesFile: File = System.getenv("ANDROID_KEY_PROPERTIES_PATH")
    ?.takeIf { it.isNotBlank() }
    ?.let(::File)
    ?: rootProject.file("key.properties")

val keystoreProperties = Properties().apply {
    if (keyPropertiesFile.isFile) {
        FileInputStream(keyPropertiesFile).use(::load)
    }
}

fun resolveReleaseSetting(propertyName: String, envName: String): String? {
    val fromFile = keystoreProperties.getProperty(propertyName)?.trim()
    if (!fromFile.isNullOrEmpty()) return fromFile
    return System.getenv(envName)?.trim()?.takeIf { it.isNotEmpty() }
}

val releaseStorePath = resolveReleaseSetting("storeFile", "ANDROID_KEYSTORE_PATH")
val releaseStorePassword = resolveReleaseSetting("storePassword", "ANDROID_KEYSTORE_PASSWORD")
val releaseKeyAlias = resolveReleaseSetting("keyAlias", "ANDROID_KEY_ALIAS")
val releaseKeyPassword = resolveReleaseSetting("keyPassword", "ANDROID_KEY_PASSWORD")

val resolvedReleaseStoreFile: File? = releaseStorePath?.let { path ->
    val direct = File(path)
    when {
        direct.isAbsolute -> direct
        keyPropertiesFile.isFile ->
            keyPropertiesFile.parentFile?.let { File(it, path) }?.takeIf { it.isFile }
                ?: rootProject.file(path).takeIf { it.isFile }
                ?: file(path)
        rootProject.file(path).isFile -> rootProject.file(path)
        else -> file(path)
    }
}

val isDebugKeystoreFile = resolvedReleaseStoreFile != null &&
    resolvedReleaseStoreFile.name.equals("debug.keystore", ignoreCase = true)
val isDebugKeyAlias = releaseKeyAlias?.equals("androiddebugkey", ignoreCase = true) == true

val hasValidReleaseSigning =
    resolvedReleaseStoreFile != null &&
    resolvedReleaseStoreFile.isFile &&
    !isDebugKeystoreFile &&
    !releaseStorePassword.isNullOrBlank() &&
    !releaseKeyAlias.isNullOrBlank() &&
    !isDebugKeyAlias &&
    !releaseKeyPassword.isNullOrBlank()

android {
    namespace = "uz.bilimyol.bilimyol_mobile"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        applicationId = "uz.bilimyol.mobile"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        create("release") {
            if (hasValidReleaseSigning) {
                storeFile = resolvedReleaseStoreFile
                storePassword = releaseStorePassword
                keyAlias = releaseKeyAlias
                keyPassword = releaseKeyPassword
            }
        }
    }

    buildTypes {
        release {
            if (hasValidReleaseSigning) {
                signingConfig = signingConfigs.getByName("release")
            }
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro",
            )
        }
    }
}

gradle.taskGraph.whenReady {
    if (!hasValidReleaseSigning) {
        val releaseTaskRegex = Regex(
            "^(assemble|bundle|package|sign|minify|lintVital).*Release([A-Z].*)?$|^validateSigning.*Release$"
        )
        val blockedTask = allTasks.firstOrNull { task ->
            releaseTaskRegex.matches(task.name)
        }
        if (blockedTask != null) {
            throw GradleException(
                "BLOCKED — RELEASE SIGNING CREDENTIALS MISSING: provide a valid non-debug keystore via mobile/android/key.properties or ANDROID_KEYSTORE_PATH/ANDROID_KEYSTORE_PASSWORD/ANDROID_KEY_ALIAS/ANDROID_KEY_PASSWORD before executing '${blockedTask.name}'."
            )
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
