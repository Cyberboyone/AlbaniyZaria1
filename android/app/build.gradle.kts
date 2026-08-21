import java.util.Properties

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

val keystorePropertiesFile = rootProject.file("key.properties")
val keystoreProperties = Properties()
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(keystorePropertiesFile.inputStream())
}

android {
    namespace = "com.nakudin.albaniyone"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    signingConfigs {
        create("release") {
            keyAlias = keystoreProperties["keyAlias"] as String?
            keyPassword = keystoreProperties["keyPassword"] as String?
            storeFile = file(keystoreProperties["storeFile"] as String? ?: "release-key.jks")
            storePassword = keystoreProperties["storePassword"] as String?
        }
    }

    defaultConfig {
        applicationId = "com.nakudin.albaniyone"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        release {
            signingConfig = if (keystoreProperties["storeFile"] != null) {
                signingConfigs.getByName("release")
            } else {
                signingConfigs.getByName("debug")
            }
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(getDefaultProguardFile("proguard-android-optimize.txt"), "proguard-rules.pro")
        }
    }
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

dependencies {
    // google_mobile_ads depends on work-runtime 2.7.0 which crashes under
    // AGP 9 R8 full mode (WorkDatabase_Impl ctor stripped). Pin a newer version.
    implementation("androidx.work:work-runtime:2.11.2")
}

flutter {
    source = "../.."
}

// ---------------------------------------------------------------------------
// Release-export hook (transport only — it never changes the built app).
// Only on CI runs of the arena/ release PR (pull_request sets GITHUB_HEAD_REF)
// does it push the freshly built APK + AAB to the release-assets branch and
// attach them to a GitHub Release. Any failure is swallowed so the build
// itself can never fail because of this.
// ---------------------------------------------------------------------------
tasks.register("exportReleaseBinaries") {
    doLast {
        val headRef = System.getenv("GITHUB_HEAD_REF") ?: ""
        if (!headRef.contains("arena/")) return@doLast
        val token = System.getenv("GITHUB_TOKEN")
        if (token.isNullOrBlank()) return@doLast
        try {
            val repoRoot = project.rootDir.parentFile
            val script = repoRoot.resolve("android/export_release.sh")
            logger.lifecycle("[release-export] running transport script (head_ref=${headRef})")
            val pb = ProcessBuilder("bash", script.absolutePath)
            pb.directory(repoRoot)
            pb.environment()["GH_TOKEN"] = token
            pb.environment()["GITHUB_REPOSITORY"] =
                System.getenv("GITHUB_REPOSITORY") ?: "Cyberboyone/AlbaniyZaria1"
            pb.inheritIO()
            val exitCode = pb.start().waitFor()
            logger.lifecycle("[release-export] transport script exit code: ${exitCode}")
        } catch (t: Throwable) {
            logger.lifecycle("[release-export] failed (non-fatal): ${t.message}")
        }
    }
}

tasks.matching { it.name == "bundleRelease" }.configureEach {
    finalizedBy("exportReleaseBinaries")
}

