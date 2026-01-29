import java.util.Properties
import java.io.FileInputStream

plugins {
    id("com.android.application")
    id("kotlin-android")
    // El plugin de Flutter debe aplicarse después de Android y Kotlin
    id("dev.flutter.flutter-gradle-plugin")
}

// --- 1. CARGA DE PROPIEDADES DE LA LLAVE ---
// Esto lee el archivo key.properties que tienes en la carpeta android
val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
}

android {
    namespace = "com.example.orator_teleprompter"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    // --- 2. CONFIGURACIÓN DE FIRMA DIGITAL ---
    // Aquí definimos los datos de tu upload-keystore.jks
    signingConfigs {
        create("release") {
            keyAlias = keystoreProperties["keyAlias"] as String
            keyPassword = keystoreProperties["keyPassword"] as String
            storeFile = file(keystoreProperties["storeFile"] as String)
            storePassword = keystoreProperties["storePassword"] as String
        }
    }

    defaultConfig {
        applicationId = "com.oratorteleprompter.app"
        
        // Configuración para compatibilidad con Supabase
        minSdk = flutter.minSdkVersion 
        
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        release {
            // --- 3. CONFIGURACIÓN DE FIRMA ---
            // Reemplazamos "debug" por "release" para que Google acepte el archivo
            signingConfig = signingConfigs.getByName("release")
            
            // --- 4. OPTIMIZACIÓN Y OFUSCACIÓN (CRÍTICO PARA MAPPING.TXT) ---
            // isMinifyEnabled activa R8 para ofuscar el código y reducir el tamaño
            isMinifyEnabled = true
            
            // isShrinkResources elimina archivos y recursos que no se utilizan
            isShrinkResources = true
            
            // Indica a Gradle dónde encontrar las reglas de ProGuard
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )
        }
    }
}

flutter {
    source = "../.."
}