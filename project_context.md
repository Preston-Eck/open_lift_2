# OpenLift 2 - Project Context & Status

## 1. Project Overview
**Name:** OpenLift 2
**Goal:** Community-driven fitness tracker with cloud sync, social leaderboards, and AI coaching.
**Tech Stack:**
- **Framework:** Flutter (Dart)
- **State Management:** Provider
- **Backend:** Supabase (Auth, Postgres, RPC, Storage)
- **Local Data:** `sqflite` (Schema v11) - Syncs with Cloud.
- **AI:** Google Generative AI (Gemini 2.0 Flash)

## 2. Database Schema (Version 11)
* **workout_sessions**: `id` (UUID), `plan_id`, `day_name`, `start_time`, `end_time`, `note`
* **workout_logs**: `id`, `session_id`, `exercise_name`, `weight`, `reps`, `volume_load`, `timestamp`, `duration`, `last_updated` (Sync)
* **workout_plans**: `id`, `name`, `goal`, `type`, `schedule_json`, `last_updated` (Sync)
* **exercise_aliases**: `original_name` (PK), `alias`
* **user_equipment**: `id`, `name`, `is_owned`
* **Cloud Tables (Supabase)**: `profiles`, `friendships`, `plans`, `logs`.

## 3. Core Features Implemented
1.  **Cloud Sync Engine:** Bi-directional sync (`SyncService`) with "Last Write Wins" logic.
2.  **Social Hub:** Friend requests, public plan cloning, and **Weekly Leaderboards** (via SQL RPC).
3.  **Flexible Workout Player:** Non-linear execution, auto-rest timers, and dynamic audio cues.
4.  **AI Coach:** RAG-enabled Plan Generator using Supabase Wiki data.
5.  **Analytics:** Volume charts, Muscle Heatmap, and 1RM history.

## 4. Key Services
* `DatabaseService`: Local SQLite management & migrations.
* `SyncService`: Handles pushing/pulling data to Supabase.
* `SocialService`: Manages friends, requests, and leaderboard data.
* `AuthService`: Handles Login/Signup and Profile creation.

## 5. Lessons Learned
* **Sync Logic:** Always check `connectivity_plus` before attempting sync.
* **State Safety:** Use `if (mounted)` before updating state in async functions.
* **Supabase RPC:** Use server-side functions for heavy aggregations (Leaderboards).