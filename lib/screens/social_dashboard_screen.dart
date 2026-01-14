import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart'; 
import 'package:uuid/uuid.dart';
import '../services/auth_service.dart';
import '../services/database_service.dart';
import '../services/social_service.dart';
import '../models/plan.dart';
import 'inbox_screen.dart'; // Import Inbox
import 'workout_player_screen.dart'; // NEW FOR CHALLENGE flow

class SocialDashboardScreen extends StatefulWidget {
  const SocialDashboardScreen({super.key});

  @override
  State<SocialDashboardScreen> createState() => _SocialDashboardScreenState();
}

class _SocialDashboardScreenState extends State<SocialDashboardScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  
  // Activity Data
  List<Map<String, dynamic>> _activityFeed = [];
  bool _isLoadingActivity = true;

  // Friend & Leaderboard Data
  List<Map<String, dynamic>> _friends = [];
  List<Map<String, dynamic>> _leaderboard = []; 
  bool _isLoadingPeople = true;

  // Search Data
  final TextEditingController _searchController = TextEditingController();
  List<Map<String, dynamic>> _searchResults = [];
  bool _isSearching = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _fetchActivity();
    _fetchPeopleData();
  }

  // --- DATA LOADING ---

  Future<void> _fetchActivity() async {
    try {
      final data = await context.read<SocialService>().getFriendActivity();
      if (mounted) {
        setState(() {
          _activityFeed = data;
          _isLoadingActivity = false;
        });
      }
    } catch (e) {
      debugPrint("Feed Error: $e");
      if (mounted) setState(() => _isLoadingActivity = false);
    }
  }

  Future<void> _fetchPeopleData() async {
    if (!mounted) return;
    final social = context.read<SocialService>();
    try {
      final results = await Future.wait([
        social.getFriends(),
        social.getWeeklyLeaderboard(),
      ]);

      if (mounted) {
        setState(() {
          _friends = results[0];
          _leaderboard = results[1]; 
          _isLoadingPeople = false;
        });
      }
    } catch (e) {
      debugPrint("People Fetch Error: $e");
      if (mounted) setState(() => _isLoadingPeople = false);
    }
  }

  Future<void> _doSearch() async {
    if (_searchController.text.length < 3) return;
    setState(() => _isSearching = true);
    
    if (!mounted) return;

    try {
      final results = await context.read<SocialService>().searchUsers(_searchController.text);
      if (mounted) {
        setState(() {
          _searchResults = results;
          _isSearching = false;
        });
      }
    } catch (e) {
      debugPrint("Search Crash Prevention: $e");
      if (mounted) setState(() => _isSearching = false);
    }
  }

  // --- UI ---

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Social Hub"),
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.deepPurple,
          unselectedLabelColor: Colors.grey,
          tabs: const [
            Tab(text: "Feed", icon: Icon(Icons.rss_feed)),
            Tab(text: "Inbox", icon: Icon(Icons.mail)),
            Tab(text: "People", icon: Icon(Icons.people)),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildActivityTab(),
          const InboxScreen(), // Reuse new Inbox Screen
          _buildPeopleTab(),
        ],
      ),
    );
  }

  // TAB 1: ACTIVITY FEED
  Widget _buildActivityTab() {
    if (_isLoadingActivity) return const Center(child: CircularProgressIndicator());
    if (_activityFeed.isEmpty) return const Center(child: Text("No recent activity from friends."));

    return RefreshIndicator(
      onRefresh: _fetchActivity,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _activityFeed.length,
        itemBuilder: (ctx, i) {
          final log = _activityFeed[i];
          final username = log['username'] ?? 'Unknown';
          final exercise = log['exercise_name'] ?? 'Exercise';
          final weight = log['weight'];
          final reps = log['reps'];
          final rpe = log['rpe'];
          final isPr = log['is_pr'] == true; // FROM SQL
          final time = DateTime.tryParse(log['log_timestamp'] ?? '') ?? DateTime.now();

          return Card(
            margin: const EdgeInsets.only(bottom: 12),
            shape: isPr ? RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: const BorderSide(color: Colors.amber, width: 2)
            ) : null,
            child: Padding(
              padding: const EdgeInsets.all(12.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                   Row(
                    children: [
                      CircleAvatar(radius: 16, child: Text(username.isNotEmpty ? username[0].toUpperCase() : "?", style: const TextStyle(fontSize: 12))),
                      const SizedBox(width: 8),
                      Text(username, style: const TextStyle(fontWeight: FontWeight.bold)),
                      if (isPr) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(color: Colors.amber, borderRadius: BorderRadius.circular(4)),
                          child: const Row(
                            children: [
                              Icon(Icons.whatshot, size: 12, color: Colors.white),
                              SizedBox(width: 2),
                              Text("PR", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 10)),
                            ],
                          ),
                        ),
                      ],
                      const Spacer(),
                      Text(DateFormat('MMM d').format(time), style: const TextStyle(color: Colors.grey, fontSize: 12)),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text("did $exercise", style: const TextStyle(fontSize: 14, color: Colors.grey)),
                  const SizedBox(height: 4),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Text("${weight.toInt()} lbs x $reps", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 24, color: Colors.deepPurple)),
                      if (rpe != null) ...[
                        const SizedBox(width: 8),
                        Text("@ RPE ${rpe.toInt()}", style: TextStyle(color: Colors.orange.shade700, fontSize: 12, fontWeight: FontWeight.bold)),
                      ]
                    ],
                  ),
                  if (isPr) ...[
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(color: Colors.blueGrey.shade900, borderRadius: BorderRadius.circular(8)),
                      child: Row(
                        children: [
                          const Icon(Icons.auto_awesome, color: Colors.amber, size: 16),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              "COACH'S ALERT: Incredible work! $username just hit a lifetime max on $exercise.",
                              style: const TextStyle(color: Colors.white, fontSize: 12, fontStyle: FontStyle.italic),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  const Divider(height: 24),
                  Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.thumb_up_alt_outlined, size: 20),
                        onPressed: () async {
                           await context.read<SocialService>().toggleLike(log['id']);
                           _fetchActivity(); 
                        },
                      ),
                      Text("${log['likes_count'] ?? 0}"),
                      const SizedBox(width: 24),
                      IconButton(
                        icon: const Icon(Icons.comment_outlined, size: 20),
                        onPressed: () => _showCommentsSheet(log['id']),
                      ),
                      Text("${log['comments_count'] ?? 0}"),
                    ],
                  )
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  void _showCommentsSheet(String logId) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => _CommentSheet(logId: logId),
    );
  }

  // TAB 3: PEOPLE (Friends + Leaderboard + Search)
  Widget _buildPeopleTab() {
    final auth = Provider.of<AuthService>(context, listen: false);
    final myUsername = auth.profile?['username'] ?? "Me";

    return RefreshIndicator(
      onRefresh: _fetchPeopleData,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // --- SEARCH SECTION ---
            TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: "Find users...",
                prefixIcon: const Icon(Icons.search),
                suffixIcon: IconButton(icon: const Icon(Icons.arrow_forward), onPressed: _doSearch),
                contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 16),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(20)),
              ),
              onSubmitted: (_) => _doSearch(),
            ),
            if (_isSearching) const LinearProgressIndicator(),
            if (_searchResults.isNotEmpty) ...[
              const SizedBox(height: 10),
              ..._searchResults.map((user) => ListTile(
                title: Text(user['username']),
                trailing: TextButton(
                  child: const Text("Add"),
                  onPressed: () async {
                    await context.read<SocialService>().sendFriendRequest(user['id']);
                    if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Request Sent!")));
                  },
                ),
              )),
              const Divider(height: 30),
            ],

            const SizedBox(height: 20),
            
            // --- LEADERBOARD ---
            const Text("🏆 Weekly Leaderboard", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
            const SizedBox(height: 10),
            Card(
              color: Colors.deepPurple,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: _leaderboard.isEmpty 
                  ? const Text("No data yet.", style: TextStyle(color: Colors.white))
                  : Column(
                      children: _leaderboard.asMap().entries.map((entry) {
                        final rank = entry.key + 1;
                        final user = entry.value;
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 6.0),
                          child: Row(
                            children: [
                              SizedBox(width: 30, child: Text("$rank.", style: const TextStyle(color: Colors.amber, fontWeight: FontWeight.bold, fontSize: 16))),
                              Text(user['username'] ?? "Unknown", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w500)),
                              const Spacer(),
                              Text("${(user['total_volume'] as num).toInt()} lbs", style: const TextStyle(color: Colors.white70)),
                            ],
                          ),
                        );
                      }).toList(),
                    ),
              ),
            ),

            const SizedBox(height: 24),
            
            // --- FRIENDS LIST ---
            const Text("My Friends", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
            if (_friends.isEmpty) 
              const Padding(padding: EdgeInsets.all(16), child: Text("No friends added yet.", style: TextStyle(color: Colors.grey))),
            
            ..._friends.map((f) {
              final fName = f['username'] ?? "Unknown";
              final fId = f['friend_id'];
              final lastSeenStr = f['last_seen'] as String?;
              final lastSeen = lastSeenStr != null ? DateTime.tryParse(lastSeenStr) : null;
              final isInactive = lastSeen == null || DateTime.now().difference(lastSeen).inDays >= 3;

              return Card(
                child: ListTile(
                  leading: CircleAvatar(child: Text(fName.isNotEmpty ? fName[0].toUpperCase() : "?")),
                  title: Text(fName),
                  subtitle: lastSeen != null 
                    ? Text("Last active: ${DateFormat('MMM d').format(lastSeen)}", style: TextStyle(fontSize: 10, color: isInactive ? Colors.orange : Colors.grey))
                    : const Text("New Friend", style: TextStyle(fontSize: 10)),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (isInactive)
                        IconButton(
                          icon: const Icon(Icons.notifications_active, color: Colors.orange),
                          tooltip: "Send Nudge",
                          onPressed: () async {
                            await context.read<SocialService>().sendNudge(fId);
                            if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Nudged $fName!")));
                          },
                        ),
                      IconButton(
                        icon: const Icon(Icons.bolt, color: Colors.blue),
                        tooltip: "Challenge (Versus)",
                        onPressed: () async {
                          final roomId = const Uuid().v4();
                          await context.read<SocialService>().sendVersusInvite(fId, roomId);
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Challenge Sent! Starting your session...")));
                             Navigator.push(context, MaterialPageRoute(builder: (_) => WorkoutPlayerScreen(versusRoomId: roomId)));
                          }
                        },
                      ),
                      IconButton(
                        icon: const Icon(Icons.person_remove, color: Colors.grey),
                        onPressed: () async {
                          await context.read<SocialService>().deleteFriendship(f['friendship_id']);
                          _fetchPeopleData();
                        },
                      ),
                    ],
                  ),
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}

class _CommentSheet extends StatefulWidget {
  final String logId;
  const _CommentSheet({required this.logId});

  @override
  State<_CommentSheet> createState() => _CommentSheetState();
}

class _CommentSheetState extends State<_CommentSheet> {
  final TextEditingController _controller = TextEditingController();
  List<Map<String, dynamic>> _comments = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadComments();
  }

  Future<void> _loadComments() async {
    final data = await context.read<SocialService>().getComments(widget.logId);
    if (mounted) setState(() { _comments = data; _isLoading = false; });
  }

  Future<void> _postComment() async {
    if (_controller.text.trim().isEmpty) return;
    final text = _controller.text.trim();
    _controller.clear();
    
    await context.read<SocialService>().addComment(widget.logId, text);
    _loadComments();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        height: MediaQuery.of(context).size.height * 0.6,
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("Comments", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            Expanded(
              child: _isLoading ? const Center(child: CircularProgressIndicator()) :
              _comments.isEmpty ? const Center(child: Text("Be the first to comment!", style: TextStyle(color: Colors.grey))) :
              ListView.builder(
                itemCount: _comments.length,
                itemBuilder: (ctx, i) {
                  final c = _comments[i];
                  final user = c['profiles'] ?? {};
                  return ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    leading: CircleAvatar(radius: 12, child: Text(user['username']?[0].toUpperCase() ?? "?", style: const TextStyle(fontSize: 10))),
                    title: Text(user['username'] ?? "Unknown", style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text(c['text']),
                  );
                },
              ),
            ),
            const Divider(),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    decoration: const InputDecoration(hintText: "Write a comment...", border: InputBorder.none),
                    onSubmitted: (_) => _postComment(),
                  ),
                ),
                IconButton(icon: const Icon(Icons.send, color: Colors.deepPurple), onPressed: _postComment),
              ],
            )
          ],
        ),
      ),
    );
  }
}