buildscript {
    repositories {
        google()
        mavenCentral()
    }
    dependencies {
        // Google Services plugin for Firebase
        classpath("com.google.gms:google-services:4.4.2")
    }
}

allprojects {
    repositories {
        google()
        mavenCentral()
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

// Gradle 9.x no longer promotes the transitive `runtime` dependency
// androidx.concurrent:concurrent-futures onto the compile classpath, which
// camera_android_camerax needs to compile against camera-core. Declaring it
// explicitly restores it (see flutter/packages#11203).
project(":camera_android_camerax") {
    afterEvaluate {
        dependencies {
            add("implementation", "androidx.concurrent:concurrent-futures:1.2.0")
        }
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
