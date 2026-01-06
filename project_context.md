# OpenLift 2 - Project Context & Status

## 1. Project Overview
**Name:** OpenLift 2
**Goal:** Community-driven fitness tracker with local-first data, AI coaching, and granular strength analytics.
**Tech Stack:**
- **Framework:** Flutter (Dart)
- **State Management:** Provider
- **Backend/Auth:** Supabase (Auth only, currently), Local SQLite (User Data)
- **AI:** Google Generative AI (Gemini 2.0 Flash)
- **Database:** `sqflite`
- **Charts:** `fl_chart`

## 2. Current Database Schema (Version 6)
*Always check this before writing SQL queries.*

* **user_equipment**: `id` (TEXT), `name` (TEXT), `is_owned` (INTEGER 0/1)
* **workout_logs**: `id` (TEXT), `exercise_id` (TEXT), `exercise_name` (TEXT), `weight` (REAL), `reps` (INTEGER), `volume_load` (REAL), `timestamp` (TEXT)
* **workout_plans**: `id` (TEXT), `name` (TEXT), `goal` (TEXT), `schedule_json` (TEXT - JSON blob of WorkoutDay list)
* **exercise_stats** (Legacy/Deprecated): `exercise_name` (TEXT), `one_rep_max` (REAL), `last_updated` (TEXT)
* **body_metrics**: `id` (TEXT), `date` (TEXT), `weight` (REAL), `measurements_json` (TEXT)
* **one_rep_max_history**: `id` (TEXT), `exercise_name` (TEXT), `weight` (REAL), `date` (TEXT)
* **custom_exercises**: `id` (TEXT), `name` (TEXT), `category` (TEXT), `primary_muscles` (TEXT), `notes` (TEXT)

## 3. Core Features Implemented
1.  **AI Plan Generator:** Generates full JSON schedules based on Goal, Days/Week, Equipment, User Profile, and Strength History.
2.  **Workout Player:** Tracks sets/reps/weight with smart suggestions, rest timers, and audio cues.
3.  **Strength Profile:** Visual history (charts) of 1 Rep Max progress.
4.  **Body Metrics:** Logs weight and body measurements; visualizes weight trends.
5.  **Equipment Manager:** Toggle owned equipment to filter AI generation.
6.  **Settings:** User profile inputs stored in `SharedPreferences`.
7.  **Wiki Integration:** Links exercises to Supabase `exercises` table.
8.  **Analytics Dashboard:** * **Volume Trend:** Weekly volume bar chart.
    * **Muscle Heatmap:** Dynamic anatomical map (Front/Back) coloring muscles based on frequency.
    * **Consistency:** aggregated data queries.

## 4. Roadmap (Intended Outcomes)
The app is NOT complete until these features are active:
* **[PRIORITY] Wiki Polish:** Ensure `ExerciseDetailScreen` properly displays images/videos from Supabase.
* **Global Search:** Ability to find any exercise or plan quickly.
* **Community Features:** Sharing plans via link or code.
* **Offline Mode Polish:** Ensure app handles no internet gracefully.
* **Theming:** Dark/Light mode toggle (Foundation laid with "Vitality Rise" theme).

## 5. Lessons Learned & Regression Prevention
* **DO NOT** use `gemini-1.5-flash-latest` or generic `gemini-pro`. **Current Stable Model:** `gemini-2.0-flash`.
* **Database:** When adding tables, ALWAYS bump the version number in `_initDB` and write the migration logic in `onUpgrade`.
* **Audio:** Ensure files (e.g., `beep.mp3`) are in `/assets` AND registered in `pubspec.yaml`.
* **AI Context:** ALWAYS pass `strengthStats` and `userProfile` to `generateFullPlan`.
* **Flutter:** Use `mounted` checks before using `BuildContext` across async gaps.
* **Charts:** `fl_chart` parameters vary by version; check installed version for `tooltipBgColor` vs `getTooltipColor`.

## 6. Directory Structure Key
* `lib/services/`: Database, API, Auth logic.
* `lib/models/`: Data classes with `fromMap`/`toMap`.
* `lib/screens/`: UI Views.
* `lib/widgets/`: Reusable components (Dialogs, Charts, Heatmaps).