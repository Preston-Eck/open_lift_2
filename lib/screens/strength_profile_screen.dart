import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import '../services/database_service.dart';

class StrengthProfileScreen extends StatefulWidget {
  const StrengthProfileScreen({super.key});

  @override
  State<StrengthProfileScreen> createState() => _StrengthProfileScreenState();
}

class _StrengthProfileScreenState extends State<StrengthProfileScreen> {
  Map<String, double> _latestMaxes = {};

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final db = context.read<DatabaseService>();
    final data = await db.getLatestOneRepMaxes();
    if (mounted) setState(() => _latestMaxes = data);
  }

  void _addEntryDialog() {
    final nameCtrl = TextEditingController();
    final weightCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Log New 1RM"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameCtrl,
              decoration: const InputDecoration(labelText: "Exercise Name", hintText: "e.g. Bench Press"),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: weightCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: "Weight (lbs)"),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancel")),
          ElevatedButton(
            onPressed: () async {
              final w = double.tryParse(weightCtrl.text);
              if (nameCtrl.text.isNotEmpty && w != null) {
                await context.read<DatabaseService>().addOneRepMax(nameCtrl.text, w);
                
                // FIXED: Check mounted before using context across async gaps
                if (ctx.mounted) {
                  Navigator.pop(ctx);
                  _loadData(); // Refresh list
                }
              }
            },
            child: const Text("Save"),
          )
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Sort exercises alphabetically
    final exercises = _latestMaxes.keys.toList()..sort();

    return Scaffold(
      appBar: AppBar(title: const Text("Strength Profile")),
      floatingActionButton: FloatingActionButton(
        onPressed: _addEntryDialog,
        backgroundColor: Colors.blueAccent,
        child: const Icon(Icons.add),
      ),
      body: exercises.isEmpty 
        ? Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.fitness_center, size: 64, color: Colors.grey),
                const SizedBox(height: 16),
                const Text("No strength data yet.", style: TextStyle(fontSize: 18, color: Colors.grey)),
                TextButton(onPressed: _addEntryDialog, child: const Text("Add your first 1RM")),
              ],
            ),
          )
        : ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: exercises.length,
            itemBuilder: (context, index) {
              final name = exercises[index];
              final weight = _latestMaxes[name];
              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                child: ExpansionTile(
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
        // Prepare chart spots. History is usually sorted DESC by date, so reverse for Left->Right chart
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