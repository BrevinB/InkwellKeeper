import java.util.Properties

plugins {
    id("com.android.application")
    id("org.jetbrains.kotlin.android")
    id("org.jetbrains.kotlin.plugin.compose")
    id("org.jetbrains.kotlin.plugin.serialization")
}

// Machine-specific config lives in local.properties, which is git-ignored:
//   openai.apiKey        debug builds only: call OpenAI directly when no proxy is set
//   ai.proxyUrl          the AI proxy Function URL (holds the real key server-side)
//   revenuecat.googleKey RevenueCat's public Google Play SDK key (goog_...)
val localProps = Properties().apply {
    val file = rootProject.file("local.properties")
    if (file.exists()) file.inputStream().use { load(it) }
}

// Release signing (the Play upload key) — see keystore.properties.example.
val keystoreProps = Properties().apply {
    val file = rootProject.file("keystore.properties")
    if (file.exists()) file.inputStream().use { load(it) }
}

android {
    namespace = "co.brevinb.inkwellkeeper"
    compileSdk = 36

    defaultConfig {
        applicationId = "co.brevinb.inkwellkeeper"
        // AVIF card art decodes natively through ImageDecoder from Android 12.
        minSdk = 31
        targetSdk = 36
        versionCode = 1
        versionName = "3.5.1"
        buildConfigField("String", "AI_PROXY_URL", "\"${localProps.getProperty("ai.proxyUrl", "")}\"")
        buildConfigField("String", "REVENUECAT_API_KEY", "\"${localProps.getProperty("revenuecat.googleKey", "")}\"")
    }

    signingConfigs {
        if (keystoreProps.getProperty("storeFile") != null) {
            create("upload") {
                storeFile = rootProject.file(keystoreProps.getProperty("storeFile"))
                storePassword = keystoreProps.getProperty("storePassword")
                keyAlias = keystoreProps.getProperty("keyAlias")
                keyPassword = keystoreProps.getProperty("keyPassword")
            }
        }
    }

    buildTypes {
        debug {
            // Never ship the OpenAI key: only debug builds may carry one, for testing without the proxy.
            buildConfigField("String", "OPENAI_API_KEY", "\"${localProps.getProperty("openai.apiKey", "")}\"")
        }
        release {
            buildConfigField("String", "OPENAI_API_KEY", "\"\"")
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(getDefaultProguardFile("proguard-android-optimize.txt"), "proguard-rules.pro")
            signingConfigs.findByName("upload")?.let { signingConfig = it }
        }
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    buildFeatures {
        compose = true
        buildConfig = true
    }

    packaging {
        resources.excludes += "/META-INF/{AL2.0,LGPL2.1}"
    }

    testOptions {
        unitTests.isReturnDefaultValues = true
    }
}

kotlin {
    compilerOptions {
        jvmTarget.set(org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17)
    }
}

dependencies {
    implementation(platform("androidx.compose:compose-bom:2025.08.00"))
    implementation("androidx.activity:activity-compose:1.10.1")
    implementation("androidx.core:core-ktx:1.16.0")
    implementation("androidx.compose.ui:ui")
    implementation("androidx.compose.ui:ui-tooling-preview")
    implementation("androidx.compose.material3:material3")
    implementation("androidx.compose.material:material-icons-extended")
    implementation("androidx.lifecycle:lifecycle-runtime-compose:2.9.2")
    implementation("androidx.lifecycle:lifecycle-viewmodel-compose:2.9.2")
    implementation("androidx.navigation:navigation-compose:2.9.3")

    implementation("org.jetbrains.kotlinx:kotlinx-serialization-json:1.9.0")
    implementation("org.jetbrains.kotlinx:kotlinx-coroutines-android:1.10.2")

    implementation("io.coil-kt.coil3:coil-compose:3.3.0")
    implementation("io.coil-kt.coil3:coil-network-okhttp:3.3.0")
    implementation("com.squareup.okhttp3:okhttp:4.12.0")

    // Subscriptions through Google Play Billing, sharing the iOS app's RevenueCat project and entitlement.
    implementation("com.revenuecat.purchases:purchases:10.26.0")

    implementation("androidx.camera:camera-camera2:1.4.2")
    implementation("androidx.camera:camera-lifecycle:1.4.2")
    implementation("androidx.camera:camera-view:1.4.2")
    implementation("com.google.mlkit:text-recognition:16.0.1")
    // QR codes on share images (iOS uses Core Image's CIQRCodeGenerator).
    implementation("com.google.zxing:core:3.5.3")

    debugImplementation("androidx.compose.ui:ui-tooling")
    testImplementation("junit:junit:4.13.2")
    testImplementation("org.json:json:20240303")
}

// The card catalog's source of truth is the iOS app's Data folder (kept current by
// Scripts/sync_new_cards.py). Copy it into generated assets at build time instead of
// duplicating ~6 MB of JSON in the repo.
val syncCardCatalog by tasks.registering(Sync::class) {
    from(rootProject.file("../Inkwell Keeper/Data")) {
        include("*.json")
    }
    into(layout.buildDirectory.dir("generated/catalogAssets"))
}

android.sourceSets.getByName("main").assets.srcDir(layout.buildDirectory.dir("generated/catalogAssets"))
tasks.named("preBuild") { dependsOn(syncCardCatalog) }

tasks.withType<Test>().configureEach {
    System.getProperty("lzfse.exportDir")?.let { systemProperty("lzfse.exportDir", it) }
}
