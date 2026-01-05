import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../services/database_service.dart';

class AnalyticsScreen extends StatefulWidget {
  const AnalyticsScreen({super.key});

  @override
  State<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends State<AnalyticsScreen> {
  // We use a future to fetch all data at once
  late Future<Map<String, dynamic>> _analyticsFuture;

  @override
  void initState() {
    super.initState();
    _analyticsFuture = _loadAnalytics();
  }

  Future<Map<String, dynamic>> _loadAnalytics() async {
    final db = Provider.of<DatabaseService>(context, listen: false);
    return {
      'volume': await db.getWeeklyVolume(),
      'consistency': await db.getWeeklyConsistency(),
      'exercises': await db.getMostFrequentExercises(),
    };
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Progress Monitor")),
      body: FutureBuilder<Map<String, dynamic>>(
        future: _analyticsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.hasError) {
            return const Center(child: Text("No data available yet. Go lift!"));
          }

          final volumeData = snapshot.data!['volume'] as List<Map<String, dynamic>>;
          final consistencyData = snapshot.data!['consistency'] as List<Map<String, dynamic>>;

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildSectionHeader("Volume Load", "Total lbs moved per week"),
                const SizedBox(height: 20),
                _buildVolumeChart(volumeData),
                const SizedBox(height: 40),
                
                _buildSectionHeader("Consistency", "Workouts per week (Target: 3+)"),
                const SizedBox(height: 20),
                _buildConsistencyChart(consistencyData),
                
                const SizedBox(height: 40),
                _buildExerciseList(snapshot.data!['exercises']),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildSectionHeader(String title, String subtitle) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
        Text(subtitle, style: TextStyle(color: Colors.grey[600], fontSize: 14)),
      ],
    );
  }

  Widget _buildVolumeChart(List<Map<String, dynamic>> data) {
    if (data.isEmpty) return const SizedBox(height: 200, child: Center(child: Text("No volume data.")));

    List<FlSpot> spots = [];
    List<String> dates = [];

    for (int i = 0; i < data.length; i++) {
      spots.add(FlSpot(i.toDouble(), (data[i]['total_volume'] as num).toDouble()));
      dates.add(data[i]['week_start'] as String);
    }

    return SizedBox(
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
                  if (index >= 0 && index < dates.length) {
                    // Show every other label to avoid clutter
                    if (index % 2 == 0) {
                      final date = DateTime.parse(dates[index]);
                      return Padding(
                        padding: const EdgeInsets.only(top: 8.0),
                        child: Text(DateFormat('MM/dd').format(date), style: const TextStyle(fontSize: 10)),
                      );
                    }
                  }
                  return const SizedBox();
                },
                interval: 1,
              ),
            ),
            leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          ),
          borderData: FlBorderData(show: false),
          lineBarsData: [
            LineChartBarData(
              spots: spots,
              isCurved: true,
              color: Colors.blueAccent,
              barWidth: 3,
              isStrokeCapRound: true,
              dotData: const FlDotData(show: true),
              belowBarData: BarAreaData(
                show: true, 
                color: Colors.blueAccent.withValues(alpha: 0.15)
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildConsistencyChart(List<Map<String, dynamic>> data) {
    if (data.isEmpty) return const SizedBox(height: 200, child: Center(child: Text("No consistency data.")));

    return SizedBox(
      height: 200,
      child: BarChart(
        BarChartData(
          gridData: const FlGridData(show: false),
          titlesData: FlTitlesData(
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (value, meta) {
                  int index = value.toInt();
                   if (index >= 0 && index < data.length) {
                    final date = DateTime.parse(data[index]['week_start']);
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
          borderData: FlBorderData(show: false),
          barGroups: data.asMap().entries.map((entry) {
            final count = (entry.value['days_active'] as num).toDouble();
            return BarChartGroupData(
              x: entry.key,
              barRods: [
                BarChartRodData(
                  toY: count,
                  color: count >= 3 ? Colors.green : Colors.orange, // Fitness Logic: Green if meeting target
                  width: 16,
                  borderRadius: BorderRadius.circular(4),
                ),
              ],
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildExerciseList(List<Map<String, dynamic>> exercises) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text("Most Frequent Exercises", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 10),
        if (exercises.isEmpty) const Text("No exercises logged yet."),
        ...exercises.map((e) => Card(
          child: ListTile(
            leading: const Icon(Icons.fitness_center),
            title: Text(e['exercise_name']),
            trailing: Text("${e['count']} sessions"),
          ),
        )),
      ],
    );
  }
}