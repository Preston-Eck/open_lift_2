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

  @override
  void initState() {
    super.initState();
    _fetchExercises();
  }

  Future<void> _fetchExercises() async {
    final data = await _supabase.from('exercises').select().order('name');
    setState(() {
      _exercises = (data as List).map((e) => Exercise.fromJson(e)).toList();
    });
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
            TextField(controller: nameController, decoration: const InputDecoration(labelText: "Name")),
            TextField(controller: muscleController, decoration: const InputDecoration(labelText: "Muscle Group")),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () async {
              if (nameController.text.isNotEmpty) {
                await _supabase.from('exercises').insert({
                  'name': nameController.text,
                  'muscle_group': muscleController.text,
                  'equipment_required': ['None'], // Simplified for demo
                });
                if(context.mounted) Navigator.pop(context);
                _fetchExercises();
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
        ],
      ),
      body: ListView.builder(
        itemCount: _exercises.length,
        itemBuilder: (context, index) {
          final ex = _exercises[index];
          return ListTile(
            title: Text(ex.name),
            subtitle: Text("${ex.muscleGroup} • ${ex.equipment.join(', ')}"),
            trailing: const Icon(Icons.edit),
            onTap: () {
              // Implement Edit Logic here using UPDATE query
            },
          );
        },
      ),
    );
  }
}