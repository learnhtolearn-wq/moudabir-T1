allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

// file_picker's transitive flutter_plugin_android_lifecycle dependency
// requires compileSdk 36+, but plugin subprojects don't inherit the app
// module's compileSdk override — force it on every Android library plugin.
// Registered first (before evaluationDependsOn below forces early
// evaluation of plugin subprojects) so afterEvaluate still has a chance to
// run before each subproject is marked evaluated.
subprojects {
    afterEvaluate {
        plugins.withId("com.android.library") {
            extensions.configure<com.android.build.gradle.LibraryExtension> {
                compileSdk = 36
            }
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
