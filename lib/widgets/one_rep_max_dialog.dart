import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
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

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(
      text: widget.currentMax != null ? widget.currentMax.toString() : ''
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text("1RM for ${widget.exerciseName}"),
      content: TextField(
        controller: _controller,
        keyboardType: TextInputType.number,
        decoration: const InputDecoration(
          labelText: "Weight (lbs)",
          suffixText: "lbs",
          border: OutlineInputBorder(),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
        ElevatedButton(
          onPressed: () {
            final val = double.tryParse(_controller.text);
            if (val != null) {
              context.read<DatabaseService>().updateOneRepMax(widget.exerciseName, val);
              Navigator.pop(context);
            }
          },
          child: const Text("Save"),
        )
      ],
    );
  }
}