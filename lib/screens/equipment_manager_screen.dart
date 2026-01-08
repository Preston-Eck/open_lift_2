import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/database_service.dart';
import '../models/exercise.dart';
import '../config/equipment_bundles.dart';
import '../theme.dart';

class EquipmentManagerScreen extends StatefulWidget {
  const EquipmentManagerScreen({super.key});

  @override
  State<EquipmentManagerScreen> createState() => _EquipmentManagerScreenState();
}

class _EquipmentManagerScreenState extends State<EquipmentManagerScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isLoading = true;
  
  // Data
  Set<String> _ownedStandardItems = {};
  List<Map<String, dynamic>> _customItems = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadData();
  }

  Future<void> _loadData() async {
    if (!mounted) return;
    final db = context.read<DatabaseService>();
    try {
      final allItems = await db.getUserEquipmentList();
      
      final Set<String> standardSet = {};
      final List<Map<String, dynamic>> customList = [];

      for (var item in allItems) {
        final name = item['name'] as String;
        final isOwned = (item['is_owned'] as int) == 1;

        if (allGenericEquipment.contains(name)) {
          if (isOwned) standardSet.add(name);
        } else if (isOwned) {
          customList.add(item);
        }
      }

      if (mounted) {
        setState(() {
          _ownedStandardItems = standardSet;
          _customItems = customList;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _toggleStandardItem(String name, bool value) async {
    setState(() {
      if (value) {
        _ownedStandardItems.add(name);
      } else {
        _ownedStandardItems.remove(name);
      }
    });
    // Fire and forget DB update
    await context.read<DatabaseService>().updateEquipment(name, value);
  }

  void _openCustomEditor([Map<String, dynamic>? item]) async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => ComplexEquipmentEditor(item: item)),
    );
    _loadData();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Manage Equipment"),
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppTheme.renewalTeal,
          unselectedLabelColor: Colors.grey,
          indicatorColor: AppTheme.renewalTeal,
          tabs: const [
            Tab(text: "Standard Checklist"),
            Tab(text: "Custom & Machines"),
          ],
        ),
      ),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator()) 
        : TabBarView(
            controller: _tabController,
            children: [
              _buildStandardTab(),
              _buildCustomTab(),
            ],
          ),
    );
  }

  Widget _buildStandardTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Card(
          color: AppTheme.clarityCream,
          child: Padding(
            padding: EdgeInsets.all(12.0),
            child: Text(
              "Select individual items you own. These are automatically used by the AI Coach.",
              style: TextStyle(fontSize: 14, color: AppTheme.foundationalSlate),
            ),
          ),
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: allGenericEquipment.map((tag) {
            final isSelected = _ownedStandardItems.contains(tag);
            return FilterChip(
              label: Text(tag),
              selected: isSelected,
              selectedColor: AppTheme.renewalTeal.withValues(alpha: 0.2),
              checkmarkColor: AppTheme.renewalTeal,
              onSelected: (val) => _toggleStandardItem(tag, val),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildCustomTab() {
    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openCustomEditor(),
        label: const Text("Add Custom Gear"),
        icon: const Icon(Icons.add),
        backgroundColor: AppTheme.motivationCoral,
        foregroundColor: Colors.white,
      ),
      body: _customItems.isEmpty
          ? const Center(child: Text("No custom equipment added.\nUse this for Home Gyms, Machines, etc.", textAlign: TextAlign.center, style: TextStyle(color: Colors.grey)))
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _customItems.length,
              itemBuilder: (context, index) {
                final item = _customItems[index];
                final tagsJson = item['capabilities_json'];
                final tags = tagsJson != null ? List<String>.from(jsonDecode(tagsJson)) : <String>[];

                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  child: ListTile(
                    title: Text(item['name'], style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text(
                      tags.isEmpty ? "No capabilities set" : "Enable: ${tags.take(4).join(', ')}${tags.length > 4 ? '...' : ''}",
                      maxLines: 1, 
                      overflow: TextOverflow.ellipsis
                    ),
                    trailing: const Icon(Icons.edit, size: 20, color: Colors.grey),
                    onTap: () => _openCustomEditor(item),
                  ),
                );
              },
            ),
    );
  }
}

class ComplexEquipmentEditor extends StatefulWidget {
  final Map<String, dynamic>? item;
  const ComplexEquipmentEditor({super.key, this.item});

  @override
  State<ComplexEquipmentEditor> createState() => _ComplexEquipmentEditorState();
}

