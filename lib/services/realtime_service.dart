import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'auth_service.dart';

class RealtimeService extends ChangeNotifier {
  final AuthService _auth;
  final SupabaseClient _supabase = Supabase.instance.client;
  RealtimeChannel? _versusChannel;
  
  Map<String, double> _competitorTonnage = {};
  Map<String, double> get competitorTonnage => _competitorTonnage;

  RealtimeService(this._auth);

  void joinVersus(String roomId) {
    _competitorTonnage = {};
    _versusChannel = _supabase.channel('versus:$roomId');

    _versusChannel!.onBroadcast(
      event: 'tonnage_update',
      callback: (payload) {
        final userId = payload['user_id'] as String;
        final username = payload['username'] as String;
        final tonnage = (payload['tonnage'] as num).toDouble();
        
        _competitorTonnage["$username ($userId)"] = tonnage;
        notifyListeners();
      },
    ).subscribe();
  }

  void broadcastTonnage(String roomId, double currentTonnage) {
    if (_versusChannel == null) return;
    
    final myId = _auth.user?.id;
    final myUsername = _auth.profile?['username'] ?? 'Anonymous';

    if (myId == null) return;

    // ignore: invalid_use_of_internal_member
    _versusChannel!.send(
      type: 'broadcast' as dynamic,
      event: 'tonnage_update',
      payload: {
        'user_id': myId,
        'username': myUsername,
        'tonnage': currentTonnage,
      },
    );
  }

  void leaveVersus() {
    _versusChannel?.unsubscribe();
    _versusChannel = null;
    _competitorTonnage = {};
    notifyListeners();
  }
}
