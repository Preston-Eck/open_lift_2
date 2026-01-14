import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart'; // NEW
import 'dart:convert' as import_convert;
import 'database_service.dart';
import 'auth_service.dart';

class SyncService extends ChangeNotifier {
  final DatabaseService _db;
  final AuthService _auth;
  final SupabaseClient _supabase = Supabase.instance.client;

  bool _isSyncing = false;
  bool get isSyncing => _isSyncing;

  String? _lastError;
  String? get lastError => _lastError;

  SyncService(this._db, this._auth);

  /// Main Sync Method.
  Future<void> syncAll() async {
    if (_isSyncing) {
      debugPrint("Sync already in progress. Skipping.");
      return;
    }

    if (!_auth.isAuthenticated) {
      debugPrint("Sync Aborted: User not logged in.");
      return;
    }

    final dynamic connectivity = await Connectivity().checkConnectivity();
    final bool isOffline = connectivity is List 
      ? connectivity.contains(ConnectivityResult.none)
      : connectivity == ConnectivityResult.none;

    if (isOffline) {
      _lastError = "Sync Aborted: No Internet.";
      debugPrint(_lastError);
      notifyListeners();
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    final lastSyncTime = prefs.getString('last_sync_timestamp') ?? '1970-01-01T00:00:00.000Z';
    debugPrint("🔄 Syncing from: $lastSyncTime");

    _isSyncing = true;
    _lastError = null;
    notifyListeners();

    try {
      // 1. Core Metadata & Equipment (Dependencies first)
      await _pushEquipment();
      await _pullEquipment(lastSyncTime);
      await _pushCustomExercises();
      await _pullCustomExercises(lastSyncTime);
      await _pushGymProfiles();
      await _pullGymProfiles(lastSyncTime);
      await _db.ensureGymExists(); // Ensure at least one gym exists after sync

      // 2. User Data (Plans & Logs)
      await _pushPlans();
      await _pullPlans(lastSyncTime); 
      await _pushLogs();
      await _pullLogs(lastSyncTime); 

      await prefs.setString('last_sync_timestamp', DateTime.now().toIso8601String());
      debugPrint("✅ Sync Complete.");
    } on PostgrestException catch (e) {
       _lastError = "Database Sync Error: ${e.message}";
       debugPrint("❌ $_lastError");
    } catch (e) {
      _lastError = "General Sync Error: $e";
      debugPrint("❌ $_lastError");
    } finally {
      _isSyncing = false;
      notifyListeners();
    }
  }

  // --- GYM PROFILES SYNC ---

  Future<void> _pushGymProfiles() async {
    final userId = _auth.user!.id;
    final unsynced = await _db.getUnsyncedGymProfiles();

    if (unsynced.isEmpty) return;

    final batch = unsynced.map((gym) {
      return {
        'id': gym['id'],
        'owner_id': userId,
        'name': gym['name'],
        'is_default': gym['is_default'],
        'created_at': gym['created_at'],
        'updated_at': gym['last_updated'] ?? DateTime.now().toIso8601String(),
        'deleted_at': gym['deleted_at'], // Tombstone
      };
    }).toList();

    await _supabase.from('gym_profiles').upsert(batch);

    // For each non-deleted gym, we still might need to push its equipment list
    // (Existing logic for gym_equipment is simplistic "full replace")
    for (var gym in unsynced) {
      if (gym['deleted_at'] != null) continue;
      final gymId = gym['id'] as String;
      final equipmentIds = await _db.getGymItemIds(gymId);
      await _supabase.from('gym_equipment').delete().eq('gym_id', gymId);
      if (equipmentIds.isNotEmpty) {
        final equipBatch = equipmentIds.map((eid) => {'gym_id': gymId, 'equipment_id': eid}).toList();
        await _supabase.from('gym_equipment').upsert(equipBatch);
      }
    }

    await _db.markGymProfilesSynced(unsynced.map((e) => e['id'] as String).toList());
  }

  Future<void> _pullGymProfiles(String lastSyncTime) async {
    final userId = _auth.user!.id;
    
    // 1. Get Changed Profiles
    final response = await _supabase
        .from('gym_profiles')
        .select()
        .eq('owner_id', userId)
        .gt('updated_at', lastSyncTime);

    if (response.isNotEmpty) {
      final List<Map<String, dynamic>> localBatch = [];
      for (var row in response) {
        localBatch.add({
          'id': row['id'],
          'name': row['name'],
          'is_default': row['is_default'],
          'created_at': row['created_at'],
          'owner_id': row['owner_id'],
          'last_updated': row['updated_at'],
          'deleted_at': row['deleted_at'],
        });
      }
      await _db.bulkUpsertGymProfiles(localBatch);
      
      // 2. For each updated gym, fetch its equipment list
      for (var row in response) {
        if (row['deleted_at'] != null) continue;
        final gymId = row['id'] as String;
        final equipResponse = await _supabase
            .from('gym_equipment')
            .select('equipment_id')
            .eq('gym_id', gymId);
            
        final List<String> equipIds = [];
        for (var eRow in equipResponse) {
          equipIds.add(eRow['equipment_id'] as String);
        }
        
        await _db.replaceGymEquipment(gymId, equipIds);
      }
    }
  }

  // --- GYM SHARING ---

  Future<void> joinGym(String gymId) async {
    if (!_auth.isAuthenticated) throw Exception("User not logged in");
    final userId = _auth.user!.id;

    // Check if already a member
    final check = await _supabase
        .from('gym_members')
        .select()
        .eq('gym_id', gymId)
        .eq('user_id', userId);
    
    if (check.isNotEmpty) return; // Already joined

    // Insert Member
    await _supabase.from('gym_members').insert({
      'id': const Uuid().v4(), // Client-side ID generation
      'gym_id': gymId,
      'user_id': userId,
      'nickname': 'My Gym (Joined)',
      'status': 'accepted'
    });

    // Trigger Pull immediately
    await _pullGymProfiles('1970-01-01T00:00:00.000Z');
  }

  Future<List<Map<String, dynamic>>> getGymMembers(String gymId) async {
    // This requires a view or RLS policy that allows reading members of a gym you are in
    try {
      final response = await _supabase
          .from('gym_members')
          .select('id, user_id, nickname, status')
          .eq('gym_id', gymId);
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      debugPrint("Fetch Members Error: $e");
      return [];
    }
  }

  Future<void> _pushEquipment() async {
    final userId = _auth.user!.id;
    final unsynced = await _db.getUnsyncedEquipment();
    
    if (unsynced.isEmpty) return;

    final batch = unsynced.map((e) {
      return {
        'id': e['id'], 
        'user_id': userId,
        'name': e['name'],
        'is_owned': e['is_owned'],
        'capabilities_json': e['capabilities_json'],
        'updated_at': e['last_updated'] ?? DateTime.now().toIso8601String(),
        'deleted_at': e['deleted_at'],
      };
    }).toList();

    await _supabase.from('user_equipment').upsert(batch);
    await _db.markEquipmentSynced(unsynced.map((e) => e['id'] as String).toList());
  }

  Future<void> _pullEquipment(String lastSyncTime) async {
    final userId = _auth.user!.id;
    final response = await _supabase
        .from('user_equipment')
        .select()
        .eq('user_id', userId)
        .gt('updated_at', lastSyncTime);

    if (response.isEmpty) return;

    // LWW: Fetch local state to compare
    final localRows = await _db.getUserEquipmentList();
    final localMap = {for (var item in localRows) item['id']: item};
    
    final List<Map<String, dynamic>> upsertBatch = [];
    
    for (var row in response) {
      final id = row['id'];
      final remoteTime = DateTime.tryParse(row['updated_at'] ?? '') ?? DateTime(1970);
      final local = localMap[id];
      
      bool shouldUpdate = false;
      if (local == null) {
        shouldUpdate = true; // New item from remote
      } else {
        // Protect local unsynced changes
        final synced = local['synced'] == 1;
        if (synced) {
          // If local is synced, we can overwrite if remote is newer
          final localTime = DateTime.tryParse(local['last_updated'] ?? '') ?? DateTime(1970);
          if (remoteTime.isAfter(localTime)) {
             shouldUpdate = true;
          }
        }
        // If !synced, we keep local (Conflict: Local change vs Remote change. We keep local draft.)
      }
      
      if (shouldUpdate) {
        upsertBatch.add({
          'id': row['id'], 
          'name': row['name'],
          'is_owned': row['is_owned'],
          'capabilities_json': row['capabilities_json'],
          'last_updated': row['updated_at'],
          'deleted_at': row['deleted_at'],
        });
      }
    }

    if (upsertBatch.isNotEmpty) {
      await _db.bulkUpsertEquipment(upsertBatch);
    }
  }

  Future<void> _pushCustomExercises() async {
    final userId = _auth.user!.id;
    final unsynced = await _db.getUnsyncedCustomExercises();
    
    if (unsynced.isEmpty) return;

    final batch = unsynced.map((e) {
      return {
        'id': e['id'],
        'user_id': userId,
        'name': e['name'],
        'category': e['category'],
        'primary_muscles': e['primary_muscles']?.split(',') ?? [], 
        'notes': e['notes'],
        'equipment_required': (e['equipment_json'] != null) 
            ? List<String>.from(Helpers.safeJsonDecode(e['equipment_json'])) 
            : [],
        'updated_at': e['last_updated'] ?? DateTime.now().toIso8601String(),
        'deleted_at': e['deleted_at'],
      };
    }).toList();

    await _supabase.from('custom_exercises').upsert(batch);
    await _db.markCustomExercisesSynced(unsynced.map((e) => e['id'] as String).toList());
  }

  Future<void> _pullCustomExercises(String lastSyncTime) async {
    final userId = _auth.user!.id;
    final response = await _supabase
        .from('custom_exercises')
        .select()
        .eq('user_id', userId)
        .gt('updated_at', lastSyncTime);

    if (response.isEmpty) return;

    // LWW: Fetch local state
    final localRows = await _db.getAllCustomExercisesRaw();
    final localMap = {for (var item in localRows) item['id']: item};

    final List<Map<String, dynamic>> upsertBatch = [];

    for (var row in response) {
      final id = row['id'];
      final remoteTime = DateTime.tryParse(row['updated_at'] ?? '') ?? DateTime(1970);
      final local = localMap[id];
      
      bool shouldUpdate = false;
      if (local == null) {
        shouldUpdate = true;
      } else {
        final synced = local['synced'] == 1;
        if (synced) {
          final localTime = DateTime.tryParse(local['last_updated'] ?? '') ?? DateTime(1970);
          if (remoteTime.isAfter(localTime)) {
             shouldUpdate = true;
          }
        }
      }
      
      if (shouldUpdate) {
        final muscles = (row['primary_muscles'] as List<dynamic>?)?.join(',') ?? '';
        final equipJson = Helpers.safeJsonEncode(row['equipment_required']);
        
        upsertBatch.add({
          'id': row['id'],
          'name': row['name'],
          'category': row['category'],
          'primary_muscles': muscles,
          'notes': row['notes'],
          'equipment_json': equipJson,
          'last_updated': row['updated_at'],
          'deleted_at': row['deleted_at'],
        });
      }
    }

    if (upsertBatch.isNotEmpty) {
      await _db.bulkUpsertCustomExercises(upsertBatch);
    }
  }

  Future<void> _pushPlans() async {
    final unsynced = await _db.getUnsyncedPlans();
    if (unsynced.isEmpty) return;
    
    final userId = _auth.user!.id;
    final batch = unsynced.map((p) => {
      'id': p['id'],
      'owner_id': userId,
      'name': p['name'],
      'goal': p['goal'],
      'type': p['type'],
      'schedule_json': p['schedule_json'],
      'updated_at': p['last_updated'] ?? DateTime.now().toIso8601String(),
      'deleted_at': p['deleted_at'],
    }).toList();
    
    await _supabase.from('plans').upsert(batch);
    await _db.markPlansSynced(unsynced.map((p) => p['id'] as String).toList());
  }

  Future<void> _pullPlans(String lastSyncTime) async {
    final userId = _auth.user!.id;
    final response = await _supabase.from('plans')
      .select()
      .eq('owner_id', userId)
      .gt('updated_at', lastSyncTime);

    if (response.isEmpty) return;

    final List<Map<String, dynamic>> plans = [];
    for (var row in response) {
      plans.add({
        'id': row['id'],
        'name': row['name'],
        'goal': row['goal'],
        'type': row['type'],
        'schedule_json': row['schedule_json'],
        'last_updated': row['updated_at'],
        'deleted_at': row['deleted_at'],
      });
    }
    await _db.bulkInsertPlans(plans);
  }

  Future<void> _pushLogs() async {
    final unsynced = await _db.getUnsyncedLogs();
    if (unsynced.isEmpty) return;
    
    final userId = _auth.user!.id;
    const int batchSize = 200;
    
    for (var i = 0; i < unsynced.length; i += batchSize) {
      final chunk = unsynced.sublist(i, (i + batchSize < unsynced.length) ? i + batchSize : unsynced.length);
      final batch = chunk.map((l) => {
        'id': l['id'],
        'owner_id': userId,
        'session_id': l['session_id'],
        'exercise_name': l['exercise_name'],
        'weight': l['weight'],
        'reps': l['reps'],
        'volume_load': l['volume_load'],
        'timestamp': l['timestamp'],
        'updated_at': l['last_updated'] ?? DateTime.now().toIso8601String(),
        'deleted_at': l['deleted_at'],
        'rpe': l['rpe'],
        'is_pr': l['is_pr'] == 1, // Boolean on Supabase
      }).toList();
      
      await _supabase.from('logs').upsert(batch);
    }
    
    await _db.markLogsSynced(unsynced.map((l) => l['id'] as String).toList());
  }

  Future<void> _pullLogs(String lastSyncTime) async {
    final userId = _auth.user!.id;
    final response = await _supabase.from('logs')
      .select()
      .eq('owner_id', userId)
      .gt('updated_at', lastSyncTime)
      .order('timestamp', ascending: false)
      .limit(1000);

    if (response.isEmpty) return;

    final List<Map<String, dynamic>> logs = [];
    for (var row in response) {
      logs.add({
        'id': row['id'],
        'session_id': row['session_id'],
        'exercise_id': row['exercise_name'],
        'exercise_name': row['exercise_name'],
        'weight': row['weight'],
        'reps': row['reps'],
        'volume_load': row['volume_load'],
        'timestamp': row['timestamp'],
        'duration': 0,
        'last_updated': row['updated_at'],
        'deleted_at': row['deleted_at'],
        'rpe': row['rpe'],
        'is_pr': row['is_pr'] == true ? 1 : 0,
      });
    }
    await _db.bulkInsertLogs(logs);
  }
}

class Helpers {
  static dynamic safeJsonDecode(String? source) {
    if (source == null || source.isEmpty) return [];
    try {
      return import_convert.jsonDecode(source);
    } catch (_) {
      return [];
    }
  }
  static String safeJsonEncode(Object? object) {
    try {
      return import_convert.jsonEncode(object);
    } catch (_) {
      return "[]";
    }
  }
}