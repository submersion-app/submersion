import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/dive_detail_sections.dart';
import 'package:submersion/core/constants/site_detail_sections.dart';
import 'package:submersion/core/services/change_log/change_log_scope.dart';
import 'package:submersion/core/services/change_log/record_edit_label.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
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
import 'package:submersion/features/change_log/domain/entities/change_log_operation.dart';
import 'package:submersion/features/change_log/domain/entities/change_log_event.dart';
import 'package:submersion/features/change_log/presentation/change_log_labels.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/arb/app_localizations_en.dart';

void main() {
  final l = AppLocalizationsEn();

  test('the tables a sitting lists under its dive have names of their own', () {
    expect(changeLogTableLabel(l, 'dive_safety_findings'), 'Safety finding');
    expect(changeLogTableLabel(l, 'tank_pressure_series'), 'Pressure readings');
    expect(changeLogTableLabel(l, 'nav_tracks'), 'Underwater track');
    expect(changeLogTableLabel(l, 'equipment_findings'), 'Condition finding');
    // A dive's first type is a row of its own, not "Dive Dive Types".
    expect(changeLogTableLabel(l, 'dive_dive_types'), 'Dive type');
  });

  test('the agent source has a label and an icon', () {
    expect(changeLogSourceLabel(l, ChangeLogSource.agent), 'Agent');
    expect(
      changeLogSourceIcon(ChangeLogSource.agent),
      Icons.smart_toy_outlined,
    );
  });

  test('an agent operation is titled by its own label', () {
    final operation = ChangeLogOperation(
      id: 'op',
      source: ChangeLogSource.agent,
      label: 'Fix buddy names',
      startedAt: DateTime(2026, 11, 2),
      endedAt: DateTime(2026, 11, 2),
    );

    expect(changeLogTitle(l, operation), 'Fix buddy names');
  });

  group('an editing sitting', () {
    final notes = DiveDetailSectionId.notes.localizedDisplayName(l);
    final tags = DiveDetailSectionId.tags.localizedDisplayName(l);
    final label = RecordEditLabel.encode(
      table: 'dives',
      id: 'dive',
      cardIds: ['tags', 'notes'],
    );

    test('its stored label reads as Edited: with the card titles', () {
      expect(changeLogStoredLabel(l, label), 'Edited: $notes, $tags');
    });

    test('a label written before it named its record reads the same', () {
      expect(
        changeLogStoredLabel(l, 'record_edit:dives:notes,tags'),
        'Edited: $notes, $tags',
      );
    });

    // The header block is not a section (issue #4527, plan 4).
    test('a sitting that changed the header names it', () {
      expect(
        changeLogStoredLabel(l, 'record_edit:dives:header,notes'),
        'Edited: ${l.diveLog_detail_section_header}, $notes',
      );
    });

    test('a card id with no title is shown as written', () {
      expect(
        changeLogStoredLabel(l, 'record_edit:dives:notes,zzz'),
        'Edited: $notes, zzz',
      );
    });

    test('a record type with no card titles shows the ids as written', () {
      expect(
        changeLogStoredLabel(l, 'record_edit:trips:dates,gear'),
        'Edited: dates, gear',
      );
    });

    // A site's sitting names the site page's cards (issue #4527, phase 2).
    test('a site sitting names its cards by their titles', () {
      final description = SiteDetailSectionId.description.localizedDisplayName(
        l,
      );
      final siteNotes = SiteDetailSectionId.notes.localizedDisplayName(l);
      expect(
        changeLogStoredLabel(l, 'record_edit:dive_sites:s1:description,notes'),
        'Edited: $description, $siteNotes',
      );
    });

    test('a site sitting names the header block', () {
      final siteNotes = SiteDetailSectionId.notes.localizedDisplayName(l);
      expect(
        changeLogStoredLabel(l, 'record_edit:dive_sites:s1:header,notes'),
        'Edited: ${l.diveSites_detail_section_header}, $siteNotes',
      );
    });

    test('a site card id with no title is shown as written', () {
      final siteNotes = SiteDetailSectionId.notes.localizedDisplayName(l);
      expect(
        changeLogStoredLabel(l, 'record_edit:dive_sites:s1:notes,zzz'),
        'Edited: $siteNotes, zzz',
      );
    });

    // Phase 3's record pages name their cards through their own card ids
    // (issue #4527, phase 3 plan 1).
    test('a buddy sitting names the header block and Contact', () {
      expect(
        changeLogStoredLabel(l, 'record_edit:buddies:b1:header,contact'),
        l.changeLog_label_recordEdit(
          [
            BuddyCardId.header.localizedDisplayName(l),
            BuddyCardId.contact.localizedDisplayName(l),
          ].join(l.changeLog_label_recordEditSeparator),
        ),
      );
    });

    test('every phase 3 table names its cards', () {
      final cases = <String, String>{
        'record_edit:dive_centers:c1:rentalGear': DiveCenterCardId.rentalGear
            .localizedDisplayName(l),
        'record_edit:certifications:c1:currency': CertificationCardId.currency
            .localizedDisplayName(l),
        'record_edit:courses:c1:requirements': CourseCardId.requirements
            .localizedDisplayName(l),
        'record_edit:documents:d1:pages': DocumentCardId.pages
            .localizedDisplayName(l),
        'record_edit:species:s1:photos': SpeciesCardId.photos
            .localizedDisplayName(l),
        'record_edit:gps_tracks:g1:trim': GpsTrackCardId.trim
            .localizedDisplayName(l),
        'record_edit:nav_tracks:n1:correction': NavTrackCardId.correction
            .localizedDisplayName(l),
        'record_edit:trips:t1:checklists': TripCardId.checklists
            .localizedDisplayName(l),
        'record_edit:equipment:e1:serviceClocks': GearItemCardId.serviceClocks
            .localizedDisplayName(l),
        'record_edit:equipment:e1:passportFills': GearItemCardId.passportFills
            .localizedDisplayName(l),
        'record_edit:equipment_sets:s1:members': EquipmentSetCardId.members
            .localizedDisplayName(l),
      };
      for (final MapEntry(key: label, value: card) in cases.entries) {
        expect(
          changeLogStoredLabel(l, label),
          l.changeLog_label_recordEdit(card),
          reason: label,
        );
      }
    });

    test('a phase 3 card id with no title is shown as written', () {
      final notes = TripCardId.notes.localizedDisplayName(l);
      expect(
        changeLogStoredLabel(l, 'record_edit:trips:t1:notes,zzz'),
        'Edited: $notes, zzz',
      );
    });

    test('a GPS track is named as one', () {
      expect(changeLogTableLabel(l, 'gps_tracks'), 'GPS Track');
    });

    // A photo's sitting reads apart from the dive's own cards, as its entry
    // sits in the dive's History (issue #4527, plan 10).
    test('a photo sitting reads "Edited photo: Color, Species"', () {
      expect(
        changeLogStoredLabel(l, 'record_edit:media:color,species'),
        'Edited photo: Color, Species',
      );
    });

    test('a photo sitting names people, time in dive and details', () {
      expect(
        changeLogStoredLabel(l, 'record_edit:media:details,people,time'),
        'Edited photo: Details, People, Time in dive',
      );
    });

    test('a photo sitting names its tags', () {
      expect(
        changeLogStoredLabel(l, 'record_edit:media:tags'),
        'Edited photo: Tags',
      );
    });

    test('a photo sitting names its file', () {
      expect(
        changeLogStoredLabel(l, 'record_edit:media:file'),
        'Edited photo: File',
      );
    });

    test('an unknown photo card id is shown as written', () {
      expect(
        changeLogStoredLabel(l, 'record_edit:media:species,zzz'),
        'Edited photo: Species, zzz',
      );
    });

    test('a label the app stores by key still translates', () {
      expect(
        changeLogStoredLabel(l, ChangeLogLabels.bulkEdit),
        l.changeLog_label_bulkEdit,
      );
    });

    test('its entry says which cards changed, after where it came from', () {
      final operation = ChangeLogOperation(
        id: 'op',
        source: ChangeLogSource.manual,
        label: label,
        rootTable: 'dives',
        rootId: 'd1',
        startedAt: DateTime(2026, 11, 2, 9, 30),
        endedAt: DateTime(2026, 11, 2, 9, 30),
      );

      final subtitle = changeLogSubtitle(
        l,
        const UnitFormatter(AppSettings()),
        operation,
        const {},
      );

      expect(
        subtitle,
        endsWith('${l.changeLog_thisDevice} · Edited: $notes, $tags'),
      );
    });

    // Another diver sees only the records of the sitting shared with them
    // (issue #4527); the cards it changed are about the dive they cannot
    // open.
    test(
      'a diver who sees only part of it is not told which cards changed',
      () {
        final operation =
            ChangeLogOperation(
              id: 'op',
              source: ChangeLogSource.manual,
              label: label,
              diverId: 'owner',
              rootTable: 'dives',
              rootId: 'd1',
              startedAt: DateTime(2026, 11, 2, 9, 30),
              endedAt: DateTime(2026, 11, 2, 9, 30),
            ).restrictedTo(
              {(table: 'dive_sites', id: 's1')},
              root: (table: 'dive_sites', id: 's1'),
              label: 'Reef',
            );

        final subtitle = changeLogSubtitle(
          l,
          const UnitFormatter(AppSettings()),
          operation,
          const {},
        );

        expect(subtitle, endsWith(l.changeLog_thisDevice));
      },
    );

    // A new dive's sitting creates the dive (issue #4527, plan 8): its
    // entry already reads Added, so the cards are named without Edited.
    test('a sitting that created its record names its cards alone', () {
      final operation = ChangeLogOperation(
        id: 'op',
        source: ChangeLogSource.manual,
        label: label,
        rootTable: 'dives',
        rootId: 'dive',
        startedAt: DateTime(2026, 11, 2, 9, 30),
        endedAt: DateTime(2026, 11, 2, 9, 30),
      );

      final subtitle = changeLogSubtitle(
        l,
        const UnitFormatter(AppSettings()),
        operation,
        const {},
        rootAction: ChangeLogAction.insert,
      );

      expect(subtitle, endsWith('${l.changeLog_thisDevice} · $notes, $tags'));
      expect(subtitle, isNot(contains('Edited')));
    });

    test('a sitting that edited its record still reads Edited:', () {
      final operation = ChangeLogOperation(
        id: 'op',
        source: ChangeLogSource.manual,
        label: label,
        rootTable: 'dives',
        rootId: 'dive',
        startedAt: DateTime(2026, 11, 2, 9, 30),
        endedAt: DateTime(2026, 11, 2, 9, 30),
      );

      final subtitle = changeLogSubtitle(
        l,
        const UnitFormatter(AppSettings()),
        operation,
        const {},
        rootAction: ChangeLogAction.update,
      );

      expect(subtitle, endsWith('Edited: $notes, $tags'));
    });

    test('a sitting that named no card reads as Edited', () {
      expect(
        changeLogStoredLabel(
          l,
          RecordEditLabel.encode(table: 'dives', id: 'd1', cardIds: const []),
        ),
        l.changeLog_action_edited,
      );
    });

    test('an entry with no sitting label ends at where it came from', () {
      final operation = ChangeLogOperation(
        id: 'op',
        source: ChangeLogSource.manual,
        rootTable: 'dives',
        rootId: 'd1',
        startedAt: DateTime(2026, 11, 2, 9, 30),
        endedAt: DateTime(2026, 11, 2, 9, 30),
      );

      final subtitle = changeLogSubtitle(
        l,
        const UnitFormatter(AppSettings()),
        operation,
        const {},
      );

      expect(subtitle, endsWith(l.changeLog_thisDevice));
    });
  });

  test('the media library bulk actions read as themselves', () {
    expect(
      changeLogStoredLabel(l, ChangeLogLabels.moveMedia),
      'Moved to another dive',
    );
    expect(
      changeLogStoredLabel(l, ChangeLogLabels.unlinkMedia),
      'Unlinked from the library',
    );
    expect(
      changeLogStoredLabel(l, ChangeLogLabels.removeGearPhotos),
      'Removed gear photos',
    );
  });
}
