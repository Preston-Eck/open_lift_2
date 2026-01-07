import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart'; 
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/exercise.dart';
import '../services/database_service.dart';
import '../widgets/one_rep_max_dialog.dart';
import 'strength_profile_screen.dart';

class ExerciseDetailScreen extends StatefulWidget {
  final Exercise exercise;

  const ExerciseDetailScreen({super.key, required this.exercise});

  @override
  State<ExerciseDetailScreen> createState() => _ExerciseDetailScreenState();
}

class _ExerciseDetailScreenState extends State<ExerciseDetailScreen> {
  // Vitality Rise Colors
  static const Color renewalTeal = Color(0xFF2A9D8F);
  static const Color motivationCoral = Color(0xFFE76F51);
  static const Color clarityCream = Color(0xFFF8F9FA);
  static const Color textDark = Color(0xFF264653);

  String? _currentAlias;

  @override
  void initState() {
    super.initState();
    _loadAlias();
  }

  Future<void> _loadAlias() async {
    final db = context.read<DatabaseService>();
    final aliases = await db.getAliases();
    if (mounted) {
      setState(() {
        _currentAlias = aliases[widget.exercise.name];
      });
    }
  }

  void _showRenameDialog() {
    final controller = TextEditingController(text: _currentAlias ?? widget.exercise.name);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Rename Exercise"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text("Set a local nickname for this exercise. The original name will still be used for tracking."),
            const SizedBox(height: 10),
            TextField(
              controller: controller,
              decoration: const InputDecoration(labelText: "Nickname", border: OutlineInputBorder()),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () async {
              // Reset to original
              await context.read<DatabaseService>().removeAlias(widget.exercise.name);
              
              // Safety check for State before calling internal method
              if (!mounted) return;
              await _loadAlias();
              
              // Safety check for Dialog Context before popping
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: const Text("Reset Default", style: TextStyle(color: Colors.red)),
          ),
          ElevatedButton(
            onPressed: () async {
              await context.read<DatabaseService>().setExerciseAlias(widget.exercise.name, controller.text);
              
              if (!mounted) return;
              await _loadAlias();
              
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: const Text("Save"),
          ),
        ],
      ),
    );
  }

  String _getImageUrl(String path) {
    if (path.startsWith('http')) return path;
    
    final supabaseUrl = dotenv.env['SUPABASE_URL'];
    if (supabaseUrl == null || supabaseUrl.isEmpty) {
      debugPrint("Error: SUPABASE_URL is missing in .env");
      return ""; 
    }

    final baseUrl = supabaseUrl.endsWith('/') ? supabaseUrl : "$supabaseUrl/";
    final cleanPath = path.startsWith('/') ? path.substring(1) : path;
    return "${baseUrl}storage/v1/object/public/exercises/$cleanPath"; 
  }

  @override
  Widget build(BuildContext context) {
    // Determine display name
    final displayName = _currentAlias ?? widget.exercise.name;
    final isAliased = _currentAlias != null && _currentAlias != widget.exercise.name;

    return Scaffold(
      backgroundColor: clarityCream,
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              displayName,
              style: GoogleFonts.poppins(fontWeight: FontWeight.w600, color: Colors.white, fontSize: 18),
            ),
            if (isAliased)
              Text(
                widget.exercise.name,
                style: GoogleFonts.inter(color: Colors.white70, fontSize: 12),
              ),
          ],
        ),
        backgroundColor: renewalTeal,
        iconTheme: const IconThemeData(color: Colors.white),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.edit),
            onPressed: _showRenameDialog,
            tooltip: "Rename Exercise",
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // --- Media Section ---
            if (widget.exercise.images.isNotEmpty)
              Container(
                height: 280,
                width: double.infinity,
                decoration: const BoxDecoration(
                  color: Colors.white,
                  border: Border(bottom: BorderSide(color: Colors.black12)),
                ),
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                  itemCount: widget.exercise.images.length,
                  itemBuilder: (context, index) {
                    final imageUrl = _getImageUrl(widget.exercise.images[index]);
                    if (imageUrl.isEmpty) return const SizedBox.shrink();

                    return Container(
                      margin: const EdgeInsets.only(right: 16),
                      width: 340,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.1),
                            blurRadius: 8,
                            offset: const Offset(0, 4),
                          )
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: CachedNetworkImage(
                          imageUrl: imageUrl,
                          fit: BoxFit.cover,
                          placeholder: (context, url) => Center(
                            child: CircularProgressIndicator(
                              value: null, 
                              color: renewalTeal.withValues(alpha: 0.5),
                            ),
                          ),
                          errorWidget: (context, url, error) => Container(
                            color: Colors.grey[200],
                            child: const Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.broken_image, size: 40, color: Colors.grey),
                                SizedBox(height: 8),
                                Text("Offline", style: TextStyle(color: Colors.grey)),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),

            Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      ...widget.exercise.primaryMuscles.map((m) => Chip(
                        label: Text(m.toUpperCase()),
                        backgroundColor: renewalTeal.withValues(alpha: 0.1),
                        labelStyle: const TextStyle(color: renewalTeal, fontWeight: FontWeight.bold, fontSize: 12),
                        padding: EdgeInsets.zero,
                        visualDensity: VisualDensity.compact,
                      )),
                      
                      // Database Dependent Actions
                      FutureBuilder<Map<String, dynamic>?>(
                        future: Provider.of<DatabaseService>(context, listen: false).getLatestOneRepMaxDetailed(widget.exercise.name),
                        builder: (context, snapshot) {
                          final data = snapshot.data;
                          final double? max = data?['weight'];
                          final String? date = data?['date'];
                          
                          String displayDate = "";
                          if (date != null) {
                             final dt = DateTime.parse(date);
                             displayDate = "(${dt.month}/${dt.day}/${dt.year.toString().substring(2)})";
                          }

                          return Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              OutlinedButton.icon(
                                icon: const Icon(Icons.edit, size: 14),
                                label: Text(max != null ? "${max.toInt()} lbs $displayDate" : "Set Max"),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: motivationCoral,
                                  side: const BorderSide(color: motivationCoral),
                                  visualDensity: VisualDensity.compact,
                                  textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                                  minimumSize: const Size(0, 32),
                                ),
                                onPressed: () async {
                                  await showDialog(
                                    context: context,
                                    builder: (ctx) => EditOneRepMaxDialog(
                                      exerciseName: widget.exercise.name,
                                      currentMax: max,
                                    ),
                                  );
                                  // Trigger rebuild to show new max immediately
                                  setState(() {});
                                },
                              ),
                              
                              const SizedBox(width: 8),

                              IconButton(
                                icon: const Icon(Icons.show_chart, color: renewalTeal),
                                tooltip: "View History Graph",
                                onPressed: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(builder: (_) => StrengthProfileScreen(initialExercise: widget.exercise.name)),
                                  );
                                },
                              ),
                            ],
                          );
                        },
                      ),
                    ],
                  ),
                  
                  const SizedBox(height: 24),

                  Row(
                    children: [
                      Container(
                        width: 4,
                        height: 24,
                        decoration: BoxDecoration(
                          color: motivationCoral,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        "INSTRUCTIONS",
                        style: GoogleFonts.poppins(
                          fontSize: 18, 
                          fontWeight: FontWeight.bold, 
                          color: textDark,
                          letterSpacing: 1.2,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  if (widget.exercise.instructions.isEmpty)
                    const Text(
                      "No detailed instructions available for this exercise.",
                      style: TextStyle(fontStyle: FontStyle.italic, color: Colors.grey),
                    )
                  else
                    ...widget.exercise.instructions.asMap().entries.map((entry) => Padding(
                      padding: const EdgeInsets.only(bottom: 16.0),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 24,
                            height: 24,
                            alignment: Alignment.center,
                            decoration: const BoxDecoration(
                              color: renewalTeal,
                              shape: BoxShape.circle,
                            ),
                            child: Text(
                              "${entry.key + 1}",
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Text(
                              entry.value,
                              style: GoogleFonts.inter(
                                fontSize: 16, 
                                height: 1.5,
                                color: Colors.black87,
                              ),
                            ),
                          ),
                        ],
                      ),
                    )),
                    
                   const SizedBox(height: 20),
                   Divider(color: Colors.grey[300]),
                   const SizedBox(height: 10),
                   if (widget.exercise.category != null)
                     _buildMetadataRow("Category", widget.exercise.category!),
                   if (widget.exercise.mechanic != null)
                     _buildMetadataRow("Mechanic", widget.exercise.mechanic!),
                   if (widget.exercise.level != null)
                     _buildMetadataRow("Level", widget.exercise.level!),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMetadataRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        children: [
          Text("$label: ", style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
          Text(value, style: const TextStyle(color: Colors.black87)),
        ],
      ),
    );
  }
}