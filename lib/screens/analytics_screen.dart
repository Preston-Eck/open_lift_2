import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import '../services/database_service.dart';
import '../services/analytics_service.dart';
import '../theme.dart';
import '../models/exercise.dart';
import '../widgets/muscle_heatmap.dart';
import 'weekly_review_screen.dart'; // NEW

class AnalyticsScreen extends StatefulWidget {
  const AnalyticsScreen({super.key});

  @override
  State<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends State<AnalyticsScreen> {
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
    if (!mounted) return;
    
    final dbService = Provider.of<DatabaseService>(context, listen: false);
    _analyticsService = AnalyticsService(dbService);

    // 1. Fetch Weekly Volume
    final vol = await dbService.getWeeklyVolume();

    // 2. Fetch Heatmap Data
    List<Exercise> allExercises = await dbService.getCustomExercises();
    
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
    return Scaffold(
      appBar: AppBar(title: const Text("Training Analytics")),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const WeeklyReviewScreen())),
        label: const Text("Weekly Review"),
        icon: const Icon(Icons.insights),
        backgroundColor: AppTheme.motivationCoral,
        foregroundColor: Colors.white,
      ),
      body: _isLoading 
          ? const Center(child: CircularProgressIndicator()) 
          : _buildContent(),
    );
  }

  Widget _buildContent() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Volume Section
          Text("Volume Trend", style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
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

          // 2. Heatmap Section
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text("Muscle Heatmap", style: Theme.of(context).textTheme.titleLarge),
              _buildLegend(),
            ],
          ),
          const SizedBox(height: 8),
          const Text("Visualizes which muscles you've trained most over the last 90 days."),
          const SizedBox(height: 24),
          
          MuscleHeatmap(muscleIntensities: _heatmapData),
          
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildLegend() {
    return Container(
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
          const Icon(Icons.arrow_forward, size: 10, color: Colors.grey),
          const SizedBox(width: 4),
          const Icon(Icons.circle, size: 8, color: AppTheme.motivationCoral),
          const Text(" More", style: TextStyle(fontSize: 10)),
        ],
      ),
    );
  }

  Widget _buildVolumeChart() {
    if (_weeklyVolume.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.bar_chart, size: 48, color: Colors.grey[300]),
            const SizedBox(height: 8),
            const Text("No workouts logged yet.", style: TextStyle(color: Colors.grey)),
          ],
        ),
      );
    }

    return BarChart(
      BarChartData(
        alignment: BarChartAlignment.spaceAround,
        barTouchData: BarTouchData(
          // FIXED: Moved tooltipBgColor inside BarTouchTooltipData
          touchTooltipData: BarTouchTooltipData(
            tooltipBgColor: AppTheme.foundationalSlate,
            getTooltipItem: (group, groupIndex, rod, rodIndex) {
              return BarTooltipItem(
                '${rod.toY.toInt()} lbs',
                const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              );
            },
          ),
        ),
        titlesData: FlTitlesData(
          show: true,
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (value, meta) {
                return Padding(
                  padding: const EdgeInsets.only(top: 8.0),
                  child: Text(
                    "W${value.toInt() + 1}", 
                    style: const TextStyle(fontSize: 10, color: Colors.grey),
                  ),
                );
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
                toY: (e.value['total_volume'] as num).toDouble(),
                color: AppTheme.renewalTeal,
                width: 16,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
              )
            ],
          );
        }).toList(),
      ),
    );
  }
}