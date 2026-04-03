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

// Force all subproject Kotlin and Java compilation to target JVM 21.
//
// Third-party Flutter plugins (desktop_drop, receive_sharing_intent) default
// to JVM 1.8 for one or both languages. Our app targets JVM 21, and AGP 8+
// rejects mismatched Kotlin/Java targets within a subproject.
//
// Kotlin: configureEach with the Property API (jvmTarget.set) takes
// precedence over the plugin's kotlinOptions block.
//
// Java: configureEach registered here is overridden when the plugin's own
// compileOptions is applied by AGP. gradle.projectsEvaluated runs after
// every project (including plugins) has been evaluated and all afterEvaluate
// callbacks have fired, so configureEach registered there is the final word.
subprojects {
    tasks.withType<org.jetbrains.kotlin.gradle.tasks.KotlinCompile>().configureEach {
        compilerOptions {
            jvmTarget.set(org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_21)
        }
    }
}
gradle.projectsEvaluated {
    subprojects {
        tasks.withType<JavaCompile>().configureEach {
            sourceCompatibility = JavaVersion.VERSION_21.toString()
            targetCompatibility = JavaVersion.VERSION_21.toString()
        }
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
