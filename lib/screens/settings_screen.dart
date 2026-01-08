import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/database_service.dart';
import 'about_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _ageController = TextEditingController();
  final _heightCmController = TextEditingController();
  final _feetController = TextEditingController();
  final _inchesController = TextEditingController();
  final _weightController = TextEditingController();
  
  String _gender = 'Male';
  String _fitnessLevel = 'Intermediate';
  String _unitSystem = 'Imperial'; 
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final db = context.read<DatabaseService>();
    final prefs = await SharedPreferences.getInstance();
    final profile = await db.getUserProfile();

    if (mounted) {
      setState(() {
        _unitSystem = prefs.getString('units') ?? 'Imperial';

        if (profile != null) {
          _ageController.text = profile['birth_date'] ?? '';
          _gender = profile['gender'] ?? 'Male';
          _fitnessLevel = profile['fitness_level'] ?? 'Intermediate';

          double storedWeight = profile['current_weight'] ?? 0.0;
          if (_unitSystem == 'Metric') {
            _weightController.text = (storedWeight * 0.453592).toStringAsFixed(1);
          } else {
            _weightController.text = storedWeight.toStringAsFixed(1);
          }

          double storedHeight = profile['height'] ?? 0.0;
          if (_unitSystem == 'Imperial') {
            double totalInches = storedHeight / 2.54;
            int feet = (totalInches / 12).floor();
            int inches = (totalInches % 12).round();
            _feetController.text = feet.toString();
            _inchesController.text = inches.toString();
          } else {
            _heightCmController.text = storedHeight.toStringAsFixed(0);
          }
        }
        _isLoading = false;
      });
    }
  }

  Future<void> _saveSettings() async {
    final db = context.read<DatabaseService>();
    final prefs = await SharedPreferences.getInstance();
    
    await prefs.setString('units', _unitSystem);

    double? weightToStore;
    double? uiWeight = double.tryParse(_weightController.text);
    if (uiWeight != null) {
      if (_unitSystem == 'Metric') {
        weightToStore = uiWeight * 2.20462;
      } else {
        weightToStore = uiWeight;
      }
    }

    double? heightToStore;
    if (_unitSystem == 'Metric') {
      heightToStore = double.tryParse(_heightCmController.text);
    } else {
      double feet = double.tryParse(_feetController.text) ?? 0;
      double inches = double.tryParse(_inchesController.text) ?? 0;
      if (feet > 0 || inches > 0) {
        heightToStore = (feet * 12 + inches) * 2.54;
      }
    }

    await db.updateUserProfile({
      'birth_date': _ageController.text,
      'height': heightToStore,
      'current_weight': weightToStore,
      'gender': _gender,
      'fitness_level': _fitnessLevel,
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Profile Saved!"))
      );
    }
  }

  void _toggleUnits(int index) {
    setState(() {
      String newSystem = index == 0 ? 'Imperial' : 'Metric';
      if (_unitSystem == newSystem) return; 

      double currentVal = double.tryParse(_weightController.text) ?? 0;
      if (currentVal > 0) {
        if (newSystem == 'Metric') {
          _weightController.text = (currentVal * 0.453592).toStringAsFixed(1);
        } else {
          _weightController.text = (currentVal * 2.20462).toStringAsFixed(1);
        }
      }

      if (newSystem == 'Metric') {
        double f = double.tryParse(_feetController.text) ?? 0;
        double i = double.tryParse(_inchesController.text) ?? 0;
        double cm = (f * 12 + i) * 2.54;
        _heightCmController.text = cm.toStringAsFixed(0);
      } else {
        double cm = double.tryParse(_heightCmController.text) ?? 0;
        double totalInches = cm / 2.54;
        _feetController.text = (totalInches / 12).floor().toString();
        _inchesController.text = (totalInches % 12).round().toString();
      }

      _unitSystem = newSystem;
    });
  }

  @override
  Widget build(BuildContext context) {
    final isMetric = _unitSystem == 'Metric';

    return Scaffold(
      appBar: AppBar(title: const Text("User Profile & Settings")),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator()) 
        : ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Center(
                child: ToggleButtons(
                  isSelected: [_unitSystem == 'Imperial', _unitSystem == 'Metric'],
                  onPressed: _toggleUnits,
                  borderRadius: BorderRadius.circular(8),
                  children: const [
                    Padding(padding: EdgeInsets.symmetric(horizontal: 24), child: Text("Imperial")),
                    Padding(padding: EdgeInsets.symmetric(horizontal: 24), child: Text("Metric")),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              const Text("Personal Stats", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 10),

              TextField(
                controller: _ageController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: "Age", border: OutlineInputBorder()),
              ),
              const SizedBox(height: 10),
              
              if (isMetric)
                TextField(
                  controller: _heightCmController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: "Height (cm)", border: OutlineInputBorder()),
                )
              else
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _feetController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(labelText: "Height (Ft)", border: OutlineInputBorder()),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextField(
                        controller: _inchesController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(labelText: "Height (In)", border: OutlineInputBorder()),
                      ),
                    ),
                  ],
                ),
              const SizedBox(height: 10),

              TextField(
                controller: _weightController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: isMetric ? "Weight (kg)" : "Weight (lbs)", 
                  border: const OutlineInputBorder()
                ),
              ),
              const SizedBox(height: 10),

              InputDecorator(
                decoration: const InputDecoration(labelText: "Gender", border: OutlineInputBorder()),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: ['Male', 'Female', 'Other'].contains(_gender) ? _gender : 'Male',
                    isDense: true,
                    items: ['Male', 'Female', 'Other'].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
                    onChanged: (val) => setState(() => _gender = val!),
                  ),
                ),
              ),
              const SizedBox(height: 10),

              InputDecorator(
                decoration: const InputDecoration(labelText: "Fitness Level", border: OutlineInputBorder()),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: ['Beginner', 'Intermediate', 'Advanced', 'Elite'].contains(_fitnessLevel) ? _fitnessLevel : 'Intermediate',
                    isDense: true,
                    items: ['Beginner', 'Intermediate', 'Advanced', 'Elite'].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
                    onChanged: (val) => setState(() => _fitnessLevel = val!),
                  ),
                ),
              ),
              
              const SizedBox(height: 30),
              ElevatedButton.icon(
                icon: const Icon(Icons.save),
                label: const Text("Save Profile"),
                style: ElevatedButton.styleFrom(minimumSize: const Size(double.infinity, 50)),
                onPressed: _saveSettings,
              ),
              const SizedBox(height: 40),
              const Divider(),
              ListTile(
                leading: const Icon(Icons.info_outline, color: Colors.grey),
                title: const Text("About & Licenses"),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AboutScreen())),
              ),
              const SizedBox(height: 20),
            ],
          ),
    );
  }
}