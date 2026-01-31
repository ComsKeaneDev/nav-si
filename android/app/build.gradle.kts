plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.example.all_brawn"
    compileSdk = 36
    ndkVersion = "28.2.13676358"

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
    }

    kotlin {
        compilerOptions {
            jvmTarget.set(org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_11)
        }
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.example.all_brawn"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = 24
        targetSdk = 36
        versionCode = flutter.versionCode
        versionName = flutter.versionName

        ndk {
            abiFilters += listOf("arm64-v8a")
        }
    }

    buildTypes {
        release {
            // TODO: Add your own signing config for the release build.
            // Signing with the debug keys for now, so `flutter run --release` works.
            signingConfig = signingConfigs.getByName("debug")
        }
    }

    lint {
        checkReleaseBuilds = false
    }

    packaging {
        jniLibs {
            useLegacyPackaging = true
            // pick sherpa_onnx.so
            pickFirsts.add("**/libsherpa-onnx-c-api.so")
            pickFirsts.add("**/libsherpa-onnx-core.so")
            pickFirsts.add("**/libc++_shared.so")
            // exclude old ONNX Runtime is any
            excludes.add("**/flutter_yolo_open_kit/**/libonnxruntime.so")
            excludes.add("**/flutter_yolo_open_kit/**/libonnxruntime_providers_shared.so")
        }
    }

    // use ONNX Runtime version compatible with sherpa_onnx 1.12.23
    configurations.all {
        resolutionStrategy {
            force("com.microsoft.onnxruntime:onnxruntime-android:1.23.2")
            // prevent version conflicts
            eachDependency {
                if (requested.group == "com.microsoft.onnxruntime") {
                    useVersion("1.23.2")
                    because("Compatible with sherpa_onnx 1.12.23")
                }
            }
        }
    }
}

flutter {
    source = "../.."
}
