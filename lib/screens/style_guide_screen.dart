import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme.dart';

class StyleGuideScreen extends StatelessWidget {
  const StyleGuideScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Vitality Rise UI"),
        actions: [
          IconButton(onPressed: () {}, icon: const Icon(Icons.settings)),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. Typography Audit
            const _SectionHeader("Typography"),
            Text("Headline 1 (Poppins)", style: Theme.of(context).textTheme.displayLarge),
            const SizedBox(height: 8),
            Text("Headline 2", style: Theme.of(context).textTheme.displayMedium),
            const SizedBox(height: 8),
            Text("Title Large", style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            const Text(
              "Body Text (Inter): This text is designed for high legibility during workouts. It uses the Foundational Slate color to be softer than pure black.",
            ),
            
            const SizedBox(height: 32),

            // 2. Color Palette Audit
            const _SectionHeader("Palette"),
            const Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                _Swatch(AppTheme.renewalTeal, "Renewal\nTeal"),
                _Swatch(AppTheme.motivationCoral, "Motivation\nCoral"),
                _Swatch(AppTheme.foundationalSlate, "Foundational\nSlate"),
                _Swatch(AppTheme.clarityCream, "Clarity\nCream"),
                _Swatch(AppTheme.achievementGold, "Achievement\nGold"),
              ],
            ),

            const SizedBox(height: 32),

            // 3. Buttons
            const _SectionHeader("Buttons & Actions"),
            ElevatedButton(
              onPressed: () {},
              child: const Text("Start Workout (CTA)"),
            ),
            const SizedBox(height: 16),
            OutlinedButton(
              onPressed: () {},
              child: const Text("View Details (Secondary)"),
            ),
            const SizedBox(height: 16),
            Center(
              child: TextButton(
                onPressed: () {},
                child: const Text("Text Action"),
              ),
            ),

            const SizedBox(height: 32),
            
            // 4. Inputs
            const _SectionHeader("Data Entry"),
            const TextField(
              decoration: InputDecoration(
                labelText: "Exercise Name",
                hintText: "e.g. Bench Press",
                prefixIcon: Icon(Icons.fitness_center),
              ),
            ),
            const SizedBox(height: 16),
            const Row(
              children: [
                Expanded(
                  child: TextField(
                    decoration: InputDecoration(
                      labelText: "Weight",
                      suffixText: "lbs",
                    ),
                    keyboardType: TextInputType.number,
                  ),
                ),
                SizedBox(width: 16),
                Expanded(
                  child: TextField(
                    decoration: InputDecoration(
                      labelText: "Reps",
                    ),
                    keyboardType: TextInputType.number,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 32),

            // 5. Cards & Data
            const _SectionHeader("Cards"),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text("Weekly Goal", style: Theme.of(context).textTheme.titleLarge),
                        const Icon(Icons.emoji_events, color: AppTheme.achievementGold, size: 28),
                      ],
                    ),
                    const SizedBox(height: 16),
                    LinearProgressIndicator(
                      value: 0.75,
                      backgroundColor: AppTheme.foundationalSlate.withValues(alpha: 0.1),
                      valueColor: const AlwaysStoppedAnimation(AppTheme.renewalTeal),
                      minHeight: 12,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    const SizedBox(height: 12),
                    Text("3/4 Workouts Complete", style: Theme.of(context).textTheme.titleMedium),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      // Demonstrate the FAB style
      floatingActionButton: FloatingActionButton(
        onPressed: () {},
        backgroundColor: AppTheme.motivationCoral,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader(this.title);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title.toUpperCase(), 
            style: GoogleFonts.inter(
              fontSize: 12, 
              fontWeight: FontWeight.bold, 
              letterSpacing: 1.5,
              color: AppTheme.foundationalSlate.withValues(alpha: 0.5)
            ),
          ),
          const Divider(),
        ],
      ),
    );
  }
}

class _Swatch extends StatelessWidget {
  final Color color;
  final String label;
  const _Swatch(this.color, this.label);

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 100,
      height: 100,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            blurRadius: 8, 
            color: Colors.black.withValues(alpha: 0.05), 
            offset: const Offset(0, 4)
          )
        ],
      ),
      alignment: Alignment.center,
      child: Text(
        label,
        textAlign: TextAlign.center,
        style: TextStyle(
          color: color.computeLuminance() > 0.5 ? Colors.black : Colors.white,
          fontWeight: FontWeight.bold,
          fontSize: 12,
        ),
      ),
    );
  }
}