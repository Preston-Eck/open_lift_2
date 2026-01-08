import 'package:flutter/material.dart';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import 'dart:convert';
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
      version: 13,
      onCreate: (db, version) async {
        await _createTables(db);
        await _createProfileTable(db);
      },
      onOpen: (db) async {
        await _cleanupGhostSessions(db);
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 12) {
           try {
            await db.execute('ALTER TABLE user_equipment ADD COLUMN capabilities_json TEXT');
            await db.execute('ALTER TABLE custom_exercises ADD COLUMN equipment_json TEXT');
          } catch (e) {
            debugPrint("v12 Migration Note: $e");
          }
        }
        if (oldVersion < 13) {
          await _createProfileTable(db);
        }
      }
    );
  }

  Future<void> _createTables(Database db) async {
    await db.execute('CREATE TABLE user_equipment (id TEXT PRIMARY KEY, name TEXT, is_owned INTEGER, capabilities_json TEXT)');
    await db.execute('CREATE TABLE workout_logs (id TEXT PRIMARY KEY, exercise_id TEXT, exercise_name TEXT, weight REAL, reps INTEGER, volume_load REAL, duration INTEGER, timestamp TEXT, session_id TEXT, last_updated TEXT)');
    await db.execute('CREATE TABLE workout_plans (id TEXT PRIMARY KEY, name TEXT, goal TEXT, type TEXT, schedule_json TEXT, last_updated TEXT)');
    await db.execute('CREATE TABLE exercise_stats (exercise_name TEXT PRIMARY KEY, one_rep_max REAL, last_updated TEXT)');
    await db.execute('CREATE TABLE body_metrics (id TEXT PRIMARY KEY, date TEXT, weight REAL, measurements_json TEXT)');
    await db.execute('CREATE TABLE one_rep_max_history (id TEXT PRIMARY KEY, exercise_name TEXT, weight REAL, date TEXT)');
    await db.execute('CREATE TABLE custom_exercises (id TEXT PRIMARY KEY, name TEXT, category TEXT, primary_muscles TEXT, notes TEXT, equipment_json TEXT)');
    await db.execute('CREATE TABLE workout_sessions (id TEXT PRIMARY KEY, plan_id TEXT, day_name TEXT, start_time TEXT, end_time TEXT, note TEXT)');
    await db.execute('CREATE TABLE exercise_aliases (original_name TEXT PRIMARY KEY, alias TEXT)');
  }

  Future<void> _createProfileTable(Database db) async {
    try {
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
    } catch (e) {
      debugPrint("Profile Table Creation Error: $e");
    }
  }

  Future<void> _cleanupGhostSessions(Database db) async {
    try {
      await db.execute('''
        DELETE FROM workout_sessions 
        WHERE id NOT IN (SELECT DISTINCT session_id FROM workout_logs WHERE session_id IS NOT NULL)
        AND end_time IS NULL 
        AND start_time < datetime('now', '-1 hour')
      ''');
    } catch (e) {
      debugPrint("Cleanup Error: $e");
    }
  }

  // --- EQUIPMENT ---

  // REPLACED: Handles simple toggles for standard equipment
  Future<void> updateEquipment(String name, bool isOwned) async { 
    final db = await database; 
    final existing = await db.query('user_equipment', where: 'id = ?', whereArgs: [name]);
    
    if (existing.isNotEmpty) {
      await db.update('user_equipment', {'is_owned': isOwned ? 1 : 0}, where: 'id = ?', whereArgs: [name]);
    } else {
      // Default capability is itself (e.g. Barbell has capability [Barbell])
      await db.insert('user_equipment', {
        'id': name, 
        'name': name, 
        'is_owned': isOwned ? 1 : 0,
        'capabilities_json': jsonEncode([name]) 
      });
    }
    notifyListeners(); 
  }

  Future<void> updateEquipmentCapabilities(String name, List<String> capabilities) async {
    final db = await database;
    await db.insert('user_equipment', {
      'id': name,
      'name': name,
      'is_owned': 1,
      'capabilities_json': jsonEncode(capabilities),
    }, conflictAlgorithm: ConflictAlgorithm.replace);
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
        } catch (e) {
          debugPrint("Error parsing capabilities for ${row['name']}: $e");
        }
      }
    }
    return capabilities.toList();
  }

  // UPDATED: Returns everything so the UI can decide what to show
  Future<List<Map<String, dynamic>>> getUserEquipmentList() async {
    final db = await database;
    return await db.query('user_equipment');
  }

  // --- USER PROFILE ---
  Future<void> updateUserProfile(Map<String, dynamic> data) async {
    final db = await database;
    await db.insert(
      'user_profile', 
      {'id': 'local_user', ...data}, 
      conflictAlgorithm: ConflictAlgorithm.replace
    );
    notifyListeners();
  }

  Future<Map<String, dynamic>?> getUserProfile() async {
    final db = await database;
    final res = await db.query('user_profile', limit: 1);
    if (res.isNotEmpty) return res.first;
    return null;
  }

  // --- ALIASES ---
  Future<void> setExerciseAlias(String original, String alias) async {
    final db = await database;
    if (alias.isEmpty || alias == original) {
      await removeAlias(original);
      return;
    }
    await db.insert(
      'exercise_aliases', 
      {'original_name': original, 'alias': alias}, 
      conflictAlgorithm: ConflictAlgorithm.replace
    );
    notifyListeners();
  }

  Future<void> removeAlias(String original) async {
    final db = await database;
    await db.delete('exercise_aliases', where: 'original_name = ?', whereArgs: [original]);
    notifyListeners();
  }

  Future<Map<String, String>> getAliases() async {
    final db = await database;
    final res = await db.query('exercise_aliases');
    final Map<String, String> map = {};
    for (var row in res) {
      map[row['original_name'] as String] = row['alias'] as String;
    }
    return map;
  }

  // --- SESSION MGMT ---
  Future<void> startSession(WorkoutSession session) async {
    final db = await database;
    await db.insert('workout_sessions', session.toMap());
    notifyListeners();
  }

  Future<void> endSession(String sessionId, DateTime endTime) async {
    final db = await database;
    await db.update('workout_sessions', {'end_time': endTime.toIso8601String()}, where: 'id = ?', whereArgs: [sessionId]);
    notifyListeners();
  }

  Future<List<WorkoutSession>> getSessionsForPlanDay(String planId, String dayName) async {
    final db = await database;
    final res = await db.query('workout_sessions', where: 'plan_id = ? AND day_name = ?', whereArgs: [planId, dayName], orderBy: 'start_time DESC');
    return res.map((e) => WorkoutSession.fromMap(e)).toList();
  }

  Future<List<LogEntry>> getLogsForSession(String sessionId) async {
    final db = await database;
    final res = await db.query('workout_logs', where: 'session_id = ?', whereArgs: [sessionId], orderBy: 'timestamp ASC');
    return res.map((e) => LogEntry.fromMap(e)).toList();
  }

  // --- ANALYTICS ---
  Future<List<LogEntry>> getLogsInDateRange(DateTime start, DateTime end) async {
    final db = await database;
    final startStr = start.toIso8601String();
    final endStr = end.toIso8601String();
    final res = await db.query('workout_logs', where: 'timestamp >= ? AND timestamp <= ?', whereArgs: [startStr, endStr]);
    return res.map((e) => LogEntry.fromMap(e)).toList();
  }

  Future<List<Map<String, dynamic>>> getWeeklyVolume() async {
    final db = await database;
    return await db.rawQuery('''
      SELECT date(timestamp, 'weekday 0', '-6 days') as week_start, SUM(volume_load) as total_volume
      FROM workout_logs 
      GROUP BY strftime('%Y-%W', timestamp)
      ORDER BY week_start ASC LIMIT 12
    ''');
  }

  Future<List<Map<String, dynamic>>> getMostFrequentExercises() async {
    final db = await database;
    return await db.rawQuery('''
      SELECT exercise_name, COUNT(*) as count 
      FROM workout_logs 
      GROUP BY exercise_name 
      ORDER BY count DESC LIMIT 5
    ''');
  }

  Future<List<LogEntry>> getHistoryForExercise(String exerciseName) async {
    final db = await database;
    final res = await db.query('workout_logs', where: 'exercise_name = ?', whereArgs: [exerciseName], orderBy: 'timestamp DESC');
    return res.map((e) => LogEntry.fromMap(e)).toList();
  }

  // --- CORE FEATURES ---
  Future<void> logSet(LogEntry entry) async {
    final db = await database;
    final map = entry.toMap();
    map['last_updated'] = DateTime.now().toIso8601String();
    await db.insert('workout_logs', map);
    notifyListeners();
  }

  Future<List<LogEntry>> getHistory() async { final db = await database; final res = await db.query('workout_logs', orderBy: 'timestamp DESC'); return res.map((e) => LogEntry.fromMap(e)).toList(); }
  
  Future<void> savePlan(WorkoutPlan plan) async {
    final db = await database;
    final map = plan.toMap();
    map['last_updated'] = DateTime.now().toIso8601String();
    await db.insert('workout_plans', map, conflictAlgorithm: ConflictAlgorithm.replace);
    notifyListeners();
  }

  Future<List<WorkoutPlan>> getPlans() async { final db = await database; final res = await db.query('workout_plans'); return res.map((e) => WorkoutPlan.fromMap(e)).toList(); }
  Future<void> deletePlan(String id) async { final db = await database; await db.delete('workout_plans', where: 'id = ?', whereArgs: [id]); notifyListeners(); }
  
  // --- BODY METRICS ---
  Future<void> logBodyMetric(BodyMetric metric) async { 
    final db = await database; 
    await db.insert('body_metrics', metric.toMap(), conflictAlgorithm: ConflictAlgorithm.replace); 
    await db.update('user_profile', {'current_weight': metric.weight}, where: 'id = ?', whereArgs: ['local_user']);
    notifyListeners(); 
  }
  Future<List<BodyMetric>> getBodyMetrics() async { final db = await database; final res = await db.query('body_metrics', orderBy: 'date DESC'); return res.map((e) => BodyMetric.fromMap(e)).toList(); }

  // --- 1RM ---
  Future<Map<String, double>> getLatestOneRepMaxes() async { final db = await database; final res = await db.query('one_rep_max_history', orderBy: 'date ASC'); final Map<String, double> latest = {}; for (var row in res) { latest[row['exercise_name'] as String] = row['weight'] as double; } return latest; }
  Future<Map<String, dynamic>?> getLatestOneRepMaxDetailed(String exerciseName) async { final db = await database; final res = await db.query('one_rep_max_history', where: 'exercise_name = ?', whereArgs: [exerciseName], orderBy: 'date DESC', limit: 1); if (res.isNotEmpty) return res.first; return null; }
  Future<List<Map<String, dynamic>>> getOneRepMaxHistory(String exerciseName) async { final db = await database; return await db.query('one_rep_max_history', where: 'exercise_name = ?', whereArgs: [exerciseName], orderBy: 'date DESC'); }
  Future<void> addOneRepMax(String exercise, double weight) async { final db = await database; await db.insert('one_rep_max_history', {'id': DateTime.now().toIso8601String(), 'exercise_name': exercise, 'weight': weight, 'date': DateTime.now().toIso8601String()}, conflictAlgorithm: ConflictAlgorithm.replace); notifyListeners(); }

  // --- CUSTOM EXERCISES ---
  Future<void> addCustomExercise(Exercise ex) async { 
    final db = await database; 
    await db.insert('custom_exercises', {
      'id': ex.id, 
      'name': ex.name, 
      'category': ex.category, 
      'primary_muscles': ex.primaryMuscles.join(','), 
      'notes': ex.instructions.join('\n'),
      'equipment_json': jsonEncode(ex.equipment) 
    }); 
    notifyListeners(); 
  }
  
  Future<List<Exercise>> getCustomExercises() async { 
    final db = await database; 
    final res = await db.query('custom_exercises'); 
    return res.map((e) {
      List<String> equipment = [];
      if (e['equipment_json'] != null) {
        equipment = List<String>.from(jsonDecode(e['equipment_json'] as String));
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

  // --- SEARCH ---
  Future<List<WorkoutPlan>> searchPlans(String query) async { final db = await database; final res = await db.query('workout_plans', where: 'name LIKE ?', whereArgs: ['%$query%']); return res.map((e) => WorkoutPlan.fromMap(e)).toList(); }
  Future<List<LogEntry>> searchHistory(String query) async {
    final db = await database;
    final res = await db.query('workout_logs', where: 'exercise_name LIKE ?', whereArgs: ['%$query%'], orderBy: 'timestamp DESC');
    final allLogs = res.map((e) => LogEntry.fromMap(e)).toList();
    final Map<String, LogEntry> latest = {};
    for (var log in allLogs) { if (!latest.containsKey(log.exerciseName)) latest[log.exerciseName] = log; }
    return latest.values.toList();
  }

  // --- SYNC ---
  Future<List<Map<String, dynamic>>> getAllPlansRaw() async { final db = await database; return await db.query('workout_plans'); }
  Future<List<Map<String, dynamic>>> getAllLogsRaw() async { final db = await database; return await db.query('workout_logs'); }
  Future<void> bulkInsertPlans(List<Map<String, dynamic>> plans) async { final db = await database; final batch = db.batch(); for (var p in plans) { batch.insert('workout_plans', p, conflictAlgorithm: ConflictAlgorithm.replace); } await batch.commit(noResult: true); notifyListeners(); }
  Future<void> bulkInsertLogs(List<Map<String, dynamic>> logs) async { final db = await database; final batch = db.batch(); for (var l in logs) { batch.insert('workout_logs', l, conflictAlgorithm: ConflictAlgorithm.replace); } await batch.commit(noResult: true); notifyListeners(); }
}