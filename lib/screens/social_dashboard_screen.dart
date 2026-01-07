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

class SocialDashboardScreen extends StatefulWidget {
  const SocialDashboardScreen({super.key});

  @override
  State<SocialDashboardScreen> createState() => _SocialDashboardScreenState();
}

class _SocialDashboardScreenState extends State<SocialDashboardScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  
  // Community Data
  List<Map<String, dynamic>> _publicPlans = [];
  bool _isLoadingPlans = true;

  // Friend & Leaderboard Data
  List<Map<String, dynamic>> _friends = [];
  List<Map<String, dynamic>> _requests = [];
  List<Map<String, dynamic>> _leaderboard = []; 
  bool _isLoadingFriends = true;

  // Search Data
  final TextEditingController _searchController = TextEditingController();
  List<Map<String, dynamic>> _searchResults = [];
  bool _isSearching = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _fetchPublicPlans();
    _fetchFriendData();
  }

  // --- DATA LOADING ---

  Future<void> _fetchPublicPlans() async {
    try {
      final data = await Supabase.instance.client
          .from('plans')
          .select('*, profiles(username)')
          .eq('is_public', true)
          .order('updated_at', ascending: false)
          .limit(20);
      
      if (mounted) {
        setState(() {
          _publicPlans = List<Map<String, dynamic>>.from(data);
          _isLoadingPlans = false;
        });
      }
    } catch (e) {
      debugPrint("Social Fetch Error: $e");
      if (mounted) setState(() => _isLoadingPlans = false);
    }
  }

  Future<void> _fetchFriendData() async {
    if (!mounted) return;
    
    final social = context.read<SocialService>();
    try {
      final results = await Future.wait([
        social.getFriends(),
        social.getIncomingRequests(),
        social.getWeeklyLeaderboard(),
      ]);

      if (mounted) {
        setState(() {
          _friends = results[0];
          _requests = results[1];
          _leaderboard = results[2]; 
          _isLoadingFriends = false;
        });
      }
    } catch (e) {
      debugPrint("Friend Fetch Error: $e");
      if (mounted) setState(() => _isLoadingFriends = false);
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

  Future<void> _clonePlan(Map<String, dynamic> publicPlan) async {
    try {
      if (!mounted) return;

      final db = context.read<DatabaseService>();
      
      final String jsonStr = publicPlan['schedule_json'];
      final List<dynamic> daysRaw = jsonDecode(jsonStr);
      final List<WorkoutDay> days = daysRaw.map((x) => WorkoutDay.fromMap(x)).toList();

      final newPlan = WorkoutPlan(
        id: const Uuid().v4(),
        name: "${publicPlan['name']} (Imported)",
        goal: publicPlan['goal'] ?? "Imported Plan",
        type: publicPlan['type'] ?? "Strength",
        days: days,
      );

      await db.savePlan(newPlan);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Imported '${newPlan.name}' to your library!"),
            backgroundColor: Colors.green,
          )
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Import Failed: $e"), backgroundColor: Colors.red),
        );
      }
    }
  }

  void _showImportDialog(Map<String, dynamic> plan) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text("Import ${plan['name']}?"),
        content: const Text("This will save a copy of this workout plan to your local device. You can then edit or start it."),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              _clonePlan(plan);
            },
            child: const Text("Import"),
          )
        ],
      ),
    );
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
            Tab(text: "Community", icon: Icon(Icons.public)),
            Tab(text: "Friends", icon: Icon(Icons.people)),
            Tab(text: "Search", icon: Icon(Icons.person_add)),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildCommunityTab(),
          _buildFriendsTab(),
          _buildSearchTab(),
        ],
      ),
    );
  }

  // TAB 1: COMMUNITY
  Widget _buildCommunityTab() {
    if (_isLoadingPlans) return const Center(child: CircularProgressIndicator());
    if (_publicPlans.isEmpty) return const Center(child: Text("No public plans found."));
    
    return RefreshIndicator(
      onRefresh: _fetchPublicPlans,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _publicPlans.length,
        itemBuilder: (ctx, i) {
          final plan = _publicPlans[i];
          final owner = plan['profiles']?['username'] ?? 'Unknown';
          final dateStr = plan['updated_at'];
          final date = dateStr != null ? DateTime.parse(dateStr) : DateTime.now();
          
          return Card(
            margin: const EdgeInsets.only(bottom: 12),
            child: ListTile(
              leading: const Icon(Icons.download_for_offline, color: Colors.deepPurple),
              title: Text(plan['name'] ?? "Untitled", style: const TextStyle(fontWeight: FontWeight.bold)),
              subtitle: Text("@$owner • ${plan['goal'] ?? 'General'}"),
              trailing: Text(
                DateFormat('MMM d').format(date), 
                style: const TextStyle(color: Colors.grey, fontSize: 12),
              ),
              onTap: () => _showImportDialog(plan),
            ),
          );
        },
      ),
    );
  }

  // TAB 2: FRIENDS
  Widget _buildFriendsTab() {
    if (_isLoadingFriends) return const Center(child: CircularProgressIndicator());
    
    final auth = Provider.of<AuthService>(context, listen: false);
    final myUsername = auth.profile?['username'] ?? "Me";

    return RefreshIndicator(
      onRefresh: _fetchFriendData,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // My Profile Header
          ListTile(
            leading: CircleAvatar(
              backgroundColor: Colors.deepPurple,
              child: Text(myUsername.isNotEmpty ? myUsername[0].toUpperCase() : "?", style: const TextStyle(color: Colors.white)),
            ),
            title: Text("Logged in as @$myUsername", style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: const Text("Sync your workouts to appear on the leaderboard!"),
          ),
          const Divider(),

          // --- LEADERBOARD ---
          if (_leaderboard.isNotEmpty) ...[
            const Text("🏆 Weekly Volume Leaderboard", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
            const SizedBox(height: 10),
            Card(
              color: Colors.deepPurple,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: Column(
                  children: _leaderboard.asMap().entries.map((entry) {
                    final rank = entry.key + 1;
                    final user = entry.value;
                    final isTop = rank == 1;
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6.0),
                      child: Row(
                        children: [
                          SizedBox(
                            width: 30,
                            child: Text(
                              "$rank.", 
                              style: TextStyle(
                                color: isTop ? Colors.amber : Colors.white, 
                                fontWeight: FontWeight.bold,
                                fontSize: 16
                              )
                            ),
                          ),
                          Text(
                            user['username'] ?? "Unknown", 
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w500, fontSize: 16)
                          ),
                          const Spacer(),
                          Text(
                            "${(user['total_volume'] as num).toInt()} lbs",
                            style: const TextStyle(color: Colors.white70, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),
            const SizedBox(height: 24),
          ],

          // --- REQUESTS ---
          if (_requests.isNotEmpty) ...[
            const Text("Friend Requests", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.orange)),
            ..._requests.map((req) {
              final requesterName = req['profiles']?['username'] ?? "Unknown User";
              return Card(
                color: Colors.orange.withValues(alpha: 0.1),
                child: ListTile(
                  title: Text(requesterName),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.check, color: Colors.green),
                        onPressed: () async {
                          await context.read<SocialService>().acceptRequest(req['id']);
                          _fetchFriendData();
                        },
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, color: Colors.red),
                        onPressed: () async {
                          await context.read<SocialService>().deleteFriendship(req['id']);
                          _fetchFriendData();
                        },
                      ),
                    ],
                  ),
                ),
              );
            }),
            const Divider(),
          ],
          
          // --- FRIENDS LIST ---
          const Text("My Friends", style: TextStyle(fontWeight: FontWeight.bold)),
          if (_friends.isEmpty) 
            const Padding(padding: EdgeInsets.all(16), child: Text("No friends yet. Go to Search!", style: TextStyle(color: Colors.grey))),
          
          ..._friends.map((f) {
            final fName = f['username'] ?? "Unknown";
            return Card(
              child: ListTile(
                leading: CircleAvatar(child: Text(fName.isNotEmpty ? fName[0].toUpperCase() : "?")),
                title: Text(fName),
                subtitle: const Text("Friend"), 
                trailing: IconButton(
                  icon: const Icon(Icons.person_remove, color: Colors.grey),
                  onPressed: () async {
                    await context.read<SocialService>().deleteFriendship(f['friendship_id']);
                    _fetchFriendData();
                  },
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  // TAB 3: SEARCH
  Widget _buildSearchTab() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: "Search Username...",
              suffixIcon: IconButton(icon: const Icon(Icons.search), onPressed: _doSearch),
              border: const OutlineInputBorder(),
            ),
            onSubmitted: (_) => _doSearch(),
          ),
        ),
        if (_isSearching) const LinearProgressIndicator(),
        Expanded(
          child: ListView.builder(
            itemCount: _searchResults.length,
            itemBuilder: (ctx, i) {
              final user = _searchResults[i];
              return ListTile(
                title: Text(user['username'] ?? "Unknown User"), 
                // FIXED: Wrapped in SizedBox + Style Override to prevent infinite width crash
                trailing: SizedBox(
                  width: 90,
                  height: 36,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      minimumSize: Size.zero, // CRITICAL: Reset global theme constraint
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                    ),
                    icon: const Icon(Icons.person_add, size: 14),
                    label: const Text("Add", style: TextStyle(fontSize: 12)),
                    onPressed: () async {
                      await context.read<SocialService>().sendFriendRequest(user['id']);
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Request Sent!")));
                      }
                    },
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}