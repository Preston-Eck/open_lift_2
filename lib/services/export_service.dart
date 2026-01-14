import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'database_service.dart';

class ExportService {
  final DatabaseService _db;

  ExportService(this._db);

  Future<void> exportToCSV() async {
    final logs = await _db.getLogsInDateRange(
      DateTime.now().subtract(const Duration(days: 365 * 10)), // All time approx
      DateTime.now(),
    );

    if (logs.isEmpty) throw "No logs to export.";

    StringBuffer csv = StringBuffer();
    // Header
    csv.writeln("Date,Exercise,Weight,Reps,Volume,RPE,PR,SessionID");

    for (var log in logs) {
      csv.writeln(
        "${log.timestamp},${log.exerciseName},${log.weight},${log.reps},${log.volumeLoad},${log.rpe},${log.isPr},${log.sessionId}",
      );
    }

    await _shareFile(csv.toString(), "openlift_logs.csv", "text/csv");
  }

  Future<void> exportToJSON() async {
    final logs = await _db.getAllLogsRaw();

    if (logs.isEmpty) throw "No logs to export.";

    final jsonString = jsonEncode(logs);
    await _shareFile(jsonString, "openlift_logs.json", "application/json");
  }

  Future<void> _shareFile(String content, String fileName, String mimeType) async {
    if (kIsWeb) {
      // For Web, we use a simple anchor element trick (not ideal in a service but common in Flutter Web)
      // Alternatively, we could use a package, but this is proof of concept.
      // In a real app, we might use 'dart:html' which is not available in cross-platform code easily.
      // For now, on web, we'll just print or throw not supported if we can't easily implement.
      throw "Export not yet supported on Web.";
    } else {
      final directory = await getTemporaryDirectory();
      final file = File('${directory.path}/$fileName');
      await file.writeAsString(content);

      await Share.shareXFiles(
        [XFile(file.path, mimeType: mimeType)],
        subject: 'My OpenLift Workout Logs',
      );
    }
  }
}
