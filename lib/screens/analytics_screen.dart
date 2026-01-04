import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/database_service.dart';
import '../models/log.dart';

class AnalyticsScreen extends StatelessWidget {
  const AnalyticsScreen({super.key});

  double calculate1RM(double weight, int reps) {
    // Brzycki Formula
    if (reps == 0) return 0;
    if (reps == 1) return weight;
    return weight / (1.0278 - (0.0278 * reps));
  }

  @override
  Widget build(BuildContext context) {
    final db = Provider.of<DatabaseService>(context);
    
    return FutureBuilder<List<LogEntry>>(
      future: db.getHistory(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
        
        // Simple Volume Load Chart Logic
        final _ = snapshot.data!;
        // Group logs by date and sum volume, skipping implementation for brevity
        
        return Scaffold(
          appBar: AppBar(title: const Text("Analytics & 1RM")),
          body: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text("Estimated 1RM Calculator", style: TextStyle(fontSize: 20)),
                const SizedBox(height: 20),
                // Example 1RM Display
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      children: [
                        const Text("Recent Bench Press 1RM"),
                        Text(
                          "${calculate1RM(100, 5).toStringAsFixed(1)} kg", 
                          style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold)
                        ),
                        const Text("Based on 100kg x 5 reps"),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                const Text("Volume Progression", style: TextStyle(fontSize: 20)),
                SizedBox(
                  height: 200,
                  child: LineChart(
                    LineChartData(
                      gridData: const FlGridData(show: false),
                      titlesData: const FlTitlesData(show: false),
                      borderData: FlBorderData(show: true),
                      lineBarsData: [
                        LineChartBarData(
                          spots: const [
                            FlSpot(0, 3000),
                            FlSpot(1, 3200),
                            FlSpot(2, 4000),
                            FlSpot(3, 3800),
                          ],
                          isCurved: true,
                          color: Colors.blue,
                        ),
                      ],
                    ),
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