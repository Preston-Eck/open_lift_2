import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'database_service.dart';
import 'package:intl/intl.dart';

class ExportService {
  final DatabaseService _db;

  ExportService(this._db);

  /// Exports all user data to a single JSON file and shares/saves it.
  Future<void> exportAllData() async {
    try {
      final data = await _gatherData();
      final jsonString = const JsonEncoder.withIndent('  ').convert(data);
      
      final timestamp = DateFormat('yyyyMMdd_HHmm').format(DateTime.now());
      final fileName = 'openlift_backup_$timestamp.json';

      final directory = await getApplicationDocumentsDirectory();
      final file = File('${directory.path}/$fileName');
      
      await file.writeAsString(jsonString);

      // On Mobile/Desktop, Share/Save dialog
      if (!kIsWeb) {
        // Share via share_plus
        // Note: On Windows this might open a share dialog or just need a "Save As".
        // share_plus 7.0+ supports XFile
        // ignore: deprecated_member_use
        await Share.shareXFiles([XFile(file.path)], text: 'OpenLift Backup Data');
      }
      
      debugPrint("Export success: ${file.path}");
    } catch (e) {
      debugPrint("Export failed: $e");
      rethrow;
    }
  }

  Future<Map<String, dynamic>> _gatherData() async {
    return {
      'metadata': {
        'version': '1.0',
        'exported_at': DateTime.now().toIso8601String(),
        'app_version': '1.1.0',
      },
      'profile': await _db.getUserProfile(),
      'gym_profiles': await _db.getGymProfiles().then((l) => l.map((e) => e.toMap()).toList()),
      'equipment': await _db.getUserEquipmentList(),
      'plans': await _db.getAllPlansRaw(),
      'logs': await _db.getAllLogsRaw(),
      'custom_exercises': await _db.getCustomExercises().then((l) => l.map((e) => {
        'id': e.id,
        'name': e.name,
        'category': e.category,
        'primary_muscles': e.primaryMuscles,
        'equipment': e.equipment,
        'notes': e.instructions
      }).toList()),
    };
  }
}
