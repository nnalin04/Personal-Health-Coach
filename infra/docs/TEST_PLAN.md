# Mobile App — Emulator Test Plan

**Target:** Android emulator (Pixel 6 API 35 or equivalent)
**Backend:** https://healthcoach.duckdns.org/api (live HTTPS)
**APK:** `mobile/build/app/outputs/flutter-apk/app-release.apk`
**Updated:** 2026-03-01

---

## Scope

Full functional coverage of all 12 feature areas on the Android emulator.
Tests are grouped into tiers by criticality. Each test case has:
- **ID** — unique reference
- **Precondition** — what must be true before running
- **Steps** — exact actions
- **Expected** — what a passing result looks like
- **Edge Case** — variant that tests error paths

---

## Test Environment Setup

| Item | Value |
|------|-------|
| Emulator | Pixel 6, API 35 (Android 15), x86_64 |
| APK type | Release (signed, cleartext disabled) |
| Backend | https://healthcoach.duckdns.org/api |
| Test account | `qa_emulator@healthcoach.test` / `TestPass@2026` (created at start) |
| Google account | Manual only — cannot automate OAuth |

---

## Tier 1 — Critical Path (must all pass for GO)

### AUTH-01 — Email Registration
**Precondition:** App freshly installed, no stored session.
**Steps:**
1. Open app → lands on Login screen
2. Tap "Create an account"
3. Fill: Name=`QA User`, Email=`qa_emulator@healthcoach.test`, Password=`TestPass@2026`
4. Fill profile: Age=`28`, Gender=`Male`, Height=`175`, Weight=`75`, Goal=`Stay Healthy`, Diet=`Omnivore`
5. Tap Register

**Expected:** Navigates to Dashboard, health score card visible, no error.
**Edge — duplicate email:** Re-register with same email → shows error "already registered" or 409.

---

### AUTH-02 — Email Login
**Precondition:** Account from AUTH-01 exists.
**Steps:**
1. Logout (if logged in)
2. Enter correct email + password → Tap Login

**Expected:** JWT stored, Dashboard loads.
**Edge — wrong password:** Enter wrong password → shows error message, stays on Login.
**Edge — empty fields:** Tap Login with empty fields → validation message shown, no API call.

---

### AUTH-03 — Session Persistence
**Precondition:** Logged in from AUTH-02.
**Steps:**
1. Force-close the app
2. Reopen app

**Expected:** Lands directly on Dashboard (not Login) — session restored from secure storage.

---

### AUTH-04 — Logout
**Precondition:** Logged in.
**Steps:**
1. Navigate to Profile tab
2. Tap Logout

**Expected:** Navigates to Login screen. Re-opening app also shows Login (token cleared).

---

### DASH-01 — Dashboard Load
**Precondition:** Logged in with some data (workouts/food already logged from earlier tests).
**Steps:**
1. Navigate to Dashboard tab
2. Pull to refresh

**Expected:** Health score (0–100) visible, daily activity cards present, no crash or infinite spinner.
**Edge — no data:** New account with no logs → dashboard shows zeroes/empty states gracefully, not crash.

---

### LOG-01 — Log a Workout
**Precondition:** Logged in.
**Steps:**
1. Tap "+" or "Add Workout" from dashboard or logging tab
2. Enter: Exercise=`Running`, Sets=`1`, Reps=`30`, Weight=`0`, Date=today
3. Tap Save

**Expected:** Success snackbar, navigates back.
**Edge — non-numeric sets:** Enter `abc` in Sets → shows validation error or snackbar, no crash.
**Edge — negative weight:** Enter `-10` in Weight → rejected or treated as 0.

---

### LOG-02 — Log Food
**Precondition:** Logged in.
**Steps:**
1. Add food: Meal=`Breakfast`, Name=`Oatmeal`, Calories=`350`, Protein=`12`, Carbs=`54`, Fats=`5`
2. Tap Save

**Expected:** Success snackbar, no crash.
**Edge — empty name:** Leave Name blank → error shown.
**Edge — missing macros:** Leave protein/carbs/fats empty → should accept (nullable fields).

---

### LOG-03 — Log Steps
**Precondition:** Logged in.
**Steps:**
1. Navigate to Steps entry
2. Enter: Steps=`8000`, Date=today
3. Tap Save

**Expected:** Success snackbar.
**Edge — zero steps:** Steps=`0` → accepted (valid rest day entry).
**Edge — text input:** Steps=`ten thousand` → validation error shown.

---

