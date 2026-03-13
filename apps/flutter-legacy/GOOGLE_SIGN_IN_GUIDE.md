# Google Sign-In Configuration Guide for Android (Production)

To use Google Sign-In in the production APK, you must register your app's SHA-1 and SHA-256 fingerprints in the Google Cloud Console.

## 1. Generate Signing Key (If not already done)

If you haven't created a release keystore, run:

```bash
keytool -genkey -v -keystore ~/upload-keystore.jks -keyalg RSA -keysize 2048 -validity 10000 -alias upload
```

## 2. Get Fingerprints

Run the following command to see your SHA-1 and SHA-256:

### For Debug (Local):

```bash
keytool -list -v -keystore ~/.android/debug.keystore -alias androiddebugkey -storepass android -keypass android
```

### For Release (Production):

```bash
keytool -list -v -keystore ~/upload-keystore.jks -alias upload
```

## 3. Google Cloud Console Setup

### A. Configure OAuth Consent Screen (Required First)

Before you can create a Client ID, Google needs to know what this app is.

1. Go to the [Google Cloud Console](https://console.cloud.google.com/).
2. Select your project.
3. Navigate to **APIs & Services > OAuth consent screen**.
4. Select **External** (unless you are a Google Workspace user and only want internal users). Click **Create**.
5. Fill in the mandatory fields:
   - **App information**: App name (e.g., "Personal Health Coach"), User support email.
   - **Developer contact information**: Your email address.
6. Click **Save and Continue** through the Scopes and Test Users screens (you can leave scopes default for simple Sign-In, and add yourself as a test user if the app stays in "Testing" mode).
7. Once the summary screen shows, go back to the Dashboard.

### B. Create OAuth Client ID

1. Navigate to **APIs & Services > Credentials**.
2. Click **Create Credentials > OAuth Client ID**.
3. Select **Android** as the application type.
4. Enter your **Package Name** (e.g., `com.healthcoach.personal_health_coach`).
5. Paste the **SHA-1 certificate fingerprint** generated in step 2.
6. Click **Create**.
7. Download the `google-services.json` file and place it in `mobile/android/app/`.

## 4. Backend Configuration

Ensure the `GOOGLE_CLIENT_ID` (the Web Client ID, not the Android Client ID) is set in your backend `.env` file. The Web Client ID allows the backend to verify the tokens sent by the Android app.

## 5. Build Release APK

```bash
cd mobile
flutter build apk --release
```

The signed APK will be available at `build/app/outputs/flutter-apk/app-release.apk`.
