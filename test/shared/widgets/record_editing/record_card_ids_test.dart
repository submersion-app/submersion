import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/features/buddies/presentation/editing/buddy_card_ids.dart';
import 'package:submersion/features/certifications/presentation/editing/certification_card_ids.dart';
import 'package:submersion/features/courses/presentation/editing/course_card_ids.dart';
import 'package:submersion/features/dive_centers/presentation/editing/dive_center_card_ids.dart';
import 'package:submersion/features/documents/presentation/editing/document_card_ids.dart';
import 'package:submersion/features/equipment/presentation/editing/equipment_set_card_ids.dart';
import 'package:submersion/features/equipment/presentation/editing/gear_item_card_ids.dart';
import 'package:submersion/features/gps_log/presentation/editing/gps_track_card_ids.dart';
import 'package:submersion/features/marine_life/presentation/editing/species_card_ids.dart';
import 'package:submersion/features/nav_track/presentation/editing/nav_track_card_ids.dart';
import 'package:submersion/features/trips/presentation/editing/trip_card_ids.dart';
import 'package:submersion/features/trips/presentation/widgets/trip_detail_tabs.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

/// Every phase 3 record type's card ids, with each card's title.
Map<String, Map<String, String Function(AppLocalizations)>> _all() => {
  'buddies': {
    for (final v in BuddyCardId.values) v.name: v.localizedDisplayName,
  },
  'dive_centers': {
    for (final v in DiveCenterCardId.values) v.name: v.localizedDisplayName,
  },
  'certifications': {
    for (final v in CertificationCardId.values) v.name: v.localizedDisplayName,
  },
  'courses': {
    for (final v in CourseCardId.values) v.name: v.localizedDisplayName,
  },
  'documents': {
    for (final v in DocumentCardId.values) v.name: v.localizedDisplayName,
  },
  'species': {
    for (final v in SpeciesCardId.values) v.name: v.localizedDisplayName,
  },
  'gps_tracks': {
    for (final v in GpsTrackCardId.values) v.name: v.localizedDisplayName,
  },
  'nav_tracks': {
    for (final v in NavTrackCardId.values) v.name: v.localizedDisplayName,
  },
  'trips': {for (final v in TripCardId.values) v.name: v.localizedDisplayName},
  'equipment': {
    for (final v in GearItemCardId.values) v.name: v.localizedDisplayName,
  },
  'equipment_sets': {
    for (final v in EquipmentSetCardId.values) v.name: v.localizedDisplayName,
  },
};

void main() {
  final l = lookupAppLocalizations(const Locale('en'));

  test('every card id is unique within its type and none is empty', () {
    final lists = <String, List<Enum>>{
      'buddies': BuddyCardId.values,
      'dive_centers': DiveCenterCardId.values,
      'certifications': CertificationCardId.values,
      'courses': CourseCardId.values,
      'documents': DocumentCardId.values,
      'species': SpeciesCardId.values,
      'gps_tracks': GpsTrackCardId.values,
      'nav_tracks': NavTrackCardId.values,
      'trips': TripCardId.values,
      'equipment': GearItemCardId.values,
      'equipment_sets': EquipmentSetCardId.values,
    };
    for (final MapEntry(key: table, value: values) in lists.entries) {
      final names = values.map((v) => v.name).toList();
      expect(names, isNotEmpty, reason: table);
      expect(names.toSet().length, names.length, reason: table);
    }
  });

  test('every card has a title', () {
    for (final MapEntry(key: table, value: cards) in _all().entries) {
      for (final MapEntry(key: id, value: title) in cards.entries) {
        final name = title(l);
        expect(name, isNotEmpty, reason: '$table $id');
        expect(name, isNot(id), reason: '$table $id');
      }
    }
  });

  test("a header block is named by its record's kind", () {
    expect(BuddyCardId.header.localizedDisplayName(l), 'Buddy');
    expect(SpeciesCardId.header.localizedDisplayName(l), 'Species');
    expect(GpsTrackCardId.header.localizedDisplayName(l), 'GPS Track');
  });

  test('trip cards know their tab', () {
    // With the rest of the trip summary, not on every tab (issue #4927).
    expect(TripCardId.header.tab, TripDetailTab.overview);
    expect(TripCardId.packedGear.tab, TripDetailTab.gear);
    expect(TripCardId.cylinders.tab, TripDetailTab.gear);
    expect(TripCardId.checklists.tab, TripDetailTab.checklist);
    expect(TripCardId.photos.tab, TripDetailTab.photos);
  });

  test('the new titles read as written', () {
    expect(DiveCenterCardId.map.localizedDisplayName(l), 'Map');
    expect(GpsTrackCardId.trim.localizedDisplayName(l), 'Trim');
    expect(BuddyCardId.gear.localizedDisplayName(l), 'Gear lent');
    expect(EquipmentSetCardId.bundle.localizedDisplayName(l), 'Bundle');
  });
}
