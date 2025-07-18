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
    namespace = "com.ziliottosmartdev.matchbjj" // Corrigido para o seu ID de pacote
    compileSdk = 35 // Usando uma versão comum do SDK

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
        // Usar Java 1.8 é mais comum e compatível com a maioria dos plugins
        sourceCompatibility = JavaVersion.VERSION_1_8
        targetCompatibility = JavaVersion.VERSION_1_8
    }

    kotlinOptions {
        jvmTarget = "1.8"
    }

    defaultConfig {
        applicationId = "com.ziliottosmartdev.matchbjj"
        minSdk = 23
        targetSdk = 34
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    // --- BLOCO DE FLAVORS ATUALIZADO PARA KOTLIN DSL ---
    flavorDimensions.add("app")

    productFlavors {
        // Flavor de desenvolvimento
        create("dev") {
            dimension = "app"
            // Adiciona o sufixo .dev ao ID do aplicativo, permitindo a instalação lado a lado
            applicationIdSuffix = ".dev"
            // Define um nome diferente para o ícone do app de desenvolvimento
            resValue("string", "app_name", "MatchBJJ Dev")
        }
        // Flavor de produção
        create("prod") {
            dimension = "app"
            // A versão de produção não tem sufixo, mantendo o ID original
            resValue("string", "app_name", "Match BJJ")
        }
    }
    // --- FIM DO BLOCO ATUALIZADO ---

    buildTypes {
        release {
            // Associa a configuração de assinatura ao tipo de build 'release'.
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
