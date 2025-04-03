plugins {
    id("com.android.application")
    id("kotlin-android")
    id("com.google.gms.google-services")
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.nsbm.studyx"
    compileSdk = 35
    ndkVersion = "27.0.12077973"

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_1_8
        targetCompatibility = JavaVersion.VERSION_1_8
        isCoreLibraryDesugaringEnabled = true
    }

     packagingOptions {
         jniLibs {
            useLegacyPackaging = true
            pickFirsts.add("lib/**/libflutter.so")
            pickFirsts.add("lib/**/libapp.so")
        }
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_1_8.toString()
    }

    defaultConfig {
        applicationId = "com.nsbm.studyx"
        minSdk = 24
        targetSdk = 34
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        
        
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("debug")
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )
            
        }
    }

    sourceSets {
        getByName("main") {
            java.srcDirs("src/main/kotlin")
        }
    }

    lint {
        disable += "InvalidPackage"
    }
}

flutter {
    source = "../.."
}

configurations.all {
    resolutionStrategy {
        // Force specific version of firebase-messaging
        force("com.google.firebase:firebase-messaging:24.1.0")
        // Exclude the problematic firebase-iid
        exclude(group = "com.google.firebase", module = "firebase-iid")
    }
}

dependencies {
    implementation(platform("com.google.firebase:firebase-bom:32.7.0"))
    implementation("com.google.firebase:firebase-analytics-ktx")
    implementation("com.google.firebase:firebase-auth-ktx")
    implementation("com.google.android.gms:play-services-auth:20.7.0")
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.0.4")
    implementation("com.google.code.gson:gson:2.10.1")
    implementation("androidx.annotation:annotation:1.7.1")
    
    implementation("com.google.firebase:firebase-messaging:24.1.0") {
        exclude(group = "com.google.firebase", module = "firebase-iid")
    }
    
    implementation("com.google.firebase:firebase-firestore-ktx") {
        exclude(group = "com.google.firebase", module = "firebase-iid")
    }
    
    implementation("com.google.firebase:firebase-storage-ktx") {
        exclude(group = "com.google.firebase", module = "firebase-iid")
    }
}