import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:shared_preferences/shared_preferences.dart';
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
  bool _isMetric = false;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _expandedExercise = widget.initialExercise;
    _loadData();
  }

  Future<void> _loadData() async {
    final db = context.read<DatabaseService>();
    final prefs = await SharedPreferences.getInstance();
    
    final unitSystem = prefs.getString('units') ?? 'Imperial';
    final data = await db.getLatestOneRepMaxes();

    if (mounted) {
      setState(() {
        _isMetric = unitSystem == 'Metric';
        _latestMaxes = data;
        _isLoading = false;
      });
    }
  }

  void _addEntryDialog() async {
    await showDialog(
      context: context, 
      builder: (context) => const EditOneRepMaxDialog(exerciseName: "New Exercise")
    );
    _loadData();
  }

  double _getDisplayWeight(double lbs) {
    return _isMetric ? lbs * 0.453592 : lbs;
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Scaffold(body: Center(child: CircularProgressIndicator()));

    final exercises = _latestMaxes.keys.toList()..sort();
    final unitLabel = _isMetric ? "kg" : "lbs";

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
              final weightLbs = _latestMaxes[name] ?? 0.0;
              final displayWeight = _getDisplayWeight(weightLbs);

              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                child: ExpansionTile(
                  key: Key(name),
                  initiallyExpanded: name == _expandedExercise,
                  title: Text(name, style: const TextStyle(fontWeight: FontWeight.bold)),
                  trailing: Text(
                    "${displayWeight.toInt()} $unitLabel", 
                    style: const TextStyle(fontSize: 18, color: Colors.blueAccent, fontWeight: FontWeight.bold)
                  ),
                  children: [
                    SizedBox(
                      height: 200,
                      child: _HistoryChart(exerciseName: name, isMetric: _isMetric),
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
  final bool isMetric;
  
  const _HistoryChart({required this.exerciseName, required this.isMetric});

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
        // Sort by date (oldest first for chart)
        history.sort((a, b) => (a['date'] as String).compareTo(b['date'] as String));

        final spots = history.asMap().entries.map((e) {
          double weight = e.value['weight'] as double;
          if (isMetric) weight *= 0.453592;
          return FlSpot(e.key.toDouble(), weight);
        }).toList();

        return Padding(
          padding: const EdgeInsets.all(16.0),
          child: LineChart(
            LineChartData(
              gridData: const FlGridData(show: false),
              titlesData: const FlTitlesData(show: false),
              borderData: FlBorderData(show: true, border: Border.all(color: Colors.black12)),
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