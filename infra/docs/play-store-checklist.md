# Google Play Store Submission Checklist

## Status Key: ✅ Done | ⚠️ Action Required | 🔲 Not Started

---

## Technical Requirements

| # | Item | Status | Notes |
|---|------|--------|-------|
| 1 | App compiles with `flutter build apk --release` | ✅ | Confirmed builds |
| 2 | `android:label` display name set | ✅ | "Personal Health Coach" |
| 3 | App ID / package name set | ✅ | `com.healthcoach.personal_health_coach` |
| 4 | `usesCleartextTraffic="false"` (HTTPS enforced) | ✅ | AndroidManifest.xml |
| 5 | Permissions declared (INTERNET, CAMERA, RECORD_AUDIO) | ✅ | AndroidManifest.xml |
| 6 | Target SDK ≥ 34 (Android 14) | ⚠️ | Verify in `build.gradle.kts` — set `targetSdk = 34` |
| 7 | Release keystore generated | ⚠️ | See `mobile/android/key.properties.example` |
| 8 | `key.properties` filled in (not in git) | ⚠️ | Copy example, fill passwords |
| 9 | `flutter build apk --release` with signing | ⚠️ | Verify `build.gradle.kts` signingConfigs block |
| 10 | 64-bit support (arm64-v8a) | ✅ | Flutter default |

---

## Play Console Setup

| # | Item | Status | Notes |
|---|------|--------|-------|
| 11 | Google Play Developer account ($25 one-time) | 🔲 | https://play.google.com/console |
| 12 | Create new app in Play Console | 🔲 | |
| 13 | App signing enrolled (upload key registered) | ⚠️ | Upload your `upload-keystore.jks` in Setup → App signing |
| 14 | Content rating questionnaire completed | 🔲 | Policy → App content → Ratings |
| 15 | Target audience set (18+) | 🔲 | Policy → App content → Target audience |
| 16 | Data Safety form completed | 🔲 | See Data Safety section below |

---

## Store Listing Assets

| # | Item | Status | Spec |
|---|------|--------|------|
| 17 | App icon (high-res) | 🔲 | 512×512 px, PNG, no alpha |
| 18 | Feature graphic | 🔲 | 1024×500 px, JPG or PNG |
| 19 | Phone screenshots (min 2) | 🔲 | 1080×1920 px or similar, JPG/PNG |
| 20 | Short description | 🔲 | ≤ 80 chars |
| 21 | Full description | 🔲 | ≤ 4000 chars |

**Suggested short description:**
> AI-powered personal health coach: track workouts, nutrition, labs & get Gemini AI insights.

---

## Legal & Privacy

| # | Item | Status | Notes |
|---|------|--------|-------|
| 22 | Privacy policy URL | ✅ | `https://healthcoach.duckdns.org/privacy` |
| 23 | Privacy policy accessible without login | ✅ | Added to Spring Security permitAll |
| 24 | GDPR account deletion in-app | ✅ | `DELETE /api/users/me` endpoint |
| 25 | GDPR data export in-app | ✅ | `GET /api/users/me/export` endpoint |

---

## Data Safety Form (Play Console → Policy → Data Safety)

Fill these answers in Play Console:

| Question | Answer |
|----------|--------|
| Does your app collect/share user data? | Yes |
| Data types collected | Name/email, Health & fitness data, Financial info (no), Photos (no), App activity |
| Is health data encrypted in transit? | Yes (TLS 1.3) |
| Can users request data deletion? | Yes — in-app Profile → Delete Account |
| Do you share data with third parties? | Yes — Google Gemini (AI processing, anonymized summaries) |

---

## Pre-Launch Checklist (run before submitting)

```bash
# 1. Run all tests
bash scripts/run_dev_tests.sh

# 2. Build release APK
cd mobile
flutter build apk --release

# 3. Check APK size (should be < 100MB)
ls -lh build/app/outputs/flutter-apk/app-release.apk

# 4. Test on real device or emulator
flutter install --release

# 5. Verify privacy policy is live
curl https://healthcoach.duckdns.org/privacy | grep -i "privacy"
```

---

## Submission Flow

1. Upload APK/AAB to Play Console (Internal testing → Closed testing → Production)
2. Fill all store listing fields + upload assets
3. Complete Data Safety form
4. Submit for review (typically 1-3 days for new apps)