class _ComplexEquipmentEditorState extends State<ComplexEquipmentEditor> {
  final _nameController = TextEditingController();
  final Set<String> _selectedCapabilities = {};
  
  // Separate list for specific exercises that are NOT standard tags
  final List<String> _specificExercises = []; 

  @override
  void initState() {
    super.initState();
    if (widget.item != null) {
      _nameController.text = widget.item!['name'];
      final json = widget.item!['capabilities_json'];
      if (json != null) {
        final List<String> allTags = List<String>.from(jsonDecode(json));
        
        for (var tag in allTags) {
          if (allGenericEquipment.contains(tag)) {
            _selectedCapabilities.add(tag);
          } else if (tag != widget.item!['name']) {
            // It's a specific exercise or custom tag
            _specificExercises.add(tag);
          }
        }
      }
    }
  }

  Future<void> _save() async {
    if (_nameController.text.isEmpty) return;

    final db = context.read<DatabaseService>();
    
    // Combine standard caps + specific exercises into one list for the DB
    final List<String> finalCapabilities = [
      ..._selectedCapabilities,
      ..._specificExercises,
      _nameController.text // Include self
    ].toSet().toList(); // De-dupe

    await db.updateEquipmentCapabilities(_nameController.text, finalCapabilities);
    if (mounted) Navigator.pop(context);
  }

  Future<void> _delete() async {
    if (widget.item != null) {
      await context.read<DatabaseService>().updateEquipment(widget.item!['name'], false);
    }
    if (mounted) Navigator.pop(context);
  }

  Future<void> _addSpecificExercise() async {
    // This assumes EquipmentSearchScreen from a previous iteration is available or needs to be included.
    // If it was lost, we need to add it back to this file or import it.
    // For now, I will include a basic Search Dialog here to keep it self-contained.
    
    // Using a simpler approach than navigating to a full screen for now to reduce dependency complexity
    final controller = TextEditingController();
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Add Specific Exercise"),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(hintText: "e.g. Lat Pulldown"),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancel")),
          ElevatedButton(
            onPressed: () {
               if (controller.text.isNotEmpty) {
                 Navigator.pop(ctx);
                 setState(() {
                   _specificExercises.add(controller.text);
                 });
               }
            },
            child: const Text("Add"),
          )
        ],
      )
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.item == null ? "Add Custom Gear" : "Edit Gear"),
        actions: [
          if (widget.item != null)
            IconButton(icon: const Icon(Icons.delete, color: AppTheme.errorRed), onPressed: _delete),
          IconButton(icon: const Icon(Icons.save), onPressed: _save),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: "Equipment Name", 
                hintText: "e.g. Major Lutie Power Cage",
                border: OutlineInputBorder()
              ),
            ),
            const SizedBox(height: 24),

            // 1. Standard Capabilities
            const Text("What functions does this provide?", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 8),
            const Text("Select standard equipment that this machine replaces or includes.", style: TextStyle(color: Colors.grey, fontSize: 12)),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: allGenericEquipment.map((tag) {
                final isSelected = _selectedCapabilities.contains(tag);
                return FilterChip(
                  label: Text(tag),
                  selected: isSelected,
                  onSelected: (val) {
                    setState(() {
                      if (val) _selectedCapabilities.add(tag);
                      else _selectedCapabilities.remove(tag);
                    });
                  },
                );
              }).toList(),
            ),

            const SizedBox(height: 30),

            // 2. Specific Exercises
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text("Specific Exercises", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                TextButton.icon(
                  onPressed: _addSpecificExercise, 
                  icon: const Icon(Icons.add), 
                  label: const Text("Add")
                ),
              ],
            ),
            const Text("Add exercises you know can be performed on this machine.", style: TextStyle(color: Colors.grey, fontSize: 12)),
            const SizedBox(height: 10),
            
            if (_specificExercises.isEmpty)
              Container(
                padding: const EdgeInsets.all(16),
                width: double.infinity,
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.withValues(alpha: 0.3)),
                  borderRadius: BorderRadius.circular(8)
                ),
                child: const Text("No specific exercises linked.", style: TextStyle(color: Colors.grey, fontStyle: FontStyle.italic)),
              )
            else
              ..._specificExercises.map((exName) => Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  dense: true,
                  title: Text(exName),
                  trailing: IconButton(
                    icon: const Icon(Icons.close, size: 16),
                    onPressed: () => setState(() => _specificExercises.remove(exName)),
                  ),
                ),
              )),
          ],
        ),
      ),
    );
  }
}