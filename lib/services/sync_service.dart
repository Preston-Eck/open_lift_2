import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'database_service.dart';
import 'auth_service.dart';

class SyncService {
  final DatabaseService _db;
  final AuthService _auth;
  final SupabaseClient _supabase = Supabase.instance.client;

  SyncService(this._db, this._auth);

  /// Main Sync Method. Call this on app start or refresh.
  Future<void> syncAll() async {
    if (!_auth.isAuthenticated) {
      debugPrint("Sync Aborted: User not logged in.");
      return;
    }

    final connectivity = await Connectivity().checkConnectivity();
    if (connectivity == ConnectivityResult.none) {
      debugPrint("Sync Aborted: No Internet.");
      return;
    }

    try {
      debugPrint("🔄 Syncing Plans...");
      await _pushPlans();
      await _pullPlans();

      debugPrint("🔄 Syncing Logs...");
      await _pushLogs();
      await _pullLogs();

      debugPrint("✅ Sync Complete.");
    } catch (e) {
      debugPrint("❌ Sync Error: $e");
    }
  }

  // --- PLANS ---

  Future<void> _pushPlans() async {
    final localPlans = await _db.getAllPlansRaw();
    if (localPlans.isEmpty) return;

    final userId = _auth.user!.id;
    final List<Map<String, dynamic>> batch = localPlans.map((p) {
      return {
        'id': p['id'],
        'owner_id': userId,
        'name': p['name'],
        'goal': p['goal'],
        'type': p['type'],
        'schedule_json': p['schedule_json'],
        'updated_at': p['last_updated'] ?? DateTime.now().toIso8601String(),
      };
    }).toList();

    await _supabase.from('plans').upsert(batch);
  }

  Future<void> _pullPlans() async {
    final userId = _auth.user!.id;
    final response = await _supabase
        .from('plans')
        .select()
        .eq('owner_id', userId);

    final List<Map<String, dynamic>> plans = [];
    for (var row in response) {
      plans.add({
        'id': row['id'],
        'name': row['name'],
        'goal': row['goal'],
        'type': row['type'],
        'schedule_json': row['schedule_json'],
        'last_updated': row['updated_at'],
      });
    }

    await _db.bulkInsertPlans(plans);
  }

  // --- LOGS ---

  Future<void> _pushLogs() async {
    final localLogs = await _db.getAllLogsRaw();
    if (localLogs.isEmpty) return;

    final userId = _auth.user!.id;
    
    // Batch in chunks of 500 to avoid request limits
    const int batchSize = 500;
    for (var i = 0; i < localLogs.length; i += batchSize) {
      final end = (i + batchSize < localLogs.length) ? i + batchSize : localLogs.length;
      final chunk = localLogs.sublist(i, end);

      final List<Map<String, dynamic>> batch = chunk.map((l) {
        return {
          'id': l['id'],
          'owner_id': userId,
          'session_id': l['session_id'],
          'exercise_name': l['exercise_name'],
          'weight': l['weight'],
          'reps': l['reps'],
          'volume_load': l['volume_load'],
          'timestamp': l['timestamp'],
          'updated_at': l['last_updated'] ?? DateTime.now().toIso8601String(),
        };
      }).toList();

      await _supabase.from('logs').upsert(batch);
    }
  }

  Future<void> _pullLogs() async {
    final userId = _auth.user!.id;
    
    // In a real app, use pagination or 'last_sync_time' to fetch only deltas.
    // For MVP, we fetch the last 1000 logs.
    final response = await _supabase
        .from('logs')
        .select()
        .eq('owner_id', userId)
        .order('timestamp', ascending: false)
        .limit(1000);

    final List<Map<String, dynamic>> logs = [];
    for (var row in response) {
      logs.add({
        'id': row['id'],
        'session_id': row['session_id'],
        'exercise_id': row['exercise_name'], // Mapping name to ID for simplicity
        'exercise_name': row['exercise_name'],
        'weight': row['weight'],
        'reps': row['reps'],
        'volume_load': row['volume_load'],
        'timestamp': row['timestamp'],
        'duration': 0, // Default if missing
        'last_updated': row['updated_at'],
      });
    }

    await _db.bulkInsertLogs(logs);
  }
}