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
                baseColor: AppTheme.foundationalSlate.withValues(alpha: 0.05),
                highlightColor: AppTheme.motivationCoral,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

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
    
    // Scale canvas to a standard 100x200 grid for easier path definition
    canvas.scale(size.width / 100, size.height / 200);

    void drawPart(String id, Path path) {
      // Check for intensity (support plural/singular naming if needed)
      final intensity = intensities[id] ?? 0.0;
      
      if (intensity > 0) {
        paint.color = Color.lerp(Colors.white, highlightColor, intensity)!;
      } else {
        paint.color = baseColor;
      }
      
      canvas.drawPath(path, paint);
      
      // Draw outline
      final borderPaint = Paint()
        ..style = PaintingStyle.stroke
        ..color = Colors.black12
        ..strokeWidth = 0.5;
      canvas.drawPath(path, borderPaint);
    }

    if (isFront) {
      _drawFront(drawPart);
    } else {
      _drawBack(drawPart);
    }
  }

  void _drawFront(Function(String, Path) draw) {
    // --- CHEST (Pectorals) ---
    final chest = Path()..addRect(const Rect.fromLTWH(35, 40, 30, 20));
    draw('pectorals', chest);
    draw('chest', chest);

    // --- ABS (Abdominals) ---
    final abs = Path()..addRect(const Rect.fromLTWH(40, 62, 20, 25));
    draw('abdominals', abs);
    draw('abs', abs);

    // --- SHOULDERS (Deltoids) ---
    final shoulders = Path()
      ..addOval(const Rect.fromLTWH(20, 38, 15, 15)) // Left
      ..addOval(const Rect.fromLTWH(65, 38, 15, 15)); // Right
    draw('shoulders', shoulders);
    draw('deltoids', shoulders);

    // --- BICEPS ---
    final biceps = Path()
      ..addRect(const Rect.fromLTWH(20, 55, 12, 15)) // Left
      ..addRect(const Rect.fromLTWH(68, 55, 12, 15)); // Right
    draw('biceps', biceps);

    // --- QUADS (Quadriceps) ---
    final quads = Path()..addRect(const Rect.fromLTWH(30, 90, 40, 40));
    draw('quadriceps', quads);
    draw('quads', quads);
  }

  void _drawBack(Function(String, Path) draw) {
    // --- BACK (Lats/Traps) ---
    final back = Path()..addRect(const Rect.fromLTWH(32, 40, 36, 35));
    draw('back', back);
    draw('lats', back);
    draw('trapezius', back);

    // --- TRICEPS ---
    final triceps = Path()
      ..addRect(const Rect.fromLTWH(20, 50, 10, 20)) // Left
      ..addRect(const Rect.fromLTWH(70, 50, 10, 20)); // Right
    draw('triceps', triceps);

    // --- GLUTES ---
    final glutes = Path()..addRect(const Rect.fromLTWH(32, 78, 36, 20));
    draw('glutes', glutes);

    // --- HAMSTRINGS ---
    final hams = Path()..addRect(const Rect.fromLTWH(32, 100, 36, 35));
    draw('hamstrings', hams);
    
    // --- CALVES ---
    final calves = Path()..addRect(const Rect.fromLTWH(35, 140, 30, 25));
    draw('calves', calves);
  }

  @override
  bool shouldRepaint(covariant BodyPainter oldDelegate) {
    return oldDelegate.intensities != intensities;
  }
}