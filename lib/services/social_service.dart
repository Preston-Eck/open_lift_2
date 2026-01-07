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
}