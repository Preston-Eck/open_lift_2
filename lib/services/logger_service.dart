import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:intl/intl.dart';

class LoggerService {
  static final LoggerService _instance = LoggerService._internal();
  factory LoggerService() => _instance;
  LoggerService._internal();

  File? _logFile;

  Future<void> init() async {
    final dir = await getApplicationDocumentsDirectory();
    _logFile = File('${dir.path}/openlift_error_log.txt');
    
    // Rolling Buffer Logic:
    // If file > 2MB, trim it down to 1MB (keeping the NEWEST data)
    if (await _logFile!.exists()) {
      final len = await _logFile!.length();
      const maxBytes = 2 * 1024 * 1024; // 2 MB
      const targetBytes = 1 * 1024 * 1024; // 1 MB

      if (len > maxBytes) {
        try {
          final content = await _logFile!.readAsString();
          // Keep the last 1MB of characters (approx)
          final trimmed = content.length > targetBytes 
              ? content.substring(content.length - targetBytes) 
              : content;
          
          await _logFile!.writeAsString(
            "--- LOG TRUNCATED ---\n$trimmed", 
            mode: FileMode.write
          );
        } catch (e) {
          // Fallback: Delete if read fails
          await _logFile!.delete();
        }
      }
    }
  }

  Future<void> log(String message, [dynamic error, StackTrace? stackTrace]) async {
    if (_logFile == null) await init();

    final timestamp = DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now());
    final logEntry = '''
--------------------------------------------------
[$timestamp] $message
Error: $error
Stack: $stackTrace
--------------------------------------------------
''';

    // Print to console for development visibility
    // ignore: avoid_print
    print(logEntry); 

    try {
      await _logFile!.writeAsString(logEntry, mode: FileMode.append);
    } catch (e) {
      // ignore: avoid_print
      print("Failed to write log: $e");
    }
  }

  Future<String> getLogFilePath() async {
    if (_logFile == null) await init();
    return _logFile!.path;
  }
}