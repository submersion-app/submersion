allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

// Force consistent dependency versions to resolve AAR metadata conflicts
subprojects {
    configurations.all {
        resolutionStrategy {
            // Force compatible versions of media libraries
            force("androidx.media:media:1.7.0")
            // Force media3 exoplayer versions to be consistent
            force("androidx.media3:media3-common:1.3.1")
            force("androidx.media3:media3-exoplayer:1.3.1")
            force("androidx.media3:media3-exoplayer-dash:1.3.1")
            force("androidx.media3:media3-exoplayer-hls:1.3.1")
        }
    }
}

val newBuildDir: Directory =
    rootProject.layout.buildDirectory
        .dir("../../build")
        .get()
rootProject.layout.buildDirectory.value(newBuildDir)

subprojects {
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)
}
subprojects {
    project.evaluationDependsOn(":app")
}

// Ensure Kotlin and Java JVM targets match within each subproject.
//
// AGP 8+ rejects mismatched Kotlin/Java targets. Third-party Flutter plugins
// (e.g. desktop_drop) set compileOptions to 1.8 but don't set kotlinOptions,
// causing Kotlin to inherit a different default. Rather than forcing all
// subprojects to JVM 21 (which breaks plugins whose source requires JVM 1.8),
// we align Kotlin to each subproject's own Java target after evaluation.
gradle.projectsEvaluated {
    subprojects {
        // Read the Java target that the plugin's build script configured.
        val javaTarget = extensions.findByType(
            com.android.build.gradle.BaseExtension::class.java,
        )?.compileOptions?.sourceCompatibility ?: return@subprojects

        val kotlinTarget = when (javaTarget) {
            JavaVersion.VERSION_1_8 ->
                org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_1_8
            JavaVersion.VERSION_11 ->
                org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_11
            JavaVersion.VERSION_17 ->
                org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
            JavaVersion.VERSION_21 ->
                org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_21
            else ->
                org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_1_8
        }

        tasks.withType<org.jetbrains.kotlin.gradle.tasks.KotlinCompile>()
            .configureEach {
                compilerOptions {
                    jvmTarget.set(kotlinTarget)
                }
            }
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
