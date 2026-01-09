class GymProfile {
  final String id;
  final String name;       // The official name
  final String? nickname;  // The local alias (if shared)
  final bool isDefault;
  final String ownerId;    // NEW
  final bool canEdit;      // NEW: Computed permission
  final bool isShared;     // NEW: True if I am not the owner

  GymProfile({
    required this.id,
    required this.name,
    this.nickname,
    this.isDefault = false,
    required this.ownerId,
    this.canEdit = true,
    this.isShared = false,
  });

  // Helper to get the display name (Nickname > Name)
  String get displayName => nickname != null && nickname!.isNotEmpty ? nickname! : name;

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'is_default': isDefault ? 1 : 0,
      'owner_id': ownerId,
    };
  }

  factory GymProfile.fromMap(Map<String, dynamic> map, {String? currentUserId}) {
    final ownerId = map['owner_id'] ?? currentUserId ?? 'unknown';
    final isShared = currentUserId != null && ownerId != currentUserId;
    
    // Permission logic: 
    // If owner -> true. 
    // If shared -> check 'can_edit_gear' (passed in map from join query)
    bool canEdit = true;
    if (isShared) {
      canEdit = (map['can_edit_gear'] == 1 || map['can_edit_gear'] == true);
    }

    return GymProfile(
      id: map['id'],
      name: map['name'],
      nickname: map['nickname'], // From gym_members table join
      isDefault: (map['is_default'] as int) == 1,
      ownerId: ownerId,
      isShared: isShared,
      canEdit: canEdit,
    );
  }
}