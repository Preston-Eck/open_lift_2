import 'package:flutter/material.dart';
import '../theme.dart';

class MuscleHeatmap extends StatelessWidget {
  final Map<String, double> muscleIntensities;

  const MuscleHeatmap({super.key, required this.muscleIntensities});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: _buildBodySide(context, "Front", true)),
        const SizedBox(width: 16),
        Expanded(child: _buildBodySide(context, "Back", false)),
      ],
    );
  }

  Widget _buildBodySide(BuildContext context, String label, bool isFront) {
    return Column(
      children: [
        Text(label, style: Theme.of(context).textTheme.labelLarge),
        const SizedBox(height: 8),
        AspectRatio(
          aspectRatio: 0.6,
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppTheme.foundationalSlate.withValues(alpha: 0.1)),
            ),
            child: CustomPaint(
              painter: BodyPainter(
                isFront: isFront,
                intensities: muscleIntensities,
                baseColor: AppTheme.foundationalSlate.withValues(alpha: 0.1),
                highlightColor: AppTheme.motivationCoral,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// 🎨 The Painter: Logic to color specific body parts
class BodyPainter extends CustomPainter {
  final bool isFront;
  final Map<String, double> intensities;
  final Color baseColor;
  final Color highlightColor;

  BodyPainter({
    required this.isFront,
    required this.intensities,
    required this.baseColor,
    required this.highlightColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final Paint paint = Paint()..style = PaintingStyle.fill;
    
    // SCALING: Fit the paths to the container size (Standard viewbox 0..100)
    canvas.scale(size.width / 100, size.height / 200);

    // --- HELPER: Draw Muscle ---
    void drawMuscle(String id, Path path) {
      final intensity = intensities[id.toLowerCase()] ?? 0.0;
      
      // Color Logic: White -> Red based on intensity
      if (intensity > 0) {
        paint.color = Color.lerp(Colors.white, highlightColor, intensity)!;
      } else {
        paint.color = baseColor; // Empty/Unused state
      }
      
      canvas.drawPath(path, paint);
      
      // Outline
      final borderPaint = Paint()
        ..style = PaintingStyle.stroke
        ..color = Colors.black12
        ..strokeWidth = 1.0;
      canvas.drawPath(path, borderPaint);
    }

    if (isFront) {
      _drawFront(drawMuscle);
    } else {
      _drawBack(drawMuscle);
    }
  }

  // --- PATH DEFINITIONS (Simplified for Prototype) ---
  // In a full app, these would be precise SVG paths imported from assets
  void _drawFront(Function(String, Path) draw) {
    // Chest
    final chest = Path()..addRect(const Rect.fromLTWH(35, 40, 30, 25));
    draw('chest', chest);
    draw('pectorals', chest);

    // Abs
    final abs = Path()..addRect(const Rect.fromLTWH(40, 65, 20, 30));
    draw('abs', abs);
    draw('abdominals', abs);

    // Quads
    final quads = Path()..addRect(const Rect.fromLTWH(30, 100, 40, 40));
    draw('quads', quads);
    draw('quadriceps', quads);
    
    // Biceps (Left/Right)
    final biceps = Path()..addRect(const Rect.fromLTWH(20, 40, 15, 25))..addRect(const Rect.fromLTWH(65, 40, 15, 25));
    draw('biceps', biceps);
    
    // Shoulders
    final shoulders = Path()..addOval(const Rect.fromLTWH(20, 35, 60, 15));
    draw('shoulders', shoulders);
    draw('deltoids', shoulders);
  }

  void _drawBack(Function(String, Path) draw) {
    // Back (Lats)
    final lats = Path()..addRect(const Rect.fromLTWH(35, 40, 30, 40));
    draw('lats', lats);
    draw('back', lats);

    // Glutes
    final glutes = Path()..addRect(const Rect.fromLTWH(35, 80, 30, 20));
    draw('glutes', glutes);

    // Hamstrings
    final hams = Path()..addRect(const Rect.fromLTWH(35, 100, 30, 40));
    draw('hamstrings', hams);
    
    // Triceps
     final triceps = Path()..addRect(const Rect.fromLTWH(25, 45, 10, 20))..addRect(const Rect.fromLTWH(65, 45, 10, 20));
    draw('triceps', triceps);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}