import org.gradle.api.Project

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

subprojects {
    plugins.withId("com.android.application") {
        configureAndroidCompileSdk()
    }
    plugins.withId("com.android.library") {
        configureAndroidCompileSdk()
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}

fun Project.configureAndroidCompileSdk() {
    val androidExt = extensions.findByName("android") ?: return
    val methods = androidExt.javaClass.methods
    methods.firstOrNull { it.name == "setCompileSdk" && it.parameterCount == 1 }?.let {
        runCatching { it.invoke(androidExt, 36) }
    }
    methods.firstOrNull { it.name == "setCompileSdkVersion" && it.parameterCount == 1 }?.let {
        runCatching { it.invoke(androidExt, "android-36") }
    }
}
