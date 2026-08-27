pluginManagement {
    val flutterSdkPath =
        run {
            val properties = java.util.Properties()
            file("local.properties").inputStream().use { properties.load(it) }
            val flutterSdkPath = properties.getProperty("flutter.sdk")
            require(flutterSdkPath != null) { "flutter.sdk not set in local.properties" }
            flutterSdkPath
        }

    includeBuild("$flutterSdkPath/packages/flutter_tools/gradle")

    repositories {
        google()
        mavenCentral()
        gradlePluginPortal()
    }
}

plugins {
    id("dev.flutter.flutter-plugin-loader") version "1.0.0"
    // Flutter's DependencyVersionChecker keeps a warn floor and a hard error
    // floor per dependency, and 3.47 promoted every one of 3.44's warn floors to
    // an error floor. AGP 8.11.1 and Gradle 8.14 (below) land exactly on the new
    // error floors, so they survive with only a "will soon be dropped" warning.
    // Kotlin was the one that fell through: 3.47 raised errorKGPVersion from
    // 2.0.0 to 2.2.20, which fails the Android build at plugin-apply time.
    //
    // Held at the 2.2.20 floor rather than the 2.4.0 the 3.47 template ships:
    // that template pairs 2.4.0 with AGP 9.1.0 and Gradle 9.3.1, and Kotlin 2.3
    // escalates the deprecated kotlinOptions properties to errors, which
    // app/build.gradle.kts and the packages/ plugin modules still use to set
    // jvmTarget. Moving off these floors is its own migration, and the next SDK
    // bump is expected to force it.
    id("com.android.application") version "8.11.1" apply false
    id("org.jetbrains.kotlin.android") version "2.2.20" apply false
}

include(":app")
