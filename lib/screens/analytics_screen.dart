import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import '../services/database_service.dart';
import '../services/analytics_service.dart';
import '../theme.dart';
import '../models/exercise.dart';
import '../widgets/muscle_heatmap.dart';

class AnalyticsScreen extends StatefulWidget {
  const AnalyticsScreen({super.key});

  @override
  State<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends State<AnalyticsScreen> {
  // State
  bool _isLoading = true;
  Map<String, double> _heatmapData = {};
  List<Map<String, dynamic>> _weeklyVolume = [];
  
  late AnalyticsService _analyticsService;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final dbService = Provider.of<DatabaseService>(context, listen: false);
    _analyticsService = AnalyticsService(dbService);

    // 1. Fetch Volume
    final vol = await dbService.getWeeklyVolume();
    
    // 2. Fetch Heatmap
    // We need to fetch all exercises first to map Names -> Muscles
    // For this prototype, we'll fetch customs. 
    // Ideally, this list should merge 'standard' exercises too.
    List<Exercise> allExercises = await dbService.getCustomExercises(); 
    // NOTE: In production, merge this with your JSON assets list!
    
    final heatMap = await _analyticsService.generateMuscleHeatmapData(allExercises);

    if (mounted) {
      setState(() {
        _weeklyVolume = vol;
        _heatmapData = heatMap;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(title: const Text("Training Analytics")),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. Volume Chart
            Text("Weekly Volume (lbs)", style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 16),
            Container(
              height: 200,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppTheme.foundationalSlate.withValues(alpha: 0.1)),
              ),
              child: _buildVolumeChart(),
            ),

            const SizedBox(height: 32),

            // 2. Muscle Heatmap
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text("Muscle Heatmap", style: Theme.of(context).textTheme.titleLarge),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppTheme.clarityCream,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppTheme.foundationalSlate.withValues(alpha: 0.1)),
                  ),
                  child: Row(
                    children: [
                      const Text("Less ", style: TextStyle(fontSize: 10)),
                      Icon(Icons.circle, size: 8, color: AppTheme.foundationalSlate.withValues(alpha: 0.1)),
                      const SizedBox(width: 4),
                      const Icon(Icons.circle, size: 8, color: AppTheme.motivationCoral),
                      const Text(" More", style: TextStyle(fontSize: 10)),
                    ],
                  ),
                )
              ],
            ),
            const SizedBox(height: 8),
            const Text("Based on exercise frequency over the last 90 days."),
            const SizedBox(height: 16),
            
            // The Heatmap Widget
            MuscleHeatmap(muscleIntensities: _heatmapData),
          ],
        ),
      ),
    );
  }

  Widget _buildVolumeChart() {
    if (_weeklyVolume.isEmpty) {
      return const Center(child: Text("No volume data yet. Go lift heavy!"));
    }

    return BarChart(
      BarChartData(
        alignment: BarChartAlignment.spaceAround,
        maxY: _weeklyVolume.map((e) => e['total_volume'] as double).reduce((a, b) => a > b ? a : b) * 1.2,
        barTouchData: BarTouchData(enabled: false),
        titlesData: FlTitlesData(
          show: true,
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (value, meta) {
                // Simplified Date logic for prototype
                return Text("W${value.toInt()}", style: const TextStyle(fontSize: 10));
              },
            ),
          ),
          leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        gridData: const FlGridData(show: false),
        borderData: FlBorderData(show: false),
        barGroups: _weeklyVolume.asMap().entries.map((e) {
          return BarChartGroupData(
            x: e.key,
            barRods: [
              BarChartRodData(
                toY: e.value['total_volume'] as double,
                color: AppTheme.renewalTeal,
                width: 16,
                borderRadius: BorderRadius.circular(4),
              )
            ],
          );
        }).toList(),
      ),
    );
  }
}