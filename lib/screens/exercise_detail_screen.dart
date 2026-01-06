import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart'; 
import 'package:google_fonts/google_fonts.dart';
import '../models/exercise.dart';

class ExerciseDetailScreen extends StatelessWidget {
  final Exercise exercise;

  const ExerciseDetailScreen({super.key, required this.exercise});

  // Vitality Rise Colors
  static const Color renewalTeal = Color(0xFF2A9D8F);
  static const Color motivationCoral = Color(0xFFE76F51);
  static const Color clarityCream = Color(0xFFF8F9FA);
  static const Color textDark = Color(0xFF264653);

  String _getImageUrl(String path) {
    if (path.startsWith('http')) return path;
    
    final supabaseUrl = dotenv.env['SUPABASE_URL'];
    if (supabaseUrl == null || supabaseUrl.isEmpty) {
      debugPrint("Error: SUPABASE_URL is missing in .env");
      return ""; 
    }

    final baseUrl = supabaseUrl.endsWith('/') ? supabaseUrl : "$supabaseUrl/";
    // Remove leading slash from path if present to prevent double slash
    final cleanPath = path.startsWith('/') ? path.substring(1) : path;
    
    // Assumes images are in a public bucket named 'exercises'
    return "${baseUrl}storage/v1/object/public/exercises/$cleanPath"; 
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: clarityCream,
      appBar: AppBar(
        title: Text(
          exercise.name,
          style: GoogleFonts.poppins(fontWeight: FontWeight.w600, color: Colors.white),
        ),
        backgroundColor: renewalTeal,
        iconTheme: const IconThemeData(color: Colors.white),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // --- Media Section ---
            if (exercise.images.isNotEmpty)
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
                  itemCount: exercise.images.length,
                  itemBuilder: (context, index) {
                    final imageUrl = _getImageUrl(exercise.images[index]);
                    if (imageUrl.isEmpty) return const SizedBox.shrink();

                    return Container(
                      margin: const EdgeInsets.only(right: 16),
                      width: 340,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            // Fixed: withOpacity -> withValues
                            color: Colors.black.withValues(alpha: 0.1),
                            blurRadius: 8,
                            offset: const Offset(0, 4),
                          )
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: Image.network(
                          imageUrl,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            // DEBUG: This will print the exact failing URL to your console
                            debugPrint("FAILED URL: $imageUrl");
                            debugPrint("ERROR: $error");
                            return Container(
                              color: Colors.grey[200],
                              child: const Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.broken_image, size: 40, color: Colors.grey),
                                  SizedBox(height: 8),
                                  Text("Image Unavailable", style: TextStyle(color: Colors.grey)),
                                ],
                              ),
                            );
                          },
                          loadingBuilder: (context, child, loadingProgress) {
                            if (loadingProgress == null) return child;
                            return Center(
                              child: CircularProgressIndicator(
                                value: loadingProgress.expectedTotalBytes != null
                                    ? loadingProgress.cumulativeBytesLoaded / loadingProgress.expectedTotalBytes!
                                    : null,
                                color: renewalTeal,
                              ),
                            );
                          },
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
                  // --- Muscles Badges ---
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      ...exercise.primaryMuscles.map((m) => Chip(
                        label: Text(m.toUpperCase()),
                        // Fixed: withOpacity -> withValues
                        backgroundColor: renewalTeal.withValues(alpha: 0.1),
                        labelStyle: const TextStyle(color: renewalTeal, fontWeight: FontWeight.bold, fontSize: 12),
                        padding: EdgeInsets.zero,
                      )),
                      ...exercise.secondaryMuscles.map((m) => Chip(
                        label: Text(m.toUpperCase()),
                        backgroundColor: Colors.grey[200],
                        labelStyle: const TextStyle(color: Colors.grey, fontWeight: FontWeight.bold, fontSize: 12),
                        padding: EdgeInsets.zero,
                      )),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // --- Instructions Header ---
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

                  // --- Instructions List ---
                  if (exercise.instructions.isEmpty)
                    const Text(
                      "No detailed instructions available for this exercise.",
                      style: TextStyle(fontStyle: FontStyle.italic, color: Colors.grey),
                    )
                  else
                    ...exercise.instructions.asMap().entries.map((entry) => Padding(
                      padding: const EdgeInsets.only(bottom: 16.0),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 24,
                            height: 24,
                            alignment: Alignment.center,
                            // Fixed: Added const
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
                    
                   // --- Metadata ---
                   const SizedBox(height: 20),
                   Divider(color: Colors.grey[300]),
                   const SizedBox(height: 10),
                   if (exercise.category != null)
                     _buildMetadataRow("Category", exercise.category!),
                   if (exercise.mechanic != null)
                     _buildMetadataRow("Mechanic", exercise.mechanic!),
                   if (exercise.level != null)
                     _buildMetadataRow("Level", exercise.level!),
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