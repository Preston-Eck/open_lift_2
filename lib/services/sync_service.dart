import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert' as import_convert; // MOVED TO TOP
import 'database_service.dart';
import 'auth_service.dart';

class SyncService {
  final DatabaseService _db;
  final AuthService _auth;
  final SupabaseClient _supabase = Supabase.instance.client;

  SyncService(this._db, this._auth);

  /// Main Sync Method.
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

    final prefs = await SharedPreferences.getInstance();
    final lastSyncTime = prefs.getString('last_sync_timestamp') ?? '1970-01-01T00:00:00.000Z';
    debugPrint("🔄 Syncing from: $lastSyncTime");

    try {
      await _pushEquipment();
      await _pullEquipment(lastSyncTime);
      await _pushCustomExercises();
      await _pullCustomExercises(lastSyncTime);
      
      // NEW: Sync Gym Profiles (v17)
      await _pushGymProfiles();
      await _pullGymProfiles(lastSyncTime);

      await _pushPlans();
      await _pullPlans(); 
      await _pushLogs();
      await _pullLogs(); 

      await prefs.setString('last_sync_timestamp', DateTime.now().toIso8601String());
      debugPrint("✅ Sync Complete.");
    } catch (e) {
      debugPrint("❌ Sync Error: $e");
    }
  }

  // --- GYM PROFILES SYNC ---

  Future<void> _pushGymProfiles() async {
    final userId = _auth.user!.id;
    final unsynced = await _db.getUnsyncedGymProfiles();

    if (unsynced.isEmpty) return;

    for (var gym in unsynced) {
      final gymId = gym['id'] as String;
      
      // 1. Push Profile Metadata
      final profileData = {
        'id': gymId,
        'owner_id': userId,
        'name': gym['name'],
        'is_default': gym['is_default'],
        'created_at': gym['created_at'],
        'updated_at': gym['last_updated'] ?? DateTime.now().toIso8601String(),
      };
      
      await _supabase.from('gym_profiles').upsert(profileData);

      // 2. Push Equipment List (Full Replace Strategy)
      // fetch local items
      final equipmentIds = await _db.getGymItemIds(gymId);
      
      // Delete existing on remote (simulated replace)
      await _supabase.from('gym_equipment').delete().eq('gym_id', gymId);
      
      // Insert current
      if (equipmentIds.isNotEmpty) {
        final equipBatch = equipmentIds.map((eid) => {
          'gym_id': gymId,
          'equipment_id': eid
        }).toList();
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
        });
      }
      await _db.bulkUpsertGymProfiles(localBatch);
      
      // 2. For each updated gym, fetch its equipment list
      for (var row in response) {
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

    if (response.isNotEmpty) {
      final List<Map<String, dynamic>> localBatch = [];
      for (var row in response) {
        localBatch.add({
          'id': row['id'], 
          'name': row['name'],
          'is_owned': row['is_owned'],
          'capabilities_json': row['capabilities_json'],
          'last_updated': row['updated_at'],
        });
      }
      await _db.bulkUpsertEquipment(localBatch);
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

    if (response.isNotEmpty) {
      final List<Map<String, dynamic>> localBatch = [];
      for (var row in response) {
        final muscles = (row['primary_muscles'] as List<dynamic>?)?.join(',') ?? '';
        final equipJson = Helpers.safeJsonEncode(row['equipment_required']);
        
        localBatch.add({
          'id': row['id'],
          'name': row['name'],
          'category': row['category'],
          'primary_muscles': muscles,
          'notes': row['notes'],
          'equipment_json': equipJson,
          'last_updated': row['updated_at'],
        });
      }
      await _db.bulkUpsertCustomExercises(localBatch);
    }
  }

  Future<void> _pushPlans() async {
    final localPlans = await _db.getAllPlansRaw();
    if (localPlans.isEmpty) return;
    final userId = _auth.user!.id;
    final batch = localPlans.map((p) => {
      'id': p['id'],
      'owner_id': userId,
      'name': p['name'],
      'goal': p['goal'],
      'type': p['type'],
      'schedule_json': p['schedule_json'],
      'updated_at': p['last_updated'] ?? DateTime.now().toIso8601String(),
    }).toList();
    await _supabase.from('plans').upsert(batch);
  }

  Future<void> _pullPlans() async {
    final userId = _auth.user!.id;
    final response = await _supabase.from('plans').select().eq('owner_id', userId);
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

  Future<void> _pushLogs() async {
    final localLogs = await _db.getAllLogsRaw();
    if (localLogs.isEmpty) return;
    final userId = _auth.user!.id;
    const int batchSize = 500;
    for (var i = 0; i < localLogs.length; i += batchSize) {
      final end = (i + batchSize < localLogs.length) ? i + batchSize : localLogs.length;
      final chunk = localLogs.sublist(i, end);
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
      }).toList();
      await _supabase.from('logs').upsert(batch);
    }
  }

  Future<void> _pullLogs() async {
    final userId = _auth.user!.id;
    final response = await _supabase.from('logs').select().eq('owner_id', userId).order('timestamp', ascending: false).limit(1000);
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