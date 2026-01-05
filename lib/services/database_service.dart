import 'package:flutter/material.dart';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import '../models/log.dart';
import '../models/plan.dart'; 
import '../models/body_metric.dart';

class DatabaseService extends ChangeNotifier {
  Database? _db;

  Future<Database> get database async {
    if (_db != null) return _db!;
    _db = await _initDB();
    return _db!;
  }

  Future<Database> _initDB() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'openfit_user.db');

    return await openDatabase(
      path,
      version: 5, // BUMPED TO 5
      onCreate: (db, version) async {
        await _createTables(db);
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        // Migration logic
        if (oldVersion < 2) {
           await db.execute('CREATE TABLE workout_plans (id TEXT PRIMARY KEY, name TEXT, goal TEXT, schedule_json TEXT)');
        }
        if (oldVersion < 3) {
          // Old table, we will replace its function with the history table below
          await db.execute('CREATE TABLE exercise_stats (exercise_name TEXT PRIMARY KEY, one_rep_max REAL, last_updated TEXT)');
        }
        if (oldVersion < 4) {
          await db.execute('CREATE TABLE body_metrics (id TEXT PRIMARY KEY, date TEXT, weight REAL, measurements_json TEXT)');
        }
        if (oldVersion < 5) {
          // NEW: History Table
          await db.execute('''
            CREATE TABLE one_rep_max_history (
              id TEXT PRIMARY KEY,
              exercise_name TEXT,
              weight REAL,
              date TEXT
            )
          ''');
        }
      }
    );
  }

  Future<void> _createTables(Database db) async {
    await db.execute('CREATE TABLE user_equipment (id TEXT PRIMARY KEY, name TEXT, is_owned INTEGER)');
    await db.execute('CREATE TABLE workout_logs (id TEXT PRIMARY KEY, exercise_id TEXT, exercise_name TEXT, weight REAL, reps INTEGER, volume_load REAL, timestamp TEXT)');
    await db.execute('CREATE TABLE workout_plans (id TEXT PRIMARY KEY, name TEXT, goal TEXT, schedule_json TEXT)');
    // We keep exercise_stats for legacy, but primarily use history now
    await db.execute('CREATE TABLE exercise_stats (exercise_name TEXT PRIMARY KEY, one_rep_max REAL, last_updated TEXT)');
    await db.execute('CREATE TABLE body_metrics (id TEXT PRIMARY KEY, date TEXT, weight REAL, measurements_json TEXT)');
    // NEW
    await db.execute('CREATE TABLE one_rep_max_history (id TEXT PRIMARY KEY, exercise_name TEXT, weight REAL, date TEXT)');
  }

  // --- STRENGTH HISTORY METHODS (NEW) ---

  // Add a new record (Snapshot of strength at this time)
  Future<void> addOneRepMax(String exercise, double weight) async {
    final db = await database;
    await db.insert(
      'one_rep_max_history',
      {
        'id': DateTime.now().toIso8601String(),
        'exercise_name': exercise,
        'weight': weight,
        'date': DateTime.now().toIso8601String()
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    notifyListeners();
  }

  // Get the most recent max for every exercise
  Future<Map<String, double>> getLatestOneRepMaxes() async {
    final db = await database;
    // Order by date ascending so we can iterate and overwrite with the latest
    final res = await db.query('one_rep_max_history', orderBy: 'date ASC');
    
    final Map<String, double> latest = {};
    for (var row in res) {
      latest[row['exercise_name'] as String] = row['weight'] as double;
    }
    return latest;
  }

  // Get full history for a specific exercise (for charting)
  Future<List<Map<String, dynamic>>> getOneRepMaxHistory(String exerciseName) async {
    final db = await database;
    return await db.query(
      'one_rep_max_history',
      where: 'exercise_name = ?',
      whereArgs: [exerciseName],
      orderBy: 'date DESC' // Newest first
    );
  }

  // --- EXISTING METHODS (UNCHANGED) ---
  
  Future<void> updateEquipment(String name, bool isOwned) async {
    final db = await database;
    await db.insert('user_equipment', {'id': name, 'name': name, 'is_owned': isOwned ? 1 : 0}, conflictAlgorithm: ConflictAlgorithm.replace);
    notifyListeners();
  }

  Future<List<String>> getOwnedEquipment() async {
    final db = await database;
    final res = await db.query('user_equipment', where: 'is_owned = 1');
    return res.map((e) => e['name'] as String).toList();
  }

  Future<void> logSet(LogEntry entry) async {
    final db = await database;
    await db.insert('workout_logs', entry.toMap());
    notifyListeners();
  }

  Future<List<LogEntry>> getHistory() async {
    final db = await database;
    final res = await db.query('workout_logs', orderBy: 'timestamp DESC');
    return res.map((e) => LogEntry.fromMap(e)).toList();
  }

  Future<void> savePlan(WorkoutPlan plan) async {
    final db = await database;
    await db.insert('workout_plans', plan.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
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

  // Deprecated simple update, keeping for compatibility but forwarding to new method recommended
  Future<void> updateOneRepMax(String exercise, double weight) async {
    await addOneRepMax(exercise, weight);
  }

  // Deprecated getter
  Future<Map<String, double>> getAllOneRepMaxes() async {
    return getLatestOneRepMaxes();
  }

  Future<void> logBodyMetric(BodyMetric metric) async {
    final db = await database;
    await db.insert('body_metrics', metric.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
    notifyListeners();
  }

  Future<List<BodyMetric>> getBodyMetrics() async {
    final db = await database;
    final res = await db.query('body_metrics', orderBy: 'date DESC');
    return res.map((e) => BodyMetric.fromMap(e)).toList();
  }

  // --- ANALYTICS METHODS ---

  /// Calculates total volume load (Weight * Reps) per week.
  /// Returns a list of maps: {'week_start': '2023-10-23', 'total_volume': 5000.0}
  /// Fitness Logic: Tracks if the user is doing more work over time (Volume Progression).
  Future<List<Map<String, dynamic>>> getWeeklyVolume() async {
    final db = await database;
    
    // SQLite query to group logs by ISO-8601 Week
    // We use substr to get YYYY-MM-DD from timestamp for date calculations
    // strftime('%W') returns week number (00-53)
    return await db.rawQuery('''
      SELECT 
        date(timestamp, 'weekday 0', '-6 days') as week_start,
        SUM(volume_load) as total_volume
      FROM workout_logs 
      GROUP BY strftime('%Y-%W', timestamp)
      ORDER BY week_start ASC
      LIMIT 12 -- Show last 12 weeks for relevance
    ''');
  }

  /// Calculates how many unique days the user worked out per week.
  /// Fitness Logic: Tracks Consistency (Hierarchy #1). Target is typically 2-4x/week.
  Future<List<Map<String, dynamic>>> getWeeklyConsistency() async {
    final db = await database;
    
    return await db.rawQuery('''
      SELECT 
        date(timestamp, 'weekday 0', '-6 days') as week_start,
        COUNT(DISTINCT substr(timestamp, 1, 10)) as days_active
      FROM workout_logs 
      GROUP BY strftime('%Y-%W', timestamp)
      ORDER BY week_start ASC
      LIMIT 12
    ''');
  }

  /// Gets the top 5 exercises by volume to see what the user focuses on.
  Future<List<Map<String, dynamic>>> getMostFrequentExercises() async {
    final db = await database;
    return await db.rawQuery('''
      SELECT exercise_name, COUNT(*) as count 
      FROM workout_logs 
      GROUP BY exercise_name 
      ORDER BY count DESC 
      LIMIT 5
    ''');
  }
}