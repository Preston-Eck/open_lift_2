import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../services/database_service.dart';
import '../models/log.dart';

class ExerciseAnalyticsScreen extends StatefulWidget {
  final String? initialExercise; // NEW: Accept deep link
  const ExerciseAnalyticsScreen({super.key, this.initialExercise});

  @override
  State<ExerciseAnalyticsScreen> createState() => _ExerciseAnalyticsScreenState();
}

class _ExerciseAnalyticsScreenState extends State<ExerciseAnalyticsScreen> {
  // ... existing state variables ...
  String? _selectedExercise;
  List<LogEntry> _fullHistory = [];
  List<LogEntry> _filteredHistory = [];
  List<Map<String, dynamic>> _exerciseList = [];
  
  // Filter State
  String _searchQuery = "";
  DateTime _startDate = DateTime.now().subtract(const Duration(days: 365)); 
  DateTime _endDate = DateTime.now();
  
  // Axis Configuration
  double? _minWeight;
  double? _maxWeight;
  double? _minReps;
  double? _maxReps;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadExerciseList();
    });
  }

  Future<void> _loadExerciseList() async {
    final db = Provider.of<DatabaseService>(context, listen: false);
    final list = await db.getMostFrequentExercises();
    if (mounted) {
      setState(() {
        _exerciseList = list;
        // LOGIC CHANGE: Prioritize initialExercise if provided
        if (widget.initialExercise != null) {
          _selectExercise(widget.initialExercise!);
        } else if (list.isNotEmpty) {
          _selectExercise(list.first['exercise_name']);
        }
      });
    }
  }

  Future<void> _selectExercise(String name) async {
    final db = Provider.of<DatabaseService>(context, listen: false);
    final history = await db.getHistoryForExercise(name);
    
    if (!mounted) return;

    setState(() {
      _selectedExercise = name;
      _fullHistory = history;
      _applyFilters();
    });
  }

  void _applyFilters() {
    setState(() {
      _filteredHistory = _fullHistory.where((log) {
        final date = DateTime.parse(log.timestamp);
        return date.isAfter(_startDate) && date.isBefore(_endDate.add(const Duration(days: 1)));
      }).toList();
    });
  }

  void _resetAxis() {
    setState(() {
      _minWeight = null;
      _maxWeight = null;
      _minReps = null;
      _maxReps = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_selectedExercise ?? "Analytics"),
        actions: [
          Builder(builder: (context) {
            return IconButton(
              icon: const Icon(Icons.settings),
              onPressed: () => Scaffold.of(context).openEndDrawer(),
              tooltip: "Settings & Exercises",
            );
          }),
        ],
      ),
      endDrawer: _buildControlPanel(),
      body: Column(
        children: [
          // --- Filter Summary Chip ---
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: Row(
              children: [
                Chip(
                  label: Text("Date: ${DateFormat('MM/yy').format(_startDate)} - ${DateFormat('MM/yy').format(_endDate)}"),
                  onDeleted: () {
                     setState(() {
                       _startDate = DateTime.now().subtract(const Duration(days: 365));
                       _endDate = DateTime.now();
                       _applyFilters();
                     });
                  },
                ),
                const SizedBox(width: 8),
                if (_filteredHistory.isNotEmpty)
                  Text("${_filteredHistory.length} sets", style: const TextStyle(color: Colors.grey)),
              ],
            ),
          ),
          
          // --- Main Chart ---
          Expanded(
            child: _filteredHistory.isEmpty
                ? const Center(child: Text("No data for selected range."))
                : Padding(
                    padding: const EdgeInsets.fromLTRB(16, 24, 32, 16),
                    child: _buildScatterChart(),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildControlPanel() {
    return Drawer(
      width: 320,
      child: Column(
        children: [
          const DrawerHeader(
            decoration: BoxDecoration(color: Colors.blueAccent),
            child: Center(child: Text("Controls", style: TextStyle(color: Colors.white, fontSize: 24))),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // 1. Date Range Section
                const Text("Date Range", style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 10),
                OutlinedButton(
                  onPressed: () async {
                    final picked = await showDateRangePicker(
                      context: context,
                      firstDate: DateTime(2020),
                      lastDate: DateTime.now(),
                      initialDateRange: DateTimeRange(start: _startDate, end: _endDate),
                    );
                    if (picked != null) {
                      setState(() {
                        _startDate = picked.start;
                        _endDate = picked.end;
                        _applyFilters();
                      });
                    }
                  },
                  child: const Text("Select Dates"),
                ),
                const Divider(height: 30),

                // 2. Axis Configuration Section
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text("Axis Settings", style: TextStyle(fontWeight: FontWeight.bold)),
                    TextButton(onPressed: _resetAxis, child: const Text("Reset"))
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(child: _buildNumInput("Min Lbs", (v) => setState(() => _minWeight = v))),
                    const SizedBox(width: 10),
                    Expanded(child: _buildNumInput("Max Lbs", (v) => setState(() => _maxWeight = v))),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(child: _buildNumInput("Min Reps", (v) => setState(() => _minReps = v))),
                    const SizedBox(width: 10),
                    Expanded(child: _buildNumInput("Max Reps", (v) => setState(() => _maxReps = v))),
                  ],
                ),
                const Divider(height: 30),

                // 3. Exercise List Section
                const Text("Select Exercise", style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 10),
                TextField(
                  decoration: const InputDecoration(
                    labelText: "Search",
                    prefixIcon: Icon(Icons.search),
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  onChanged: (v) => setState(() => _searchQuery = v),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  height: 300, 
                  child: ListView.builder(
                    itemCount: _exerciseList.length,
                    itemBuilder: (ctx, i) {
                      final ex = _exerciseList[i];
                      if (_searchQuery.isNotEmpty && 
                          !ex['exercise_name'].toString().toLowerCase().contains(_searchQuery.toLowerCase())) {
                        return const SizedBox.shrink();
                      }
                      final isSelected = ex['exercise_name'] == _selectedExercise;
                      return ListTile(
                        title: Text(ex['exercise_name']),
                        selected: isSelected,
                        selectedColor: Colors.blueAccent,
                        trailing: Text("${ex['count']}"),
                        onTap: () {
                           _selectExercise(ex['exercise_name']);
                           Navigator.pop(context);
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNumInput(String label, Function(double?) onChanged) {
    return TextField(
      keyboardType: TextInputType.number,
      decoration: InputDecoration(labelText: label, border: const OutlineInputBorder(), isDense: true),
      onSubmitted: (val) {
        if (val.isEmpty) {
          onChanged(null);
        } else {
          onChanged(double.tryParse(val));
        }
      },
    );
  }

  Widget _buildScatterChart() {
    double autoMaxY = 0;
    double autoMaxX = 0;
    for (var log in _filteredHistory) {
      if (log.reps > autoMaxY) autoMaxY = log.reps.toDouble();
      if (log.weight > autoMaxX) autoMaxX = log.weight;
    }

    return ScatterChart(
      ScatterChartData(
        scatterSpots: _filteredHistory.map((log) {
          return ScatterSpot(
            log.weight,
            log.reps.toDouble(),
            radius: 8,
            color: _getDateColor(DateTime.parse(log.timestamp)),
          );
        }).toList(),
        minX: _minWeight ?? 0,
        maxX: _maxWeight ?? (autoMaxX * 1.1),
        minY: _minReps ?? 0,
        maxY: _maxReps ?? (autoMaxY * 1.1),
        gridData: const FlGridData(show: true),
        titlesData: FlTitlesData(
          bottomTitles: AxisTitles(
            axisNameWidget: const Text("Weight (lbs)"),
            sideTitles: SideTitles(showTitles: true, reservedSize: 30, getTitlesWidget: (val, meta) => Text(val.toInt().toString())),
          ),
          leftTitles: AxisTitles(
            axisNameWidget: const Text("Reps"),
            sideTitles: SideTitles(showTitles: true, reservedSize: 30, getTitlesWidget: (val, meta) => Text(val.toInt().toString())),
          ),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        borderData: FlBorderData(show: true, border: Border.all(color: Colors.grey.withValues(alpha: 0.2))),
        
        // --- FIX IS HERE ---
        scatterTouchData: ScatterTouchData(
          enabled: true,
          touchTooltipData: ScatterTouchTooltipData(
            tooltipBgColor: Colors.grey[800], // Corrected property for older v0.63.0 API
            getTooltipItems: (ScatterSpot spot) {
              return ScatterTooltipItem(
                "${spot.x.toInt()} lbs\n${spot.y.toInt()} reps",
                textStyle: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              );
            },
          ),
        ),
      ),
    );
  }

  Color _getDateColor(DateTime date) {
    final daysOld = DateTime.now().difference(date).inDays;
    if (daysOld < 7) return Colors.greenAccent; 
    if (daysOld < 30) return Colors.blueAccent; 
    if (daysOld < 90) return Colors.orangeAccent;
    return Colors.grey.withValues(alpha: 0.3);
  }
}