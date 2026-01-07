# OpenLift 2 - Project Context & Status

## 1. Project Overview
**Name:** OpenLift 2
**Goal:** Community-driven fitness tracker with cloud sync, social leaderboards, and AI coaching.
**Tech Stack:**
- **Framework:** Flutter (Dart)
- **State Management:** Provider
- **Backend:** Supabase (Auth, Postgres, RPC, Storage)
- **Local Data:** `sqflite` (Schema v13) - Syncs with Cloud & Isolated per User.
- **AI:** Google Generative AI (Gemini 2.0 Flash)

## 2. Database Schema (Version 13)
* **user_profile (Local)**: `id` (PK), `birth_date`, `current_weight`, `height`, `gender`, `fitness_level`
* **user_equipment**: `id`, `name`, `is_owned`, `capabilities_json` (AI Tags)
* **custom_exercises**: `id`, `name`, `category`, `primary_muscles`, `notes`, `equipment_json`
* **workout_sessions**: `id` (UUID), `plan_id`, `day_name`, `start_time`, `end_time`, `note`
* **workout_logs**: `id`, `session_id`, `exercise_name`, `weight`, `reps`, `volume_load`, `timestamp`, `duration`
* **workout_plans**: `id`, `name`, `goal`, `type`, `schedule_json`, `last_updated`
* **Cloud Tables (Supabase)**: `profiles`, `friendships`, `plans`, `logs`, `exercises` (Wiki).

## 3. Core Features Implemented
1.  **Intelligent Gym (AI):** Equipment capability analysis (e.g., "SincMill" -> "Cable, Bench") & Gap Analysis Auditor.
2.  **User Isolation:** Database file switching (`user_{UUID}.db`) upon login/logout to prevent data leaks.
3.  **Cloud Sync Engine:** Bi-directional sync (`SyncService`) with "Last Write Wins" logic.
4.  **Social Hub:** Friend requests, public plan cloning, and **Weekly Leaderboards**.
5.  **Flexible Workout Player:** Non-linear execution, auto-rest timers, and dynamic audio cues.
6.  **AI Coach:** RAG-enabled Plan Generator & "Fill Gap" Exercise Generator.
7.  **Analytics:** Volume charts, Muscle Heatmap, and 1RM history.

## 4. Key Services
* `DatabaseService`: Manages isolated SQLite DBs, migrations (v13), and local CRUD.
* `GeminiService`: Handles Equipment Analysis, Plan Generation, and Missing Exercise Suggestions.
* `SyncService`: Handles pushing/pulling data to Supabase.
* `SocialService`: Manages friends, requests, and leaderboard data.

## 5. Recent Wins & Lessons
* **Windows Stability:** Switched complex ListViews to `ListView.builder` or `SingleChildScrollView` to fix `!semantics.parentDataDirty` crashes.
* **AI Context:** Providing full inventory lists to Gemini prevents "hallucinated" equipment suggestions.
* **Data Safety:** Using `ChangeNotifierProxyProvider` in `main.dart` ensures DB reference updates immediately upon Auth changes.