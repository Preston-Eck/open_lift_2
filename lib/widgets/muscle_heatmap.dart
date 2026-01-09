import 'package:flutter/material.dart';
import '../theme.dart';
import 'body_paths.dart';

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
          aspectRatio: 0.5, // Taller aspect ratio for full body
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppTheme.foundationalSlate.withValues(alpha: 0.1)),
            ),
            child: CustomPaint(
              painter: LowPolyBodyPainter(
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

class LowPolyBodyPainter extends CustomPainter {
  final bool isFront;
  final Map<String, double> intensities;
  final Color baseColor;
  final Color highlightColor;

  LowPolyBodyPainter({
    required this.isFront,
    required this.intensities,
    required this.baseColor,
    required this.highlightColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..style = PaintingStyle.fill;
    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..color = Colors.white
      ..strokeWidth = 2; // Thicker white lines for "Low Poly" look

    // Scale 100x120 grid to canvas
    // Our paths are approx 0..100 width, 0..120 height
    final scaleX = size.width / 100;
    final scaleY = size.height / 130;
    canvas.scale(scaleX, scaleY);

    void draw(Path path, List<String> muscleKeys) {
      double maxIntensity = 0.0;
      for (var key in muscleKeys) {
        // Normalize keys
        final k = key.toLowerCase().trim();
        if (intensities.containsKey(k)) {
          if (intensities[k]! > maxIntensity) maxIntensity = intensities[k]!;
        }
        // Handle common variations
        if (k == 'legs' && (muscleKeys.contains('quads') || muscleKeys.contains('hamstrings'))) {
           if ((intensities['legs'] ?? 0) > maxIntensity) maxIntensity = intensities['legs']!;
        }
      }

      paint.color = maxIntensity > 0 
          ? Color.lerp(baseColor, highlightColor, maxIntensity)!
          : baseColor;

      canvas.drawPath(path, paint);
      canvas.drawPath(path, stroke);
    }

    if (isFront) {
      draw(BodyPaths.chestLeft, ['chest', 'pectorals', 'pecs', 'upper body']);
      draw(BodyPaths.chestRight, ['chest', 'pectorals', 'pecs', 'upper body']);
      draw(BodyPaths.absUpper, ['abs', 'abdominals', 'core']);
      draw(BodyPaths.absLower, ['abs', 'abdominals', 'core']);
      draw(BodyPaths.shoulderLeft, ['shoulders', 'deltoids', 'delts']);
      draw(BodyPaths.shoulderRight, ['shoulders', 'deltoids', 'delts']);
      draw(BodyPaths.bicepLeft, ['biceps', 'arms']);
      draw(BodyPaths.bicepRight, ['biceps', 'arms']);
      draw(BodyPaths.forearmsLeft, ['forearms', 'arms']);
      draw(BodyPaths.forearmsRight, ['forearms', 'arms']);
      draw(BodyPaths.quadsLeft, ['quads', 'quadriceps', 'legs']);
      draw(BodyPaths.quadsRight, ['quads', 'quadriceps', 'legs']);
      draw(BodyPaths.calvesLeft, ['calves', 'legs']);
      draw(BodyPaths.calvesRight, ['calves', 'legs']);
    } else {
      draw(BodyPaths.traps, ['traps', 'trapezius', 'back', 'shoulders']);
      draw(BodyPaths.latsLeft, ['lats', 'latissimus', 'back']);
      draw(BodyPaths.latsRight, ['lats', 'latissimus', 'back']);
      draw(BodyPaths.glutesLeft, ['glutes', 'gluteus', 'butt', 'legs']);
      draw(BodyPaths.glutesRight, ['glutes', 'gluteus', 'butt', 'legs']);
      draw(BodyPaths.hamsLeft, ['hamstrings', 'hams', 'legs']);
      draw(BodyPaths.hamsRight, ['hamstrings', 'hams', 'legs']);
      draw(BodyPaths.tricepsLeft, ['triceps', 'arms']);
      draw(BodyPaths.tricepsRight, ['triceps', 'arms']);
      draw(BodyPaths.calvesLeft, ['calves', 'legs']);
      draw(BodyPaths.calvesRight, ['calves', 'legs']);
    }
  }

  @override
  bool shouldRepaint(covariant LowPolyBodyPainter oldDelegate) {
    return oldDelegate.intensities != intensities;
  }
}