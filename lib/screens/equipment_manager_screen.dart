// lib/screens/equipment_manager_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/database_service.dart';
import '../config/equipment_bundles.dart';

class EquipmentManagerScreen extends StatefulWidget {
  const EquipmentManagerScreen({super.key});

  @override
  State<EquipmentManagerScreen> createState() => _EquipmentManagerScreenState();
}

class _EquipmentManagerScreenState extends State<EquipmentManagerScreen> {
  // We keep a local set of selected IDs for instant UI feedback
  Set<String> _localOwned = {};

  @override
  void initState() {
    super.initState();
    // Load initial state
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final db = context.read<DatabaseService>();
      final owned = await db.getOwnedEquipment();
      setState(() {
        _localOwned = owned.toSet();
      });
    });
  }

  void _toggleItem(String item) {
    final db = context.read<DatabaseService>();
    final isOwned = !_localOwned.contains(item);
    
    setState(() {
      if (isOwned) {
        _localOwned.add(item);
      } else {
        _localOwned.remove(item);
      }
    });
    
    // Save to SQLite
    db.updateEquipment(item, isOwned);
  }

  void _applyBundle(EquipmentBundle bundle) {
    final db = context.read<DatabaseService>();
    setState(() {
      _localOwned.addAll(bundle.equipmentTags);
    });
    
    // Save all tags in the bundle
    for (var tag in bundle.equipmentTags) {
      db.updateEquipment(tag, true);
    }
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text("Applied ${bundle.name} bundle!")),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Manage Equipment")),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          // Section 1: Quick Bundles
          const Text("Quick Setup (Bundles)", 
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.blueAccent)),
          const SizedBox(height: 10),
          ...equipmentBundles.map((bundle) => Card(
            child: ListTile(
              title: Text(bundle.name),
              subtitle: Text(bundle.description),
              trailing: ElevatedButton(
                onPressed: () => _applyBundle(bundle),
                child: const Text("Add All"),
              ),
            ),
          )),

          const Divider(height: 40),

          // Section 2: Individual Items
          const Text("Individual Items", 
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8.0,
            runSpacing: 4.0,
            children: allGenericEquipment.map((item) {
              final isSelected = _localOwned.contains(item);
              return FilterChip(
                label: Text(item),
                selected: isSelected,
                onSelected: (_) => _toggleItem(item),
                checkmarkColor: Colors.white,
                selectedColor: Colors.green.withOpacity(0.3),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}