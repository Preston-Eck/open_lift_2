import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/database_service.dart';
import '../services/gemini_service.dart';
import '../theme.dart';

class AICoachScreen extends StatefulWidget {
  const AICoachScreen({super.key});

  @override
  State<AICoachScreen> createState() => _AICoachScreenState();
}

class _AICoachScreenState extends State<AICoachScreen> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final List<Map<String, String>> _messages = []; // {'role': 'user'|'model', 'content': '...'}
  bool _isLoading = false;
  Map<String, dynamic> _contextData = {};

  @override
  void initState() {
    super.initState();
    _loadContext();
  }

  Future<void> _loadContext() async {
    final db = Provider.of<DatabaseService>(context, listen: false);
    
    // 1. Profile
    final profile = await db.getUserProfile();
    final profileStr = profile != null ? profile.toString() : "No profile set.";

    // 2. Equipment
    final equipment = await db.getOwnedItemNames();
    final equipStr = equipment.join(', ');

    // 3. Stats (1RMs)
    final stats = await db.getLatestOneRepMaxes();
    final statsStr = stats.entries.map((e) => "${e.key}: ${e.value.toStringAsFixed(1)}").join(', ');

    // 4. Recent Logs
    final logs = await db.getHistory();
    final logsStr = logs.take(10).map((l) => "${l.timestamp.substring(0,10)}: ${l.exerciseName} ${l.weight}x${l.reps}").join('\n');

    setState(() {
      _contextData = {
        'profile': profileStr,
        'equipment': equipStr,
        'strength_stats': statsStr,
        'recent_logs': logsStr,
      };
      
      // Initial Greeting
      _messages.add({
        'role': 'model',
        'content': "Hello! I'm your AI Coach. I have access to your profile, equipment, and workout history. How can I help you today?"
      });
    });
  }

  Future<void> _sendMessage() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;

    _controller.clear();
    setState(() {
      _messages.add({'role': 'user', 'content': text});
      _isLoading = true;
    });
    _scrollToBottom();

    final db = Provider.of<DatabaseService>(context, listen: false);
    final gemini = Provider.of<GeminiService>(context, listen: false);
    
    // RAG: Check if user is asking about a specific exercise
    String specificHistory = "";
    try {
      final exercises = await db.getMostFrequentExercises();
      for (var ex in exercises) {
        final name = ex['exercise_name'] as String;
        if (text.toLowerCase().contains(name.toLowerCase())) {
          final history = await db.getHistoryForExercise(name);
          specificHistory += "\nHistory for $name:\n" + 
            history.take(20).map((l) => "${l.timestamp.substring(0,10)}: ${l.weight}x${l.reps} (Vol: ${l.volumeLoad})").join('\n');
          break; // Found one, stop for now to keep context window clean
        }
      }
    } catch (e) {
      debugPrint("RAG Error: $e");
    }

    // Merge RAG into context
    final currentContext = Map<String, dynamic>.from(_contextData);
    if (specificHistory.isNotEmpty) {
      currentContext['specific_history'] = specificHistory;
    }

    // Call API
    final response = await gemini.chatWithCoach(text, _messages, currentContext);

    if (mounted) {
      setState(() {
        _messages.add({'role': 'model', 'content': response});
        _isLoading = false;
      });
      _scrollToBottom();
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("AI Coach"),
        backgroundColor: AppTheme.clarityCream,
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.all(16),
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                final msg = _messages[index];
                final isUser = msg['role'] == 'user';
                return Align(
                  alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
                  child: Container(
                    margin: const EdgeInsets.symmetric(vertical: 4),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isUser ? AppTheme.renewalTeal : Colors.white,
                      borderRadius: BorderRadius.only(
                        topLeft: const Radius.circular(12),
                        topRight: const Radius.circular(12),
                        bottomLeft: isUser ? const Radius.circular(12) : Radius.zero,
                        bottomRight: isUser ? Radius.zero : const Radius.circular(12),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.05),
                          blurRadius: 2,
                          offset: const Offset(0, 1),
                        )
                      ],
                    ),
                    constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
                    child: Text(
                      msg['content']!,
                      style: TextStyle(color: isUser ? Colors.white : AppTheme.foundationalSlate),
                    ),
                  ),
                );
              },
            ),
          ),
          if (_isLoading)
            const Padding(
              padding: EdgeInsets.all(8.0),
              child: LinearProgressIndicator(color: AppTheme.renewalTeal),
            ),
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.white,
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    decoration: const InputDecoration(
                      hintText: "Ask about your training...",
                      border: InputBorder.none,
                    ),
                    onSubmitted: (_) => _sendMessage(),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.send, color: AppTheme.renewalTeal),
                  onPressed: _sendMessage,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
