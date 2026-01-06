import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _ageController = TextEditingController();
  final _heightController = TextEditingController();
  final _weightController = TextEditingController();
  String _gender = 'Male';
  String _fitnessLevel = 'Intermediate';

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _ageController.text = prefs.getString('user_age') ?? '';
      _heightController.text = prefs.getString('user_height') ?? '';
      _weightController.text = prefs.getString('user_weight') ?? '';
      _gender = prefs.getString('user_gender') ?? 'Male';
      _fitnessLevel = prefs.getString('user_fitness_level') ?? 'Intermediate';
    });
  }

  Future<void> _saveSettings() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('user_age', _ageController.text);
    await prefs.setString('user_height', _heightController.text);
    await prefs.setString('user_weight', _weightController.text);
    await prefs.setString('user_gender', _gender);
    await prefs.setString('user_fitness_level', _fitnessLevel);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Profile Saved!"))
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("User Profile & Settings")),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text("About You", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 5),
          const Text("This data is sent to the AI Coach to tailor your plans."),
          const SizedBox(height: 20),

          TextField(
            controller: _ageController,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: "Age", border: OutlineInputBorder()),
          ),
          const SizedBox(height: 10),
          
          TextField(
            controller: _heightController,
            keyboardType: TextInputType.text,
            decoration: const InputDecoration(labelText: "Height (e.g. 5'10\" or 178cm)", border: OutlineInputBorder()),
          ),
          const SizedBox(height: 10),

          TextField(
            controller: _weightController,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: "Weight (lbs)", border: OutlineInputBorder()),
          ),
          const SizedBox(height: 10),

          DropdownButtonFormField<String>(
            initialValue: _gender,
            decoration: const InputDecoration(labelText: "Gender", border: OutlineInputBorder()),
            items: ['Male', 'Female', 'Other'].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
            onChanged: (val) => setState(() => _gender = val!),
          ),
          const SizedBox(height: 10),

          DropdownButtonFormField<String>(
            initialValue: _fitnessLevel,
            decoration: const InputDecoration(labelText: "Fitness Level", border: OutlineInputBorder()),
            items: ['Beginner', 'Intermediate', 'Advanced', 'Elite'].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
            onChanged: (val) => setState(() => _fitnessLevel = val!),
          ),
          
          const SizedBox(height: 30),
          ElevatedButton.icon(
            icon: const Icon(Icons.save),
            label: const Text("Save Profile"),
            style: ElevatedButton.styleFrom(minimumSize: const Size(double.infinity, 50)),
            onPressed: _saveSettings,
          )
        ],
      ),
    );
  }
}