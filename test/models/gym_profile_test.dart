import 'package:flutter_test/flutter_test.dart';
import 'package:open_lift_2/models/gym_profile.dart';

void main() {
  group('GymProfile', () {
    test('Correctly identifies owner vs shared', () {
      final ownerId = 'user_123';
      final gymMap = {
        'id': 'gym_abc',
        'name': 'My Gym',
        'is_default': 1,
        'owner_id': ownerId,
      };

      // Case 1: I am the owner
      final profileOwner = GymProfile.fromMap(gymMap, currentUserId: ownerId);
      expect(profileOwner.isShared, false);
      expect(profileOwner.canEdit, true);

      // Case 2: I am a visitor (Shared)
      final visitorId = 'user_456';
      final profileVisitor = GymProfile.fromMap(gymMap, currentUserId: visitorId);
      expect(profileVisitor.isShared, true);
      // By default visitors can't edit unless specified in join query (which isn't in this map)
      // The logic says: if isShared -> check 'can_edit_gear'. Map doesn't have it, so null/false.
      expect(profileVisitor.canEdit, false);
    });

    test('Shared profile respects can_edit_gear permission', () {
      final ownerId = 'user_123';
      final visitorId = 'user_456';
      
      final gymMap = {
        'id': 'gym_abc',
        'name': 'Shared Gym',
        'is_default': 0,
        'owner_id': ownerId,
        'can_edit_gear': 1 // Granted
      };

      final profile = GymProfile.fromMap(gymMap, currentUserId: visitorId);
      expect(profile.isShared, true);
      expect(profile.canEdit, true);
    });
  });
}
