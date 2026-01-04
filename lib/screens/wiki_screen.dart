import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/exercise.dart';

class WikiScreen extends StatefulWidget {
  const WikiScreen({super.key});

  @override
  State<WikiScreen> createState() => _WikiScreenState();
}

class _WikiScreenState extends State<WikiScreen> {
  final _supabase = Supabase.instance.client;
  List<Exercise> _exercises = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _fetchExercises();
  }

  Future<void> _fetchExercises() async {
    setState(() => _isLoading = true);
    try {
      final data = await _supabase
          .from('exercises')
          .select()
          .order('name')
          .limit(100); // Limit to 100 for performance until we add pagination
      
      if (mounted) {
        setState(() {
          _exercises = (data as List).map((e) => Exercise.fromJson(e)).toList();
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading exercises: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _addExerciseDialog() async {
    final nameController = TextEditingController();
    final muscleController = TextEditingController();
    
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Add Public Exercise"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController, 
              decoration: const InputDecoration(labelText: "Name")
            ),
            TextField(
              controller: muscleController, 
              decoration: const InputDecoration(labelText: "Primary Muscle (e.g. Chest)")
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel"),
          ),
          TextButton(
            onPressed: () async {
              if (nameController.text.isNotEmpty) {
                try {
                  await _supabase.from('exercises').insert({
                    'name': nameController.text,
                    'primary_muscles': [muscleController.text],
                    'equipment_required': [], 
                  });
                  if(context.mounted) Navigator.pop(context);
                  _fetchExercises();
                } catch (e) {
                  if(context.mounted) {
                     ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
                  }
                }
              }
            },
            child: const Text("Save to Wiki"),
          )
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Community Exercise Wiki"),
        actions: [
          IconButton(icon: const Icon(Icons.add), onPressed: _addExerciseDialog),
          IconButton(icon: const Icon(Icons.refresh), onPressed: _fetchExercises),
        ],
      ),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator())
        : ListView.builder(
            itemCount: _exercises.length,
            itemBuilder: (context, index) {
              final ex = _exercises[index];
              final muscles = ex.primaryMuscles.isNotEmpty 
                  ? ex.primaryMuscles.join(', ') 
                  : 'General';
              
              return ListTile(
                title: Text(ex.name),
                subtitle: Text("$muscles • ${ex.equipment.join(', ')}"),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  // Navigate to details (placeholder)
                },
              );
            },
          ),
    );
  }
}