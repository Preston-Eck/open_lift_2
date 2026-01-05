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
      version: 4, // Bumped to version 4
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
      }
    );
  }

  Future<void> _createTables(Database db) async {
    await db.execute('CREATE TABLE user_equipment (id TEXT PRIMARY KEY, name TEXT, is_owned INTEGER)');
    await db.execute('CREATE TABLE workout_logs (id TEXT PRIMARY KEY, exercise_id TEXT, exercise_name TEXT, weight REAL, reps INTEGER, volume_load REAL, timestamp TEXT)');
    await db.execute('CREATE TABLE workout_plans (id TEXT PRIMARY KEY, name TEXT, goal TEXT, schedule_json TEXT)');
    await db.execute('CREATE TABLE exercise_stats (exercise_name TEXT PRIMARY KEY, one_rep_max REAL, last_updated TEXT)');
    await db.execute('CREATE TABLE body_metrics (id TEXT PRIMARY KEY, date TEXT, weight REAL, measurements_json TEXT)');
  }

  // --- Equipment Methods ---
  Future<void> updateEquipment(String name, bool isOwned) async {
    final db = await database;
    await db.insert(
      'user_equipment',
      {'id': name, 'name': name, 'is_owned': isOwned ? 1 : 0},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    notifyListeners();
  }

  Future<List<String>> getOwnedEquipment() async {
    final db = await database;
    final res = await db.query('user_equipment', where: 'is_owned = 1');
    return res.map((e) => e['name'] as String).toList();
  }

  // --- Logging Methods ---
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

  // --- Plan Methods ---
  Future<void> savePlan(WorkoutPlan plan) async {
    final db = await database;
    await db.insert(
      'workout_plans', 
      plan.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace
    );
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

  // --- Stats / 1RM Methods ---
  Future<void> updateOneRepMax(String exercise, double weight) async {
    final db = await database;
    await db.insert(
      'exercise_stats',
      {
        'exercise_name': exercise,
        'one_rep_max': weight,
        'last_updated': DateTime.now().toIso8601String()
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    notifyListeners();
  }

  Future<Map<String, double>> getAllOneRepMaxes() async {
    final db = await database;
    final res = await db.query('exercise_stats');
    return {
      for (var e in res) e['exercise_name'] as String: e['one_rep_max'] as double
    };
  }

  // --- Body Metrics Methods ---
  Future<void> logBodyMetric(BodyMetric metric) async {
    final db = await database;
    await db.insert(
      'body_metrics',
      metric.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    notifyListeners();
  }

  Future<List<BodyMetric>> getBodyMetrics() async {
    final db = await database;
    final res = await db.query('body_metrics', orderBy: 'date DESC');
    return res.map((e) => BodyMetric.fromMap(e)).toList();
  }
}