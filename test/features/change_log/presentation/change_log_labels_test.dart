import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/dive_detail_sections.dart';
import 'package:submersion/core/services/change_log/change_log_scope.dart';
import 'package:submersion/core/services/change_log/record_edit_label.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/change_log/domain/entities/change_log_operation.dart';
import 'package:submersion/features/change_log/presentation/change_log_labels.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/arb/app_localizations_en.dart';

void main() {
  final l = AppLocalizationsEn();

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
      cardIds: ['tags', 'notes'],
    );

    test('its stored label reads as Edited: with the card titles', () {
      expect(changeLogStoredLabel(l, label), 'Edited: $notes, $tags');
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
}
