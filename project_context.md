# OpenLift 2 - Project Context & Status

## 1. Project Overview
**Name:** OpenLift 2
**Goal:** Community-driven fitness tracker with cloud sync, social leaderboards, and AI coaching.
**Version:** 1.0.2+3 (Release Candidate)
**Status:** Post-Release / Hotfix Mode
**Tech Stack:**
- **Framework:** Flutter (Dart)
- **Backend:** Supabase (Auth, Postgres, RPC, Storage)
- **Local Data:** `sqflite` (Schema v13)
- **AI:** Gemini 2.0 Flash (Plan Gen, Equipment Analysis)

## 2. Database Schema (Version 14)
* **user_profile (Local)**: `id`, `birth_date`, `weight`, `height`, `gender`, `fitness_level`
* **user_equipment**: `id`, `name`, `is_owned`, `capabilities_json`, `last_updated`, `synced`
* **custom_exercises**: `id`, `name`, `category`, `muscles`, `notes`, `equipment_json`, `last_updated`, `synced`
* **workout_sessions**: `id`, `plan_id`, `start_time`, `end_time`
* **workout_logs**: `id`, `session_id`, `exercise`, `weight`, `reps`
* **workout_plans**: `id`, `name`, `schedule_json`

## 3. Critical Issues (Hotfix Priority)
* **[CRITICAL] Sync Gap:** `SyncService` currently **only** syncs Plans and Logs. It fails to sync `user_equipment` and `custom_exercises`, causing data loss across devices.
    * *Action:* Must implement `_pushEquipment`, `_pullEquipment`, `_pushCustomExercises` in `SyncService`.

## 4. Completed Features (v1.1.0)

*   **[NEW] AI Coach Chatbot:** Conversational RAG interface (Profile + Logs + Equipment).

*   **[NEW] Weekly Review:** AI-generated analysis of volume, consistency, and goals.

*   **[NEW] Visual Heatmap:** "Low Poly" anatomical map visualizing muscle usage.

*   **[NEW] Data Export:** JSON backup of all user data.

*   **[NEW] Health Integration:** Sync weight from Health Connect/Google Fit (Stubbed for Mobile).

*   **[NEW] Gym Locations:** Multi-profile equipment management with "Full Replace" sync.

*   **[NEW] Onboarding Checklist:** Guided setup for new users.



## 5. Roadmap (Future)

1.  **Wearable Integration:** Real-time heart rate from Bluetooth Low Energy (BLE) devices.

2.  **Social Leaderboards:** Share "Weekly Score" with friends.

3.  **Offline Mode Polish:** Queue requests when offline (currently SyncService aborts).



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