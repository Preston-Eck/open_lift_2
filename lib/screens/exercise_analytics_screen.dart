import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../services/database_service.dart';

class ExerciseAnalyticsScreen extends StatefulWidget {
  const ExerciseAnalyticsScreen({super.key});

  @override
  State<ExerciseAnalyticsScreen> createState() => _ExerciseAnalyticsScreenState();
}

class _ExerciseAnalyticsScreenState extends State<ExerciseAnalyticsScreen> {
  String? _selectedExercise;
  List<Map<String, dynamic>> _chartData = [];

  @override
  void initState() {
    super.initState();
    // Use addPostFrameCallback to safely access context after init
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadInitialData();
    });
  }

  Future<void> _loadInitialData() async {
    if (!mounted) return;
    final db = Provider.of<DatabaseService>(context, listen: false);
    final exercises = await db.getMostFrequentExercises();
    
    if (mounted && exercises.isNotEmpty) {
      _selectExercise(exercises.first['exercise_name']);
    }
  }

  Future<void> _selectExercise(String exerciseName) async {
    if (!mounted) return;
    final db = Provider.of<DatabaseService>(context, listen: false);
    final history = await db.getHistory();
    
    final data = history
        .where((log) => log.exerciseName == exerciseName)
        .map((log) => {
              'weight': log.weight,
              'reps': log.reps,
              'date': DateTime.parse(log.timestamp),
            })
        .toList();

    if (mounted) {
      setState(() {
        _selectedExercise = exerciseName;
        _chartData = data;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Exercise Performance")),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: ElevatedButton.icon(
              icon: const Icon(Icons.search),
              label: Text(_selectedExercise ?? "Select Exercise"),
              onPressed: () => _showExercisePicker(context),
            ),
          ),
          if (_chartData.isNotEmpty) ...[
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: ScatterChart(
                  ScatterChartData(
                    scatterSpots: _chartData.map((d) {
                      return ScatterSpot(
                        d['weight'], 
                        (d['reps'] as int).toDouble(),
                        radius: 8,
                      );
                    }).toList(),
                    titlesData: const FlTitlesData(
                      bottomTitles: AxisTitles(
                        axisNameWidget: Text("Weight (lbs)"),
                        sideTitles: SideTitles(showTitles: true, reservedSize: 30),
                      ),
                      leftTitles: AxisTitles(
                        axisNameWidget: Text("Reps"),
                        sideTitles: SideTitles(showTitles: true, reservedSize: 30),
                      ),
                      topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    ),
                    borderData: FlBorderData(
                      show: true, 
                      border: Border.all(color: Colors.grey.withValues(alpha: 0.2))
                    ),
                    gridData: const FlGridData(show: true),
                    // Removed manual touchData configuration to prevent version conflicts
                  ),
                ),
              ),
            ),
             const Padding(
              padding: EdgeInsets.only(bottom: 20.0),
              child: Text("X: Weight  |  Y: Reps", style: TextStyle(color: Colors.grey)),
            ),
          ] else 
            const Expanded(child: Center(child: Text("No data found for this exercise"))),
        ],
      ),
    );
  }

  void _showExercisePicker(BuildContext context) async {
    final db = Provider.of<DatabaseService>(context, listen: false);
    final exercises = await db.getMostFrequentExercises();
    
    if (!mounted) return;

    showModalBottomSheet(
      context: context,
      builder: (_) => ListView.builder(
        itemCount: exercises.length,
        itemBuilder: (_, i) => ListTile(
          title: Text(exercises[i]['exercise_name']),
          onTap: () {
            Navigator.pop(context);
            _selectExercise(exercises[i]['exercise_name']);
          },
        ),
      ),
    );
  }
}