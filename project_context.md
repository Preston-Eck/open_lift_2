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

## 2. Current Database Schema (Version 5)
*Always check this before writing SQL queries.*

* **user_equipment**: `id` (TEXT), `name` (TEXT), `is_owned` (INTEGER 0/1)
* **workout_logs**: `id` (TEXT), `exercise_id` (TEXT), `exercise_name` (TEXT), `weight` (REAL), `reps` (INTEGER), `volume_load` (REAL), `timestamp` (TEXT)
* **workout_plans**: `id` (TEXT), `name` (TEXT), `goal` (TEXT), `schedule_json` (TEXT - JSON blob of WorkoutDay list)
* **exercise_stats** (Legacy/Deprecated): `exercise_name` (TEXT), `one_rep_max` (REAL), `last_updated` (TEXT)
* **body_metrics**: `id` (TEXT), `date` (TEXT), `weight` (REAL), `measurements_json` (TEXT)
* **one_rep_max_history**: `id` (TEXT), `exercise_name` (TEXT), `weight` (REAL), `date` (TEXT)

## 3. Core Features Implemented
1.  **AI Plan Generator:** Generates full JSON schedules based on Goal, Days/Week, Equipment, User Profile, and Strength History.
2.  **Workout Player:** * Tracks sets/reps/weight.
    * **Smart Suggestions:** Calculates target weight based on plan intensity (e.g., "75%") and user's 1RM.
    * **Timed Sets:** Countdown timer with audio beeps for duration-based exercises.
    * **Rest Timer:** Auto-starts after set completion.
3.  **Strength Profile:** Visual history (charts) of 1 Rep Max progress; explicit entry dialogs.
4.  **Body Metrics:** Logs weight and body measurements; visualizes weight trends.
5.  **Equipment Manager:** Toggle owned equipment to filter AI generation.
6.  **Settings:** User profile inputs (Age, Height, Gender, Fitness Level) stored in `SharedPreferences`.
7.  **Wiki Integration:** Links exercises to Supabase `exercises` table for details.
8.  **Analytics Backend:** SQLite aggregation queries for Weekly Volume, Consistency (Frequency), and Exercise Popularity implemented in `DatabaseService`.

## 4. Roadmap (Intended Outcomes)
The app is NOT complete until these features are active:
* **[PRIORITY] Wiki Polish:** Ensure `ExerciseDetailScreen` properly displays images/videos from Supabase.
* **[PRIORITY] Analytics Dashboard:** Aggregate data (Total volume lifted, workouts per week, muscle group heatmaps).
* **Global Search:** Ability to find any exercise or plan quickly.
* **Community Features:** Sharing plans via link or code (requires Supabase expansion).
* **Offline Mode Polish:** Ensure app handles no internet gracefully (AI features should show specific error, local DB works 100%).
* **Plate Calculator:** (Optional/Low Priority) Visual guide for loading bars.
* **Theming:** Dark/Light mode toggle and consistent UI styling.

## 5. Lessons Learned & Regression Prevention
* **DO NOT** use `gemini-1.5-flash-latest` or generic `gemini-pro` aliases without verifying availability. **Current Stable Model:** `gemini-2.0-flash`.
* **DO NOT** swallow errors in Services. Always throw exceptions or return meaningful error objects so the UI (`PlanGeneratorScreen`) can display a `SnackBar` or Dialog.
* **Database:** When adding tables, ALWAYS bump the version number in `_initDB` and write the migration logic in `onUpgrade`.
* **Audio:** When using `audioplayers`, ensure files (e.g., `beep.mp3`) are physically present in `/assets` AND registered in `pubspec.yaml`.
* **AI Context:** The AI is stupid without context. ALWAYS pass `strengthStats` and `userProfile` to `generateFullPlan`.
* **Flutter:** Use `mounted` checks before using `BuildContext` across async gaps.

## 6. Directory Structure Key
* `lib/services/`: Database, API, Auth logic.
* `lib/models/`: Data classes with `fromMap`/`toMap`.
* `lib/screens/`: UI Views.
* `lib/widgets/`: Reusable components (Dialogs, Charts).