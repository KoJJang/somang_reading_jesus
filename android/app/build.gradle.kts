import java.util.Properties
import java.io.FileInputStream

// Load key.properties file
val keystorePropertiesFile = rootProject.file("key.properties")
val keystoreProperties = Properties()
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
}

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
    id("com.google.gms.google-services")
}

dependencies {
  // Firebase BoM을 사용하여 Firebase 라이브러리 버전 관리
  implementation(platform("com.google.firebase:firebase-bom:33.10.0"))
  
  // 필요한 Firebase 라이브러리
  implementation("com.google.firebase:firebase-analytics")
  implementation("com.google.firebase:firebase-auth") // 인증에 필요한 필수 의존성
  implementation("com.google.firebase:firebase-appcheck-playintegrity")

  
  // Play Integrity API를 위한 필수 의존성
  implementation("com.google.android.play:integrity:1.3.0")
  
  // reCAPTCHA는 Firebase Phone Auth에 필요 (제거하지 않음)
  implementation("com.google.android.recaptcha:recaptcha:18.4.0")
  
  // 멀티덱스 지원 추가 (필수)
  implementation("androidx.multidex:multidex:2.0.1")
  
  // Kotlin Coroutines (비동기 작업에 필요)
  implementation("org.jetbrains.kotlinx:kotlinx-coroutines-android:1.7.3")
  implementation("org.jetbrains.kotlinx:kotlinx-coroutines-play-services:1.7.3")
}

android {
    namespace = "com.somangchurch.readingjesus"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = "27.0.12077973"

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_11.toString()
    }

    // Add signing configs
    signingConfigs {
        create("release") {
            keyAlias = keystoreProperties["keyAlias"] as String
            keyPassword = keystoreProperties["keyPassword"] as String
            storeFile = file(keystoreProperties["storeFile"] as String)
            storePassword = keystoreProperties["storePassword"] as String
        }
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.somangchurch.readingjesus"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = 23
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        // 추가 - 멀티덱스 활성화
        multiDexEnabled = true
    }

    buildTypes {
        release {
            // Update release signing config
            signingConfig = signingConfigs.getByName("release")
            isMinifyEnabled = false
            isShrinkResources = false
            proguardFiles(getDefaultProguardFile("proguard-android.txt"), "proguard-rules.pro")
        }
    }
}

flutter {
    source = "../.."
}
