import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/services/sync/sync_service.dart';
import 'package:submersion/features/settings/presentation/conflicts/conflict_comparison.dart';
import 'package:submersion/features/settings/presentation/conflicts/conflict_device_labels.dart';
import 'package:submersion/features/settings/presentation/conflicts/conflict_field.dart';
import 'package:submersion/features/settings/presentation/conflicts/widgets/conflict_choice_consequence.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

void main() {
  late AppLocalizations l10n;
  setUpAll(() async {
    l10n = await AppLocalizations.delegate.load(const Locale('en'));
  });
  const devices = ConflictDeviceLabels(local: 'Pixel 8', remote: 'Windows PC');

  FieldDifference d(String label) => FieldDifference(
    key: label,
    label: label,
    kind: FieldKind.shortText,
    localValue: 'a',
    remoteValue: 'b',
    localDisplay: 'a',
    remoteDisplay: 'b',
  );

  final differing = ConflictComparison(
    state: ConflictComparisonState.differing,
    differences: [d('Water temp'), d('Notes')],
  );

  String text(ConflictComparison c, ConflictResolution? choice) =>
      conflictConsequence(
        l10n: l10n,
        comparison: c,
        devices: devices,
        choice: choice,
      );

  test('nothing chosen asks for a choice', () {
    expect(text(differing, null), 'Choose which version to keep.');
  });

  test('keep local names what the other device loses', () {
    expect(
      text(differing, ConflictResolution.keepLocal),
      "Keeps Pixel 8's version. Windows PC's values for Water temp, Notes "
      'are discarded.',
    );
  });

  test('a long list of fields is cut short', () {
    final many = ConflictComparison(
      state: ConflictComparisonState.differing,
      differences: [
        for (final l in ['A', 'B', 'C', 'D', 'E']) d(l),
      ],
    );
    expect(
      text(many, ConflictResolution.keepLocal),
      "Keeps Pixel 8's version. Windows PC's values for A, B, C and 2 more "
      'are discarded.',
    );
  });

  test('keep remote is the mirror', () {
    expect(
      text(differing, ConflictResolution.keepRemote),
      "Keeps Windows PC's version. Pixel 8's values for Water temp, Notes "
      'are discarded.',
    );
  });

  test('keep both adds a copy', () {
    expect(
      text(differing, ConflictResolution.keepBoth),
      "Keeps Pixel 8's version and adds Windows PC's version as a separate "
      'copy.',
    );
  });

  test('same content loses nothing under any choice', () {
    const same = ConflictComparison(state: ConflictComparisonState.sameContent);
    for (final choice in ConflictResolution.values) {
      expect(text(same, choice), 'Both versions match, so nothing is lost.');
    }
  });

  test('deletion states name the deletion', () {
    const remoteDeleted = ConflictComparison(
      state: ConflictComparisonState.remoteDeleted,
    );
    const localDeleted = ConflictComparison(
      state: ConflictComparisonState.localDeleted,
    );
    expect(
      text(remoteDeleted, ConflictResolution.keepLocal),
      "Keeps the record, with Pixel 8's values.",
    );
    expect(
      text(remoteDeleted, ConflictResolution.keepRemote),
      'Deletes the record on this device too.',
    );
    expect(
      text(localDeleted, ConflictResolution.keepLocal),
      'The record stays deleted on this device.',
    );
    expect(
      text(localDeleted, ConflictResolution.keepRemote),
      "Keeps the record, with Windows PC's values.",
    );
  });

  group('canKeepBoth', () {
    SyncConflict c(
      Map<String, dynamic> local,
      Map<String, dynamic> remote, {
      String type = 'dives',
    }) => SyncConflict(
      entityType: type,
      recordId: 'r',
      localData: local,
      remoteData: remote,
      localModified: DateTime(2026),
      remoteModified: DateTime(2026),
    );

    test('a normal record with an id can be copied', () {
      expect(canKeepBoth(differing, c({'id': 'r'}, {'id': 'r'})), isTrue);
    });

    test('not when the remote side is a deletion', () {
      expect(
        canKeepBoth(differing, c({'id': 'r'}, {'id': 'r', '_deleted': true})),
        isFalse,
      );
    });

    test('not when the local side is gone', () {
      expect(canKeepBoth(differing, c({}, {'id': 'r'})), isFalse);
    });

    test('not for a junction row with no id', () {
      expect(
        canKeepBoth(
          differing,
          c(
            {'diveId': 'd', 'tagId': 't'},
            {'diveId': 'd', 'tagId': 't'},
            type: 'diveEquipment',
          ),
        ),
        isFalse,
      );
    });

    test('not when both versions match', () {
      // Keep both would still copy the remote row, making a duplicate of a
      // record the dialog has just said is unchanged.
      const same = ConflictComparison(
        state: ConflictComparisonState.sameContent,
      );
      expect(canKeepBoth(same, c({'id': 'r'}, {'id': 'r'})), isFalse);
    });

    test('not for settings', () {
      expect(
        canKeepBoth(differing, c({'id': 'r'}, {'id': 'r'}, type: 'settings')),
        isFalse,
      );
    });
  });
}
