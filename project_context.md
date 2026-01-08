# OpenLift 2 - Project Context & Status

## 1. Project Overview
**Name:** OpenLift 2
**Goal:** Community-driven fitness tracker with cloud sync, social leaderboards, and AI coaching.
**Tech Stack:**
- **Framework:** Flutter (Dart)
- **State Management:** Provider
- **Backend:** Supabase (Auth, Postgres, RPC, Storage)
- **Local Data:** `sqflite` (Schema v13) - Syncs with Cloud & Isolated per User.
- **AI:** Google Generative AI (Gemini 2.0 Flash) - Used for Plan Generation & Equipment Tagging.

## 2. Database Schema (Version 13)
* **user_profile (Local)**: `id` (PK), `birth_date`, `current_weight` (LBS), `height` (CM), `gender`, `fitness_level`
* **user_equipment**: `id`, `name`, `is_owned`, `capabilities_json` (AI Tags)
* **custom_exercises**: `id`, `name`, `category`, `primary_muscles`, `notes`, `equipment_json`
* **workout_sessions**: `id` (UUID), `plan_id`, `day_name`, `start_time`, `end_time`, `note`
* **workout_logs**: `id`, `session_id`, `exercise_name`, `weight`, `reps`, `volume_load`, `timestamp`, `duration`
* **workout_plans**: `id`, `name`, `goal`, `type`, `schedule_json`, `last_updated`
* **Cloud Tables (Supabase)**: `profiles`, `friendships`, `plans`, `logs`, `exercises` (Wiki).

## 3. Core Features Implemented
1.  **Intelligent Gym (AI):** Equipment capability analysis & Gap Analysis Auditor.
2.  **Global Unit System:** Toggle between Imperial (Lbs/Ft) and Metric (Kg/Cm) in Settings; UI converts on the fly while DB stores standardized units.
3.  **Production Data:** 873 Exercises seeded with images and AI-generated equipment tags.
4.  **User Isolation:** Database file switching (`user_{UUID}.db`) upon login/logout.
5.  **Cloud Sync Engine:** Bi-directional sync (`SyncService`) with "Last Write Wins" logic.
6.  **Social Hub:** Friend requests, public plan cloning, and **Weekly Leaderboards**.
7.  **AI Coach:** RAG-enabled Plan Generator using real user stats and equipment.

## 4. Key Services
* `DatabaseService`: Manages isolated SQLite DBs, migrations (v13), and local CRUD.
* `GeminiService`: Handles Equipment Analysis, Plan Generation (Type-Safe inputs).
* `SyncService`: Handles pushing/pulling data to Supabase.
* `SocialService`: Manages friends, requests, and leaderboard data.

## 5. Recent Wins & Lessons
* **Data Seeding:** Created `full_seeder.py` to upload 800+ images and `ai_tagger.py` to auto-tag equipment requirements using Gemini.
* **Type Safety:** Fixed `Map<String, dynamic>` runtime errors in AI Service by enforcing strict String conversion.
* **Migration Strategy:** Used `on_conflict` upserts to safely hydrate the production DB without duplicates.