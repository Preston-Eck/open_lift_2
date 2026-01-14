import 'dart:typed_data'; // For Web Bytes
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../services/ai_equipment_service.dart';
import '../models/attachment.dart';
import '../models/exercise.dart'; // Assuming this exists or similar

class MachineEntryScreen extends StatefulWidget {
  const MachineEntryScreen({super.key});

  @override
  State<MachineEntryScreen> createState() => _MachineEntryScreenState();
}

class _MachineEntryScreenState extends State<MachineEntryScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _modelController = TextEditingController();
  final _notesController = TextEditingController();
  
  List<Attachment> _attachedFiles = [];
  bool _isAnalyzing = false;
  List<String> _identifiedExercises = [];

  Future<void> _pickImage() async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.gallery);
    if (image != null) {
      final bytes = await image.readAsBytes();
      setState(() {
        _attachedFiles.add(Attachment(name: image.name, bytes: bytes, mimeType: image.mimeType ?? 'image/jpeg'));
      });
    }
  }

  Future<void> _pickFile() async {
    // on Web, 'withData: true' is required to get bytes
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom, 
      allowedExtensions: ['pdf', 'jpg', 'png'],
      withData: true
    );
    
    if (result != null) {
      final file = result.files.single;
      setState(() {
        _attachedFiles.add(Attachment(
          name: file.name, 
          bytes: file.bytes, 
          mimeType: 'application/pdf' // Simplified inference
        ));
      });
    }
  }

  Future<void> _analyzeAndCreate() async {
    if (!_formKey.currentState!.validate()) return;
    if (_attachedFiles.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Please attach an image or PDF of the machine.")));
      return;
    }

    setState(() => _isAnalyzing = true);
    
    final service = AiEquipmentService();

    try {
      final results = await service.analyzeEquipment(
        title: _titleController.text,
        model: _modelController.text,
        notes: _notesController.text,
        attachments: _attachedFiles, // Updated Param
      );

      setState(() {
        _identifiedExercises = results;
        _isAnalyzing = false;
      });

      if (results.isEmpty) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("AI could not identify any matching exercises.")));
      } else {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Success! Identified ${results.length} exercises.")));
      }

    } catch (e) {
      setState(() => _isAnalyzing = false);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
    }
  }

  void _saveMachine() {
    // TODO: persist to DB with identified exercises
    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Machine Saved!")));
  }

  @override
  Widget build(BuildContext context) {
    // Dark Theme Config for Readability
    final inputDecor = InputDecoration(
      labelStyle: const TextStyle(color: Colors.white70), 
      hintStyle: const TextStyle(color: Colors.white24),
      enabledBorder: const OutlineInputBorder(borderSide: BorderSide(color: Colors.white24)),
      focusedBorder: const OutlineInputBorder(borderSide: BorderSide(color: Colors.blueAccent)),
      border: const OutlineInputBorder(),
      filled: true,
      fillColor: Colors.grey[900],
    );

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text("Smart Machine Creator", style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.grey[900],
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 1. DETAILS INPUT
              TextFormField(
                controller: _titleController,
                style: const TextStyle(color: Colors.white),
                decoration: inputDecor.copyWith(labelText: "Machine Name"),
                validator: (v) => v!.isEmpty ? "Required" : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _modelController,
                style: const TextStyle(color: Colors.white),
                decoration: inputDecor.copyWith(labelText: "Model / Brand (Optional)"),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _notesController,
                style: const TextStyle(color: Colors.white),
                maxLines: 3,
                decoration: inputDecor.copyWith(labelText: "Description / Notes"),
              ),
              const SizedBox(height: 24),

              // 2. FILE UPLOAD
              const Text("Media & Documents", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: [
                  ..._attachedFiles.map((f) => Chip(
                    label: Text(f.name, style: const TextStyle(fontSize: 12, color: Colors.black)),
                    backgroundColor: Colors.white,
                    deleteIconColor: Colors.red,
                    onDeleted: () => setState(() => _attachedFiles.remove(f)),
                  )),
                  ActionChip(
                    avatar: const Icon(Icons.add_a_photo, color: Colors.blue),
                    label: const Text("Add Photo", style: TextStyle(color: Colors.blue)),
                    backgroundColor: Colors.grey[900],
                    onPressed: _pickImage,
                  ),
                  ActionChip(
                    avatar: const Icon(Icons.file_upload, color: Colors.blue),
                    label: const Text("Add File", style: TextStyle(color: Colors.blue)),
                    backgroundColor: Colors.grey[900],
                    onPressed: _pickFile,
                  ),
                ],
              ),
              const SizedBox(height: 32),

              // 3. AI ACTION
              if (_isAnalyzing)
                const Center(child: CircularProgressIndicator(color: Colors.blueAccent))
              else if (_identifiedExercises.isEmpty)
                ElevatedButton.icon(
                  onPressed: _analyzeAndCreate,
                  icon: const Icon(Icons.auto_awesome),
                  label: const Text("ANALYZE WITH AI"),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blueAccent,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.all(16),
                  ),
                ),

              // 4. RESULTS
              if (_identifiedExercises.isNotEmpty) ...[
                const SizedBox(height: 24),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(color: Colors.green.withOpacity(0.1), borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.green.withOpacity(0.3))),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text("AI Identified Exercises:", style: TextStyle(color: Colors.greenAccent, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      ..._identifiedExercises.map((e) => Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Row(children: [const Icon(Icons.check, color: Colors.green, size: 16), const SizedBox(width: 8), Expanded(child: Text(e, style: const TextStyle(color: Colors.white)))]),
                      )),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: _saveMachine,
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white, padding: const EdgeInsets.all(16)),
                  child: const Text("SAVE MACHINE"),
                )
              ]
            ],
          ),
        ),
      ),
    );
  }
}
