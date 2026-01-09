import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:percent_indicator/circular_percent_indicator.dart';
import '../services/database_service.dart';
import '../services/gemini_service.dart';
import '../theme.dart';

class WeeklyReviewScreen extends StatefulWidget {
  const WeeklyReviewScreen({super.key});

  @override
  State<WeeklyReviewScreen> createState() => _WeeklyReviewScreenState();
}

class _WeeklyReviewScreenState extends State<WeeklyReviewScreen> {
  bool _isLoading = true;
  Map<String, dynamic>? _reviewData;

  @override
  void initState() {
    super.initState();
    _generateReview();
  }

  Future<void> _generateReview() async {
    final db = context.read<DatabaseService>();
    final gemini = context.read<GeminiService>();

    // 1. Get logs for last 7 days
    final now = DateTime.now();
    final start = now.subtract(const Duration(days: 7));
    final logs = await db.getLogsInDateRange(start, now);
    
    if (logs.isEmpty) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _reviewData = null; // No data
        });
      }
      return;
    }

    // 2. Format for AI
    final rawLogs = logs.map((l) => {
      'exercise': l.exerciseName,
      'weight': l.weight,
      'reps': l.reps,
      'date': l.timestamp
    }).toList();

    // 3. Call AI
    final result = await gemini.generateWeeklyReview(rawLogs);

    if (mounted) {
      setState(() {
        _reviewData = result;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Weekly Review")),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _reviewData == null
              ? const Center(child: Text("No workouts found for the last 7 days."))
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      // Score Card
                      Card(
                        elevation: 4,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        child: Padding(
                          padding: const EdgeInsets.all(24.0),
                          child: Column(
                            children: [
                              const Text("CONSISTENCY SCORE", style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1.2)),
                              const SizedBox(height: 16),
                              CircularPercentIndicator(
                                radius: 60.0,
                                lineWidth: 10.0,
                                percent: (_reviewData!['score'] as int) / 100.0,
                                center: Text(
                                  "${_reviewData!['score']}",
                                  style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold),
                                ),
                                progressColor: AppTheme.renewalTeal,
                                backgroundColor: Colors.grey.withValues(alpha: 0.2),
                                animation: true,
                              ),
                              const SizedBox(height: 16),
                              Text(
                                _reviewData!['summary'],
                                textAlign: TextAlign.center,
                                style: const TextStyle(fontSize: 16, fontStyle: FontStyle.italic),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),

                      _buildSection("Highlights", Icons.emoji_events, Colors.amber, _reviewData!['highlights']),
                      _buildSection("Improvements", Icons.trending_up, Colors.orange, _reviewData!['improvements']),
                      _buildSection("Next Week's Goals", Icons.flag, AppTheme.motivationCoral, _reviewData!['next_week_goals']),
                    ],
                  ),
                ),
    );
  }

  Widget _buildSection(String title, IconData icon, Color color, List<dynamic> items) {
    if (items.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, color: color),
            const SizedBox(width: 8),
            Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          ],
        ),
        const SizedBox(height: 8),
        ...items.map((item) => Card(
          child: ListTile(
            leading: const Icon(Icons.check_circle_outline, size: 20, color: Colors.grey),
            title: Text(item),
          ),
        )),
        const SizedBox(height: 20),
      ],
    );
  }
}
