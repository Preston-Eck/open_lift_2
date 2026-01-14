import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../services/database_service.dart';
import '../models/plan.dart';
import '../models/exercise.dart';
import '../models/log.dart';
import 'workout_player_screen.dart';
import 'exercise_detail_screen.dart';
import 'exercise_analytics_screen.dart';
import '../widgets/one_rep_max_dialog.dart'; // NEW: Import Dialog
import '../theme.dart';

class GlobalSearchScreen extends StatefulWidget {
  const GlobalSearchScreen({super.key});

  @override
  State<GlobalSearchScreen> createState() => _GlobalSearchScreenState();
}

class _GlobalSearchScreenState extends State<GlobalSearchScreen> {
  final TextEditingController _searchController = TextEditingController();
  Timer? _debounce;
  bool _isLoading = false;
  bool _isOffline = false;

  // Results
  List<WorkoutPlan> _plans = [];
  List<LogEntry> _history = [];
  List<Exercise> _wikiExercises = [];
  
  // 1RM Cache
  Map<String, double> _oneRepMaxes = {};

  @override
  void initState() {
    super.initState();
    _loadOneRepMaxes();
  }

  Future<void> _loadOneRepMaxes() async {
    final db = context.read<DatabaseService>();
    final maxes = await db.getLatestOneRepMaxes();
    if (mounted) setState(() => _oneRepMaxes = maxes);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  void _onSearchChanged(String query) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () {
      if (query.isNotEmpty) {
        _performSearch(query);
      } else {
        setState(() {
          _plans = [];
          _history = [];
          _wikiExercises = [];
        });
      }
    });
  }

  Future<void> _performSearch(String query) async {
    setState(() => _isLoading = true);

    final db = context.read<DatabaseService>();
    final supabase = Supabase.instance.client;

    // 1. Local Search (Plans & History)
    final localPlans = await db.searchPlans(query);
    final localHistory = await db.searchHistory(query);

    // 2. Remote Search (Wiki)
    List<Exercise> remoteExercises = [];
    final dynamic connectivity = await Connectivity().checkConnectivity();
    final bool isOffline = connectivity is List 
      ? connectivity.contains(ConnectivityResult.none)
      : connectivity == ConnectivityResult.none;
    
    if (isOffline) {
      setState(() => _isOffline = true);
    } else {
      setState(() => _isOffline = false);
      try {
        final data = await supabase
            .from('exercises')
            .select()
            .ilike('name', '%$query%')
            .limit(5);
        remoteExercises = (data as List).map((e) => Exercise.fromJson(e)).toList();
      } catch (e) {
        debugPrint("Wiki search error: $e");
      }
    }

    if (mounted) {
      setState(() {
        _plans = localPlans;
        _history = localHistory;
        _wikiExercises = remoteExercises;
        _isLoading = false;
      });
    }
  }

  void _openOneRepMaxDialog(String exerciseName) async {
    await showDialog(
      context: context,
      builder: (context) => EditOneRepMaxDialog(
        exerciseName: exerciseName,
        currentMax: _oneRepMaxes[exerciseName],
      ),
    );
    _loadOneRepMaxes(); // Refresh after edit
  }

  void _startPlan(WorkoutPlan plan) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text("Start ${plan.name}"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: plan.days.map((day) => ListTile(
            title: Text(day.name),
            trailing: const Icon(Icons.play_arrow, color: Colors.green),
            onTap: () {
              Navigator.pop(ctx);
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => WorkoutPlayerScreen(
                  workoutDay: day,
                  isHiit: plan.type == 'HIIT'
                ))
              );
            },
          )).toList(),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancel"))
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: TextField(
          controller: _searchController,
          autofocus: true,
          style: const TextStyle(color: Colors.black),
          decoration: const InputDecoration(
            hintText: "Search plans, history, wiki...",
            border: InputBorder.none,
            hintStyle: TextStyle(color: Colors.grey),
          ),
          onChanged: _onSearchChanged,
        ),
      ),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator()) 
        : _buildResultsList(),
    );
  }

  Widget _buildResultsList() {
    if (_plans.isEmpty && _history.isEmpty && _wikiExercises.isEmpty) {
      return Center(
        child: Text(_searchController.text.isEmpty ? "Type to search" : "No results found."),
      );
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (_plans.isNotEmpty) ...[
          _buildSectionHeader("Plans", Icons.calendar_today),
          ..._plans.map((p) => ListTile(
            title: Text(p.name, style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Text(p.goal),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _startPlan(p),
          )),
          const Divider(),
        ],

        if (_history.isNotEmpty) ...[
          _buildSectionHeader("History", Icons.history),
          ..._history.map((h) {
            final max = _oneRepMaxes[h.exerciseName];
            return ListTile(
              title: Text(h.exerciseName),
              subtitle: Text("Last: ${h.weight}lbs x ${h.reps}"),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (max != null)
                    ActionChip(
                      label: Text("1RM: ${max.toInt()}"),
                      visualDensity: VisualDensity.compact,
                      onPressed: () => _openOneRepMaxDialog(h.exerciseName),
                    ),
                  const SizedBox(width: 8),
                  const Icon(Icons.show_chart, color: AppTheme.renewalTeal),
                ],
              ),
              onTap: () {
                 Navigator.push(context, MaterialPageRoute(
                   builder: (_) => ExerciseAnalyticsScreen(initialExercise: h.exerciseName)
                 ));
              },
            );
          }),
          const Divider(),
        ],

        _buildSectionHeader("Wiki", Icons.menu_book),
        if (_isOffline)
          const Padding(
            padding: EdgeInsets.all(8.0),
            child: Text("Offline. Cannot search Wiki.", style: TextStyle(color: Colors.grey, fontStyle: FontStyle.italic)),
          )
        else ...[
          if (_wikiExercises.isEmpty && _searchController.text.isNotEmpty)
             const Padding(padding: EdgeInsets.all(8), child: Text("No wiki results.")),
          ..._wikiExercises.map((e) {
            final max = _oneRepMaxes[e.name];
            return ListTile(
              title: Text(e.name),
              subtitle: Text(e.primaryMuscles.join(', ')),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ActionChip(
                    label: Text(max != null ? "1RM: ${max.toInt()}" : "Set 1RM"),
                    visualDensity: VisualDensity.compact,
                    onPressed: () => _openOneRepMaxDialog(e.name),
                  ),
                  const SizedBox(width: 8),
                  const Icon(Icons.info_outline),
                ],
              ),
              onTap: () {
                 Navigator.push(context, MaterialPageRoute(
                   builder: (_) => ExerciseDetailScreen(exercise: e)
                 ));
              },
            );
          }),
        ]
      ],
    );
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0, top: 8.0),
      child: Row(
        children: [
          Icon(icon, size: 20, color: Colors.grey),
          const SizedBox(width: 8),
          Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.grey)),
        ],
      ),
    );
  }
}