import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/services/sync/sync_coordinator.dart';
import 'package:submersion/features/equipment/data/repositories/equipment_repository_impl.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
import 'package:submersion/features/equipment/presentation/editing/gear_item_edit_fields.dart';
import 'package:submersion/features/cylinder_passports/data/repositories/cylinder_fill_repository.dart';
import 'package:submersion/features/cylinder_passports/data/repositories/cylinder_pairing_repository.dart';
import 'package:submersion/features/cylinder_passports/data/repositories/cylinder_passport_repository.dart';
import 'package:submersion/features/cylinder_passports/domain/entities/cylinder_fill.dart';
import 'package:submersion/features/cylinder_passports/domain/entities/passport_usage.dart';
import 'package:submersion/features/cylinder_passports/presentation/pages/passport_page.dart';
import 'package:submersion/features/cylinder_passports/presentation/providers/cylinder_passport_providers.dart';
import 'package:submersion/features/cylinder_passports/presentation/widgets/passport_entry_card.dart';
import 'package:submersion/features/gear_passports/presentation/pages/gear_passport_page.dart';
import 'package:submersion/features/gear_passports/presentation/widgets/gear_passport_entry_card.dart';
import 'package:submersion/features/equipment/domain/entities/service_clock_status.dart';
import 'package:submersion/features/equipment/domain/entities/service_record.dart';
import 'package:submersion/shared/widgets/record_editing/record_satellite_bar.dart';
import 'package:submersion/features/cylinder_passports/domain/entities/cylinder_pairing.dart';
import 'package:submersion/features/cylinder_passports/presentation/providers/cylinder_pairing_providers.dart';
import 'package:submersion/features/equipment/data/repositories/equipment_component_repository.dart';
import 'package:submersion/features/equipment/data/repositories/equipment_findings_repository.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_providers.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_finding.dart';
import 'package:submersion/features/equipment/presentation/editing/gear_item_card_ids.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_condition_providers.dart';
import 'package:submersion/l10n/arb/app_localizations_en.dart';
import 'package:submersion/shared/widgets/record_editing/edit_session.dart';
import 'package:submersion/shared/widgets/record_editing/record_card_frame.dart';
import 'package:submersion/shared/widgets/record_editing/record_edit_controller.dart';

import '../../../../helpers/test_database.dart';
import 'equipment_detail_page_unlock_harness.dart';

