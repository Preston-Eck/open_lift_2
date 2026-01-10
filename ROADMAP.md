# OpenLift 2 - Development Roadmap

**Core Philosophy:** "Free to Maintain" (F2M).
**Architecture:** Flutter (Client) + Supabase (Backend/Realtime) + Firebase Cloud Messaging (Transport).
**AI Model:** Gemini 2.0 Flash (Free Tier).

---

## v1.0.3: The Hotfix (Immediate Priority)
**Goal:** Fix data loss issues where Custom Equipment and Exercises do not sync between devices.
* **Scope:**
    * [x] Update `SyncService` to handle `user_equipment` table.
    * [x] Update `SyncService` to handle `custom_exercises` table.
    * [x] Verify `last_updated` timestamps are correctly managing conflict resolution (Last-Write-Wins).
* **Key Files:** `lib/services/sync_service.dart`.

---

## v1.1.0: The Social Structure (The "Inbox" Update)
**Goal:** Eliminate "Share Codes". Enable direct Gym/Plan sharing via a Friend Graph and an In-App Inbox.
* **Schema Changes:**
    * `notifications`: `id`, `user_id`, `type` (invite/nudge/share), `payload_json`, `is_read`, `created_at`.
    * `gym_members`: Add `status` (pending/active) and `invited_by`.
    * `workout_comments`: `id`, `session_id`, `user_id`, `text`, `created_at`.
    * `workout_likes`: `id`, `session_id`, `user_id`.
* **Features:**
    * [x] **The Inbox:** A new screen tab for accepting Friend Requests, Gym Invites, and Plan Shares.
    * [x] **Direct Sharing:** "Send to Friend" button for Plans and Gyms (writes to `notifications`).
    * [x] **Activity Feed:** Convert `SocialDashboard` to show Friends' latest `workout_logs` with Like/Comment buttons.
* **Key Files:** `social_service.dart`, `inbox_screen.dart`, `social_dashboard_screen.dart`.

---

## v1.2.0: The Vision Update (Automated Onboarding)
**Goal:** Reduce friction in setting up a gym using Multi-Modal AI.
* **New Packages:** `image_picker`, `flutter_image_compress`, `file_picker`, `syncfusion_flutter_pdf` (or similar).
* **Features:**
    * [x] **Equipment Input UI:** Form accepting Name, Description, Photo, and PDF Manual.
    * [x] **Gemini Vision Service:** Update `GeminiService` to send `Content.multi` (Text + Image/PDF bytes).
    * [x] **Parser:** Convert AI JSON response into `custom_exercises` linked to the new equipment.
* **Risk:** Payload size limits on Gemini API. Need robust image compression.

---

## v1.2.5: The Flow Update (Smart Player)
**Goal:** Transform the app from a "Logger" to a "Coach".
* **Schema Changes:**
    * `exercises`: Add `metric_type` ('weight_reps', 'time', 'amrap').
    * `workout_plans`: Add `circuit_group_id` (for supersets).
* **Features:**
    * [x] **Smart Timers:** 3s Countdown (Pre-set), Duration Timer (During-set), Auto-Rest (Post-set).
    * [x] **Audio Ducking:** Lower background music volume during beeps/TTS.
    * [x] **Auto-Play:** State machine that automatically advances to the next step.
    * [x] **Circuit Logic:** Interleave sets (A1 -> B1 -> A2 -> B2).
* **Key Files:** `workout_player_service.dart`, `workout_player_screen.dart`.

---

## v1.3.0: The Visual Update
**Goal:** Visual motivation.
* **New Packages:** `flutter_svg`.
* **Features:**
    * [x] **Muscle Heat Map:** Render a human body SVG. Map `primary_muscles` strings to SVG paths.
    * [x] **Analytics:** Color code muscles by Volume (Red = High, Blue = Low) over the last 30 days.

---

## v1.4.0: The Connectivity Update
**Goal:** Real-time competition and accountability notifications.
* **New Packages:** `firebase_messaging` (FCM), `flutter_local_notifications`.
* **Infrastructure:**
    * **Supabase Edge Functions (Free Tier):**
        * `check_missed_workouts`: Runs nightly. If user missed schedule -> Sends FCM to Friends.
* **Features:**
    * [x] **Versus Mode:** Live "Tonnage" counter using Supabase Realtime Broadcast channels.
    * [x] **Push Notifications:** Deep linking for Nudges and Invites.

---

## v1.5.0: The Intelligence Update
**Goal:** Conversational AI Coach.
* **Features:**
    * [x] **Chat Interface:** RAG (Retrieval-Augmented Generation) on user's `workout_logs`.
    * [x] **Querying:** "Why is my bench press stalled?" -> AI analyzes volume/intensity trends.
