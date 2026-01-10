import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'auth_service.dart';

class SocialService {
  final AuthService _auth;
  final SupabaseClient _supabase = Supabase.instance.client;

  SocialService(this._auth);

  // --- SEARCH ---
  
  /// Find users by username (partial match)
  Future<List<Map<String, dynamic>>> searchUsers(String query) async {
    if (query.length < 3) return [];
    
    final currentUserId = _auth.user?.id;
    if (currentUserId == null) return [];

    try {
      final response = await _supabase
          .from('profiles')
          .select()
          .ilike('username', '%$query%')
          .neq('id', currentUserId) // Don't show myself
          .limit(10);
      
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      debugPrint("Search Error: $e");
      return [];
    }
  }

  // --- FRIENDSHIP MANAGEMENT ---

  /// Send a request to another user
  Future<void> sendFriendRequest(String targetUserId) async {
    final myId = _auth.user!.id;
    
    // Check if reverse exists (they sent me one)
    // For MVP we just try insert; Supabase unique constraint (requester, receiver) handles dupes
    await _supabase.from('friendships').insert({
      'requester_id': myId,
      'receiver_id': targetUserId,
      'status': 'pending',
    });
  }

  /// Accept a request
  Future<void> acceptRequest(String friendshipId) async {
    await _supabase
        .from('friendships')
        .update({'status': 'accepted'})
        .eq('id', friendshipId);
  }

  /// Reject or Cancel a request
  Future<void> deleteFriendship(String friendshipId) async {
    await _supabase.from('friendships').delete().eq('id', friendshipId);
  }

  // --- DATA FETCHING ---

  /// Get requests sent TO me
  Future<List<Map<String, dynamic>>> getIncomingRequests() async {
    final myId = _auth.user!.id;
    
    final response = await _supabase
        .from('friendships')
        .select('*, profiles:requester_id(username, avatar_url)') // Join to get sender details
        .eq('receiver_id', myId)
        .eq('status', 'pending');
        
    return List<Map<String, dynamic>>.from(response);
  }

  /// Get confirmed friends
  Future<List<Map<String, dynamic>>> getFriends() async {
    final myId = _auth.user!.id;

    // We need to fetch rows where I am requester OR receiver, AND status is accepted
    final response = await _supabase
        .from('friendships')
        .select('''
          *,
          requester:requester_id(id, username, avatar_url),
          receiver:receiver_id(id, username, avatar_url)
        ''')
        .or('requester_id.eq.$myId,receiver_id.eq.$myId')
        .eq('status', 'accepted');

    // Parse the result to just get the "Other Person"
    return List<Map<String, dynamic>>.from(response).map((row) {
      final isMeRequester = row['requester_id'] == myId;
      final friendProfile = isMeRequester ? row['receiver'] : row['requester'];
      return {
        'friendship_id': row['id'],
        'friend_id': friendProfile['id'],
        'username': friendProfile['username'],
        'avatar_url': friendProfile['avatar_url'],
      };
    }).toList();
  }

  // --- LEADERBOARD ---

  Future<List<Map<String, dynamic>>> getWeeklyLeaderboard() async {
    try {
      // Call the Postgres function
      final response = await _supabase.rpc('get_weekly_leaderboard');
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      debugPrint("Leaderboard Error: $e");
      return [];
    }
  }

  // --- INBOX & NOTIFICATIONS (v1.1.0) ---

  Future<List<Map<String, dynamic>>> getNotifications() async {
    final myId = _auth.user!.id;
    final response = await _supabase
        .from('notifications')
        .select()
        .eq('user_id', myId)
        .order('created_at', ascending: false);
    return List<Map<String, dynamic>>.from(response);
  }

  Future<void> markNotificationRead(String id) async {
    await _supabase.from('notifications').update({'is_read': true}).eq('id', id);
  }

  Future<void> deleteNotification(String id) async {
    await _supabase.from('notifications').delete().eq('id', id);
  }

  Future<void> sendGymInvite(String gymId, String gymName, String friendId) async {
    final myId = _auth.user!.id;
    final myName = _auth.profile?['username'] ?? 'A friend';

    // 1. Create Pending Member Entry
    await _supabase.from('gym_members').insert({
      'id': _uuid(),
      'gym_id': gymId,
      'user_id': friendId,
      'nickname': 'Pending Member',
      'status': 'pending',
      'invited_by': myId
    });

    // 2. Send Notification
    await _supabase.from('notifications').insert({
      'user_id': friendId,
      'type': 'gym_invite',
      'payload_json': {'gym_id': gymId, 'gym_name': gymName, 'inviter_name': myName},
      'is_read': false,
    });
  }

  Future<void> sharePlan(Map<String, dynamic> planData, String friendId) async {
    final myName = _auth.profile?['username'] ?? 'A friend';
    
    await _supabase.from('notifications').insert({
      'user_id': friendId,
      'type': 'plan_share',
      'payload_json': {
        'plan_name': planData['name'],
        'plan_data': planData, // Embed full JSON for import
        'sender_name': myName
      },
      'is_read': false,
    });
  }

  // --- ACTIVITY FEED (v1.1.0) ---

  Future<List<Map<String, dynamic>>> getFriendActivity() async {
    final friends = await getFriends();
    final friendIds = friends.map((f) => f['friend_id']).toList();
    if (friendIds.isEmpty) return [];

    // Fetch logs from friends
    final response = await _supabase
        .from('logs')
        .select('*, profiles(username, avatar_url)')
        .in_('owner_id', friendIds)
        .order('timestamp', ascending: false)
        .limit(50);
        
    return List<Map<String, dynamic>>.from(response);
  }

  Future<void> toggleLike(String logId) async {
    final myId = _auth.user!.id;
    // Check if liked
    final existing = await _supabase
        .from('workout_likes')
        .select()
        .eq('log_id', logId) // Assuming schema links to log_id, or session_id depending on granularity
        .eq('user_id', myId);
        
    if (existing.isNotEmpty) {
      await _supabase.from('workout_likes').delete().eq('id', existing.first['id']);
    } else {
      await _supabase.from('workout_likes').insert({
        'log_id': logId,
        'user_id': myId,
      });
    }
  }

  // Helper
  String _uuid() {
    return DateTime.now().millisecondsSinceEpoch.toString(); // Simple ID for now
  }
}