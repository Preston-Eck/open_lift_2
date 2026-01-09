# OpenLift Roadmap & Handoff Strategy

## 🚀 Current Status (v1.1.0)
The application is robust, supporting:
*   **AI Plan Generation** with self-healing library (auto-defines new exercises).
*   **Data Sovereignty** via JSON Export/Import.
*   **Community Features** via Gym ID Sharing and JSON Plan Sharing.
*   **Health Sync** (Android/iOS) for weight data.
*   **Visual Analytics** with a low-poly muscle heatmap.

---

## 📅 Roadmap: v1.2 (The "Connected" Update)
**Focus:** Removing friction in sharing and usage.

### 1. Deep Linking (High Priority)
*   **Goal:** Allow users to click `openlift://share/plan?id=123` to instantly import a plan.
*   **Tech:** `app_links` or `uni_links` package.
*   **Implementation:** Handle incoming URL, parse query params, fetch JSON from Supabase (requires uploading plans to public bucket or table first), and trigger the "Import" logic.

### 2. The "Plate Calculator" Utility
*   **Goal:** Visual aid for loading the bar.
*   **UI:** A popup where user enters "Target Weight" (e.g., 315 lbs) and "Bar Weight" (45 lbs).
*   **Output:** Visual stack of plates (e.g., [45][45][45] | [45][45][45]).

### 3. Social Leaderboards
*   **Goal:** Simple "Weekly Volume" leaderboard for users in the same "Gym".
*   **Tech:** Supabase Realtime or standard RPC.
*   **Logic:** `SELECT sum(volume) FROM logs WHERE gym_id = X GROUP BY user_id`.

---

## 🔮 Roadmap: v2.0 (The "Hardware" Update)
**Focus:** Integration with the physical world.

### 1. Wearable Integration (BLE)
*   **Goal:** Real-time Heart Rate during workout player.
*   **Tech:** `flutter_blue_plus`.
*   **Logic:** Scan for HRM services, display BPM on the player screen.

### 2. Advanced AI Coaching
*   **Goal:** "Predictive Loading".
*   **Logic:** AI analyzes previous session's RPE (Rate of Perceived Exertion) and suggests the exact weight for the next set *during* the workout.

---

## 📱 Deployment Instructions

### Web
*   **Artifact:** `build/web`
*   **Action:** Deploy this folder to Firebase Hosting, Vercel, or GitHub Pages.
*   **Command:** `firebase deploy` (if initialized).

### Android
*   **Artifact:** `build/app/outputs/flutter-apk/app-release.apk`
*   **Action:** Upload to Google Play Console (requires signing with a release keystore, currently signed with debug key for testing).

### iOS (Requires Mac)
*   **Prerequisites:** Xcode, Apple Developer Account.
*   **Action:**
    1.  Transfer repo to a Mac.
    2.  Run `flutter build ios`.
    3.  Open `ios/Runner.xcworkspace` in Xcode.
    4.  Configure Signing & Capabilities.
    5.  Archive & Upload to TestFlight.

---

## 🛠 Maintenance
*   **Supabase:** Ensure RLS policies allow the new `gym_members` inserts.
*   **Gemini:** Monitor quota usage. The new prompt is larger (two-part JSON).
