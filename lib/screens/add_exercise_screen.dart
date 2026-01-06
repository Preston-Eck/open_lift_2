import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import '../services/database_service.dart';
import '../models/exercise.dart';

class AddExerciseScreen extends StatefulWidget {
  const AddExerciseScreen({super.key});

  @override
  State<AddExerciseScreen> createState() => _AddExerciseScreenState();
}

class _AddExerciseScreenState extends State<AddExerciseScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _muscleController = TextEditingController();
  String _category = "Strength";

  void _save() {
    if (_formKey.currentState!.validate()) {
      final newExercise = Exercise(
        id: const Uuid().v4(),
        name: _nameController.text,
        category: _category,
        primaryMuscles: _muscleController.text.split(',').map((e) => e.trim()).toList(),
        secondaryMuscles: [],
        equipment: [],
        instructions: [],
        images: [],
      );

      Provider.of<DatabaseService>(context, listen: false).addCustomExercise(newExercise);
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Add Custom Exercise")),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(labelText: "Exercise Name"),
              validator: (v) => v!.isEmpty ? "Required" : null,
            ),
            const SizedBox(height: 10),
            TextFormField(
              controller: _muscleController,
              decoration: const InputDecoration(labelText: "Target Muscles (comma separated)"),
            ),
             const SizedBox(height: 10),
            DropdownButtonFormField<String>(
              initialValue: _category, 
              items: ["Strength", "Cardio", "Stretching"].map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
              onChanged: (v) => setState(() => _category = v!),
              decoration: const InputDecoration(labelText: "Category"),
            ),
            const SizedBox(height: 20),
            ElevatedButton(onPressed: _save, child: const Text("Save Exercise")),
          ],
        ),
      ),
    );
  }
}