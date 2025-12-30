allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

val newBuildDir: Directory = rootProject.layout.buildDirectory.dir("../../build").get()
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

subprojects {
    // Check immediately when the project is configured
    if (this.name == "flutter_vision") {
        // Use a plugin manager listener to wait for the android library plugin to be applied
        pluginManager.withPlugin("com.android.library") {
            // Once the android plugin is applied, we can access the android extension
            extensions.configure<com.android.build.gradle.LibraryExtension> {
                namespace = "com.vvvir.flutter_vision"
            }
        }
    }
}