import 'package:flutter/material.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/buddies/domain/entities/buddy.dart';
import 'package:submersion/features/buddies/presentation/providers/buddy_providers.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/l10n/l10n_extension.dart';
import 'package:submersion/shared/widgets/profile_photo/profile_avatar.dart';

/// Who a DPV mission member is: a name, and the buddy or diver profile it
/// came from (at most one of the two ids is set).
typedef MissionWho = ({String name, String? buddyId, String? diverId});

/// A single-select sheet listing the active diver ("Me") and their buddies,
/// with photos. Returns null when dismissed.
Future<MissionWho?> showBuddyPickerSheet(BuildContext context) {
  return showModalBottomSheet<MissionWho>(
    context: context,
    isScrollControlled: true,
    builder: (context) => const _BuddyPickerSheet(),
  );
}

class _BuddyPickerSheet extends ConsumerWidget {
  const _BuddyPickerSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final me = ref.watch(currentDiverProvider).value;
    final buddies = ref.watch(allBuddiesProvider).value ?? const <Buddy>[];
    return SafeArea(
      child: ListView(
        shrinkWrap: true,
        children: [
          ListTile(title: Text(l10n.plannerMission_buddyPicker_title)),
          if (me != null)
            ListTile(
              leading: ProfileAvatar(photo: me.photo, initials: me.initials),
              title: Text(l10n.plannerMission_buddyPicker_me),
              subtitle: Text(me.name, maxLines: 1),
              onTap: () => Navigator.of(
                context,
              ).pop((name: me.name, buddyId: null, diverId: me.id)),
            ),
          if (buddies.isEmpty)
            ListTile(title: Text(l10n.plannerMission_buddyPicker_empty)),
          for (final buddy in buddies)
            ListTile(
              leading: MissionBuddyAvatar(buddy: buddy),
              title: Text(
                buddy.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              onTap: () => Navigator.of(
                context,
              ).pop((name: buddy.name, buddyId: buddy.id, diverId: null)),
            ),
        ],
      ),
    );
  }
}

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
