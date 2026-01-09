import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:health/health.dart';
import 'package:permission_handler/permission_handler.dart';

class HealthService {
  final Health _health = Health();

  /// Supported data types
  static const List<HealthDataType> _types = [
    HealthDataType.WEIGHT,
    HealthDataType.HEIGHT,
    HealthDataType.STEPS,
    HealthDataType.ACTIVE_ENERGY_BURNED,
  ];

  /// Check if Health Connect / HealthKit is supported
  Future<bool> isSupported() async {
    if (kIsWeb || Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
      return false;
    }
    // health package handles platform checks internally too
    return true;
  }

  /// Request permissions to read/write health data
  Future<bool> requestPermissions() async {
    if (!await isSupported()) return false;

    // Check permissions
    await Permission.activityRecognition.request();
    await Permission.location.request();

    bool requested = false;
    try {
       requested = await _health.requestAuthorization(_types);
    } catch (e) {
      debugPrint("Health Auth Error: $e");
    }
    return requested;
  }

  /// Fetch the latest weight in KG
  Future<double?> fetchLatestWeight() async {
    if (!await isSupported()) return null;

    try {
      final now = DateTime.now();
      final stats = await _health.getHealthDataFromTypes(
        startTime: now.subtract(const Duration(days: 30)), 
        endTime: now, 
        types: [HealthDataType.WEIGHT]
      );
      
      // Filter clean
      final weights = _health.removeDuplicates(stats);
      
      if (weights.isNotEmpty) {
        // Sort by date desc
        weights.sort((a, b) => b.dateFrom.compareTo(a.dateFrom));
        // Value is typically NumericHealthValue
        final val = weights.first.value;
        if (val is NumericHealthValue) {
          // Health package usually returns generic units, verify documentation says KG?
          // Usually standardized to KG/Meters/Count.
          return val.numericValue.toDouble();
        }
      }
    } catch (e) {
      debugPrint("Fetch Weight Error: $e");
    }
    return null;
  }

  /// Write weight to Health Connect/Kit
  Future<bool> writeWeight(double weightKg) async {
    if (!await isSupported()) return false;

    try {
      final now = DateTime.now();
      return await _health.writeHealthData(
        value: weightKg,
        type: HealthDataType.WEIGHT,
        startTime: now,
        endTime: now,
      );
    } catch (e) {
      debugPrint("Write Weight Error: $e");
      return false;
    }
  }
}
