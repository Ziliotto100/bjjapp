// Importa as classes necessárias no topo do arquivo.
import java.util.Properties
import java.io.FileInputStream

plugins {
    id("com.android.application")
    // START: FlutterFire Configuration
    id("com.google.gms.google-services")
    // END: FlutterFire Configuration
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
}

// Carrega as propriedades do arquivo key.properties usando a sintaxe Kotlin.
val keyPropertiesFile = rootProject.file("key.properties")
val keyProperties = Properties()
if (keyPropertiesFile.exists()) {
    keyProperties.load(FileInputStream(keyPropertiesFile))
}

android {
    namespace = "com.example.bjjapp"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = "27.0.12077973"

    signingConfigs {
        // Cria a configuração de assinatura para 'release'
        create("release") {
            keyAlias = keyProperties["keyAlias"] as String?
            keyPassword = keyProperties["keyPassword"] as String?
            storeFile = file(keyProperties["storeFile"] as String?)
            storePassword = keyProperties["storePassword"] as String?
        }
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = "17"
    }

    defaultConfig {
        applicationId = "com.ziliottosmartdev.matchbjj"
        minSdk = 23
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    // --- BLOCO ADICIONADO PARA CORRIGIR O ERRO ---
    // NOVO: Define uma categoria para seus flavors.
    flavorDimensions.add("app")

    // NOVO: Define os flavors 'prod' e 'dev' que seu app possui.
    productFlavors {
        // Flavor de produção (o que você tentou compilar)
        create("prod") {
            dimension = "app"
            // Você pode diferenciar o ID do aplicativo para cada flavor, se quiser.
            // Ex: applicationIdSuffix = ".prod"
        }
        // Flavor de desenvolvimento (para corresponder ao seu main.dart)
        create("dev") {
            dimension = "app"
            // Ex: applicationIdSuffix = ".dev"
        }
    }
    // --- FIM DO BLOCO ADICIONADO ---

    buildTypes {
        release {
            // Associa a configuração de assinatura ao tipo de build 'release'.
            // A sintaxe correta é usar getByName para referenciar a config criada.
            signingConfig = signingConfigs.getByName("release")
        }
    }
}

flutter {
    source = "../.."
}

dependencies {
    // Adicione suas dependências aqui, se necessário.
}