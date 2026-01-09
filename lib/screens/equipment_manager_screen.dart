import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/database_service.dart';
import '../services/sync_service.dart'; // For Auto-Sync
import '../config/equipment_bundles.dart';
import '../theme.dart';
import '../widgets/exercise_selection_dialog.dart';

class EquipmentManagerScreen extends StatefulWidget {
  const EquipmentManagerScreen({super.key});

  @override
  State<EquipmentManagerScreen> createState() => _EquipmentManagerScreenState();
}

class _EquipmentManagerScreenState extends State<EquipmentManagerScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isLoading = true;
  
  Set<String> _gymEnabledItems = {}; // Changed from _ownedStandardItems
  List<Map<String, dynamic>> _customItems = [];
  String? _currentGymName; // Displayed for context

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
      // 1. Get Current Gym Context
      final gymProfiles = await db.getGymProfiles();
      final currentGymId = db.currentGymId ?? (gymProfiles.isNotEmpty ? gymProfiles.firstWhere((g) => g.isDefault).id : null);
      
      if (currentGymId == null) {
        if (mounted) setState(() => _isLoading = false);
        return;
      }

      final currentGym = gymProfiles.firstWhere((g) => g.id == currentGymId);
      
      // 2. Get Items Enabled in THIS Gym (IDs)
      final enabledIds = await db.getGymItemIds(currentGymId);
      final enabledSet = enabledIds.toSet();

      // 3. Get All Custom Items (Global) to display in the list
      final allItems = await db.getUserEquipmentList();
      final List<Map<String, dynamic>> customList = [];

      for (var item in allItems) {
        final name = item['name'] as String;
        // If it's NOT a standard tag, it's a custom item/machine
        if (!allGenericEquipment.contains(name)) {
          // Add 'isEnabled' flag for UI
          final map = Map<String, dynamic>.from(item);
          map['isEnabledInGym'] = enabledSet.contains(item['id']);
          customList.add(map);
        }
      }

      if (mounted) {
        setState(() {
          _gymEnabledItems = enabledSet;
          _customItems = customList;
          _currentGymName = currentGym.name;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _toggleStandardItem(String name, bool value) async {
    final db = context.read<DatabaseService>();
    final gymId = db.currentGymId;
    if (gymId == null) return;

    setState(() {
      if (value) {
        _gymEnabledItems.add(name); // For standard items, ID = Name
      } else {
        _gymEnabledItems.remove(name);
      }
    });
    
    // Update Gym Junction Table
    await db.toggleGymEquipment(gymId, name, value);
    
    // Auto-Sync
    if (mounted) context.read<SyncService>().syncAll();
  }

  void _openCustomEditor([Map<String, dynamic>? item]) async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => ComplexEquipmentEditor(item: item)),
    );
    _loadData();
  }

  void _toggleCustomItem(String id, bool value) async {
    final db = context.read<DatabaseService>();
    final gymId = db.currentGymId;
    if (gymId == null) return;

    setState(() {
      // Optimistic Update
      final index = _customItems.indexWhere((i) => i['id'] == id);
      if (index != -1) {
        _customItems[index]['isEnabledInGym'] = value;
      }
    });

    await db.toggleGymEquipment(gymId, id, value);
    if (mounted) context.read<SyncService>().syncAll();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("Manage Equipment", style: TextStyle(fontSize: 18)),
            if (_currentGymName != null)
              Text("Editing: $_currentGymName", style: const TextStyle(fontSize: 12, color: Colors.grey)),
          ],
        ),
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppTheme.renewalTeal,
          unselectedLabelColor: Colors.grey,
          indicatorColor: AppTheme.renewalTeal,
          tabs: const [
            Tab(text: "Checklist"),
            Tab(text: "Machines"),
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
              "Select items available at this specific location.",
              style: TextStyle(fontSize: 14, color: AppTheme.foundationalSlate),
            ),
          ),
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: allGenericEquipment.map((tag) {
            final isSelected = _gymEnabledItems.contains(tag);
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
        label: const Text("Create New"),
        icon: const Icon(Icons.add),
        backgroundColor: AppTheme.motivationCoral,
        foregroundColor: Colors.white,
      ),
      body: _customItems.isEmpty
          ? const Center(child: Text("No custom equipment created.", style: TextStyle(color: Colors.grey)))
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _customItems.length,
              itemBuilder: (context, index) {
                final item = _customItems[index];
                final isEnabled = item['isEnabledInGym'] as bool;
                final tagsJson = item['capabilities_json'];
                final List<String> tags = tagsJson != null 
                    ? (jsonDecode(tagsJson) as List).map((e) => e.toString()).toList()
                    : [];

                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  // Visual indication if enabled/disabled
                  color: isEnabled ? Colors.white : Colors.grey[100],
                  child: SwitchListTile(
                    title: Text(
                      item['name'], 
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: isEnabled ? Colors.black : Colors.grey
                      )
                    ),
                    subtitle: Text(
                      tags.isEmpty ? "No capabilities" : tags.take(4).join(', '),
                      maxLines: 1, 
                      overflow: TextOverflow.ellipsis
                    ),
                    value: isEnabled,
                    // FIXED: Replaced deprecated activeColor
                    activeTrackColor: AppTheme.renewalTeal,
                    onChanged: (val) => _toggleCustomItem(item['id'], val),
                    secondary: IconButton(
                      icon: const Icon(Icons.edit, size: 20, color: Colors.grey),
                      onPressed: () => _openCustomEditor(item),
                    ),
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
  final List<String> _specificExercises = []; 

  @override
  void initState() {
    super.initState();
    if (widget.item != null) {
      _nameController.text = widget.item!['name'];
      final json = widget.item!['capabilities_json'];
      if (json != null) {
        final List<String> allTags = (jsonDecode(json) as List).map((e) => e.toString()).toList();
        for (var tag in allTags) {
          if (allGenericEquipment.contains(tag)) {
            _selectedCapabilities.add(tag);
          } else if (tag != widget.item!['name']) {
            _specificExercises.add(tag);
          }
        }
      }
    }
  }

  Future<void> _save() async {
    if (_nameController.text.isEmpty) return;

    final db = context.read<DatabaseService>();
    final sync = context.read<SyncService>();
    
    final List<String> finalCapabilities = {
      ..._selectedCapabilities,
      ..._specificExercises,
      _nameController.text 
    }.toList();

    // 1. Update Global Definition
    // (Note: We use updateEquipmentCapabilities which manages the 'user_equipment' table)
    await db.updateEquipmentCapabilities(_nameController.text, finalCapabilities);
    
    // 2. If it's a NEW item (or not passed in), auto-enable it for the current gym
    // (Assumes updateEquipmentCapabilities creates it if missing, which it does)
    if (widget.item == null) {
      final gymId = db.currentGymId;
      if (gymId != null) {
        // Need to find the ID. Since updateEquipmentCapabilities uses name as ID for standard or existing logic,
        // we need to be careful.
        // Actually, user_equipment IDs are typically names for standard, but UUIDs for custom?
        // Your existing DatabaseService.updateEquipmentCapabilities uses:
        // where: 'id = ?', whereArgs: [name]
        // This implies for Custom items you are using the Name as the ID? 
        // If so, we can use the name. If not, we need the UUID.
        // Looking at DatabaseService: updateEquipment inserts with 'id': name.
        // So ID = Name currently.
        await db.toggleGymEquipment(gymId, _nameController.text, true);
      }
    }
    
    sync.syncAll();
    if (mounted) Navigator.pop(context);
  }

  Future<void> _delete() async {
    // Soft delete or remove? Currently just disables ownership globally.
    if (widget.item != null) {
      await context.read<DatabaseService>().updateEquipment(widget.item!['name'], false);
      if (mounted) context.read<SyncService>().syncAll();
    }
    if (mounted) Navigator.pop(context);
  }

  Future<void> _addSpecificExercise() async {
    final String? selectedName = await showDialog<String>(
      context: context,
      builder: (ctx) => const ExerciseSelectionDialog(),
    );

    if (selectedName != null && selectedName.isNotEmpty) {
      setState(() {
        _specificExercises.add(selectedName);
      });
    }
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
              // Disable editing ID (Name) for existing items to prevent breaking links
              enabled: widget.item == null, 
            ),
            const SizedBox(height: 24),

            const Text("What functions does this provide?", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
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
                      if (val) {
                        _selectedCapabilities.add(tag);
                      } else {
                        _selectedCapabilities.remove(tag);
                      }
                    });
                  },
                );
              }).toList(),
            ),
            // ... (Rest of UI same as before) ...
             const SizedBox(height: 30),

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