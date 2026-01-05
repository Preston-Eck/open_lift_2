import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import 'package:intl/intl.dart';
import '../models/body_metric.dart';
import '../services/database_service.dart';

class BodyMetricsScreen extends StatefulWidget {
  const BodyMetricsScreen({super.key});

  @override
  State<BodyMetricsScreen> createState() => _BodyMetricsScreenState();
}

class _BodyMetricsScreenState extends State<BodyMetricsScreen> {
  final _weightController = TextEditingController();
  final Map<String, TextEditingController> _measurementsControllers = {
    'Biceps': TextEditingController(),
    'Waist': TextEditingController(),
    'Thighs': TextEditingController(),
    'Chest': TextEditingController(),
  };

  void _saveEntry() {
    final weight = double.tryParse(_weightController.text);
    Map<String, double> measurements = {};
    
    // Fix: Use for-in loop instead of forEach
    for (var entry in _measurementsControllers.entries) {
      if (entry.value.text.isNotEmpty) {
        measurements[entry.key] = double.tryParse(entry.value.text) ?? 0.0;
      }
    }

    if (weight == null && measurements.isEmpty) return;

    final metric = BodyMetric(
      id: const Uuid().v4(),
      date: DateTime.now(),
      weight: weight,
      measurements: measurements,
    );

    context.read<DatabaseService>().logBodyMetric(metric);
    
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Logged!")));
    _weightController.clear();
    for (var ctrl in _measurementsControllers.values) {
      ctrl.clear();
    }
  }

  @override
  Widget build(BuildContext context) {
    final db = Provider.of<DatabaseService>(context);

    return Scaffold(
      appBar: AppBar(title: const Text("Body Metrics")),
      body: FutureBuilder<List<BodyMetric>>(
        future: db.getBodyMetrics(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
          final data = snapshot.data!;

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text("New Entry", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 10),
                        TextField(
                          controller: _weightController,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(labelText: "Weight (lbs)"),
                        ),
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 10,
                          runSpacing: 10,
                          children: _measurementsControllers.keys.map((key) {
                            return SizedBox(
                              width: 150,
                              child: TextField(
                                controller: _measurementsControllers[key],
                                keyboardType: TextInputType.number,
                                decoration: InputDecoration(labelText: "$key (in)", isDense: true),
                              ),
                            );
                          }).toList(),
                        ),
                        const SizedBox(height: 15),
                        ElevatedButton(onPressed: _saveEntry, child: const Text("Log Metrics")),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                if (data.isNotEmpty) ...[
                  const Text("Weight History", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 10),
                  SizedBox(
                    height: 200,
                    child: LineChart(
                      LineChartData(
                        gridData: const FlGridData(show: false),
                        titlesData: const FlTitlesData(show: false),
                        borderData: FlBorderData(show: true),
                        lineBarsData: [
                          LineChartBarData(
                            spots: data
                                .where((e) => e.weight != null)
                                .map((e) => FlSpot(e.date.millisecondsSinceEpoch.toDouble(), e.weight!))
                                .toList(),
                            isCurved: true,
                            color: Colors.green,
                            dotData: const FlDotData(show: true),
                          )
                        ],
                      ),
                    ),
                  ),
                ],

                const SizedBox(height: 20),
                const Text("History Log", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: data.length,
                  itemBuilder: (ctx, i) {
                    final entry = data[i];
                    return ListTile(
                      title: Text(DateFormat.yMMMd().format(entry.date)),
                      subtitle: Text(
                        "Weight: ${entry.weight ?? '-'} lbs\n${entry.measurements.entries.map((e) => '${e.key}: ${e.value}"').join(', ')}"
                      ),
                    );
                  },
                )
              ],
            ),
          );
        },
      ),
    );
  }
}