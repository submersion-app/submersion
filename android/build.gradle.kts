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

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
