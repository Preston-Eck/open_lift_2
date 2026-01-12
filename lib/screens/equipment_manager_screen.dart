import 'package:flutter/services.dart'; // For Clipboard

// ... imports below
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import '../services/database_service.dart';
import '../services/sync_service.dart'; // For Auto-Sync
import '../services/gemini_service.dart'; // NEW
import '../config/equipment_bundles.dart';
import '../theme.dart';
import '../widgets/exercise_selection_dialog.dart';
import '../widgets/user_picker_dialog.dart'; // NEW
import '../models/exercise.dart'; // NEW
import '../services/social_service.dart'; // NEW

class EquipmentManagerScreen extends StatefulWidget {
// ... (rest of EquipmentManagerScreen remains the same)
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
  String? _currentGymId; // NEW: Store ID for sharing

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
          _currentGymId = currentGymId; // Set ID
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showShareDialog() {
    if (_currentGymId == null) return;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Share Gym Profile"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text("Share this ID with a friend so they can join this gym and see the equipment."),
            const SizedBox(height: 16),
            SelectableText(
              _currentGymId!,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              icon: const Icon(Icons.copy),
              label: const Text("Copy ID"),
              onPressed: () {
                Clipboard.setData(ClipboardData(text: _currentGymId!));
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Copied to clipboard")));
              },
            ),
            const SizedBox(height: 8),
            ElevatedButton.icon(
              icon: const Icon(Icons.person_add),
              label: const Text("Send to Friend"),
              style: ElevatedButton.styleFrom(backgroundColor: AppTheme.renewalTeal, foregroundColor: Colors.white),
              onPressed: () async {
                final friendId = await showDialog<String>(
                  context: context,
                  builder: (ctx) => const UserPickerDialog(title: "Invite Friend to Gym"),
                );
                if (friendId != null && mounted) {
                  await context.read<SocialService>().sendGymInvite(_currentGymId!, _currentGymName ?? "Shared Gym", friendId);
                  if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Invite Sent!")));
                }
              },
            ),
            const Divider(height: 32),
            const Text("Or join a gym:", style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(ctx);
                _showJoinDialog();
              },
              child: const Text("Join via ID"),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Close")),
        ],
      ),
    );
  }

  void _showJoinDialog() {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Join a Gym"),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(labelText: "Enter Gym ID", border: OutlineInputBorder()),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancel")),
          ElevatedButton(
            onPressed: () async {
              if (controller.text.isNotEmpty) {
                final syncService = context.read<SyncService>(); // Get service before async
                try {
                  await syncService.joinGym(controller.text.trim());
                  if (ctx.mounted) { // Check ctx (dialog context) or use 'mounted'
                    Navigator.pop(ctx);
                  }
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Successfully Joined Gym!")));
                    _loadData();
                  }
                } catch (e) {
                  if (mounted) {
                     ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e"), backgroundColor: Colors.red));
                  }
                }
              }
            },
            child: const Text("Join"),
          ),
        ],
      ),
    );
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
        actions: [
          IconButton(
            icon: const Icon(Icons.share, color: AppTheme.renewalTeal),
            onPressed: _showShareDialog,
          ),
        ],
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
  bool _isAnalyzing = false;

  // Vision State
  File? _selectedFile;
  String? _mimeType;

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

  Future<void> _pickImage(ImageSource source) async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: source);
    if (pickedFile != null) {
      // Compress Image
      final targetPath = "${pickedFile.path}_compressed.jpg";
      final result = await FlutterImageCompress.compressAndGetFile(
        pickedFile.path,
        targetPath,
        quality: 50, // High compression for AI analysis
      );

      if (result != null) {
        setState(() {
          _selectedFile = File(result.path);
          _mimeType = 'image/jpeg';
        });
      }
    }
  }

  Future<void> _pickPDF() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
    );
    if (result != null && result.files.single.path != null) {
      setState(() {
        _selectedFile = File(result.files.single.path!);
        _mimeType = 'application/pdf';
      });
    }
  }

  Future<void> _runAIAnalysis() async {
    if (_nameController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Please enter equipment name first")));
      return;
    }

    setState(() => _isAnalyzing = true);
    
    try {
      final gemini = context.read<GeminiService>();
      List<DataPart>? mediaParts;
      
      if (_selectedFile != null && _mimeType != null) {
        final bytes = await _selectedFile!.readAsBytes();
        mediaParts = [DataPart(_mimeType!, bytes)];
      }

      final result = await gemini.analyzeEquipmentVision(
        itemName: _nameController.text,
        mediaParts: mediaParts,
      );

      // Parse Result
      final List<dynamic> caps = result['capabilities'] ?? [];
      final List<dynamic> exes = result['exercises'] ?? [];

      setState(() {
        for (var c in caps) {
          if (allGenericEquipment.contains(c)) _selectedCapabilities.add(c.toString());
        }
        
        // Convert suggested exercises to local Exercises and save them
        _specificExercises.addAll(exes.map((e) => e['name'].toString()));
      });

      // Auto-save new exercises to DB
      final db = context.read<DatabaseService>();
      for (var e in exes) {
         final newEx = Exercise(
           id: const Uuid().v4(),
           name: e['name'],
           category: e['category'],
           primaryMuscles: List<String>.from(e['primary_muscles'] ?? []),
           secondaryMuscles: [],
           equipment: [_nameController.text],
           instructions: List<String>.from(e['instructions'] ?? []),
           images: [],
         );
         await db.addCustomExercise(newEx);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("AI Found ${exes.length} exercises!")));
      }

    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("AI Error: $e")));
    } finally {
      if (mounted) setState(() => _isAnalyzing = false);
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

    await db.updateEquipmentCapabilities(_nameController.text, finalCapabilities);
    
    if (widget.item == null) {
      final gymId = db.currentGymId;
      if (gymId != null) await db.toggleGymEquipment(gymId, _nameController.text, true);
    }
    
    sync.syncAll();
    if (mounted) Navigator.pop(context);
  }

  Future<void> _delete() async {
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
      setState(() => _specificExercises.add(selectedName));
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
              enabled: widget.item == null, 
            ),
            const SizedBox(height: 20),

            // --- VISION SECTION ---
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.renewalTeal.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppTheme.renewalTeal.withValues(alpha: 0.2)),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      const Icon(Icons.auto_awesome, color: AppTheme.renewalTeal),
                      const SizedBox(width: 8),
                      const Text("AI Automated Setup", style: TextStyle(fontWeight: FontWeight.bold)),
                      const Spacer(),
                      if (_isAnalyzing) const CircularProgressIndicator(strokeWidth: 2),
                    ],
                  ),
                  const SizedBox(height: 12),
                  const Text("Upload a photo or PDF manual to automatically identify capabilities and exercises.", style: TextStyle(fontSize: 12)),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _MediaButton(icon: Icons.camera_alt, label: "Photo", onTap: () => _pickImage(ImageSource.camera)),
                      _MediaButton(icon: Icons.photo_library, label: "Gallery", onTap: () => _pickImage(ImageSource.gallery)),
                      _MediaButton(icon: Icons.picture_as_pdf, label: "PDF", onTap: _pickPDF),
                    ],
                  ),
                  if (_selectedFile != null) ...[
                    const SizedBox(height: 12),
                    Text("Selected: ${_selectedFile!.path.split('/').last}", style: const TextStyle(fontSize: 11, color: Colors.blue)),
                  ],
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.analytics),
                      label: const Text("ANALYZE WITH AI"),
                      style: ElevatedButton.styleFrom(backgroundColor: AppTheme.renewalTeal, foregroundColor: Colors.white),
                      onPressed: _isAnalyzing ? null : _runAIAnalysis,
                    ),
                  ),
                ],
              ),
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
                      if (val) _selectedCapabilities.add(tag);
                      else _selectedCapabilities.remove(tag);
                    });
                  },
                );
              }).toList(),
            ),

            const SizedBox(height: 30),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text("Linked Exercises", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                TextButton.icon(onPressed: _addSpecificExercise, icon: const Icon(Icons.add), label: const Text("Add")),
              ],
            ),
            if (_specificExercises.isEmpty)
              const Text("No exercises linked.", style: TextStyle(color: Colors.grey, fontStyle: FontStyle.italic))
            else
              ..._specificExercises.map((exName) => Card(
                child: ListTile(
                  dense: true,
                  title: Text(exName),
                  trailing: IconButton(icon: const Icon(Icons.close, size: 16), onPressed: () => setState(() => _specificExercises.remove(exName))),
                ),
              )),
          ],
        ),
      ),
    );
  }
}

class _MediaButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _MediaButton({required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        IconButton.filledTonal(onPressed: onTap, icon: Icon(icon), color: AppTheme.renewalTeal),
        Text(label, style: const TextStyle(fontSize: 10)),
      ],
    );
  }
}