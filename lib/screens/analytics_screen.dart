import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../services/database_service.dart';
import '../models/log.dart';

class AnalyticsScreen extends StatelessWidget {
  const AnalyticsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final db = Provider.of<DatabaseService>(context);
    
    return FutureBuilder<List<LogEntry>>(
      future: db.getHistory(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
        
        final logs = snapshot.data!;
        if (logs.isEmpty) {
          return const Center(child: Text("No workout data yet. Go lift!"));
        }

        // 1. Process Data: Group by Date -> Sum Volume
        final Map<String, double> volumeByDate = {};
        for (var log in logs) {
          final dateStr = log.timestamp.split('T')[0]; 
          volumeByDate[dateStr] = (volumeByDate[dateStr] ?? 0) + log.volumeLoad;
        }

        // 2. Convert to FlSpots for the Chart
        final sortedDates = volumeByDate.keys.toList()..sort();
        final spots = sortedDates.asMap().entries.map((entry) {
          final dateString = entry.value; 
          final volume = volumeByDate[dateString] ?? 0.0;
          // FIX: Use the volume for Y-axis, not the date string
          return FlSpot(entry.key.toDouble(), volume); 
        }).toList();

        return Scaffold(
          appBar: AppBar(title: const Text("Progress Analytics")),
          body: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text("Volume Progression (lbs)", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                const SizedBox(height: 5),
                const Text("Total weight moved per workout session"),
                const SizedBox(height: 30),
                
                // --- Volume Chart ---
                SizedBox(
                  height: 250,
                  child: LineChart(
                    LineChartData(
                      gridData: const FlGridData(show: true, drawVerticalLine: false),
                      titlesData: FlTitlesData(
                        bottomTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            getTitlesWidget: (value, meta) {
                              int index = value.toInt();
                              if (index >= 0 && index < sortedDates.length) {
                                final date = DateTime.parse(sortedDates[index]);
                                return Padding(
                                  padding: const EdgeInsets.only(top: 8.0),
                                  child: Text(DateFormat('MM/dd').format(date), style: const TextStyle(fontSize: 10)),
                                );
                              }
                              return const SizedBox();
                            },
                          ),
                        ),
                        leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      ),
                      borderData: FlBorderData(show: true, border: Border.all(color: Colors.white10)),
                      lineBarsData: [
                        LineChartBarData(
                          spots: spots,
                          isCurved: true,
                          color: Colors.blueAccent,
                          barWidth: 4,
                          isStrokeCapRound: true,
                          dotData: const FlDotData(show: true),
                          belowBarData: BarAreaData(show: true, color: Colors.blueAccent.withValues(alpha: 0.2)),
                        ),
                      ],
                    ),
                  ),
                ),
                
                const SizedBox(height: 30),
                const Text("Recent Logs", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                Expanded(
                  child: ListView.builder(
                    itemCount: logs.length,
                    itemBuilder: (context, index) {
                      final log = logs[index];
                      final date = DateTime.parse(log.timestamp);
                      return ListTile(
                        dense: true,
                        leading: Text(DateFormat('MM/dd').format(date)),
                        title: Text(log.exerciseName),
                        subtitle: Text("${log.weight} lbs x ${log.reps} reps"),
                        trailing: Text("${log.volumeLoad.toInt()} vol"),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}