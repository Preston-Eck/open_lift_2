# OpenLift 2 - Project Context & Status

## 1. Project Overview
**Name:** OpenLift 2
**Goal:** Community-driven fitness tracker with local-first data, AI coaching, and granular strength analytics.
**Tech Stack:**
- **Framework:** Flutter (Dart)
- **State Management:** Provider
- **Backend:** Supabase (Wiki/Auth), Local SQLite (User Data/History)
- **AI:** Google Generative AI (Gemini 2.0 Flash)
- **Database:** `sqflite` (Schema v9)
- **Charts:** `fl_chart`

## 2. Current Database Schema (Version 9)
*Always check this before writing SQL queries.*

* **workout_sessions** (NEW): `id` (UUID), `plan_id` (TEXT), `day_name` (TEXT), `start_time` (TEXT), `end_time` (TEXT), `note` (TEXT)
* **workout_logs**: `id` (TEXT), `session_id` (TEXT - Links to Session), `exercise_id` (TEXT), `exercise_name` (TEXT), `weight` (REAL), `reps` (INTEGER), `volume_load` (REAL), `timestamp` (TEXT), `duration` (INTEGER)
* **workout_plans**: `id` (TEXT), `name` (TEXT), `goal` (TEXT), `type` (TEXT - Strength/HIIT), `schedule_json` (TEXT)
* **one_rep_max_history**: `id` (TEXT), `exercise_name` (TEXT), `weight` (REAL), `date` (TEXT)
* **body_metrics**: `id` (TEXT), `date` (TEXT), `weight` (REAL), `measurements_json` (TEXT)
* **user_equipment**: `id` (TEXT), `name` (TEXT), `is_owned` (INTEGER 0/1)
* **custom_exercises**: `id` (TEXT), `name` (TEXT), `category` (TEXT), `primary_muscles` (TEXT), `notes` (TEXT)

## 3. Core Features Implemented
1.  **Session Engine:** Logs are now grouped into Sessions. Supports "History Cycling" (viewing past workouts for specific days).
2.  **Flexible Workout Player:** Non-linear execution. Users can jump between exercises, pause globally, skip sets, and finish early.
3.  **Smart Timers:** * **Strength:** Counts UP.
    * **HIIT/Timed:** Counts DOWN with auto-advance logic.
    * **Individual:** Per-exercise stopwatch for ad-hoc timing.
4.  **AI Plan Generator:** RAG-enabled (pulls valid names from Wiki) to prevent hallucinations.
5.  **Exercise Wiki:** thumbnails, 1RM history (with dates), and deep-linking to analytics.
6.  **Error Logging:** `LoggerService` captures crashes to a rolling buffer text file for diagnostics.
7.  **Ghost Cleanup:** Database automatically purges empty/abandoned sessions on startup.

## 4. Roadmap (Intended Outcomes)
* **Nicknames/Aliases:** Allow users to rename exercises locally (e.g. "Skullcrushers" -> "Tricep Ext").
* **Community Sharing:** Share plans via text/link (JSON export/import).
* **Theming:** Dark/Light mode toggle.
* **Plate Calculator:** Helper widget inside the Workout Player.

## 5. Lessons Learned & Regression Prevention
* **State Isolation:** In `ListView.builder`, complex widgets (like `ExerciseCard`) MUST be their own `StatefulWidget` to manage controllers. Never store controllers in a parent `Map` (causes GlobalKey crashes).
* **Async Safety:** Always check `if (!mounted) return;` before using `context` after an `await`.
* **Database:** When adding tables, always bump version in `_initDB`.
* **Gemini:** Always feed it a "Vocabulary List" of valid exercises to ensure database consistency.