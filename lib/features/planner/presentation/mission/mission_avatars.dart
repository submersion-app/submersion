import 'package:flutter/material.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/buddies/domain/entities/buddy.dart';
import 'package:submersion/features/buddies/presentation/providers/buddy_providers.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/planner/domain/entities/mission/mission_member.dart';
import 'package:submersion/shared/widgets/profile_photo/profile_avatar.dart';

/// A buddy's avatar; a buddy with no photo of their own who is linked to a
/// diver profile shows that profile's photo, as the buddy list does.
class MissionBuddyAvatar extends ConsumerWidget {
  const MissionBuddyAvatar({super.key, required this.buddy});

  final Buddy buddy;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final linkedId = buddy.linkedDiverId;
    final linkedPhoto = buddy.photo == null && linkedId != null
        ? ref.watch(diverByIdProvider(linkedId)).value?.photo
        : null;
    return ProfileAvatar(
      photo: buddy.photo ?? linkedPhoto,
      initials: buddy.initials,
    );
  }
}

/// The photo of the buddy or diver profile a team member was picked from,
/// else the member's initials.
class MissionMemberAvatar extends ConsumerWidget {
  const MissionMemberAvatar({super.key, required this.member});

  final MissionMember member;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final buddyId = member.buddyId;
    final diverId = member.diverId;
    if (buddyId != null) {
      final buddy = ref.watch(buddyByIdProvider(buddyId)).value;
      if (buddy != null) return MissionBuddyAvatar(buddy: buddy);
    } else if (diverId != null) {
      final diver = ref.watch(diverByIdProvider(diverId)).value;
      if (diver != null) {
        return ProfileAvatar(photo: diver.photo, initials: diver.initials);
      }
    }
    return ProfileAvatar(photo: null, initials: _initials(member.displayName));
  }

  /// First and last initials, as buddy and diver profiles show them.
  static String _initials(String name) {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.length >= 2) {
      return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
    }
    final only = parts.first;
    return only.isEmpty ? '?' : only[0].toUpperCase();
  }
}
