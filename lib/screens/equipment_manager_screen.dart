import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/database_service.dart';
import '../services/gemini_service.dart';

class EquipmentManagerScreen extends StatefulWidget {
  const EquipmentManagerScreen({super.key});

  @override
  State<EquipmentManagerScreen> createState() => _EquipmentManagerScreenState();
}

class _EquipmentManagerScreenState extends State<EquipmentManagerScreen> {
  // Standard list for quick toggles
  final List<String> _standardEquipment = [
    'Barbell', 'Dumbbell', 'Kettlebell', 'Bench', 
    'Pull Up Bar', 'Dip Station', 'Cable Machine', 
    'Resistance Bands', 'Smith Machine', 'Leg Press'
  ];

  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _contextController = TextEditingController();
  
  List<String> _aiDetectedTags = []; 
  bool _isAnalyzing = false;
  
  // Loading State
  bool _isLoading = true;
  String? _errorMessage;
  
  // Local state of owned items
  final Map<String, bool> _ownedMap = {};

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final db = context.read<DatabaseService>();
    try {
      final ownedList = await db.getOwnedEquipment();
      
      if (mounted) {
        setState(() {
          // 1. Initialize map with standard items (default false)
          for (var item in _standardEquipment) {
            _ownedMap[item] = false;
          }
          // 2. Mark owned items as true.
          // Note: ownedList now returns capabilities too, so we check if the standard item is present.
          for (var item in ownedList) {
            if (_standardEquipment.contains(item)) {
              _ownedMap[item] = true;
            } else {
              // It's a custom item name
              _ownedMap[item] = true; 
            }
          }
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final db = Provider.of<DatabaseService>(context);
    final gemini = Provider.of<GeminiService>(context, listen: false);

    return Scaffold(
      appBar: AppBar(title: const Text("Manage Equipment")),
      body: _buildBody(db, gemini),
    );
  }

  Widget _buildBody(DatabaseService db, GeminiService gemini) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, color: Colors.red, size: 48),
              const SizedBox(height: 10),
              Text("Error loading equipment:\n$_errorMessage", textAlign: TextAlign.center),
              const SizedBox(height: 20),
              ElevatedButton(onPressed: _loadData, child: const Text("Retry"))
            ],
          ),
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.all(16.0),
      children: [
        _buildAddCustomSection(db, gemini),
        const Divider(height: 30),
        const Text("Standard Equipment", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        const SizedBox(height: 10),
        
        ..._standardEquipment.map((eq) => CheckboxListTile(
          title: Text(eq),
          value: _ownedMap[eq] ?? false,
          onChanged: (val) {
            setState(() => _ownedMap[eq] = val!);
            if (val == true) {
              db.updateEquipmentCapabilities(eq, [eq]); 
            } else {
              db.updateEquipment(eq, val!);
            }
          },
        )),
        
        const Divider(),
        const Text("Your Custom Gear", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        
        if (_ownedMap.entries.where((e) => !_standardEquipment.contains(e.key) && e.value).isEmpty)
          const Padding(
            padding: EdgeInsets.only(top: 8.0),
            child: Text("No custom equipment added.", style: TextStyle(color: Colors.grey)),
          ),

        ..._ownedMap.entries.where((e) => !_standardEquipment.contains(e.key) && e.value).map((entry) {
            return ListTile(
              title: Text(entry.key),
              trailing: IconButton(
                icon: const Icon(Icons.delete, color: Colors.red),
                onPressed: () {
                  setState(() => _ownedMap.remove(entry.key));
                  db.updateEquipment(entry.key, false);
                },
              ),
            );
        }),
      ],
    );
  }

  Widget _buildAddCustomSection(DatabaseService db, GeminiService gemini) {
    return Card(
      color: Colors.grey[100],
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("Add Specialized Gear", style: TextStyle(fontWeight: FontWeight.bold)),
            const Text("Enter name, model number, or paste a product link/description.", style: TextStyle(fontSize: 12, color: Colors.grey)),
            const SizedBox(height: 10),
            
            // Name Input
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: "Equipment Name (e.g. SincMill)",
                border: OutlineInputBorder(),
                isDense: true,
              ),
            ),
            const SizedBox(height: 10),
            
            // Context Input
            TextField(
              controller: _contextController,
              decoration: const InputDecoration(
                labelText: "Details / Model # / URL",
                border: OutlineInputBorder(),
                isDense: true,
              ),
              maxLines: 2,
            ),
            const SizedBox(height: 10),
            
            // AI Action
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                icon: _isAnalyzing 
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) 
                  : const Icon(Icons.auto_awesome),
                label: const Text("Analyze Capabilities"),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.deepPurple, foregroundColor: Colors.white),
                onPressed: _isAnalyzing ? null : () async {
                    if (_nameController.text.isEmpty) return;
                    setState(() => _isAnalyzing = true);
                    
                    try {
                      final tags = await gemini.analyzeEquipment(
                        _nameController.text, 
                        contextInfo: _contextController.text
                      );
                      
                      if (mounted) {
                        setState(() {
                          final Set<String> uniqueTags = Set.from(_aiDetectedTags)..addAll(tags);
                          _aiDetectedTags = uniqueTags.toList();
                          _isAnalyzing = false;
                        });
                      }
                    } catch (e) {
                      if (mounted) {
                        setState(() => _isAnalyzing = false);
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("AI Error: $e")));
                      }
                    }
                },
              ),
            ),
            
            // Tags & Save
            if (_nameController.text.isNotEmpty || _aiDetectedTags.isNotEmpty) ...[
               const SizedBox(height: 15),
               Row(
                 children: [
                   const Text("Capabilities:", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                   const Spacer(),
                   TextButton.icon(
                     icon: const Icon(Icons.add, size: 16),
                     label: const Text("Add Tag"),
                     onPressed: _showAddTagDialog,
                   )
                 ],
               ),
               Wrap(
                spacing: 8.0,
                children: _aiDetectedTags.map((tag) => Chip(
                  label: Text(tag),
                  backgroundColor: Colors.white,
                  deleteIcon: const Icon(Icons.close, size: 16),
                  onDeleted: () {
                    setState(() => _aiDetectedTags.remove(tag));
                  },
                )).toList(),
              ),
              const SizedBox(height: 10),
              ElevatedButton.icon(
                icon: const Icon(Icons.save),
                label: const Text("Save to My Gym"),
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 40),
                  backgroundColor: Colors.green, 
                  foregroundColor: Colors.white
                ),
                onPressed: () async {
                   final name = _nameController.text;
                   if (name.isEmpty) return;

                   await db.updateEquipmentCapabilities(name, _aiDetectedTags);
                   
                   setState(() {
                     _ownedMap[name] = true;
                     _nameController.clear();
                     _contextController.clear();
                     _aiDetectedTags = [];
                   });
                   
                   if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Added $name!")));
                },
              )
            ]
          ],
        ),
      ),
    );
  }

  void _showAddTagDialog() {
    final tagController = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Add Capability Tag"),
        content: TextField(
          controller: tagController,
          decoration: const InputDecoration(hintText: "e.g. Cable, Smith Machine"),
          autofocus: true,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancel")),
          ElevatedButton(
            onPressed: () {
              if (tagController.text.isNotEmpty) {
                setState(() {
                  _aiDetectedTags.add(tagController.text);
                });
              }
              Navigator.pop(ctx);
            },
            child: const Text("Add"),
          )
        ],
      ),
    );
  }
}