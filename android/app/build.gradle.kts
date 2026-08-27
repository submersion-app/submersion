import java.util.Properties

plugins {
    id("com.android.application")
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
}

val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
if (keystorePropertiesFile.exists()) {
    keystorePropertiesFile.inputStream().use { keystoreProperties.load(it) }
}

android {
    namespace = "app.submersion"
    // Pinned above Flutter 3.47's default (36) because flutter_secure_storage
    // 11 hardcodes `compileSdk = 37` in its own module, and Gradle refuses to
    // build an app compiled against an older API than a library it consumes.
    // Bumping here rather than waiting on flutter.compileSdkVersion also
    // unblocks permission_handler 13, which demands the same.
    compileSdk = 37
    ndkVersion = flutter.ndkVersion

    compileOptions {
        isCoreLibraryDesugaringEnabled = true
        sourceCompatibility = JavaVersion.VERSION_21
        targetCompatibility = JavaVersion.VERSION_21
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_21.toString()
    }

    defaultConfig {
        applicationId = "app.submersion"
        minSdk = 26
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        if (keystorePropertiesFile.exists()) {
            create("release") {
                keyAlias = keystoreProperties["keyAlias"]?.toString()
                    ?: error("Missing 'keyAlias' in key.properties")
                keyPassword = keystoreProperties["keyPassword"]?.toString()
                    ?: error("Missing 'keyPassword' in key.properties")
                storeFile = file(keystoreProperties["storeFile"]?.toString()
                    ?: error("Missing 'storeFile' in key.properties"))
                storePassword = keystoreProperties["storePassword"]?.toString()
                    ?: error("Missing 'storePassword' in key.properties")
            }
        }
    }

    buildTypes {
        release {
            signingConfig = if (keystorePropertiesFile.exists()) {
                signingConfigs.getByName("release")
            } else {
                signingConfigs.getByName("debug")
            }
        }
    }
}

flutter {
    source = "../.."
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
    implementation("androidx.documentfile:documentfile:1.0.1")
    implementation("androidx.exifinterface:exifinterface:1.3.7")
}
