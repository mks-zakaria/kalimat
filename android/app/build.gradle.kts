plugins {
    alias(libs.plugins.android.application)
    alias(libs.plugins.kotlin.compose)
    alias(libs.plugins.kotlin.serialization)
}

// Real AdMob ids for the Play Store build, from gradle.properties.
val admobAppId = providers.gradleProperty("kalimat.admob.appId").getOrElse("")
val admobRewarded = providers.gradleProperty("kalimat.admob.rewarded").getOrElse("")
val admobInterstitial = providers.gradleProperty("kalimat.admob.interstitial").getOrElse("")

android {
    namespace = "com.zakaria.crossword"
    compileSdk {
        version = release(37)
    }

    defaultConfig {
        applicationId = "com.zakaria.crossword"   // same id as the iOS app
        minSdk = 26
        targetSdk = 37
        versionCode = 1
        versionName = "1.0.0"
    }

    buildTypes {
        // Debug builds (your phone, the emulator) only ever load Google's test ads:
        // tapping a live ad yourself gets an AdMob account suspended.
        debug {
            manifestPlaceholders["admobAppId"] = "ca-app-pub-3940256099942544~3347511713"
            buildConfigField("String", "AD_UNIT_REWARDED", "\"ca-app-pub-3940256099942544/5224354917\"")
            buildConfigField("String", "AD_UNIT_INTERSTITIAL", "\"ca-app-pub-3940256099942544/1033173712\"")
        }
        release {
            manifestPlaceholders["admobAppId"] = admobAppId
            buildConfigField("String", "AD_UNIT_REWARDED", "\"$admobRewarded\"")
            buildConfigField("String", "AD_UNIT_INTERSTITIAL", "\"$admobInterstitial\"")
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(getDefaultProguardFile("proguard-android-optimize.txt"), "proguard-rules.pro")
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
}

// A release build without real AdMob ids would crash at launch: stop it with a clear message instead.
val checkAdMobIds by tasks.registering {
    val missing = listOf(admobAppId, admobRewarded, admobInterstitial).any { it.isBlank() }
    doLast {
        if (missing) throw GradleException("Fill in kalimat.admob.* in gradle.properties before a release build.")
    }
}
tasks.matching { it.name == "preReleaseBuild" }.configureEach { dependsOn(checkAdMobIds) }

dependencies {
    implementation(libs.androidx.core.ktx)
    implementation(libs.androidx.activity.compose)
    implementation(libs.androidx.lifecycle.runtime.compose)
    implementation(libs.kotlinx.serialization.json)
    implementation(libs.play.services.ads)
    implementation(libs.ump)
    implementation(libs.play.review)

    implementation(platform(libs.androidx.compose.bom))
    implementation(libs.androidx.compose.ui)
    implementation(libs.androidx.compose.ui.graphics)
    implementation(libs.androidx.compose.foundation)
    implementation(libs.androidx.compose.material.icons)
    implementation(libs.androidx.compose.ui.tooling.preview)
    debugImplementation(libs.androidx.compose.ui.tooling)

    testImplementation(libs.junit)
}
