import 'package:flutter/material.dart';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import 'dart:convert';
import 'package:uuid/uuid.dart';
import '../models/log.dart';
import '../models/plan.dart';
import '../models/body_metric.dart';
import '../models/exercise.dart';
import '../models/session.dart';

class DatabaseService extends ChangeNotifier {
  Database? _db;
  String? _currentUserId;

  Future<void> setUserId(String? userId) async {
    if (_currentUserId == userId) return;
    _currentUserId = userId;
    if (_db != null) {
      await _db!.close();
      _db = null;
    }
    notifyListeners();
  }

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
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, fileName);

    return await openDatabase(
      path,
      version: 14, // Schema v14
      onCreate: (db, version) async {
        await _createTables(db);
        await _createProfileTable(db);
      },
      onOpen: (db) async {
        await _cleanupGhostSessions(db);
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        // v12 Migration
        if (oldVersion < 12) {
          try {
            await db.execute('ALTER TABLE user_equipment ADD COLUMN capabilities_json TEXT');
            await db.execute('ALTER TABLE custom_exercises ADD COLUMN equipment_json TEXT');
          } catch (e) { debugPrint("v12 Error: $e"); }
        }
        // v13 Migration
        if (oldVersion < 13) {
          await _createProfileTable(db);
        }
        // v14 Migration (Sync Support)
        if (oldVersion < 14) {
          debugPrint("⚡ Migrating to v14: Adding Sync Columns...");
          try {
            await db.execute('ALTER TABLE user_equipment ADD COLUMN last_updated TEXT');
            await db.execute('ALTER TABLE user_equipment ADD COLUMN synced INTEGER DEFAULT 0');
          } catch (e) { debugPrint("Migration v14 (Equipment): $e"); }
          
          try {
            await db.execute('ALTER TABLE custom_exercises ADD COLUMN last_updated TEXT');
            await db.execute('ALTER TABLE custom_exercises ADD COLUMN synced INTEGER DEFAULT 0');
          } catch (e) { debugPrint("Migration v14 (Custom Ex): $e"); }
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
  }

  Future<void> _createProfileTable(Database db) async {
    await db.execute('''
        CREATE TABLE IF NOT EXISTS user_profile (
          id TEXT PRIMARY KEY, 
          birth_date TEXT, 
          current_weight REAL, 
          height REAL, 
          gender TEXT, 
          fitness_level TEXT
        )
      ''');
  }

  Future<void> _cleanupGhostSessions(Database db) async {
    try {
      // Clean up sessions older than 1 hour that have no logs and no end time
      await db.execute('''
        DELETE FROM workout_sessions 
        WHERE id NOT IN (SELECT DISTINCT session_id FROM workout_logs WHERE session_id IS NOT NULL)
        AND end_time IS NULL 
        AND start_time < datetime('now', '-1 hour')
      ''');
    } catch (e) { /* Silent catch */ }
  }

  // ============================================================================
  //                              USER PROFILE
  // ============================================================================

  Future<Map<String, dynamic>?> getUserProfile() async {
    final db = await database;
    final res = await db.query('user_profile', limit: 1);
    return res.isNotEmpty ? res.first : null;
  }

  Future<void> updateUserProfile(Map<String, dynamic> data) async {
    final db = await database;
    final existing = await getUserProfile();
    if (existing == null) {
      data['id'] = 'user_profile';
      await db.insert('user_profile', data);
    } else {
      await db.update('user_profile', data, where: 'id = ?', whereArgs: ['user_profile']);
    }
    notifyListeners();
  }

  // ============================================================================
  //                              EQUIPMENT
  // ============================================================================

  Future<void> updateEquipment(String name, bool isOwned) async {
    final db = await database;
    final now = DateTime.now().toIso8601String();
    
    final existing = await db.query('user_equipment', where: 'id = ?', whereArgs: [name]);

    if (existing.isNotEmpty) {
      await db.update(
        'user_equipment',
        { 'is_owned': isOwned ? 1 : 0, 'last_updated': now, 'synced': 0 },
        where: 'id = ?', whereArgs: [name]
      );
    } else {
      await db.insert('user_equipment', {
        'id': name,
        'name': name,
        'is_owned': isOwned ? 1 : 0,
        'capabilities_json': jsonEncode([name]),
        'last_updated': now,
        'synced': 0
      });
    }
    notifyListeners();
  }

  Future<void> updateEquipmentCapabilities(String name, List<String> capabilities) async {
    final db = await database;
    final now = DateTime.now().toIso8601String();
    await db.update(
      'user_equipment',
      { 'capabilities_json': jsonEncode(capabilities), 'last_updated': now, 'synced': 0 },
      where: 'id = ?', whereArgs: [name]
    );
    notifyListeners();
  }

  Future<List<String>> getOwnedEquipment() async {
    final db = await database;
    final res = await db.query('user_equipment', where: 'is_owned = 1');
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

  Future<List<String>> getOwnedItemNames() async {
    final db = await database;
    final res = await db.query('user_equipment', where: 'is_owned = 1');
    return res.map((e) => e['name'] as String).toList();
  }

  Future<List<Map<String, dynamic>>> getUserEquipmentList() async {
    final db = await database;
    return await db.query('user_equipment');
  }

  // ============================================================================
  //                            CUSTOM EXERCISES
  // ============================================================================

  Future<void> addCustomExercise(Exercise ex) async {
    final db = await database;
    final now = DateTime.now().toIso8601String();
    
    await db.insert('custom_exercises', {
      'id': ex.id,
      'name': ex.name,
      'category': ex.category,
      'primary_muscles': ex.primaryMuscles.join(','),
      'notes': ex.instructions.join('\n'),
      'equipment_json': jsonEncode(ex.equipment),
      'last_updated': now,
      'synced': 0 
    }, conflictAlgorithm: ConflictAlgorithm.replace);
    notifyListeners();
  }

  Future<List<Exercise>> getCustomExercises() async {
    final db = await database;
    final res = await db.query('custom_exercises');
    return res.map((e) {
      List<String> equipment = [];
      if (e['equipment_json'] != null) {
        try { equipment = List<String>.from(jsonDecode(e['equipment_json'] as String)); } catch (_) {}
      }
      return Exercise(
          id: e['id'] as String,
          name: e['name'] as String,
          category: e['category'] as String?,
          primaryMuscles: (e['primary_muscles'] as String).split(','),
          secondaryMuscles: [],
          equipment: equipment,
          instructions: [(e['notes'] as String?) ?? ''],
          images: []
      );
    }).toList();
  }

  // ============================================================================
  //                                PLANS
  // ============================================================================

  Future<void> savePlan(WorkoutPlan plan) async {
    final db = await database;
    final now = DateTime.now().toIso8601String();
    await db.insert('workout_plans', {
      'id': plan.id,
      'name': plan.name,
      'goal': plan.goal,
      'type': plan.type,
      'schedule_json': jsonEncode(plan.days.map((d) => d.toMap()).toList()),
      'last_updated': now
    }, conflictAlgorithm: ConflictAlgorithm.replace);
    notifyListeners();
  }

  Future<List<WorkoutPlan>> getPlans() async {
    final db = await database;
    final res = await db.query('workout_plans');
    return res.map((e) => WorkoutPlan.fromMap(e)).toList();
  }

  Future<void> deletePlan(String id) async {
    final db = await database;
    await db.delete('workout_plans', where: 'id = ?', whereArgs: [id]);
    notifyListeners();
  }

  Future<List<WorkoutPlan>> searchPlans(String query) async {
    final db = await database;
    final res = await db.query('workout_plans', where: 'name LIKE ?', whereArgs: ['%$query%']);
    return res.map((e) => WorkoutPlan.fromMap(e)).toList();
  }

  Future<List<Map<String, dynamic>>> getAllPlansRaw() async { 
    final db = await database; 
    return await db.query('workout_plans'); 
  }
  
  Future<void> bulkInsertPlans(List<Map<String, dynamic>> plans) async { 
    final db = await database; 
    final batch = db.batch(); 
    for (var p in plans) { 
      batch.insert('workout_plans', p, conflictAlgorithm: ConflictAlgorithm.replace); 
    } 
    await batch.commit(noResult: true); 
    notifyListeners(); 
  }

  // ============================================================================
  //                            SESSIONS & LOGS
  // ============================================================================

  Future<void> startSession(WorkoutSession session) async {
    final db = await database;
    await db.insert('workout_sessions', {
      'id': session.id,
      'plan_id': session.planId,
      'day_name': session.dayName,
      'start_time': session.startTime.toIso8601String(),
    });
    notifyListeners();
  }

  Future<void> endSession(String sessionId, DateTime endTime) async {
    final db = await database;
    await db.update('workout_sessions', 
      {'end_time': endTime.toIso8601String()},
      where: 'id = ?', whereArgs: [sessionId]
    );
    notifyListeners();
  }

  Future<void> logSet(LogEntry log) async {
    final db = await database;
    final now = DateTime.now().toIso8601String();
    await db.insert('workout_logs', {
      'id': log.id,
      'session_id': log.sessionId,
      'exercise_id': log.exerciseId,
      'exercise_name': log.exerciseName,
      'weight': log.weight,
      'reps': log.reps,
      'volume_load': log.volumeLoad,
      'duration': log.duration,
      'timestamp': log.timestamp,
      'last_updated': now
    }, conflictAlgorithm: ConflictAlgorithm.replace);
    
    // Auto-update 1RM estimation (Epley formula)
    final oneRepMax = log.weight * (1 + (log.reps / 30));
    await _checkAndUpdateOneRepMax(log.exerciseName, oneRepMax);
    
    notifyListeners();
  }

  Future<List<WorkoutSession>> getSessionsForPlanDay(String planId, String dayName) async {
    final db = await database;
    final res = await db.query('workout_sessions', 
      where: 'plan_id = ? AND day_name = ?', 
      whereArgs: [planId, dayName],
      orderBy: 'start_time DESC'
    );
    return res.map((e) => WorkoutSession(
      id: e['id'] as String,
      planId: e['plan_id'] as String,
      dayName: e['day_name'] as String,
      startTime: DateTime.parse(e['start_time'] as String),
      endTime: e['end_time'] != null ? DateTime.parse(e['end_time'] as String) : null,
      note: e['note'] as String?
    )).toList();
  }

  Future<List<LogEntry>> getLogsForSession(String sessionId) async {
    final db = await database;
    final res = await db.query('workout_logs', where: 'session_id = ?', whereArgs: [sessionId]);
    return res.map((e) => LogEntry.fromMap(e)).toList();
  }

  Future<LogEntry?> getLastLogForExercise(String exerciseName) async {
    final db = await database;
    final res = await db.query('workout_logs',
      where: 'exercise_name = ?',
      whereArgs: [exerciseName],
      orderBy: 'timestamp DESC',
      limit: 1
    );
    if (res.isEmpty) return null;
    return LogEntry.fromMap(res.first);
  }

  Future<List<LogEntry>> getHistory() async {
    final db = await database;
    final res = await db.query('workout_logs', orderBy: 'timestamp DESC', limit: 50);
    return res.map((e) => LogEntry.fromMap(e)).toList();
  }

  Future<List<LogEntry>> getHistoryForExercise(String name) async {
    final db = await database;
    final res = await db.query('workout_logs', where: 'exercise_name = ?', whereArgs: [name], orderBy: 'timestamp DESC');
    return res.map((e) => LogEntry.fromMap(e)).toList();
  }

  Future<List<LogEntry>> getLogsInDateRange(DateTime start, DateTime end) async {
    final db = await database;
    final res = await db.query('workout_logs',
      where: 'timestamp BETWEEN ? AND ?',
      whereArgs: [start.toIso8601String(), end.toIso8601String()]
    );
    return res.map((e) => LogEntry.fromMap(e)).toList();
  }

  Future<List<LogEntry>> searchHistory(String query) async {
    final db = await database;
    final res = await db.query('workout_logs', where: 'exercise_name LIKE ?', whereArgs: ['%$query%'], orderBy: 'timestamp DESC');
    
    // Unique by exercise name, most recent first
    final Set<String> seen = {};
    final List<LogEntry> uniqueResults = [];
    for (var row in res) {
      final log = LogEntry.fromMap(row);
      if (!seen.contains(log.exerciseName)) {
        seen.add(log.exerciseName);
        uniqueResults.add(log);
      }
    }
    return uniqueResults;
  }

  // --- ANALYTICS ---

  Future<List<Map<String, dynamic>>> getWeeklyVolume() async {
    final db = await database;
    // SQLite doesn't have easy week grouping, so we fetch all and aggregate in Dart for MVP
    final res = await db.rawQuery('''
      SELECT strftime('%W', timestamp) as week, SUM(volume_load) as total_volume
      FROM workout_logs
      GROUP BY week
      ORDER BY week ASC
      LIMIT 12
    ''');
    return res;
  }

  Future<List<Map<String, dynamic>>> getMostFrequentExercises() async {
    final db = await database;
    return await db.rawQuery('''
      SELECT exercise_name, COUNT(*) as count 
      FROM workout_logs 
      GROUP BY exercise_name 
      ORDER BY count DESC 
      LIMIT 20
    ''');
  }

  // ============================================================================
  //                              1RM & STATS
  // ============================================================================

  Future<void> _checkAndUpdateOneRepMax(String exerciseName, double potentialMax) async {
    // FIXED: Removed unused 'db' and 'now' variables here.
    // Logic delegated to helper methods which handle their own DB connections.
    
    final current = await getLatestOneRepMaxDetailed(exerciseName);
    if (current == null || potentialMax > (current['weight'] as double)) {
      await addOneRepMax(exerciseName, potentialMax);
    }
  }

  Future<void> addOneRepMax(String exerciseName, double weight) async {
    final db = await database;
    final now = DateTime.now().toIso8601String();
    
    // Update current Stats
    await db.insert('exercise_stats', {
      'exercise_name': exerciseName,
      'one_rep_max': weight,
      'last_updated': now
    }, conflictAlgorithm: ConflictAlgorithm.replace);

    // Add to history
    await db.insert('one_rep_max_history', {
      'id': const Uuid().v4(),
      'exercise_name': exerciseName,
      'weight': weight,
      'date': now
    });
    notifyListeners();
  }

  Future<Map<String, double>> getLatestOneRepMaxes() async {
    final db = await database;
    final res = await db.query('exercise_stats');
    final Map<String, double> map = {};
    for (var r in res) {
      map[r['exercise_name'] as String] = r['one_rep_max'] as double;
    }
    return map;
  }

  Future<Map<String, dynamic>?> getLatestOneRepMaxDetailed(String exerciseName) async {
    final db = await database;
    final res = await db.query('one_rep_max_history', 
      where: 'exercise_name = ?', 
      whereArgs: [exerciseName],
      orderBy: 'date DESC',
      limit: 1
    );
    if (res.isNotEmpty) {
      return {'weight': res.first['weight'], 'date': res.first['date']};
    }
    return null;
  }

  Future<List<Map<String, dynamic>>> getOneRepMaxHistory(String exerciseName) async {
    final db = await database;
    return await db.query('one_rep_max_history', where: 'exercise_name = ?', whereArgs: [exerciseName]);
  }

  // ============================================================================
  //                            BODY METRICS
  // ============================================================================

  Future<void> logBodyMetric(BodyMetric metric) async {
    final db = await database;
    await db.insert('body_metrics', {
      'id': metric.id,
      'date': metric.date.toIso8601String(),
      'weight': metric.weight,
      'measurements_json': jsonEncode(metric.measurements),
    }, conflictAlgorithm: ConflictAlgorithm.replace);
    notifyListeners();
  }

  Future<List<BodyMetric>> getBodyMetrics() async {
    final db = await database;
    final res = await db.query('body_metrics', orderBy: 'date DESC');
    return res.map((e) {
      Map<String, double> measurements = {};
      if (e['measurements_json'] != null) {
        try {
          final decoded = jsonDecode(e['measurements_json'] as String) as Map<String, dynamic>;
          decoded.forEach((k, v) => measurements[k] = (v as num).toDouble());
        } catch (_) {}
      }
      return BodyMetric(
        id: e['id'] as String,
        date: DateTime.parse(e['date'] as String),
        weight: e['weight'] as double?,
        measurements: measurements
      );
    }).toList();
  }

  // ============================================================================
  //                            ALIASES
  // ============================================================================

  Future<Map<String, String>> getAliases() async {
    final db = await database;
    final res = await db.query('exercise_aliases');
    final Map<String, String> aliases = {};
    for (var row in res) {
      aliases[row['original_name'] as String] = row['alias'] as String;
    }
    return aliases;
  }

  Future<void> setExerciseAlias(String original, String alias) async {
    final db = await database;
    await db.insert('exercise_aliases', {
      'original_name': original,
      'alias': alias
    }, conflictAlgorithm: ConflictAlgorithm.replace);
    notifyListeners();
  }

  Future<void> removeAlias(String original) async {
    final db = await database;
    await db.delete('exercise_aliases', where: 'original_name = ?', whereArgs: [original]);
    notifyListeners();
  }

  // ============================================================================
  //                            SYNC HELPERS
  // ============================================================================

  Future<List<Map<String, dynamic>>> getUnsyncedEquipment() async {
    final db = await database;
    return await db.query('user_equipment', where: 'synced = 0');
  }

  Future<List<Map<String, dynamic>>> getUnsyncedCustomExercises() async {
    final db = await database;
    return await db.query('custom_exercises', where: 'synced = 0');
  }

  Future<void> markEquipmentSynced(List<String> ids) async {
    final db = await database;
    final batch = db.batch();
    for (var id in ids) {
      batch.update('user_equipment', {'synced': 1}, where: 'id = ?', whereArgs: [id]);
    }
    await batch.commit(noResult: true);
  }

  Future<void> markCustomExercisesSynced(List<String> ids) async {
    final db = await database;
    final batch = db.batch();
    for (var id in ids) {
      batch.update('custom_exercises', {'synced': 1}, where: 'id = ?', whereArgs: [id]);
    }
    await batch.commit(noResult: true);
  }

  Future<void> bulkUpsertEquipment(List<Map<String, dynamic>> items) async {
    final db = await database;
    final batch = db.batch();
    for (var item in items) {
      final row = Map<String, dynamic>.from(item);
      row['synced'] = 1; 
      batch.insert('user_equipment', row, conflictAlgorithm: ConflictAlgorithm.replace);
    }
    await batch.commit(noResult: true);
    notifyListeners();
  }

  Future<void> bulkUpsertCustomExercises(List<Map<String, dynamic>> items) async {
    final db = await database;
    final batch = db.batch();
    for (var item in items) {
      final row = Map<String, dynamic>.from(item);
      row['synced'] = 1;
      batch.insert('custom_exercises', row, conflictAlgorithm: ConflictAlgorithm.replace);
    }
    await batch.commit(noResult: true);
    notifyListeners();
  }

  Future<List<Map<String, dynamic>>> getAllLogsRaw() async { 
    final db = await database; 
    return await db.query('workout_logs'); 
  }

  Future<void> bulkInsertLogs(List<Map<String, dynamic>> logs) async { 
    final db = await database; 
    final batch = db.batch(); 
    for (var l in logs) { 
      batch.insert('workout_logs', l, conflictAlgorithm: ConflictAlgorithm.replace); 
    } 
    await batch.commit(noResult: true); 
    notifyListeners(); 
  }
}