import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import '../services/database_service.dart';
import '../widgets/one_rep_max_dialog.dart';

class StrengthProfileScreen extends StatefulWidget {
  final String? initialExercise; 
  const StrengthProfileScreen({super.key, this.initialExercise});

  @override
  State<StrengthProfileScreen> createState() => _StrengthProfileScreenState();
}

class _StrengthProfileScreenState extends State<StrengthProfileScreen> {
  Map<String, double> _latestMaxes = {};
  String? _expandedExercise;

  @override
  void initState() {
    super.initState();
    _expandedExercise = widget.initialExercise;
    _loadData();
  }

  Future<void> _loadData() async {
    final db = context.read<DatabaseService>();
    final data = await db.getLatestOneRepMaxes();
    if (mounted) setState(() => _latestMaxes = data);
  }

  void _addEntryDialog() async {
    await showDialog(
      context: context, 
      builder: (context) => const EditOneRepMaxDialog(exerciseName: "New Exercise")
    );
    _loadData();
  }

  @override
  Widget build(BuildContext context) {
    final exercises = _latestMaxes.keys.toList()..sort();

    return Scaffold(
      appBar: AppBar(title: const Text("Strength Profile")),
      floatingActionButton: FloatingActionButton(
        onPressed: _addEntryDialog, 
        backgroundColor: Colors.blueAccent,
        child: const Icon(Icons.add),
      ),
      body: exercises.isEmpty 
        ? const Center(child: Text("No strength data."))
        : ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: exercises.length,
            itemBuilder: (context, index) {
              final name = exercises[index];
              final weight = _latestMaxes[name];
              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                child: ExpansionTile(
                  key: Key(name),
                  initiallyExpanded: name == _expandedExercise,
                  title: Text(name, style: const TextStyle(fontWeight: FontWeight.bold)),
                  trailing: Text(
                    "${weight?.toInt()} lbs", 
                    style: const TextStyle(fontSize: 18, color: Colors.blueAccent, fontWeight: FontWeight.bold)
                  ),
                  children: [
                    SizedBox(
                      height: 200,
                      child: _HistoryChart(exerciseName: name),
                    ),
                  ],
                ),
              );
            },
          ),
    );
  }
}

class _HistoryChart extends StatelessWidget {
  final String exerciseName;
  const _HistoryChart({required this.exerciseName});

  @override
  Widget build(BuildContext context) {
    final db = Provider.of<DatabaseService>(context, listen: false);
    
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: db.getOneRepMaxHistory(exerciseName),
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return const Center(child: Text("Loading chart..."));
        }
        
        final history = snapshot.data!;
        final sortedHistory = history.reversed.toList();
        final spots = sortedHistory.asMap().entries.map((e) {
          return FlSpot(e.key.toDouble(), e.value['weight'] as double);
        }).toList();

        return Padding(
          padding: const EdgeInsets.all(16.0),
          child: LineChart(
            LineChartData(
              gridData: const FlGridData(show: false),
              titlesData: const FlTitlesData(show: false),
              borderData: FlBorderData(show: true, border: Border.all(color: Colors.white10)),
              lineBarsData: [
                LineChartBarData(
                  spots: spots,
                  isCurved: true,
                  color: Colors.blueAccent,
                  barWidth: 3,
                  dotData: const FlDotData(show: true),
                  belowBarData: BarAreaData(show: true, color: Colors.blueAccent.withValues(alpha: 0.1)),
                )
              ],
            ),
          ),
        );
      },
    );
  }
}