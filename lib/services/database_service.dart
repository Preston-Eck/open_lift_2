// lib/services/database_service.dart
import 'package:flutter/material.dart';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import '../models/log.dart';
import '../models/plan.dart'; // Import the Plan model

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
      version: 2, // Bump version
      onCreate: (db, version) async {
        // 1. Equipment
        await db.execute('''
          CREATE TABLE user_equipment (
            id TEXT PRIMARY KEY,
            name TEXT,
            is_owned INTEGER
          )
        ''');

        // 2. Logs
        await db.execute('''
          CREATE TABLE workout_logs (
            id TEXT PRIMARY KEY,
            exercise_id TEXT,
            exercise_name TEXT,
            weight REAL,
            reps INTEGER,
            volume_load REAL,
            timestamp TEXT
          )
        ''');
        
        // 3. Plans (New)
        await db.execute('''
          CREATE TABLE workout_plans (
            id TEXT PRIMARY KEY,
            name TEXT,
            goal TEXT,
            schedule_json TEXT
          )
        ''');
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
           await db.execute('''
            CREATE TABLE workout_plans (
              id TEXT PRIMARY KEY,
              name TEXT,
              goal TEXT,
              schedule_json TEXT
            )
          ''');
        }
      }
    );
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

  // --- Plan Methods (New) ---
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
}