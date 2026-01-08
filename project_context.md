# OpenLift 2 - Project Context & Status

## 1. Project Overview
**Name:** OpenLift 2
**Goal:** Community-driven fitness tracker with cloud sync, social leaderboards, and AI coaching.
**Version:** 1.0.2+3 (Release Candidate)
**Tech Stack:**
- **Framework:** Flutter (Dart)
- **State Management:** Provider
- **Backend:** Supabase (Auth, Postgres, RPC, Storage)
- **Local Data:** `sqflite` (Schema v13) - Syncs with Cloud & Isolated per User.
- **AI:** Google Generative AI (Gemini 2.0 Flash) - RAG-enabled Plan Generation & Equipment Analysis.

## 2. Database Schema (Version 13)
* **user_profile (Local)**: `id` (PK), `birth_date`, `current_weight`, `height`, `gender`, `fitness_level`
* **user_equipment**: `id`, `name`, `is_owned`, `capabilities_json` (AI Tags)
* **custom_exercises**: `id`, `name`, `category`, `primary_muscles`, `notes`, `equipment_json`
* **workout_sessions**: `id` (UUID), `plan_id`, `day_name`, `start_time`, `end_time`, `note`
* **workout_logs**: `id`, `session_id`, `exercise_name`, `weight`, `reps`, `volume_load`, `timestamp`, `duration`
* **workout_plans**: `id`, `name`, `goal`, `type`, `schedule_json`, `last_updated`
* **Cloud Tables (Supabase)**: `profiles`, `friendships`, `plans`, `logs`, `exercises` (Wiki).

## 3. Core Features Implemented
1.  **Intelligent Gym (AI):** Separates "Physical Items" (e.g., Power Rack) from "Capabilities" (e.g., Squats) to prevent hallucinations.
2.  **Smart Workout Player:** Displays 1RM history and provides "Smart Hints" for weight selection (75% 1RM or Progressive Overload).
3.  **Fuzzy Search:** "Sit Ups" matches "Sit-Ups" in local and remote databases.
4.  **Global Unit System:** Imperial/Metric toggle with on-the-fly conversion.
5.  **Cloud Sync Engine:** Bi-directional sync with "Last Write Wins" logic; auto-syncs on critical actions.
6.  **Social Hub:** Friend requests, public plan cloning, and Weekly Leaderboards.

## 4. Key Services
* `DatabaseService`: Handles CRUD and strictly separates `getOwnedEquipment` (Capabilities) from `getOwnedItemNames` (Inventory).
* `GeminiService`: Enforces "Warm-up" mandates and strict equipment constraints via Prompt Engineering.
* `SyncService`: Handles pushing/pulling data to Supabase.
* `SocialService`: Manages friends, requests, and leaderboard data.

## 5. Recent Wins & Lessons
* **Prompt Engineering:** Learned that AI needs explicit distinction between "Tools" and "Actions" to avoid programming machines as exercises.
* **UX Polish:** "Smart Hints" in text fields (semi-transparent suggestions) are cleaner than cluttering the UI with label text.
* **Stability:** Moving async initialization (like UUID generation) out of `build()` methods prevents runtime `LateInitializationError` crashes.
* **Linter Discipline:** Enforcing `prefer_collection_literals` and removing unused imports keeps the codebase maintainable.
* **Search UX:** Custom `ExerciseSelectionDialog` provides a better experience than standard `Autocomplete` for mixed local/remote data.

## 6. Next Objectives (v1.1.0)
1.  **AI Coach Chatbot:** Interactive chat interface for ad-hoc advice.
    * *Requirement:* New `chat_history` table.
    * *Requirement:* RAG access to `workout_logs` for personalized answers.
2.  **Workout History Analytics:** Scatter plot visualization of volume/intensity over time.