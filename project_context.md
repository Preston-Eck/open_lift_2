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

## 4. Roadmap (v1.1.0 & Beyond)
1.  **Gym Locations (Multi-Profile):**
    * Allow users to define "Gym Profiles" (e.g., Home, Work, Brother's Gym).
    * Link specific equipment lists to these profiles.
    * Switching profiles automatically filters available exercises/plans.
    * Allow users to share "Gym Profiles" with others.
2.  **User Onboarding Checklist:**
    * Dashboard widget guiding users: 1. Profile -> 2. Gym Setup -> 3. Create Plan.
3.  **AI Coach Chatbot:**
    * Conversational interface for fitness advice using RAG on user logs.

## 5. Recent Lessons
* **Prompt Engineering:** AI requires explicit distinction between "Tools" (Machines) and "Actions" (Exercises).
* **Deployment:** `accessibility_plugin.cc` errors on Windows are harmless noise.
* **Data Safety:** Always verify "Sync" covers *all* new tables created during feature development.

## 6. Key Files
* `lib/services/sync_service.dart` (Needs Update)
* `lib/services/database_service.dart` (Source of Truth)
* `lib/screens/equipment_manager_screen.dart` (UI for Equipment)