import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../theme.dart';

class MuscleRadarChart extends StatelessWidget {
  final Map<String, double> data;

  const MuscleRadarChart({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    if (data.isEmpty) return const Center(child: Text("No muscle data."));

    final entries = data.entries.toList();

    return RadarChart(
      RadarChartData(
        radarBorderData: const BorderSide(color: Colors.transparent),
        radarShape: RadarShape.polygon,
        dataSets: [
          RadarDataSet(
            fillColor: AppTheme.renewalTeal.withValues(alpha: 0.3),
            borderColor: AppTheme.renewalTeal,
            entryRadius: 3,
            dataEntries: entries.map((e) => RadarEntry(value: e.value)).toList(),
          ),
        ],
        tickCount: 5,
        ticksTextStyle: const TextStyle(color: Colors.transparent),
        gridBorderData: BorderSide(color: AppTheme.foundationalSlate.withValues(alpha: 0.1), width: 1),
        getTitle: (index, angle) {
          if (index >= entries.length) return const RadarChartTitle(text: '');
          return RadarChartTitle(
            text: entries[index].key,
            angle: angle,
          );
        },
        titlePositionPercentageOffset: 0.15,
        titleTextStyle: const TextStyle(color: AppTheme.foundationalSlate, fontSize: 10, fontWeight: FontWeight.bold),
      ),
    );
  }
}
