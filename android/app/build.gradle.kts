import java.util.Properties

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
    id("com.google.gms.google-services")
    }

val mrsSigningFile = rootProject.file("key.properties")
val mrsSigning = Properties().apply {
    if (mrsSigningFile.exists()) mrsSigningFile.inputStream().use { load(it) }
}

val validateMrsosReleaseSigning = tasks.register("validateMrsosReleaseSigning") {
    doLast {
        check(mrsSigningFile.exists() &&
            listOf("storeFile", "storePassword", "keyAlias", "keyPassword")
                .all { !mrsSigning.getProperty(it).isNullOrBlank() }) {
            "Configura android/key.properties con la firma de MRSoS antes de compilar release. Consulta docs/php-firebase-ios-integration.md."
        }
        check(file(mrsSigning.getProperty("storeFile")).isFile) {
            "No se encontro el keystore configurado. No se usara la firma debug para release."
        }
    }
}
tasks.configureEach {
    if (name == "preReleaseBuild") dependsOn(validateMrsosReleaseSigning)
}

android {
    namespace = "com.example.mrsos"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = "27.0.12077973"


    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
        isCoreLibraryDesugaringEnabled = true
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.example.mrsos"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        create("release") {
            keyAlias = mrsSigning.getProperty("keyAlias")
            keyPassword = mrsSigning.getProperty("keyPassword")
            storeFile = mrsSigning.getProperty("storeFile")?.let { file(it) }
            storePassword = mrsSigning.getProperty("storePassword")
        }
    }

    buildTypes {
        release {
            // Production builds must use the owner's upload certificate.
            isMinifyEnabled = false
            isShrinkResources = false
            signingConfig = signingConfigs.getByName("release")
            
        }
    }
}

flutter {
    source = "../.."
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
    implementation(platform("com.google.firebase:firebase-bom:34.19.0"))
    implementation("com.google.firebase:firebase-analytics")
}
