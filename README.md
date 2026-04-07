# Monday Range Journal

Phone-first Flutter app for the Monday Range Trading Strategy.

## What this package now includes
- Flutter source
- Android wrapper files so it can be built into an APK
- Codemagic cloud build config for phone-only APK generation
- Local notifications scaffold
- Local persistence, journal, checklist, scoring, CSV export

## Build an APK from your Samsung S25 with no PC

### Method 1: Codemagic in your mobile browser
1. Create a GitHub account if you do not already have one.
2. Upload this project to a new GitHub repository.
3. In your phone browser, open Codemagic and sign in with GitHub.
4. Choose **Add application** and select your new repository.
5. Choose the workflow from `codemagic.yaml`.
6. Start build.
7. When the build finishes, download the generated `.apk` onto your phone.
8. Open the APK file and allow **Install unknown apps** when Android asks.

### Method 2: Build locally on a computer
1. Install Flutter stable.
2. Install Android Studio and Android SDK.
3. Create `android/local.properties` based on `android/local.properties.example`.
4. Run:
   ```bash
   flutter pub get
   flutter build apk --release
   ```
5. The APK will be at:
   `build/app/outputs/flutter-apk/app-release.apk`

## Important note about alerts
This version supports local notifications and reminders.
Fully automatic market-triggered alerts like:
- Price near 4H Support / Monday Low
- Price near 4H Resistance / Monday High
- 4H Range Breakout Detected

need a live market data source or TradingView webhook bridge plus Firebase Cloud Messaging.

## Recommended next upgrade
Use TradingView alerts + webhook -> small backend -> Firebase Cloud Messaging.
That will make the app send real signal alerts to your phone.
