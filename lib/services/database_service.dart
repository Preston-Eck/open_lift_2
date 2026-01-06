import 'package:flutter/material.dart';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import '../models/log.dart';
import '../models/plan.dart'; 
import '../models/body_metric.dart';
import '../models/exercise.dart'; 

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
      version: 6, 
      onCreate: (db, version) async {
        await _createTables(db);
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
           await db.execute('CREATE TABLE workout_plans (id TEXT PRIMARY KEY, name TEXT, goal TEXT, schedule_json TEXT)');
        }
        if (oldVersion < 3) {
          await db.execute('CREATE TABLE exercise_stats (exercise_name TEXT PRIMARY KEY, one_rep_max REAL, last_updated TEXT)');
        }
        if (oldVersion < 4) {
          await db.execute('CREATE TABLE body_metrics (id TEXT PRIMARY KEY, date TEXT, weight REAL, measurements_json TEXT)');
        }
        if (oldVersion < 5) {
          await db.execute('''
            CREATE TABLE one_rep_max_history (
              id TEXT PRIMARY KEY,
              exercise_name TEXT,
              weight REAL,
              date TEXT
            )
          ''');
        }
        if (oldVersion < 6) {
          await db.execute('''
            CREATE TABLE custom_exercises (
              id TEXT PRIMARY KEY, 
              name TEXT, 
              category TEXT, 
              primary_muscles TEXT, 
              notes TEXT
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
    await db.execute('CREATE TABLE exercise_stats (exercise_name TEXT PRIMARY KEY, one_rep_max REAL, last_updated TEXT)');
    await db.execute('CREATE TABLE body_metrics (id TEXT PRIMARY KEY, date TEXT, weight REAL, measurements_json TEXT)');
    await db.execute('CREATE TABLE one_rep_max_history (id TEXT PRIMARY KEY, exercise_name TEXT, weight REAL, date TEXT)');
    await db.execute('CREATE TABLE custom_exercises (id TEXT PRIMARY KEY, name TEXT, category TEXT, primary_muscles TEXT, notes TEXT)');
  }

  // --- ANALYTICS METHODS ---
  Future<List<Map<String, dynamic>>> getWeeklyVolume() async {
    final db = await database;
    return await db.rawQuery('''
      SELECT 
        date(timestamp, 'weekday 0', '-6 days') as week_start,
        SUM(volume_load) as total_volume
      FROM workout_logs 
      GROUP BY strftime('%Y-%W', timestamp)
      ORDER BY week_start ASC
      LIMIT 12
    ''');
  }

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

  // NEW METHOD FOR SCATTER PLOT
  Future<List<LogEntry>> getHistoryForExercise(String exerciseName) async {
    final db = await database;
    final res = await db.query(
      'workout_logs',
      where: 'exercise_name = ?',
      whereArgs: [exerciseName],
      orderBy: 'timestamp DESC'
    );
    return res.map((e) => LogEntry.fromMap(e)).toList();
  }

  // --- CUSTOM EXERCISES ---
  Future<void> addCustomExercise(Exercise ex) async {
    final db = await database;
    await db.insert('custom_exercises', {
      'id': ex.id,
      'name': ex.name,
      'category': ex.category,
      'primary_muscles': ex.primaryMuscles.join(','),
      'notes': ex.instructions.join('\n'),
    });
    notifyListeners();
  }

  Future<List<Exercise>> getCustomExercises() async {
    final db = await database;
    final res = await db.query('custom_exercises');
    return res.map((e) => Exercise(
      id: e['id'] as String,
      name: e['name'] as String,
      category: e['category'] as String?,
      primaryMuscles: (e['primary_muscles'] as String).split(','),
      secondaryMuscles: [],
      equipment: [],
      instructions: [(e['notes'] as String?) ?? ''],
      images: [],
    )).toList();
  }

  // --- STRENGTH HISTORY ---
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

  Future<Map<String, double>> getLatestOneRepMaxes() async {
    final db = await database;
    final res = await db.query('one_rep_max_history', orderBy: 'date ASC');
    final Map<String, double> latest = {};
    for (var row in res) {
      latest[row['exercise_name'] as String] = row['weight'] as double;
    }
    return latest;
  }

  Future<List<Map<String, dynamic>>> getOneRepMaxHistory(String exerciseName) async {
    final db = await database;
    return await db.query(
      'one_rep_max_history',
      where: 'exercise_name = ?',
      whereArgs: [exerciseName],
      orderBy: 'date DESC'
    );
  }

  // --- EXISTING METHODS ---
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

  Future<void> updateOneRepMax(String exercise, double weight) async {
    await addOneRepMax(exercise, weight);
  }

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

  // --- ANALYTICS EXPANSION ---
  
  // Fetch all logs within a date range to calculate heatmap data
  Future<List<LogEntry>> getLogsInDateRange(DateTime start, DateTime end) async {
    final db = await database;
    final startStr = start.toIso8601String();
    final endStr = end.toIso8601String();
    
    final res = await db.query(
      'workout_logs',
      where: 'timestamp >= ? AND timestamp <= ?',
      whereArgs: [startStr, endStr],
    );
    
    return res.map((e) => LogEntry.fromMap(e)).toList();
  }

  // Get total volume for the last X days for the Volume Chart
  Future<Map<String, double>> getVolumePerDay(int days) async {
    final db = await database;
    final start = DateTime.now().subtract(Duration(days: days));
    final startStr = start.toIso8601String();

    final res = await db.rawQuery('''
      SELECT substr(timestamp, 1, 10) as date, SUM(volume_load) as total_vol
      FROM workout_logs
      WHERE timestamp >= ?
      GROUP BY substr(timestamp, 1, 10)
      ORDER BY date ASC
    ''', [startStr]);

    final Map<String, double> data = {};
    for (var row in res) {
      data[row['date'] as String] = (row['total_vol'] as num).toDouble();
    }
    return data;
  }
}