### LOG-04 — Log Body Metrics
**Precondition:** Logged in.
**Steps:**
1. Navigate to Body Metrics entry
2. Enter: Weight=`75.0`, BMI=`24.5`, Body Fat=`18`, Muscle Mass=`35`
3. Tap Save

**Expected:** Success snackbar.
**Edge — weight missing:** Leave Weight blank → error (required field).
**Edge — optional fields empty:** Leave BMI/BodyFat/MuscleMass empty → accepted (nullable).

---

## Tier 2 — Data Integrity

### MED-01 — Upload Medical Report (PDF)
**Precondition:** Logged in, small test PDF available on emulator storage.
**Steps:**
1. Navigate to Medical tab → Upload
2. Set Report Date = today
3. Tap Pick File → select PDF
4. Tap Upload

**Expected:** Progress shown, upload succeeds, navigates back to Medical Hub, biomarker gauges visible (Vitamin D, LDL, Glucose).
**Edge — no file selected:** Tap Upload without picking file → validation error shown.
**Edge — unsupported type:** Pick a `.xlsx` file → file picker should filter it out or show error.
**Edge — very large file:** Try to pick a 20MB file → should either show size error or proceed (depending on server limit: 10MB configured).

---

### MED-02 — Medical Hub Biomarker Display
**Precondition:** MED-01 completed, at least one report uploaded.
**Steps:**
1. Open Medical tab (hub screen)

**Expected:** Biomarker gauge cards visible with colored status indicators. Recent reports list not empty.
**Edge — no reports:** Fresh account, no uploads → shows empty state message, not crash.

---

### CHAT-01 — Send Text Message for Metric Extraction
**Precondition:** Logged in.
**Steps:**
1. Navigate to Chat tab
2. Type: `I ran 5km today and ate 400 calories for lunch`
3. Tap Send

**Expected:** Message appears in chat, AI response shown with extracted metrics (workout logged or food logged confirmation). No crash.
**Edge — AI service down:** If AI returns error → fallback regex parser runs, still extracts what it can.

---

### CHAT-02 — AI Insights from Chat
**Precondition:** Some data logged (workouts, food).
**Steps:**
1. In Chat, type `give me health insights` or tap insight button
2. Wait for response

**Expected:** Structured response with diet/training/recovery suggestions. No infinite spinner.
**Edge — no data:** No logs → AI returns generic advice (not crash).

---

### CHAT-03 — Image Attachment in Chat
**Precondition:** Logged in, emulator has image in gallery.
**Steps:**
1. Tap attachment icon in chat
2. Select "Gallery" or "Camera"
3. Pick an image

**Expected:** Image previewed in chat, send button active, no crash.
**Edge — camera picker:** Tap Camera → emulator camera preview opens (may show blank/test image).

---

### TRENDS-01 — View Trends Chart
**Precondition:** At least 2 body metrics entries logged (for chart to render).
**Steps:**
1. Navigate to Trends screen (from dashboard or navigation)
2. View weight trend line chart
3. Toggle "Steps Overlay" switch ON

**Expected:** Line chart renders with weight data. Steps overlay appears as dotted line. No crash.
**Edge — less than 2 entries:** Only 1 metric logged → shows "Add more weight logs" message instead of chart.

---

### TRENDS-02 — Time Window Changes
**Precondition:** Data logged across multiple dates.
**Steps:**
1. Tap `7D` chip → chart re-renders
2. Tap `30D` chip → chart re-renders
3. Tap `90D` chip → chart re-renders

**Expected:** Each tap triggers API reload, chart updates. KPI tiles at bottom update. No crash.

---

### INSIGHTS-01 — Generate AI Insights (Standalone)
**Precondition:** Logged in, some data present.
**Steps:**
1. Navigate to AI Insights screen
2. Tap Generate Insights

**Expected:** Loading spinner while waiting. Diet/training/recovery/medical suggestion lists appear. Disclaimer text visible at bottom.
**Edge — empty response:** If AI returns no suggestions → shows empty state, not crash.

---

### PROFILE-01 — View and Update Profile
**Precondition:** Logged in.
**Steps:**
1. Navigate to Profile tab
2. Verify user data loaded (age, gender, height, etc.)
3. Change Goal to `Lose Weight`
4. Tap Save

**Expected:** Success message, changes persisted (re-open profile, value still `Lose Weight`).
**Edge — invalid API URL:** Change API Base URL to `notaurl` → show validation error, do not save.

---

### PROFILE-02 — API Base URL Change
**Precondition:** Logged in, backend running locally.
**Steps:**
1. Go to Profile → Connection settings
2. Change API Base URL to `https://healthcoach.duckdns.org/api`
3. Tap Save / Navigate away
4. Open Dashboard

