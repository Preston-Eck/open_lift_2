import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart'; // NEW
import 'package:cached_network_image/cached_network_image.dart'; // NEW
import '../models/exercise.dart';
import 'exercise_detail_screen.dart';
import 'add_exercise_screen.dart';

class WikiScreen extends StatefulWidget {
  const WikiScreen({super.key});

  @override
  State<WikiScreen> createState() => _WikiScreenState();
}

class _WikiScreenState extends State<WikiScreen> {
  final _supabase = Supabase.instance.client;
  final TextEditingController _searchController = TextEditingController();
  List<Exercise> _exercises = [];
  bool _isLoading = false;
  bool _isOffline = false;

  @override
  void initState() {
    super.initState();
    _fetchExercises();
  }

  Future<void> _fetchExercises([String? query]) async {
    setState(() => _isLoading = true);
    
    final dynamic connectivity = await Connectivity().checkConnectivity();
    final bool isOffline = connectivity is List 
      ? connectivity.contains(ConnectivityResult.none)
      : connectivity == ConnectivityResult.none;

    if (isOffline) {
      if (mounted) {
        setState(() {
          _isOffline = true;
          _isLoading = false;
          _exercises = [];
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("You are offline. Cannot search Wiki."))
        );
      }
      return;
    }

    try {
      setState(() => _isOffline = false);
      var dbQuery = _supabase.from('exercises').select();
      
      if (query != null && query.isNotEmpty) {
        dbQuery = dbQuery.ilike('name', '%$query%');
      }
      
      final data = await dbQuery.order('name').limit(50);
      
      if (mounted) {
        setState(() {
          _exercises = (data as List).map((e) => Exercise.fromJson(e)).toList();
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // Reuse logic for image URL
  String? _getThumbnailUrl(Exercise ex) {
    if (ex.images.isEmpty) return null;
    
    String path = ex.images.first;
    if (path.startsWith('http')) return path;
    
    final supabaseUrl = dotenv.env['SUPABASE_URL'];
    if (supabaseUrl == null || supabaseUrl.isEmpty) return null;

    final baseUrl = supabaseUrl.endsWith('/') ? supabaseUrl : "$supabaseUrl/";
    final cleanPath = path.startsWith('/') ? path.substring(1) : path;
    return "${baseUrl}storage/v1/object/public/exercises/$cleanPath"; 
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Exercise Wiki")),
      floatingActionButton: FloatingActionButton(
        child: const Icon(Icons.add),
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const AddExerciseScreen()),
          );
        },
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: "Search (e.g. Bench Press)",
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.clear),
                  onPressed: () {
                    _searchController.clear();
                    _fetchExercises(); 
                  },
                ),
              ),
              onSubmitted: (value) => _fetchExercises(value),
            ),
          ),
          
          Expanded(
            child: _isLoading 
              ? const Center(child: CircularProgressIndicator())
              : _isOffline 
                  ? _buildOfflineView()
                  : _exercises.isEmpty 
                      ? const Center(child: Text("No exercises found."))
                      : ListView.builder(
                          itemCount: _exercises.length,
                          itemBuilder: (context, index) {
                            final ex = _exercises[index];
                            final muscles = ex.primaryMuscles.isNotEmpty 
                                ? ex.primaryMuscles.join(', ') 
                                : 'General';
                            
                            // Updated: Added Leading Thumbnail
                            final thumbUrl = _getThumbnailUrl(ex);

                            return ListTile(
                              leading: Container(
                                width: 50,
                                height: 50,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(8),
                                  color: Colors.grey[200],
                                ),
                                child: thumbUrl != null 
                                  ? ClipRRect(
                                      borderRadius: BorderRadius.circular(8),
                                      child: CachedNetworkImage(
                                        imageUrl: thumbUrl,
                                        fit: BoxFit.cover,
                                        errorWidget: (c,u,e) => const Icon(Icons.fitness_center, size: 20, color: Colors.grey),
                                        placeholder: (c,u) => const Padding(
                                          padding: EdgeInsets.all(12.0),
                                          child: CircularProgressIndicator(strokeWidth: 2),
                                        ),
                                      ),
                                    )
                                  : const Icon(Icons.fitness_center, size: 20, color: Colors.grey),
                              ),
                              title: Text(ex.name),
                              subtitle: Text(muscles, maxLines: 1, overflow: TextOverflow.ellipsis),
                              trailing: const Icon(Icons.chevron_right),
                              onTap: () {
                                Navigator.push(
                                  context, 
                                  MaterialPageRoute(builder: (_) => ExerciseDetailScreen(exercise: ex))
                                );
                              },
                            );
                          },
                        ),
          ),
        ],
      ),
    );
  }

  Widget _buildOfflineView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.wifi_off, size: 64, color: Colors.grey),
          const SizedBox(height: 16),
          const Text("You are offline.", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const Text("The Wiki requires internet to search."),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: _fetchExercises,
            child: const Text("Retry Connection"),
          ),
        ],
      ),
    );
  }
}