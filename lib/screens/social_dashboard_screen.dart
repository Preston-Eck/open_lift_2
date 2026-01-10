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
          final profile = log['profiles'] ?? {};
          final username = profile['username'] ?? 'Unknown';
          final exercise = log['exercise_name'] ?? 'Exercise';
          final weight = log['weight'];
          final reps = log['reps'];
          final time = DateTime.tryParse(log['timestamp'] ?? '') ?? DateTime.now();

          return Card(
            margin: const EdgeInsets.only(bottom: 12),
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
                      const Spacer(),
                      Text(DateFormat('MMM d, h:mm a').format(time), style: const TextStyle(color: Colors.grey, fontSize: 12)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text("did $exercise", style: const TextStyle(fontSize: 16)),
                  const SizedBox(height: 4),
                  Text("$weight lbs x $reps reps", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.deepPurple)),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.thumb_up_alt_outlined, size: 20),
                        onPressed: () {
                           // Optimistic UI update could go here
                           context.read<SocialService>().toggleLike(log['id']);
                           ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Liked!")));
                        },
                      ),
                      const Text("Like"),
                      const SizedBox(width: 16),
                      const Icon(Icons.comment_outlined, size: 20),
                      const SizedBox(width: 4),
                      const Text("Comment"),
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
              return Card(
                child: ListTile(
                  leading: CircleAvatar(child: Text(fName.isNotEmpty ? fName[0].toUpperCase() : "?")),
                  title: Text(fName),
                  trailing: IconButton(
                    icon: const Icon(Icons.person_remove, color: Colors.grey),
                    onPressed: () async {
                      await context.read<SocialService>().deleteFriendship(f['friendship_id']);
                      _fetchPeopleData();
                    },
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