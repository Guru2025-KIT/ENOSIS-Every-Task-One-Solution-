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

val corruptDir = file("../../build/file_picker/intermediates/aar_metadata/debug/writeDebugAarMetadata/aar-metadata.properties")
if (corruptDir.exists() && corruptDir.isDirectory) {
    corruptDir.deleteRecursively()
}

subprojects {
    if (project.name != "app") {
        afterEvaluate {
            val androidExt = project.extensions.findByName("android")
            if (androidExt != null) {
                for (method in androidExt.javaClass.methods) {
                    if (method.name in listOf("compileSdkVersion", "setCompileSdkVersion", "setCompileSdk")) {
                        try {
                            if (method.parameterCount == 1) {
                                val paramType = method.parameterTypes[0]
                                if (paramType == Int::class.javaPrimitiveType || paramType == java.lang.Integer::class.java) {
                                    method.invoke(androidExt, 36)
                                } else if (paramType == String::class.java) {
                                    method.invoke(androidExt, "android-36")
                                }
                            }
                        } catch (_: Throwable) {}
                    }
                }
            }
        }
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
