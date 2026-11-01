import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/dive_field.dart';
import 'package:submersion/core/constants/enums.dart' show WeightType;
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/buddies/data/repositories/buddy_repository.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/dive_log/data/services/bulk_dive_edit_service.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/domain/entities/dive_weight.dart';
import 'package:submersion/features/marine_life/data/repositories/species_repository.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/features/table_editor/domain/paste_planner.dart';
import 'package:submersion/features/table_editor/domain/table_draft.dart';
import 'package:submersion/features/table_editor/domain/table_draft_state.dart';
import 'package:submersion/features/table_editor/domain/table_editor_column.dart';
import 'package:submersion/features/table_editor/entities/dive_table_editor_entity.dart';
import 'package:submersion/features/table_editor/presentation/table_editor_paste.dart';
import 'package:submersion/l10n/arb/app_localizations_en.dart';

import '../../../helpers/test_database.dart';

/// The paste flow (#3422): clipboard text to a plan, a plan to drafts.
void main() {
  late DiveTableEditorEntity entity;
  final l10n = AppLocalizationsEn();
  const units = UnitFormatter(AppSettings());
  final d1 = Dive(id: 'd1', diveNumber: 1, dateTime: DateTime(2026, 1, 1));
  final d2 = Dive(id: 'd2', diveNumber: 2, dateTime: DateTime(2026, 1, 2));

  setUp(() async {
    await setUpTestDatabase();
    final repo = DiveRepository();
    entity = DiveTableEditorEntity(
      diveRepo: repo,
      bulk: BulkDiveEditService(repo, BuddyRepository(), SpeciesRepository()),
      sites: const [ChoiceOption('s1', 'Blue Hole')],
      centers: const [],
      trips: const [],
    );
  });

  tearDown(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null);
    await tearDownTestDatabase();
  });

  void mockClipboard(Object? Function() reply) {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
          if (call.method == 'Clipboard.getData') return reply();
          return null;
        });
  }

  test('two-column paste with dive numbers lands by number and flags an '
      'unknown list value', () {
    final plan = planClipboardPaste<Dive, DiveField>(
      text: '2\tBlue Hole\n1\tAtlantis\n',
      entity: entity,
      rows: [d1, d2],
      visibleColumns: const [DiveField.diveNumber, DiveField.siteName],
      selected: CellPosition('d1', DiveField.siteName.name),
      l10n: l10n,
    );
    expect(plan.matching, PasteMatching.byNumber);

    final notifier = TableDraftsNotifier();
    applyPastePlan<Dive, DiveField>(
      plan: plan,
      entity: entity,
      rowsById: {'d1': d1, 'd2': d2},
      units: units,
      l10n: l10n,
      notifier: notifier,
    );

    expect(notifier.state.at('d2', DiveField.siteName.name)?.value, 's1');
    final bad = notifier.state.at('d1', DiveField.siteName.name);
    expect(bad?.flag, TableDraftFlag.unknownValue);
    expect(bad?.rawText, 'Atlantis');
  });

  test('a header row maps columns by their labels', () {
    final plan = planClipboardPaste<Dive, DiveField>(
      text: 'Dive #\tSite\n1\tBlue Hole\n',
      entity: entity,
      rows: [d1, d2],
      visibleColumns: const [DiveField.diveNumber, DiveField.siteName],
      selected: CellPosition('d2', DiveField.siteName.name),
      l10n: l10n,
    );

    expect(plan.hadHeader, isTrue);
    expect(plan.matching, PasteMatching.byNumber);
    expect(plan.cells.single.entityId, 'd1');
    expect(plan.cells.single.field, DiveField.siteName);
  });

  test('readClipboardText returns the text, and null when the platform '
      'refuses', () async {
    mockClipboard(() => <String, dynamic>{'text': '6,5'});
    expect(await readClipboardText(), '6,5');

    mockClipboard(() => throw PlatformException(code: 'denied'));
    expect(await readClipboardText(), isNull);
  });

  test('a cell the row cannot edit is reported as read-only', () {
    final twoWeights = Dive(
      id: 'd3',
      diveNumber: 3,
      dateTime: DateTime(2026, 1, 3),
      weights: const [
        DiveWeight(
          id: 'w1',
          diveId: 'd3',
          weightType: WeightType.belt,
          amountKg: 3,
        ),
        DiveWeight(
          id: 'w2',
          diveId: 'd3',
          weightType: WeightType.belt,
          amountKg: 4,
        ),
      ],
    );
    final plan = planClipboardPaste<Dive, DiveField>(
      text: '3\t6\n1\t7\n',
      entity: entity,
      rows: [d1, twoWeights],
      visibleColumns: const [DiveField.diveNumber, DiveField.totalWeight],
      selected: CellPosition('d1', DiveField.totalWeight.name),
      l10n: l10n,
    );
    final notifier = TableDraftsNotifier();

    final skipped = applyPastePlan<Dive, DiveField>(
      plan: plan,
      entity: entity,
      rowsById: {'d1': d1, 'd3': twoWeights},
      units: units,
      l10n: l10n,
      notifier: notifier,
    );

    expect(notifier.state.at('d1', DiveField.totalWeight.name)?.value, 7.0);
    expect(notifier.state.at('d3', DiveField.totalWeight.name), isNull);
    expect(skipped.single.reason, PasteSkipReason.readOnlyCell);
    expect(skipped.single.detail, '3');
  });

  test('pasting over a drafted cell keeps that draft\'s original', () {
    final notifier = TableDraftsNotifier()
      ..put(
        TableDraft(
          entityId: 'd1',
          fieldName: DiveField.siteName.name,
          original: 'old-site',
          value: 's1',
        ),
      );
    final plan = planClipboardPaste<Dive, DiveField>(
      text: 'Blue Hole',
      entity: entity,
      rows: [d1],
      visibleColumns: const [DiveField.diveNumber, DiveField.siteName],
      selected: CellPosition('d1', DiveField.siteName.name),
      l10n: l10n,
    );

    applyPastePlan<Dive, DiveField>(
      plan: plan,
      entity: entity,
      rowsById: {'d1': d1},
      units: units,
      l10n: l10n,
      notifier: notifier,
      existing: notifier.state,
    );

    expect(
      notifier.state.at('d1', DiveField.siteName.name)?.original,
      'old-site',
    );
  });
}
