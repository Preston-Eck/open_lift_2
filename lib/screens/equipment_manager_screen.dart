import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/database_service.dart';
import '../services/gemini_service.dart';
import '../models/exercise.dart';

class EquipmentManagerScreen extends StatefulWidget {
  const EquipmentManagerScreen({super.key});

  @override
  State<EquipmentManagerScreen> createState() => _EquipmentManagerScreenState();
}

class _EquipmentManagerScreenState extends State<EquipmentManagerScreen> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _contextController = TextEditingController();
  List<String> _aiDetectedTags = []; 
  bool _isAnalyzing = false;
  bool _isLoading = true;

  // Replaced simple Map with List of Maps to support full editing
  List<Map<String, dynamic>> _ownedItems = [];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final db = context.read<DatabaseService>();
    try {
      final items = await db.getUserEquipmentList();
      if (mounted) {
        setState(() {
          _ownedItems = List.from(items);
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _saveNewItem() async {
    final db = context.read<DatabaseService>();
    final name = _nameController.text;
    if (name.isEmpty) return;

    await db.updateEquipmentCapabilities(name, _aiDetectedTags);
    
    // Clear & Reload
    setState(() {
      _nameController.clear();
      _contextController.clear();
      _aiDetectedTags = [];
    });
    await _loadData();
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Added $name!")));
  }

  // NEW: Search for an exercise to link its capabilities
  Future<void> _importCapabilitiesFromExercise(Map<String, dynamic> equipmentItem) async {
    String? selectedExerciseName;
    List<String> newTags = [];

    // 1. Show Search Dialog
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Link Exercise to Equipment"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
             const Text("Search for an exercise (e.g., 'Lat Pulldown'). We will add its required equipment tags (e.g., 'Cable') to this machine."),
             const SizedBox(height: 10),
             Autocomplete<Exercise>(
                optionsBuilder: (TextEditingValue textEditingValue) async {
                  if (textEditingValue.text.isEmpty) return const Iterable<Exercise>.empty();
                  // Search Supabase (Wiki)
                  try {
                    final data = await Supabase.instance.client
                        .from('exercises')
                        .select()
                        .ilike('name', '%${textEditingValue.text}%')
                        .limit(5);
                    return (data as List).map((e) => Exercise.fromJson(e));
                  } catch (e) {
                    return const Iterable<Exercise>.empty();
                  }
                },
                displayStringForOption: (Exercise option) => option.name,
                onSelected: (Exercise selection) {
                  selectedExerciseName = selection.name;
                  newTags = selection.equipment;
                  // If no specific equipment required, maybe add the name itself?
                  if (newTags.isEmpty) newTags.add(selection.name);
                },
             ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancel")),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text("Import Tags"),
          )
        ],
      )
    );

    if (selectedExerciseName == null) return;

    // 2. Merge Tags
    final currentJson = equipmentItem['capabilities_json'];
    List<String> currentTags = [];
    if (currentJson != null) {
      currentTags = List<String>.from(jsonDecode(currentJson));
    }

    // Add new tags if unique
    int addedCount = 0;
    for (var tag in newTags) {
      if (!currentTags.contains(tag)) {
        currentTags.add(tag);
        addedCount++;
      }
    }

    // 3. Save
    if (addedCount > 0) {
      await context.read<DatabaseService>().updateEquipmentCapabilities(
        equipmentItem['name'], 
        currentTags
      );
      await _loadData();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Added $addedCount tags from '$selectedExerciseName'")));
      }
    } else {
       if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("No new tags to add.")));
      }
    }
  }

  void _showEditDialog(Map<String, dynamic> item) {
    final tagsJson = item['capabilities_json'];
    List<String> tags = tagsJson != null ? List<String>.from(jsonDecode(tagsJson)) : [];
    if (tags.isEmpty) tags.add(item['name']); // Default to name if empty

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setSheetState) {
          return Padding(
            padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom, left: 16, right: 16, top: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("Edit ${item['name']}", style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                const SizedBox(height: 10),
                const Text("Capabilities / Tags:", style: TextStyle(fontWeight: FontWeight.bold)),
                Wrap(
                  spacing: 8,
                  children: tags.map((t) => Chip(
                    label: Text(t),
                    onDeleted: () {
                      setSheetState(() => tags.remove(t));
                    },
                  )).toList(),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    TextButton.icon(
                      icon: const Icon(Icons.add),
                      label: const Text("Add Tag"),
                      onPressed: () {
                        // Simple Text Input Dialog
                        showDialog(
                          context: context,
                          builder: (c) {
                            final textC = TextEditingController();
                            return AlertDialog(
                              title: const Text("Add Tag"),
                              content: TextField(controller: textC, autofocus: true),
                              actions: [
                                ElevatedButton(
                                  onPressed: () {
                                    if(textC.text.isNotEmpty) {
                                      setSheetState(() => tags.add(textC.text));
                                    }
                                    Navigator.pop(c);
                                  },
                                  child: const Text("Add")
                                )
                              ],
                            );
                          }
                        );
                      },
                    ),
                    const Spacer(),
                    ElevatedButton.icon(
                      icon: const Icon(Icons.fitness_center),
                      label: const Text("Link Exercise..."),
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.deepPurple, foregroundColor: Colors.white),
                      onPressed: () async {
                        // Close sheet, trigger import, then re-open? 
                        // Easier to just run logic and update local state
                        Navigator.pop(ctx); 
                        await _importCapabilitiesFromExercise(item);
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    child: const Text("Save Changes"),
                    onPressed: () async {
                      await context.read<DatabaseService>().updateEquipmentCapabilities(item['name'], tags);
                      Navigator.pop(ctx);
                      _loadData();
                    },
                  ),
                ),
                const SizedBox(height: 20),
              ],
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final gemini = Provider.of<GeminiService>(context, listen: false);
    final db = context.read<DatabaseService>(); // for passing to sub-widgets

    return Scaffold(
      appBar: AppBar(title: const Text("Manage Equipment")),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator()) 
        : ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _buildAddCustomSection(gemini),
              const Divider(height: 30),
              
              if (_ownedItems.isEmpty)
                const Center(child: Text("Your gym is empty.", style: TextStyle(color: Colors.grey))),

              ..._ownedItems.map((item) {
                final tagsJson = item['capabilities_json'];
                final tags = tagsJson != null ? List<String>.from(jsonDecode(tagsJson)) : <String>[];
                
                return Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    title: Text(item['name'], style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text(tags.take(3).join(", ") + (tags.length > 3 ? "..." : ""), style: const TextStyle(fontSize: 12)),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.edit, color: Colors.blue),
                          onPressed: () => _showEditDialog(item),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete, color: Colors.red),
                          onPressed: () async {
                            await context.read<DatabaseService>().updateEquipment(item['name'], false);
                            _loadData();
                          },
                        ),
                      ],
                    ),
                  ),
                );
              }),
            ],
          ),
    );
  }

  Widget _buildAddCustomSection(GeminiService gemini) {
    // ... (This section remains mostly the same, but I'll condense it for the response to focus on the new features)
    return Card(
      color: Colors.grey[100],
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("Add New Gear", style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(labelText: "Name (e.g. Power Rack)", border: OutlineInputBorder(), isDense: true),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                icon: _isAnalyzing 
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)) 
                  : const Icon(Icons.auto_awesome),
                label: const Text("Analyze & Add"),
                onPressed: _isAnalyzing ? null : () async {
                   if (_nameController.text.isEmpty) return;
                   setState(() => _isAnalyzing = true);
                   try {
                     final tags = await gemini.analyzeEquipment(_nameController.text);
                     if (mounted) {
                       setState(() {
                         _aiDetectedTags = tags;
                         _isAnalyzing = false;
                       });
                       await _saveNewItem();
                     }
                   } catch (e) {
                     if (mounted) setState(() => _isAnalyzing = false);
                   }
                },
              ),
            )
          ],
        ),
      ),
    );
  }
}