/// The gear item page's cards plan 7 holds (issue #4527, phase 3): the
/// condition findings, components and twin set, and the passports pushed
/// from the page as its satellites.
void main() {
  final l = AppLocalizationsEn();

  // The cards read their rows themselves (the tags, the moves); an empty
  // test database answers them with none.
  setUp(() async {
    await setUpTestDatabase();
    addTearDown(SyncCoordinator.reset);
  });
  tearDown(tearDownTestDatabase);

  Future<void> unlock(WidgetTester tester) async {
    await tester.tap(find.byIcon(Icons.lock_outline));
    await tester.pumpAndSettle();
  }

  Future<void> openCard(WidgetTester tester, String title) async {
    final pencil = find.byTooltip(l.recordEdit_editCardTooltip(title));
    await tester.ensureVisible(pencil);
    await tester.tap(pencil);
    await tester.pumpAndSettle();
  }

  Future<void> save(WidgetTester tester) async {
    await tester.tap(find.text(l.forms_save));
    await tester.pumpAndSettle();
  }

  EditSession<EquipmentItem> sessionOf(WidgetTester tester) {
    final element = tester.element(
      find.byType(RecordCardFrame<EquipmentItem>).first,
    );
    return RecordEditScope.maybeOf<EquipmentItem>(element)!.session!;
  }

  // Plan 7: a dismissal is held in the item's sitting.
  group('condition findings', () {
    final evidence = FindingEvidence(
      n: 1,
      windowStart: DateTime(2026, 3, 3),
      windowEnd: DateTime(2026, 3, 3),
    );
    final incident = EquipmentFinding(
      id: 'cf_g1_incidentLinked',
      equipmentId: 'g1',
      ruleId: ConditionRuleId.incidentLinked,
      severity: ConditionSeverity.info,
      value: 1,
      evidence: evidence,
      evidenceFingerprint: evidenceFingerprint(evidence),
      engineVersion: 1,
      createdAt: DateTime(2026, 3, 3),
    );
    final findingsTitle = l.equipmentCondition_findings_title;

    Future<({GearPageHarness harness, _RecordingFindings repo})> pump(
      WidgetTester tester,
    ) async {
      final repo = _RecordingFindings();
      final harness = await pumpGearPage(
        tester,
        findings: [incident],
        extraOverrides: [
          equipmentFindingsRepositoryProvider.overrideWithValue(repo),
        ],
      );
      return (harness: harness, repo: repo);
    }

    testWidgets('locked, a finding offers no dismiss', (tester) async {
      final page = await pump(tester);

      expect(find.text(findingsTitle), findsOneWidget);
      expect(
        find.byTooltip(l.equipmentCondition_findings_dismiss),
        findsNothing,
      );
      expect(page.repo.calls, isEmpty);
    });

    testWidgets('a dismissal and a notes change are one save, written with '
        'it', (tester) async {
      final page = await pump(tester);
      await unlock(tester);
      await openCard(tester, findingsTitle);

      await tester.tap(find.byTooltip(l.equipmentCondition_findings_dismiss));
      await tester.pumpAndSettle();
      expect(page.repo.calls, isEmpty);
      sessionOf(tester).set(gearNotesField, 'Checked');
      await save(tester);

      expect(page.harness.save.calls.single.cards, {
        GearItemCardId.conditionFindings.name,
        GearItemCardId.notes.name,
      });
      expect(page.repo.calls, [(incident.id, true)]);
    });

    testWidgets('a dismissal, then Cancel: nothing written', (tester) async {
      final page = await pump(tester);
      await unlock(tester);
      await openCard(tester, findingsTitle);
      await tester.tap(find.byTooltip(l.equipmentCondition_findings_dismiss));
      await tester.pumpAndSettle();

      await tester.tap(find.text(l.common_action_cancel));
      await tester.pumpAndSettle();
      await tester.tap(find.text(l.forms_discard_discard));
      await tester.pumpAndSettle();

      expect(page.harness.save.calls, isEmpty);
      expect(page.repo.calls, isEmpty);
      expect(
        find.byTooltip(l.equipmentCondition_findings_dismiss),
        findsNothing,
      );
    });
  });

  // Plan 7: the parts are held in the item's sitting.
  group('components', () {
    testWidgets('a part removed in the sitting is removed at Save, not '
        'before', (tester) async {
      final components = EquipmentComponentRepository();
      await tester.runAsync(() async {
        final items = EquipmentRepository();
        await items.createEquipment(apex);
        await items.createEquipment(
          const EquipmentItem(
            id: 'p1',
            name: 'Second stage',
            type: EquipmentType.regulator,
          ),
        );
        await components.addComponent(parentId: 'g1', componentId: 'p1');
      });
      final harness = await pumpGearPage(tester);
      await unlock(tester);
      await openCard(tester, l.equipment_components_title);
      expect(find.text('Second stage'), findsOneWidget);

      await tester.tap(find.byTooltip(l.equipment_components_remove));
      await tester.pumpAndSettle();
      expect(find.text('Second stage'), findsNothing);
      expect(
        await tester.runAsync(() => components.getComponents('g1')),
        hasLength(1),
      );
      await save(tester);
      await tester.runAsync(() async {});

      expect(harness.save.calls.single.cards, {GearItemCardId.components.name});
      expect(
        await tester.runAsync(() => components.getComponents('g1')),
        isEmpty,
      );
    });
  });

  // Plan 7: a passport is a satellite of the item, joined while the item
  // page is unlocked, with a lock of its own while it is locked.
  group('passports', () {
    final tank = apex.copyWith(name: 'Left 12', type: EquipmentType.tank);
    late CylinderFill stored;

    Future<GearPageHarness> pumpTank(WidgetTester tester) async {
      await tester.runAsync(() async {
        await EquipmentRepository().createEquipment(tank);
        final passport = await CylinderPassportRepository().ensurePassportId(
          'g1',
        );
        stored = await CylinderFillRepository().create(
          CylinderFill(
            id: 'f0',
            passportId: passport,
            equipmentId: 'g1',
            filledAt: DateTime(2026, 3, 3),
            o2Percent: 32,
            createdAt: DateTime(2026, 3, 3),
            updatedAt: DateTime(2026, 3, 3),
          ),
        );
      });
      return pumpGearPage(
        tester,
        item: tank,
        extraOverrides: [
          allPairingsProvider.overrideWith((ref) async => const []),
          passportIdProvider(
            'g1',
          ).overrideWith((ref) async => stored.passportId),
          passportUsageProvider(
            stored.passportId,
          ).overrideWith((ref) async => const <PassportUsageDive>[]),
          fillsForEquipmentProvider('g1').overrideWith((ref) async => [stored]),
          newestFillProvider('g1').overrideWith((ref) async => stored),
          tiedFillsProvider('g1').overrideWith((ref) async => const {}),
          tripCopyFillIdsProvider('g1').overrideWith((ref) async => const {}),
          serviceClockStatusesProvider(
            'g1',
          ).overrideWith((ref) async => const <ServiceClockStatus>[]),
          serviceRecordsForEquipmentProvider(
            'g1',
          ).overrideWith((ref) async => const <ServiceRecord>[]),
        ],
      );
    }

    Future<void> openPassport(WidgetTester tester) async {
      await tester.ensureVisible(find.byType(PassportEntryCard));
      await tester.tap(find.byType(PassportEntryCard));
      await tester.pumpAndSettle();
    }

    testWidgets('from an unlocked item page the passport joins its sitting, '
        'and the item page saves what it held', (tester) async {
      final harness = await pumpTank(tester);
      await unlock(tester);
      await openPassport(tester);

      expect(find.byType(PassportPage), findsOneWidget);
      expect(find.byType(RecordSatelliteBar), findsOneWidget);
      final pencil = find.byTooltip(
        l.recordEdit_editCardTooltip(l.passport_history_title),
      );
      await tester.ensureVisible(pencil);
      await tester.tap(pencil);
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byTooltip(l.passport_history_delete));
      await tester.tap(find.byTooltip(l.passport_history_delete));
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 50)),
      );
      await tester.pumpAndSettle();
      await tester.tap(
        find.widgetWithText(FilledButton, l.passport_history_delete),
      );
      await tester.pumpAndSettle();
      // The bar's Done closes the card the passport opened, then leaves.
      await tester.tap(
        find.descendant(
          of: find.byType(RecordSatelliteBar),
          matching: find.text(l.common_action_done),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(PassportPage), findsNothing);
      expect(harness.save.calls, isEmpty);
      await save(tester);
      await tester.runAsync(() async {});

      expect(harness.save.calls.single.cards, {
        GearItemCardId.passportFills.name,
      });
      final left = await tester.runAsync(
        () => CylinderFillRepository().getForCylinder(
          passportId: stored.passportId,
          equipmentId: 'g1',
        ),
      );
      expect(left, isEmpty);
    });

    testWidgets('See all is hidden on a gear passport joined to the item '
        "page's sitting", (tester) async {
      final at = DateTime(2026, 3, 3);
      await pumpGearPage(
        tester,
        extraOverrides: [
          passportIdProvider('g1').overrideWith((ref) async => 'pp'),
          serviceClockStatusesProvider(
            'g1',
          ).overrideWith((ref) async => const <ServiceClockStatus>[]),
          serviceRecordsForEquipmentProvider('g1').overrideWith(
            (ref) async => [
              ServiceRecord(
                id: 'r1',
                equipmentId: 'g1',
                serviceCategory: ServiceCategory.annual,
                serviceDate: at,
                createdAt: at,
                updatedAt: at,
              ),
            ],
          ),
        ],
      );
      await unlock(tester);
      await tester.ensureVisible(find.byType(GearPassportEntryCard));
      await tester.tap(find.byType(GearPassportEntryCard));
      await tester.pumpAndSettle();

      expect(find.byType(GearPassportPage), findsOneWidget);
      expect(find.byType(RecordSatelliteBar), findsOneWidget);
      expect(find.text(l.gearPassport_recent_seeAll), findsNothing);
    });

    testWidgets('from a locked item page the passport has its own lock', (
      tester,
    ) async {
      await pumpTank(tester);
      await openPassport(tester);

      expect(find.byType(PassportPage), findsOneWidget);
      expect(find.byType(RecordSatelliteBar), findsNothing);
      expect(
        find.descendant(
          of: find.byType(PassportPage),
          matching: find.byIcon(Icons.lock_outline),
        ),
        findsOneWidget,
      );
    });
  });

  // Plan 7: a tank's pairings are held in the item's sitting.
  group('twin set', () {
    final tank = apex.copyWith(name: 'Left 12', type: EquipmentType.tank);
    final partner = EquipmentItem(
      id: 'g2',
      name: 'Right 12',
      type: EquipmentType.tank,
      createdAt: DateTime(2026),
    );

    testWidgets('a pairing made in the sitting is saved with it', (
      tester,
    ) async {
      final repository = _RecordingPairings();
      final harness = await pumpGearPage(
        tester,
        item: tank,
        extraOverrides: [
          allPairingsProvider.overrideWith((ref) async => const []),
          activeEquipmentProvider.overrideWith((ref) async => [tank, partner]),
          cylinderPairingRepositoryProvider.overrideWithValue(repository),
        ],
      );
      expect(find.text(l.twinSet_link), findsNothing);
      await unlock(tester);
      await openCard(tester, l.twinSet_title);

      await tester.tap(find.text(l.twinSet_link));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Right 12'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();
      expect(repository.created, isEmpty);
      await save(tester);

      expect(harness.save.calls.single.cards, {GearItemCardId.twinSet.name});
      expect(repository.created, ['g1+g2']);
    });
  });
}

/// Records the dismissals the page writes, writing none.
class _RecordingFindings extends EquipmentFindingsRepository {
  final calls = <(String, bool)>[];

  @override
  Future<void> setDismissed({
    required String findingId,
    required bool dismissed,
    required DateTime now,
  }) async {
    calls.add((findingId, dismissed));
  }
}

/// Records the pairings the page makes, storing none.
class _RecordingPairings extends CylinderPairingRepository {
  final created = <String>[];

  @override
  Future<CylinderPairing> createPairing({
    required String cylinderAId,
    required String cylinderBId,
    required DateTime pairedOn,
    DateTime? unpairedOn,
    bool replace = false,
  }) async {
    created.add('$cylinderAId+$cylinderBId');
    return CylinderPairing(
      id: 'p',
      cylinderAId: cylinderAId,
      cylinderBId: cylinderBId,
      pairedOn: calendarDay(pairedOn),
      createdAt: pairedOn,
      updatedAt: pairedOn,
    );
  }
}
