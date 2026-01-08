import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/database_service.dart';

class EditOneRepMaxDialog extends StatefulWidget {
  final String exerciseName;
  final double? currentMax;

  const EditOneRepMaxDialog({super.key, required this.exerciseName, this.currentMax});

  @override
  State<EditOneRepMaxDialog> createState() => _EditOneRepMaxDialogState();
}

class _EditOneRepMaxDialogState extends State<EditOneRepMaxDialog> {
  late TextEditingController _controller;
  bool _isMetric = false;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    final prefs = await SharedPreferences.getInstance();
    final unitSystem = prefs.getString('units') ?? 'Imperial';
    _isMetric = unitSystem == 'Metric';

    double initialValue = 0;
    if (widget.currentMax != null) {
      // Convert stored LBS to display unit if needed
      initialValue = _isMetric ? widget.currentMax! * 0.453592 : widget.currentMax!;
    }

    _controller = TextEditingController(
      text: widget.currentMax != null ? initialValue.toStringAsFixed(1) : ''
    );

    if (mounted) setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Center(child: CircularProgressIndicator());

    final unitLabel = _isMetric ? "kg" : "lbs";

    return AlertDialog(
      title: Text("1RM for ${widget.exerciseName}"),
      content: TextField(
        controller: _controller,
        keyboardType: TextInputType.number,
        decoration: InputDecoration(
          labelText: "Weight ($unitLabel)",
          suffixText: unitLabel,
          border: const OutlineInputBorder(),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
        ElevatedButton(
          onPressed: () {
            final val = double.tryParse(_controller.text);
            if (val != null) {
              // Convert DISPLAY unit back to STORAGE unit (LBS)
              final weightInLbs = _isMetric ? val * 2.20462 : val;
              
              context.read<DatabaseService>().addOneRepMax(widget.exerciseName, weightInLbs);
              Navigator.pop(context);
            }
          },
          child: const Text("Save"),
        )
      ],
    );
  }
}