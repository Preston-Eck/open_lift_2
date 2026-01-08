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
  List<String> _aiDetectedTags = []; 
  bool _isAnalyzing = false;
  bool _isLoading = true;

  List<Map<String, dynamic>> _ownedItems = [];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    if (!mounted) return;
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
    if (!mounted) return;
    final db = context.read<DatabaseService>();
    final name = _nameController.text;
    if (name.isEmpty) return;

    await db.updateEquipmentCapabilities(name, _aiDetectedTags);
    
    if (mounted) {
      setState(() {
        _nameController.clear();
        _aiDetectedTags = [];
      });
      await _loadData(); // Refresh list
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Added $name!")));
      }
    }
  }

  void _openEditor(Map<String, dynamic> item) async {
    // STABILITY FIX: Use full screen navigation instead of Dialogs
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => EquipmentEditorScreen(item: item)),
    );
    _loadData(); // Refresh on return
  }

  @override
  Widget build(BuildContext context) {
    final gemini = Provider.of<GeminiService>(context, listen: false);

    return Scaffold(
      appBar: AppBar(title: const Text("Manage Equipment")),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator()) 
        : SingleChildScrollView( 
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                _buildAddCustomSection(gemini),
                const Divider(height: 30),
                if (_ownedItems.isEmpty)
                  const Center(child: Text("Your gym is empty.", style: TextStyle(color: Colors.grey))),
                
                ..._ownedItems.map((item) {
                  final tagsJson = item['capabilities_json'];
                  final tags = tagsJson != null ? List<String>.from(jsonDecode(tagsJson)) : <String>[];
                  
                  return Card(
                    key: ValueKey("eq_${item['name']}"), 
                    margin: const EdgeInsets.only(bottom: 8),
                    child: ListTile(
                      title: Text(item['name'], style: const TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Text(tags.take(5).join(", ") + (tags.length > 5 ? "..." : ""), style: const TextStyle(fontSize: 12)),
                      onTap: () => _openEditor(item), // Tap whole row to edit
                      trailing: IconButton(
                        icon: const Icon(Icons.delete, color: Colors.red),
                        onPressed: () async {
                          await context.read<DatabaseService>().updateEquipment(item['name'], false);
                          _loadData();
                        },
                      ),
                    ),
                  );
                }),
                const SizedBox(height: 40),
              ],
            ),
          ),
    );
  }

  Widget _buildAddCustomSection(GeminiService gemini) {
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

// --- FULL SCREEN EDITOR (STABLE) ---
class EquipmentEditorScreen extends StatefulWidget {
  final Map<String, dynamic> item;
  const EquipmentEditorScreen({super.key, required this.item});

  @override
  State<EquipmentEditorScreen> createState() => _EquipmentEditorScreenState();
}

class _EquipmentEditorScreenState extends State<EquipmentEditorScreen> {
  late List<String> _tags;

  @override
  void initState() {
    super.initState();
    final json = widget.item['capabilities_json'];
    _tags = json != null ? List<String>.from(jsonDecode(json)) : [];
    if (_tags.isEmpty) _tags.add(widget.item['name']);
  }

  Future<void> _save() async {
    final db = context.read<DatabaseService>();
    await db.updateEquipmentCapabilities(widget.item['name'], _tags);
    if (mounted) Navigator.pop(context);
  }

  Future<void> _linkExercise() async {
    // Navigate to Search Screen
    final Exercise? result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const EquipmentSearchScreen()),
    );

    if (result != null) {
      setState(() {
        for (var t in result.equipment) {
          if (!_tags.contains(t)) _tags.add(t);
        }
        if (!_tags.contains(result.name)) _tags.add(result.name); // Add exercise name itself if equipment list is empty
      });
    }
  }

  void _addManualTag() {
    // Simple dialogs for text input are usually fine, but let's be safe
    final textC = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Add Tag"),
        content: TextField(controller: textC, autofocus: true),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancel")),
          ElevatedButton(
            onPressed: () {
              if (textC.text.isNotEmpty) {
                setState(() => _tags.add(textC.text));
              }
              Navigator.pop(ctx);
            }, 
            child: const Text("Add")
          )
        ],
      )
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Edit ${widget.item['name']}"),
        actions: [
          IconButton(icon: const Icon(Icons.save), onPressed: _save)
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("Capabilities define what exercises this machine can perform.", style: TextStyle(color: Colors.grey)),
            const SizedBox(height: 20),
            
            const Text("Current Tags", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _tags.map((t) => Chip(
                label: Text(t),
                deleteIcon: const Icon(Icons.close, size: 18),
                onDeleted: () => setState(() => _tags.remove(t)),
              )).toList(),
            ),
            
            const SizedBox(height: 30),
            const Divider(),
            const SizedBox(height: 10),
            
            const Text("Add Capabilities", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 10),
            ListTile(
              leading: const CircleAvatar(child: Icon(Icons.edit)),
              title: const Text("Manual Entry"),
              subtitle: const Text("Type a capability tag manually"),
              onTap: _addManualTag,
            ),
            ListTile(
              leading: const CircleAvatar(child: Icon(Icons.search)),
              title: const Text("Infer from Exercise"),
              subtitle: const Text("Search an exercise (e.g. 'Lat Pulldown') to auto-add its tags"),
              onTap: _linkExercise,
            ),
          ],
        ),
      ),
    );
  }
}

// --- FULL SCREEN SEARCH (STABLE) ---
class EquipmentSearchScreen extends StatefulWidget {
  const EquipmentSearchScreen({super.key});

  @override
  State<EquipmentSearchScreen> createState() => _EquipmentSearchScreenState();
}

class _EquipmentSearchScreenState extends State<EquipmentSearchScreen> {
  final TextEditingController _ctrl = TextEditingController();
  List<Exercise> _results = [];
  bool _searching = false;

  Future<void> _doSearch() async {
    if (_ctrl.text.isEmpty) return;
    setState(() => _searching = true);
    
    try {
      final data = await Supabase.instance.client
          .from('exercises')
          .select()
          .ilike('name', '%${_ctrl.text}%')
          .limit(15);
      
      if (mounted) {
        setState(() {
          _results = (data as List).map((e) => Exercise.fromJson(e)).toList();
          _searching = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _searching = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: TextField(
          controller: _ctrl,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: "Search Exercise...",
            border: InputBorder.none,
          ),
          onSubmitted: (_) => _doSearch(),
        ),
        actions: [
          IconButton(icon: const Icon(Icons.search), onPressed: _doSearch)
        ],
      ),
      body: _searching 
        ? const LinearProgressIndicator() 
        : ListView.separated(
            itemCount: _results.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (ctx, i) {
              final ex = _results[i];
              return ListTile(
                title: Text(ex.name),
                subtitle: Text(ex.equipment.join(", ")),
                onTap: () => Navigator.pop(context, ex),
              );
            },
          ),
    );
  }
}