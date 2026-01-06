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
  Set<String> _localOwned = {};

  @override
  void initState() {
    super.initState();
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
    
    db.updateEquipment(item, isOwned);
  }

  void _applyBundle(EquipmentBundle bundle) {
    final db = context.read<DatabaseService>();
    setState(() {
      _localOwned.addAll(bundle.equipmentTags);
    });
    
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
          const Text("Quick Setup (Bundles)", 
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.blueAccent)),
          const SizedBox(height: 10),
          ...equipmentBundles.map((bundle) => Card(
            child: ListTile(
              title: Text(bundle.name),
              subtitle: Text(bundle.description),
              // FIX: Constrained width to prevent layout crash
              trailing: SizedBox(
                width: 100, 
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    padding: EdgeInsets.zero,
                    minimumSize: const Size(0, 36), // Compact button
                  ),
                  onPressed: () => _applyBundle(bundle),
                  child: const Text("Add All", style: TextStyle(fontSize: 12)),
                ),
              ),
            ),
          )),

          const Divider(height: 40),

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
                // FIX: Use withValues to fix deprecation warning
                selectedColor: Colors.green.withValues(alpha: 0.3),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}