**Expected:** Dashboard still loads from new URL. JWT auth still works.
**Edge — unreachable URL:** Set URL to `https://notexist.example.com/api` → Dashboard shows network error, not crash.

---

## Tier 3 — Edge Cases & Validation

### EDGE-01 — Date Picker Boundaries
**Precondition:** Any add-entry screen open (workout, food, steps).
**Steps:**
1. Tap Date field
2. Try to navigate to a date before 2020
3. Try to navigate to a future date

**Expected:** Dates before firstDate (2020-01-01) are greyed out and not selectable. Future dates (> today) are greyed out.

---

### EDGE-02 — Double-Tap Prevention
**Precondition:** On any save screen with network call.
**Steps:**
1. Fill form
2. Quickly double-tap Save button

**Expected:** Only one API request sent. No duplicate entry created. Button disabled during loading.

---

### EDGE-03 — Network Failure During Save
**Precondition:** Logged in.
**Steps:**
1. Disable network on emulator (Airplane mode)
2. Fill workout form → Tap Save

**Expected:** Error snackbar/message shown ("network error" or similar). App does not crash. Can retry after re-enabling network.

---

### EDGE-04 — Session Expiry
**Precondition:** Logged in.
**Steps:**
1. Manually expire the JWT (or wait — token expires in 24h; simulate by clearing token from storage via adb)
2. Try to navigate to Dashboard

**Expected:** App detects 401 response, logs out, redirects to Login screen.

---

### EDGE-05 — Very Long Text Inputs
**Precondition:** On any text input screen.
**Steps:**
1. In Exercise Name field, enter 500 character string
2. Tap Save

**Expected:** Either truncated on display or accepted by backend. No crash. No layout overflow.

---

### EDGE-06 — Pull to Refresh While Loading
**Precondition:** Dashboard loading.
**Steps:**
1. Immediately pull to refresh while initial load is still in progress

**Expected:** No crash. Either queues the refresh or ignores the second pull. Not two simultaneous API calls.

---

## Test Execution Checklist

For each test run, fill this table:

| ID | Name | Status | Notes |
|----|------|--------|-------|
| AUTH-01 | Email Registration | ⬜ | |
| AUTH-02 | Email Login | ⬜ | |
| AUTH-03 | Session Persistence | ⬜ | |
| AUTH-04 | Logout | ⬜ | |
| DASH-01 | Dashboard Load | ⬜ | |
| LOG-01 | Log Workout | ⬜ | |
| LOG-02 | Log Food | ⬜ | |
| LOG-03 | Log Steps | ⬜ | |
| LOG-04 | Log Body Metrics | ⬜ | |
| MED-01 | Upload Medical Report | ⬜ | |
| MED-02 | Medical Hub Display | ⬜ | |
| CHAT-01 | Chat Metric Extraction | ⬜ | |
| CHAT-02 | Chat AI Insights | ⬜ | |
| CHAT-03 | Chat Image Attachment | ⬜ | |
| TRENDS-01 | Trends Chart | ⬜ | |
| TRENDS-02 | Time Window Changes | ⬜ | |
| INSIGHTS-01 | Standalone AI Insights | ⬜ | |
| PROFILE-01 | Profile Update | ⬜ | |
| PROFILE-02 | API URL Change | ⬜ | |
| EDGE-01 | Date Picker Boundaries | ⬜ | |
| EDGE-02 | Double-Tap Prevention | ⬜ | |
| EDGE-03 | Network Failure | ⬜ | |
| EDGE-04 | Session Expiry | ⬜ | |
| EDGE-05 | Long Text Input | ⬜ | |
| EDGE-06 | Pull-to-Refresh Race | ⬜ | |

---

## Acceptance Criteria

| Tier | Threshold | Verdict |
|------|-----------|---------|
| Tier 1 (AUTH + DASH + LOG) | 100% pass | Required for GO |
| Tier 2 (MED + CHAT + TRENDS + INSIGHTS + PROFILE) | ≥ 85% pass | Required for GO |
| Tier 3 (EDGE) | ≥ 70% pass | Advisory — logged as bugs if failing |

Overall **GO** = Tier 1 all pass + Tier 2 ≥ 85%.

---

## Known Skips (Cannot Automate)

| Test | Reason |
|------|--------|
| Google Sign-In | OAuth flow requires real Google account in browser — no automation possible on emulator |
| Camera Live Preview | Emulator camera shows blank/virtual feed — test picker opening only, not actual photo |
| Apple Sign-In | iOS only |
