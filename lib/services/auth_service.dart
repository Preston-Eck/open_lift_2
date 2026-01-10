import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AuthService extends ChangeNotifier {
  final SupabaseClient _supabase = Supabase.instance.client;
  User? _user;
  Map<String, dynamic>? _profile;

  AuthService() {
    _user = _supabase.auth.currentUser;
    _loadProfile();
    
    _supabase.auth.onAuthStateChange.listen((data) {
      _user = data.session?.user;
      if (_user != null) {
        _loadProfile();
      } else {
        _profile = null;
      }
      notifyListeners();
    });
  }

  User? get user => _user;
  Map<String, dynamic>? get profile => _profile;
  bool get isAuthenticated => _user != null;
  String? get username => _profile?['username'];

  Future<void> _loadProfile() async {
    if (_user == null) return;
    try {
      final data = await _supabase
          .from('profiles')
          .select()
          .eq('id', _user!.id)
          .maybeSingle();
      _profile = data;
      notifyListeners();
    } catch (e) {
      debugPrint("Error loading profile: $e");
    }
  }

  /// Sign up and create a basic profile
  Future<void> signUp(String email, String password, String username) async {
    // We pass 'data' so the SQL Trigger can extract the username
    final response = await _supabase.auth.signUp(
      email: email, 
      password: password,
      data: {'username': username}, 
    );
    
    // If auto-confirm is off, user is null/not-logged-in here, which is fine.
    // The DB Trigger handles the profile creation in the background.
    
    if (response.user != null) {
      await _loadProfile();
    }
  }

  Future<void> signIn(String email, String password) async {
    await _supabase.auth.signInWithPassword(email: email, password: password);
  }

  Future<void> signOut() async {
    await _supabase.auth.signOut();
    _user = null;
    _profile = null;
    notifyListeners();
  }

  Future<void> updateFcmToken(String token) async {
    if (_user == null) return;
    try {
      await _supabase.from('profiles').update({'fcm_token': token}).eq('id', _user!.id);
      debugPrint("FCM Token Updated in Supabase");
    } catch (e) {
      debugPrint("Error updating FCM token: $e");
    }
  }
}