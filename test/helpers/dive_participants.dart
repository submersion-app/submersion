import 'package:submersion/features/buddies/domain/entities/buddy.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_roles/domain/entities/dive_role.dart';

/// A `dive_buddies` junction participant named [name] in the [roleId] role.
BuddyWithRole linkedParticipant(String name, String roleId) => BuddyWithRole(
  buddy: Buddy(
    id: 'buddy-$name',
    name: name,
    createdAt: DateTime(2026, 1, 1),
    updatedAt: DateTime(2026, 1, 1),
  ),
  role: DiveRole.synthetic(roleId),
);

/// A dive whose team was linked through the buddy picker: one peer buddy plus
/// a dive guide and a dive master, carrying stale legacy scalars that a
/// junction-authoritative export must ignore.
///
/// Expected export: Buddy `Ana`, Dive Master `Gil, Mia`. Neither
/// `Stalebuddy` nor `Staledm` may appear anywhere.
Dive diveWithLinkedTeam({String id = 'dive-team'}) => Dive(
  id: id,
  diveNumber: 42,
  dateTime: DateTime(2026, 5, 1, 9, 30),
  buddy: 'Stalebuddy',
  diveMaster: 'Staledm',
  buddies: [
    linkedParticipant('Ana', DiveRole.buddyId),
    linkedParticipant('Gil', DiveRole.diveGuideId),
    linkedParticipant('Mia', DiveRole.diveMasterId),
  ],
);

/// A legacy dive that only ever used the free-text scalars.
Dive diveWithLegacyScalarsOnly({String id = 'dive-legacy'}) => Dive(
  id: id,
  diveNumber: 7,
  dateTime: DateTime(2020, 5, 1, 9, 30),
  buddy: 'Oldbuddy',
  diveMaster: 'Olddm',
);
