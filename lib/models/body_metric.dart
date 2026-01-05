class BodyMetric {
  final String id;
  final DateTime date;
  final double? weight;
  // Store measurements as a Map to be flexible (e.g. {'biceps': 14.5, 'waist': 32.0})
  final Map<String, double> measurements;

  BodyMetric({
    required this.id,
    required this.date,
    this.weight,
    required this.measurements,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'date': date.toIso8601String(),
      'weight': weight,
      'measurements_json': measurements.toString(), // Simple storage
    };
  }

  factory BodyMetric.fromMap(Map<String, dynamic> map) {
    Map<String, double> parsedMeasurements = {};
    if (map['measurements_json'] != null) {
      // Basic parsing of stringified map like "{biceps: 12.0}"
      String raw = map['measurements_json'];
      if (raw.length > 2) {
        raw = raw.substring(1, raw.length - 1); // remove {}
        if (raw.isNotEmpty) {
          final parts = raw.split(', ');
          for (var part in parts) {
            var kv = part.split(': ');
            if (kv.length == 2) {
              parsedMeasurements[kv[0]] = double.tryParse(kv[1]) ?? 0.0;
            }
          }
        }
      }
    }

    return BodyMetric(
      id: map['id'],
      date: DateTime.parse(map['date']),
      weight: map['weight'],
      measurements: parsedMeasurements,
    );
  }
}