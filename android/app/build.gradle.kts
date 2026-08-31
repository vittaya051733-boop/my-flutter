plugins {
    id("com.android.application")
    // START: FlutterFire Configuration
    id("com.google.gms.google-services")
    // END: FlutterFire Configuration
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

import java.util.Properties
import java.io.FileInputStream

android {
    namespace = "van.merchant"
    compileSdk = 36 // Updated to satisfy plugins requiring SDK 35/36
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
        isCoreLibraryDesugaringEnabled = true
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "van.merchant"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        // Drop x86_64 from production APK (not used on real phones)
        ndk {
            abiFilters += listOf("armeabi-v7a", "arm64-v8a")
        }
    }

    val keystorePropertiesFile = rootProject.file("key.properties")
    val keystoreProperties = Properties()
    if (keystorePropertiesFile.exists()) {
        keystoreProperties.load(FileInputStream(keystorePropertiesFile))
    }

    fun Properties.keystoreProp(name: String): String? {
        val value = getProperty(name)?.trim().orEmpty()
        if (value.isNotEmpty()) {
            return value
        }
        val bomName = "\uFEFF$name"
        val bomValue = getProperty(bomName)?.trim().orEmpty()
        return bomValue.takeIf { it.isNotEmpty() }
    }

    val releaseStoreFile = keystoreProperties.keystoreProp("storeFile")
        ?.let { rootProject.file(it) }
    val hasReleaseKeystore = releaseStoreFile?.exists() == true &&
        keystoreProperties.keystoreProp("storePassword") != null &&
        keystoreProperties.keystoreProp("keyPassword") != null &&
        keystoreProperties.keystoreProp("keyAlias") != null

    signingConfigs {
        if (hasReleaseKeystore) {
            create("release") {
                keyAlias = keystoreProperties.keystoreProp("keyAlias")
                keyPassword = keystoreProperties.keystoreProp("keyPassword")
                storeFile = releaseStoreFile
                storePassword = keystoreProperties.keystoreProp("storePassword")
            }
        }
    }

    buildTypes {
        release {
            signingConfig = if (hasReleaseKeystore) {
                signingConfigs.getByName("release")
            } else {
                signingConfigs.getByName("debug")
            }
            // Enable R8 code shrinking. Resource shrinking still off to be safe with
            // dynamically-referenced printing/ML Kit resources.
            isMinifyEnabled = true
            isShrinkResources = false
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )
        }
    }

    packaging {
        resources {
            excludes += setOf(
                "META-INF/AL2.0",
                "META-INF/LGPL2.1",
                "META-INF/*.kotlin_module",
                "META-INF/DEPENDENCIES",
                "META-INF/LICENSE*",
                "META-INF/NOTICE*",
                "META-INF/*.version"
            )
        }
    }
}

flutter {
    source = "../.."
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
    implementation("com.facebook.android:facebook-android-sdk:16.3.0")
    implementation(platform("com.google.firebase:firebase-bom:33.5.1"))
    implementation("com.google.firebase:firebase-messaging-ktx:24.1.0")
    implementation("com.google.firebase:firebase-auth")
}
