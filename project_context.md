# OpenLift 2 - Project Context & Status

## 1. Project Overview
**Name:** OpenLift 2
**Goal:** Community-driven fitness tracker with cloud sync, direct social sharing, and AI coaching.
**Version:** 1.0.3 (In Development)
**Status:** Post-Release / Hotfix & Feature Expansion
**Tech Stack:**
- **Framework:** Flutter (Dart)
- **Backend:** Supabase (Auth, Postgres, Realtime, Edge Functions, Storage)
- **Notifications:** Firebase Cloud Messaging (Transport only)
- **Local Data:** `sqflite` (Schema v16)
- **AI:** Gemini 2.0 Flash (Plan Gen, Vision Analysis)

## 2. Database Schema (Target: v17+)
* **user_profile**: `id`, `birth_date`, `weight`, `height`, `gender`, `fitness_level`
* **gym_profiles**: `id`, `name`, `owner_id`, `is_default`
* **gym_members**: `id`, `gym_id`, `user_id`, `status` (pending/active), `nickname`
* **notifications** (Planned): `id`, `user_id`, `type`, `payload`, `is_read`
* **workout_plans**: `id`, `name`, `schedule_json`, `is_public`
* **user_equipment**: `id`, `name`, `capabilities_json`
* **custom_exercises**: `id`, `name`, `muscles`, `equipment_json`

## 3. Architecture Decisions ("Free to Maintain")
1.  **No Share Codes:** All sharing happens via the Friend Graph (`friendships` table) and the "Inbox" pattern.
2.  **Notification Pipeline:** Supabase Edge Functions (Logic) -> FCM (Delivery). Cost: $0.
3.  **Realtime:** "Versus Mode" uses Supabase Realtime Broadcasts (ephemeral), not database writes.
4.  **Multi-Modal AI:** We use Gemini Flash for analyzing User Photos and PDFs to auto-populate equipment capabilities.

## 4. Critical Issues (Hotfix Priority)
* **[CRITICAL] Sync Gap:** `SyncService` currently **only** syncs Plans and Logs. It fails to sync `user_equipment` and `custom_exercises`, causing data loss across devices.
    * *Action:* Must implement `_pushEquipment`, `_pullEquipment`, `_pushCustomExercises` in `SyncService`.

## 5. Completed Features (v1.1.0)
*   **[NEW] Weekly Review:** AI-generated analysis of volume, consistency, and goals.
*   **[NEW] Visual Heatmap:** "Low Poly" anatomical map visualizing muscle usage.
*   **[NEW] Data Export:** JSON backup of all user data.
*   **[NEW] Gym Locations:** Multi-profile equipment management with "Full Replace" sync.
*   **[NEW] Onboarding Checklist:** Guided setup for new users.

## 6. Roadmap (Future)
1.  **Wearable Integration:** Real-time heart rate from Bluetooth Low Energy (BLE) devices.
2.  **Social Leaderboards:** Share "Weekly Score" with friends.
3.  **Offline Mode Polish:** Queue requests when offline (currently SyncService aborts).
4.  **AI Coach Chatbot:** Conversational RAG interface (Profile + Logs + Equipment).
5.  **Health Integration:** Sync weight from Health Connect/Google Fit (Stubbed for Mobile).

## 6. Recent Lessons
*   **Prompt Engineering:** AI requires explicit distinction between "Tools" (Machines) and "Actions" (Exercises).
*   **Deployment:** `accessibility_plugin.cc` errors on Windows are harmless noise.
*   **Data Safety:** Always verify "Sync" covers *all* new tables created during feature development.
*   **Linter:** `share_plus` API shifts frequently; ignore deprecation warnings if functionality works.



## 7. Key Files

*   `lib/services/sync_service.dart` (Critical Sync Logic)
*   `lib/services/gemini_service.dart` (AI Logic)
*   `lib/services/health_service.dart` (HealthKit/Connect)
*   `lib/screens/ai_coach_screen.dart` (Chat UI)
*   `lib/services/social_service.dart` (To be expanded for Inbox)
*   `ROADMAP.md` (Source of Truth for phases)