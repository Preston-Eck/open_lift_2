import 'package:flutter/foundation.dart';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import 'dart:convert';
import 'package:uuid/uuid.dart';
import '../models/log.dart';
import '../models/plan.dart';
import '../models/body_metric.dart';
import '../models/exercise.dart';
import '../models/session.dart';
import '../models/gym_profile.dart';

class DatabaseService extends ChangeNotifier {
  Database? _db;
  String? _currentUserId;
  String? _currentGymId;

  Future<void> setUserId(String? userId) async {
    if (_currentUserId == userId) return;
    _currentUserId = userId;
    if (_db != null) {
      await _db!.close();
      _db = null;
    }
    notifyListeners();
  }

  void setCurrentGym(String gymId) {
    _currentGymId = gymId;
    notifyListeners();
  }

  String? get currentGymId => _currentGymId;

  Future<Database> get database async {
    if (_db != null && _db!.isOpen) return _db!;
    if (_currentUserId == null) {
      _db = await _initDB('guest_user.db');
    } else {
      _db = await _initDB('user_$_currentUserId.db');
    }
    return _db!;
  }

  Future<Database> _initDB(String fileName) async {
    String path;
    if (kIsWeb) {
      path = fileName;
    } else {
      final dbPath = await getDatabasesPath();
      path = join(dbPath, fileName);
    }

        return await openDatabase(
          path,
          version: 18,
          onCreate: (db, version) async {
            await _createTables(db);
            await _createProfileTable(db);
            
            // ✅ NEW: Initialize default gym for fresh installs
            final defaultGymId = const Uuid().v4();
            await db.insert('gym_profiles', {
              'id': defaultGymId,
              'name': 'Main Gym',
              'is_default': 1,
              'created_at': DateTime.now().toIso8601String(),
              'owner_id': _currentUserId ?? 'guest',
              'last_updated': DateTime.now().toIso8601String(),
              'synced': 0,
            });
          },
          onOpen: (db) async {        await _cleanupGhostSessions(db);
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 12) {
          try {
            await db.execute('ALTER TABLE user_equipment ADD COLUMN capabilities_json TEXT');
            await db.execute('ALTER TABLE custom_exercises ADD COLUMN equipment_json TEXT');
          } catch (_) {} 
        }
        if (oldVersion < 13) await _createProfileTable(db);
        if (oldVersion < 14) {
          try {
            await db.execute('ALTER TABLE user_equipment ADD COLUMN last_updated TEXT');
            await db.execute('ALTER TABLE user_equipment ADD COLUMN synced INTEGER DEFAULT 0');
            await db.execute('ALTER TABLE custom_exercises ADD COLUMN last_updated TEXT');
            await db.execute('ALTER TABLE custom_exercises ADD COLUMN synced INTEGER DEFAULT 0');
          } catch (_) {} 
        }
        if (oldVersion < 15) {
          debugPrint("⚡ Migrating to v15: Gym Profiles...");
          await db.execute('CREATE TABLE gym_profiles (id TEXT PRIMARY KEY, name TEXT, is_default INTEGER, created_at TEXT)');
          await db.execute('CREATE TABLE gym_equipment (gym_id TEXT, equipment_id TEXT, PRIMARY KEY (gym_id, equipment_id))');
          
          final defaultGymId = const Uuid().v4();
          await db.insert('gym_profiles', {
            'id': defaultGymId,
            'name': 'Main Gym',
            'is_default': 1,
            'created_at': DateTime.now().toIso8601String()
          });

          final owned = await db.query('user_equipment', where: 'is_owned = 1');
          if (owned.isNotEmpty) {
            final batch = db.batch();
            for (var row in owned) {
              batch.insert('gym_equipment', {
                'gym_id': defaultGymId,
                'equipment_id': row['id']
              });
            }
            await batch.commit(noResult: true);
          }
        }
        if (oldVersion < 16) {
          debugPrint("⚡ Migrating to v16: Shared Gyms...");
          try {
            await db.execute('ALTER TABLE gym_profiles ADD COLUMN owner_id TEXT');
            if (_currentUserId != null) {
              await db.execute("UPDATE gym_profiles SET owner_id = ?", [_currentUserId]);
            }
          } catch (_) {} 

          await db.execute('''
            CREATE TABLE gym_members (
              id TEXT PRIMARY KEY, 
              gym_id TEXT, 
              user_id TEXT, 
              nickname TEXT, 
              can_edit_gear INTEGER DEFAULT 0,
              status TEXT
            )
          ''');
        }
        if (oldVersion < 17) {
           debugPrint("⚡ Migrating to v17: Gym Sync...");
           try {
             await db.execute('ALTER TABLE gym_profiles ADD COLUMN last_updated TEXT');
             await db.execute('ALTER TABLE gym_profiles ADD COLUMN synced INTEGER DEFAULT 0');
             await db.execute("UPDATE gym_profiles SET last_updated = ?, synced = 0", [DateTime.now().toIso8601String()]);
           } catch (_) {} 
        }
        if (oldVersion < 18) {
           debugPrint("⚡ Migrating to v18: Social Invite...");
           try {
             await db.execute('ALTER TABLE gym_members ADD COLUMN invited_by TEXT');
           } catch (_) {} 
        }
      }
    );
  }

  Future<void> _createTables(Database db) async {
    await db.execute('CREATE TABLE user_equipment (id TEXT PRIMARY KEY, name TEXT, is_owned INTEGER, capabilities_json TEXT, last_updated TEXT, synced INTEGER DEFAULT 0)');
    await db.execute('CREATE TABLE workout_logs (id TEXT PRIMARY KEY, exercise_id TEXT, exercise_name TEXT, weight REAL, reps INTEGER, volume_load REAL, duration INTEGER, timestamp TEXT, session_id TEXT, last_updated TEXT)');
    await db.execute('CREATE TABLE workout_plans (id TEXT PRIMARY KEY, name TEXT, goal TEXT, type TEXT, schedule_json TEXT, last_updated TEXT)');
    await db.execute('CREATE TABLE exercise_stats (exercise_name TEXT PRIMARY KEY, one_rep_max REAL, last_updated TEXT)');
    await db.execute('CREATE TABLE body_metrics (id TEXT PRIMARY KEY, date TEXT, weight REAL, measurements_json TEXT)');
    await db.execute('CREATE TABLE one_rep_max_history (id TEXT PRIMARY KEY, exercise_name TEXT, weight REAL, date TEXT)');
    await db.execute('CREATE TABLE custom_exercises (id TEXT PRIMARY KEY, name TEXT, category TEXT, primary_muscles TEXT, notes TEXT, equipment_json TEXT, last_updated TEXT, synced INTEGER DEFAULT 0)');
    await db.execute('CREATE TABLE workout_sessions (id TEXT PRIMARY KEY, plan_id TEXT, day_name TEXT, start_time TEXT, end_time TEXT, note TEXT)');
    await db.execute('CREATE TABLE exercise_aliases (original_name TEXT PRIMARY KEY, alias TEXT)');
    
    await db.execute('CREATE TABLE gym_profiles (id TEXT PRIMARY KEY, name TEXT, is_default INTEGER, created_at TEXT, owner_id TEXT, last_updated TEXT, synced INTEGER DEFAULT 0)');
    await db.execute('CREATE TABLE gym_equipment (gym_id TEXT, equipment_id TEXT, PRIMARY KEY (gym_id, equipment_id))');
    await db.execute('CREATE TABLE gym_members (id TEXT PRIMARY KEY, gym_id TEXT, user_id TEXT, nickname TEXT, can_edit_gear INTEGER DEFAULT 0, status TEXT, invited_by TEXT)');
  }

  Future<void> _createProfileTable(Database db) async {
    await db.execute('CREATE TABLE IF NOT EXISTS user_profile (id TEXT PRIMARY KEY, birth_date TEXT, current_weight REAL, height REAL, gender TEXT, fitness_level TEXT)');
  }

  Future<void> _cleanupGhostSessions(Database db) async {
    try {
      await db.execute("DELETE FROM workout_sessions WHERE id NOT IN (SELECT DISTINCT session_id FROM workout_logs WHERE session_id IS NOT NULL) AND end_time IS NULL AND start_time < datetime('now', '-1 hour')");
    } catch (_) {} 
  }

  // --- GYM PROFILES ---

  Future<List<GymProfile>> getGymProfiles() async {
    final db = await database;
    final owned = await db.query('gym_profiles', where: 'owner_id = ?', whereArgs: [_currentUserId]);
    final memberRows = await db.query('gym_members', where: 'user_id = ?', whereArgs: [_currentUserId]);
    
    List<GymProfile> allGyms = [];
    for (var row in owned) {
      allGyms.add(GymProfile.fromMap(row, currentUserId: _currentUserId));
    }
    for (var mRow in memberRows) {
      final gymId = mRow['gym_id'] as String;
      final gymRes = await db.query('gym_profiles', where: 'id = ?', whereArgs: [gymId]);
      if (gymRes.isNotEmpty) {
        final gymMap = Map<String, dynamic>.from(gymRes.first);
        gymMap['nickname'] = mRow['nickname'];
        gymMap['can_edit_gear'] = mRow['can_edit_gear'];
        allGyms.add(GymProfile.fromMap(gymMap, currentUserId: _currentUserId));
      }
    }
    return allGyms;
  }

  Future<String> createGymProfile(String name) async {
    final db = await database;
    final id = const Uuid().v4();
    await db.insert('gym_profiles', {
      'id': id,
      'name': name,
      'is_default': 0, 
      'created_at': DateTime.now().toIso8601String(),
      'owner_id': _currentUserId, 
      'last_updated': DateTime.now().toIso8601String(),
      'synced': 0,
    });
    notifyListeners();
    return id;
  }

  Future<void> updateGymName(String gymId, String newName) async {
    final db = await database;
    final gym = await db.query('gym_profiles', where: 'id = ?', whereArgs: [gymId]);
    if (gym.isEmpty) return;
    final ownerId = gym.first['owner_id'] as String?;
    if (ownerId == _currentUserId) {
      await db.update('gym_profiles', {
        'name': newName,
        'last_updated': DateTime.now().toIso8601String(),
        'synced': 0
      }, where: 'id = ?', whereArgs: [gymId]);
    } else {
      await db.update('gym_members', {'nickname': newName}, where: 'gym_id = ? AND user_id = ?', whereArgs: [gymId, _currentUserId]);
    }
    notifyListeners();
  }

  Future<void> deleteGymProfile(String id) async {
    final db = await database;
    final gym = await db.query('gym_profiles', where: 'id = ?', whereArgs: [id]);
    if (gym.isEmpty) return;
    final ownerId = gym.first['owner_id'] as String?;
    if (ownerId == _currentUserId) {
      await db.delete('gym_profiles', where: 'id = ?', whereArgs: [id]);
      await db.delete('gym_equipment', where: 'gym_id = ?', whereArgs: [id]);
      await db.delete('gym_members', where: 'gym_id = ?', whereArgs: [id]);
    } else {
      await db.delete('gym_members', where: 'gym_id = ? AND user_id = ?', whereArgs: [id, _currentUserId]);
    }
    notifyListeners();
  }

  // --- EQUIPMENT ---

  Future<List<String>> getActiveEquipment() async {
    final db = await database;
    String? targetGymId = _currentGymId;
    if (targetGymId == null) {
      final defaults = await db.query('gym_profiles', where: 'is_default = 1', limit: 1);
      if (defaults.isNotEmpty) {
        targetGymId = defaults.first['id'] as String;
        _currentGymId = targetGymId;
      } else {
        return [];
      }
    }
    final res = await db.rawQuery('''
      SELECT e.name, e.capabilities_json 
      FROM user_equipment e
      JOIN gym_equipment ge ON e.id = ge.equipment_id
      WHERE ge.gym_id = ?
    ''', [targetGymId]);
    final Set<String> capabilities = {};
    for (var row in res) {
      capabilities.add(row['name'] as String);
      if (row['capabilities_json'] != null) {
        try {
          final List<dynamic> tags = jsonDecode(row['capabilities_json'] as String);
          capabilities.addAll(tags.map((e) => e.toString()));
        } catch (_) {} 
      }
    }
    return capabilities.toList();
  }

  Future<List<String>> getGymItemIds(String gymId) async {
    final db = await database;
    final res = await db.query('gym_equipment', columns: ['equipment_id'], where: 'gym_id = ?', whereArgs: [gymId]);
    return res.map((e) => e['equipment_id'] as String).toList();
  }

  Future<void> toggleGymEquipment(String gymId, String equipmentId, bool isEnabled) async {
    final db = await database;
    if (isEnabled) {
      await db.insert('gym_equipment', {'gym_id': gymId, 'equipment_id': equipmentId}, conflictAlgorithm: ConflictAlgorithm.ignore);
    } else {
      await db.delete('gym_equipment', where: 'gym_id = ? AND equipment_id = ?', whereArgs: [gymId, equipmentId]);
    }
    await db.update('gym_profiles', {
      'last_updated': DateTime.now().toIso8601String(),
      'synced': 0
    }, where: 'id = ?', whereArgs: [gymId]);
    if (isEnabled) await updateEquipment(equipmentId, true);
    notifyListeners();
  }

  Future<void> updateEquipment(String name, bool isOwned) async {
    final db = await database;
    final now = DateTime.now().toIso8601String();
    final existing = await db.query('user_equipment', where: 'id = ?', whereArgs: [name]);
    if (existing.isNotEmpty) {
      await db.update('user_equipment', {'is_owned': isOwned ? 1 : 0, 'last_updated': now, 'synced': 0}, where: 'id = ?', whereArgs: [name]);
    } else {
      await db.insert('user_equipment', {'id': name, 'name': name, 'is_owned': isOwned ? 1 : 0, 'capabilities_json': jsonEncode([name]), 'last_updated': now, 'synced': 0});
    }
    notifyListeners();
  }

  Future<void> updateEquipmentCapabilities(String name, List<String> capabilities) async {
     final db = await database;
     final now = DateTime.now().toIso8601String();
     await db.update('user_equipment', {'capabilities_json': jsonEncode(capabilities), 'last_updated': now, 'synced': 0}, where: 'id = ?', whereArgs: [name]);
     notifyListeners();
  }

  Future<List<String>> getOwnedEquipment() async => getActiveEquipment();
  Future<List<String>> getOwnedItemNames() async {
    final db = await database;
    final res = await db.query('user_equipment', where: 'is_owned = 1');
    return res.map((e) => e['name'] as String).toList();
  }
  Future<List<Map<String, dynamic>>> getUserEquipmentList() async { final db = await database; return await db.query('user_equipment'); }

  // --- SYNC HELPERS ---
  Future<List<Map<String, dynamic>>> getUnsyncedEquipment() async { final db = await database; return await db.query('user_equipment', where: 'synced = 0'); }
  Future<List<Map<String, dynamic>>> getUnsyncedCustomExercises() async { final db = await database; return await db.query('custom_exercises', where: 'synced = 0'); }
  Future<List<Map<String, dynamic>>> getUnsyncedGymProfiles() async { final db = await database; return await db.query('gym_profiles', where: 'synced = 0 AND owner_id = ?', whereArgs: [_currentUserId]); }
  
  Future<void> markEquipmentSynced(List<String> ids) async { final db = await database; final batch = db.batch(); for (var id in ids) { batch.update('user_equipment', {'synced': 1}, where: 'id = ?', whereArgs: [id]); } await batch.commit(noResult: true); }
  Future<void> markCustomExercisesSynced(List<String> ids) async { final db = await database; final batch = db.batch(); for (var id in ids) { batch.update('custom_exercises', {'synced': 1}, where: 'id = ?', whereArgs: [id]); } await batch.commit(noResult: true); }
  Future<void> markGymProfilesSynced(List<String> ids) async { final db = await database; final batch = db.batch(); for (var id in ids) { batch.update('gym_profiles', {'synced': 1}, where: 'id = ?', whereArgs: [id]); } await batch.commit(noResult: true); }

  Future<void> bulkUpsertEquipment(List<Map<String, dynamic>> items) async { final db = await database; final batch = db.batch(); for (var item in items) { final row = Map<String, dynamic>.from(item); row['synced'] = 1; batch.insert('user_equipment', row, conflictAlgorithm: ConflictAlgorithm.replace); } await batch.commit(noResult: true); notifyListeners(); }
  Future<void> bulkUpsertCustomExercises(List<Map<String, dynamic>> items) async { final db = await database; final batch = db.batch(); for (var item in items) { final row = Map<String, dynamic>.from(item); row['synced'] = 1; batch.insert('custom_exercises', row, conflictAlgorithm: ConflictAlgorithm.replace); } await batch.commit(noResult: true); notifyListeners(); }
  Future<void> bulkUpsertGymProfiles(List<Map<String, dynamic>> items) async { final db = await database; final batch = db.batch(); for (var item in items) { final row = Map<String, dynamic>.from(item); row['synced'] = 1; batch.insert('gym_profiles', row, conflictAlgorithm: ConflictAlgorithm.replace); } await batch.commit(noResult: true); notifyListeners(); }
  Future<void> replaceGymEquipment(String gymId, List<String> equipmentIds) async {
    final db = await database;
    await db.delete('gym_equipment', where: 'gym_id = ?', whereArgs: [gymId]);
    final batch = db.batch();
    for (var eid in equipmentIds) {
      batch.insert('gym_equipment', {'gym_id': gymId, 'equipment_id': eid});
    }
    await batch.commit(noResult: true);
    notifyListeners();
  }


  // ---OTHER CRUD ---
  Future<void> addCustomExercise(Exercise ex) async {
    final db = await database;
    final now = DateTime.now().toIso8601String();
    await db.insert('custom_exercises', {
      'id': ex.id, 'name': ex.name, 'category': ex.category, 'primary_muscles': ex.primaryMuscles.join(','),
      'notes': ex.instructions.join('\n'), 'equipment_json': jsonEncode(ex.equipment), 'last_updated': now, 'synced': 0
    }, conflictAlgorithm: ConflictAlgorithm.replace);
    notifyListeners();
  }
  Future<List<Exercise>> getCustomExercises() async {
    final db = await database;
    final res = await db.query('custom_exercises');
    return res.map((e) {
      List<String> eq = [];
      if (e['equipment_json'] != null) { try { eq = List<String>.from(jsonDecode(e['equipment_json'] as String)); } catch (_) {} } 
      return Exercise(id: e['id'] as String, name: e['name'] as String, category: e['category'] as String?, primaryMuscles: (e['primary_muscles'] as String).split(','), secondaryMuscles: [], equipment: eq, instructions: [(e['notes'] as String?) ?? ''], images: []);
    }).toList();
  }

  Future<Exercise?> findCustomExerciseByName(String name) async {
    final db = await database;
    final res = await db.query(
      'custom_exercises',
      where: 'name LIKE ?',
      whereArgs: [name],
      limit: 1,
    );
    if (res.isEmpty) return null;
    
    final e = res.first;
    List<String> eq = [];
    if (e['equipment_json'] != null) {
      try { eq = List<String>.from(jsonDecode(e['equipment_json'] as String)); } catch (_) {} 
    }
    return Exercise(
      id: e['id'] as String,
      name: e['name'] as String,
      category: e['category'] as String?,
      primaryMuscles: (e['primary_muscles'] as String).split(','),
      secondaryMuscles: [],
      equipment: eq,
      instructions: [(e['notes'] as String?) ?? ''],
      images: [],
    );
  }

  Future<List<Map<String, dynamic>>> getAllCustomExercisesRaw() async { final db = await database; return await db.query('custom_exercises'); }
  
  // Plans
  Future<void> savePlan(WorkoutPlan plan) async {
    final db = await database;
    final now = DateTime.now().toIso8601String();
    await db.insert('workout_plans', {'id': plan.id, 'name': plan.name, 'goal': plan.goal, 'type': plan.type, 'schedule_json': jsonEncode(plan.days.map((d) => d.toMap()).toList()), 'last_updated': now}, conflictAlgorithm: ConflictAlgorithm.replace);
    notifyListeners();
  }
  Future<List<WorkoutPlan>> getPlans() async { final db = await database; final res = await db.query('workout_plans'); return res.map((e) => WorkoutPlan.fromMap(e)).toList(); }
  Future<void> deletePlan(String id) async { final db = await database; await db.delete('workout_plans', where: 'id = ?', whereArgs: [id]); notifyListeners(); }
  Future<List<WorkoutPlan>> searchPlans(String q) async { final db = await database; final res = await db.query('workout_plans', where: 'name LIKE ?', whereArgs: ['%$q%']); return res.map((e) => WorkoutPlan.fromMap(e)).toList(); }
  Future<List<Map<String, dynamic>>> getAllPlansRaw() async { final db = await database; return await db.query('workout_plans'); }
  Future<void> bulkInsertPlans(List<Map<String, dynamic>> p) async { final db = await database; final batch = db.batch(); for (var x in p) { batch.insert('workout_plans', x, conflictAlgorithm: ConflictAlgorithm.replace); } await batch.commit(noResult: true); notifyListeners(); }

  // Logs
  Future<void> startSession(WorkoutSession s) async { final db = await database; await db.insert('workout_sessions', {'id': s.id, 'plan_id': s.planId, 'day_name': s.dayName, 'start_time': s.startTime.toIso8601String()}); notifyListeners(); }
  Future<void> endSession(String id, DateTime end) async { final db = await database; await db.update('workout_sessions', {'end_time': end.toIso8601String()}, where: 'id = ?', whereArgs: [id]); notifyListeners(); }
  Future<void> logSet(LogEntry log) async {
    final db = await database;
    final now = DateTime.now().toIso8601String();
    await db.insert('workout_logs', {'id': log.id, 'session_id': log.sessionId, 'exercise_id': log.exerciseId, 'exercise_name': log.exerciseName, 'weight': log.weight, 'reps': log.reps, 'volume_load': log.volumeLoad, 'duration': log.duration, 'timestamp': log.timestamp, 'last_updated': now}, conflictAlgorithm: ConflictAlgorithm.replace);
    final max = log.weight * (1 + (log.reps / 30));
    await _checkAndUpdateOneRepMax(log.exerciseName, max);
    notifyListeners();
  }
  Future<List<WorkoutSession>> getSessionsForPlanDay(String p, String d) async { final db = await database; final res = await db.query('workout_sessions', where: 'plan_id = ? AND day_name = ?', whereArgs: [p, d], orderBy: 'start_time DESC'); return res.map((e) => WorkoutSession(id: e['id'] as String, planId: e['plan_id'] as String, dayName: e['day_name'] as String, startTime: DateTime.parse(e['start_time'] as String), endTime: e['end_time'] != null ? DateTime.parse(e['end_time'] as String) : null)).toList(); }
  Future<List<LogEntry>> getLogsForSession(String s) async { final db = await database; final res = await db.query('workout_logs', where: 'session_id = ?', whereArgs: [s]); return res.map((e) => LogEntry.fromMap(e)).toList(); }
  Future<LogEntry?> getLastLogForExercise(String n) async { final db = await database; final res = await db.query('workout_logs', where: 'exercise_name = ?', whereArgs: [n], orderBy: 'timestamp DESC', limit: 1); return res.isEmpty ? null : LogEntry.fromMap(res.first); }
  Future<List<LogEntry>> getHistory() async { final db = await database; final res = await db.query('workout_logs', orderBy: 'timestamp DESC', limit: 50); return res.map((e) => LogEntry.fromMap(e)).toList(); }
  Future<List<LogEntry>> getHistoryForExercise(String n) async { final db = await database; final res = await db.query('workout_logs', where: 'exercise_name = ?', whereArgs: [n], orderBy: 'timestamp DESC'); return res.map((e) => LogEntry.fromMap(e)).toList(); }
  Future<List<LogEntry>> searchHistory(String q) async { final db = await database; final res = await db.query('workout_logs', where: 'exercise_name LIKE ?', whereArgs: ['%$q%'], orderBy: 'timestamp DESC'); Set<String> seen = {}; List<LogEntry> uniq = []; for (var row in res) { var log = LogEntry.fromMap(row); if (!seen.contains(log.exerciseName)) { seen.add(log.exerciseName); uniq.add(log); }} return uniq; }
  Future<List<LogEntry>> getLogsInDateRange(DateTime s, DateTime e) async { final db = await database; final res = await db.query('workout_logs', where: 'timestamp BETWEEN ? AND ?', whereArgs: [s.toIso8601String(), e.toIso8601String()]); return res.map((e) => LogEntry.fromMap(e)).toList(); }
  Future<List<Map<String, dynamic>>> getWeeklyVolume() async { final db = await database; return await db.rawQuery("SELECT strftime('%W', timestamp) as week, SUM(volume_load) as total_volume FROM workout_logs GROUP BY week ORDER BY week ASC LIMIT 12"); }
  Future<List<Map<String, dynamic>>> getMostFrequentExercises() async { final db = await database; return await db.rawQuery("SELECT exercise_name, COUNT(*) as count FROM workout_logs GROUP BY exercise_name ORDER BY count DESC LIMIT 20"); }
  Future<List<Map<String, dynamic>>> getAllLogsRaw() async { final db = await database; return await db.query('workout_logs'); }
  Future<void> bulkInsertLogs(List<Map<String, dynamic>> l) async { final db = await database; final batch = db.batch(); for (var x in l) { batch.insert('workout_logs', x, conflictAlgorithm: ConflictAlgorithm.replace); } await batch.commit(noResult: true); notifyListeners(); }

  // Stats
  Future<void> _checkAndUpdateOneRepMax(String n, double w) async { final cur = await getLatestOneRepMaxDetailed(n); if (cur == null || w > (cur['weight'] as double)) await addOneRepMax(n, w); }
  Future<void> addOneRepMax(String n, double w) async { final db = await database; final now = DateTime.now().toIso8601String(); await db.insert('exercise_stats', {'exercise_name': n, 'one_rep_max': w, 'last_updated': now}, conflictAlgorithm: ConflictAlgorithm.replace); await db.insert('one_rep_max_history', {'id': const Uuid().v4(), 'exercise_name': n, 'weight': w, 'date': now}); notifyListeners(); }
  Future<Map<String, double>> getLatestOneRepMaxes() async { final db = await database; final res = await db.query('exercise_stats'); Map<String, double> m = {}; for (var r in res) { m[r['exercise_name'] as String] = r['one_rep_max'] as double; } return m; }
  Future<Map<String, dynamic>?> getLatestOneRepMaxDetailed(String n) async { final db = await database; final res = await db.query('one_rep_max_history', where: 'exercise_name = ?', whereArgs: [n], orderBy: 'date DESC', limit: 1); return res.isNotEmpty ? {'weight': res.first['weight'], 'date': res.first['date']} : null; }
  Future<List<Map<String, dynamic>>> getOneRepMaxHistory(String n) async { final db = await database; return await db.query('one_rep_max_history', where: 'exercise_name = ?', whereArgs: [n]); }
  
  // Body Metrics
  Future<void> logBodyMetric(BodyMetric m) async { final db = await database; await db.insert('body_metrics', {'id': m.id, 'date': m.date.toIso8601String(), 'weight': m.weight, 'measurements_json': jsonEncode(m.measurements)}, conflictAlgorithm: ConflictAlgorithm.replace); notifyListeners(); }
  Future<List<BodyMetric>> getBodyMetrics() async { final db = await database; final res = await db.query('body_metrics', orderBy: 'date DESC'); return res.map((e) { Map<String, double> meas = {}; if (e['measurements_json'] != null) { try { (jsonDecode(e['measurements_json'] as String) as Map).forEach((k, v) => meas[k] = (v as num).toDouble()); } catch (_) {} } return BodyMetric(id: e['id'] as String, date: DateTime.parse(e['date'] as String), weight: e['weight'] as double?, measurements: meas); }).toList(); }
  
  // Profile
  Future<void>updateUserProfile(Map<String, dynamic> d) async { final db = await database; final ex = await getUserProfile(); if (ex == null) { d['id'] = 'user_profile'; await db.insert('user_profile', d); } else { await db.update('user_profile', d, where: 'id = ?', whereArgs: ['user_profile']); } notifyListeners(); }
  Future<Map<String, dynamic>?> getUserProfile() async { final db = await database; final res = await db.query('user_profile', limit: 1); return res.isNotEmpty ? res.first : null; } 
  
  // Aliases
  Future<Map<String, String>> getAliases() async { final db = await database; final res = await db.query('exercise_aliases'); Map<String, String> m = {}; for (var r in res) { m[r['original_name'] as String] = r['alias'] as String; } return m; }
  Future<void> setExerciseAlias(String o, String a) async { final db = await database; await db.insert('exercise_aliases', {'original_name': o, 'alias': a}, conflictAlgorithm: ConflictAlgorithm.replace); notifyListeners(); }
  Future<void> removeAlias(String o) async { final db = await database; await db.delete('exercise_aliases', where: 'original_name = ?', whereArgs: [o]); notifyListeners(); }
}
