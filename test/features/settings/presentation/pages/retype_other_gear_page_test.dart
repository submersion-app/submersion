import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/equipment/data/repositories/equipment_repository_impl.dart';
import 'package:submersion/features/equipment/data/services/other_gear_retype_service.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
import 'package:submersion/features/equipment/domain/entities/other_gear_retype.dart';
import 'package:submersion/features/equipment/presentation/providers/other_gear_retype_providers.dart';
import 'package:submersion/features/settings/presentation/pages/retype_other_gear_page.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

/// Mock SettingsNotifier that does not access the database.
class _MockSettingsNotifier extends StateNotifier<AppSettings>
    implements SettingsNotifier {
  _MockSettingsNotifier(super.initial);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// Records what the page applies and undoes. Apply fails [failures] items;
/// Undo reports [undoResult].
class _FakeRetypeService extends OtherGearRetypeService {
  _FakeRetypeService({
    this.failures = 0,
    this.undoResult = const RetypeUndoResult(restored: 1),
  }) : super(EquipmentRepository());

  final int failures;
  final RetypeUndoResult undoResult;
  final applied = <List<RetypeCandidate>>[];
  final undone = <RetypeReceipt>[];

  @override
  Future<RetypeReceipt> apply(List<RetypeCandidate> candidates) async {
    applied.add(candidates);
    final written = candidates.skip(failures);
    return RetypeReceipt(
      retyped: [
        for (final c in written)
          RetypedItem(
            before: c.item,
            after: c.item.copyWith(type: c.type),
          ),
      ],
      failed: candidates.length - written.length,
    );
  }

  @override
  Future<RetypeUndoResult> undo(RetypeReceipt receipt) async {
    undone.add(receipt);
    return undoResult;
  }
}

final _l10n = lookupAppLocalizations(const Locale('en'));

RetypeCandidate _candidate(
  String id,
  String name,
  EquipmentType type, {
  String? thickness,
}) => RetypeCandidate(
  item: EquipmentItem(id: id, name: name, type: EquipmentType.other),
  type: type,
  thickness: thickness,
);

final _candidates = [
  _candidate('suit', '7mm Wetsuit', EquipmentType.wetsuit, thickness: '7mm'),
  _candidate('fins', 'Apeks fins', EquipmentType.fins),
];

Future<void> _pump(
  WidgetTester tester,
  _FakeRetypeService service,
  List<RetypeCandidate>? candidates,
) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        otherGearRetypeCandidatesProvider.overrideWith(
          (ref) async => candidates,
        ),
        otherGearRetypeServiceProvider.overrideWithValue(service),
        settingsProvider.overrideWith(
          (ref) => _MockSettingsNotifier(const AppSettings()),
        ),
      ],
      child: const MaterialApp(
        locale: Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: RetypeOtherGearPage(),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('lists each item with the type and thickness it would get', (
    tester,
  ) async {
    await _pump(tester, _FakeRetypeService(), _candidates);

    expect(find.text('7mm Wetsuit'), findsOneWidget);
    expect(find.text('Becomes Wetsuit, 7 mm'), findsOneWidget);
    expect(find.text('Apeks fins'), findsOneWidget);
    expect(find.text('Becomes Fins'), findsOneWidget);
    expect(find.text(_l10n.equipment_retypeOther_apply(2)), findsOneWidget);
  });

  testWidgets('unticking an item updates the button', (tester) async {
    await _pump(tester, _FakeRetypeService(), _candidates);

    await tester.tap(find.text('Apeks fins'));
    await tester.pump();

    expect(find.text(_l10n.equipment_retypeOther_apply(1)), findsOneWidget);
    expect(find.text(_l10n.equipment_retypeOther_selectAll), findsOneWidget);
  });

  testWidgets('Deselect all disables the button, Select all restores it', (
    tester,
  ) async {
    await _pump(tester, _FakeRetypeService(), _candidates);

    await tester.tap(find.text(_l10n.equipment_retypeOther_deselectAll));
    await tester.pump();

    final button = find.widgetWithText(
      FilledButton,
      _l10n.equipment_retypeOther_apply(0),
    );
    expect(tester.widget<FilledButton>(button).onPressed, isNull);

    await tester.tap(find.text(_l10n.equipment_retypeOther_selectAll));
    await tester.pump();

    expect(find.text(_l10n.equipment_retypeOther_apply(2)), findsOneWidget);
  });

  testWidgets('Retype applies the ticked items and offers Undo', (
    tester,
  ) async {
    final service = _FakeRetypeService();
    await _pump(tester, service, _candidates);

    await tester.tap(find.text('Apeks fins'));
    await tester.pump();
    await tester.tap(find.text(_l10n.equipment_retypeOther_apply(1)));
    await tester.pumpAndSettle();

    expect(service.applied.single.map((c) => c.item.id), ['suit']);
    expect(
      find.text(_l10n.equipment_retypeOther_retypedSnackbar(1)),
      findsOneWidget,
    );

    await tester.tap(find.text(_l10n.diveLog_bulkDelete_undo));
    await tester.pumpAndSettle();

    expect(service.undone.single.retyped.map((r) => r.id), ['suit']);
    expect(find.text(_l10n.equipment_retypeOther_undone), findsOneWidget);
    await tester.pump(const Duration(seconds: 6));
  });

  testWidgets('Undo reports items it left alone or could not put back', (
    tester,
  ) async {
    await _pump(
      tester,
      _FakeRetypeService(
        undoResult: const RetypeUndoResult(restored: 1, skipped: 1, failed: 1),
      ),
      _candidates,
    );

    await tester.tap(find.text(_l10n.equipment_retypeOther_apply(2)));
    await tester.pumpAndSettle();
    await tester.tap(find.text(_l10n.diveLog_bulkDelete_undo));
    await tester.pumpAndSettle();

    expect(
      find.text(
        [
          _l10n.equipment_retypeOther_undone,
          _l10n.equipment_retypeOther_undoSkipped(1),
          _l10n.equipment_retypeOther_undoFailed(1),
        ].join(' · '),
      ),
      findsOneWidget,
    );
    await tester.pump(const Duration(seconds: 6));
  });

  testWidgets('reports items that could not be retyped', (tester) async {
    await _pump(tester, _FakeRetypeService(failures: 1), _candidates);

    await tester.tap(find.text(_l10n.equipment_retypeOther_apply(2)));
    await tester.pumpAndSettle();

    expect(
      find.text(
        [
          _l10n.equipment_retypeOther_retypedSnackbar(1),
          _l10n.equipment_retypeOther_failedSnackbar(1),
        ].join(' · '),
      ),
      findsOneWidget,
    );
    await tester.pump(const Duration(seconds: 6));
  });

  testWidgets('offers no Undo when every item failed', (tester) async {
    await _pump(tester, _FakeRetypeService(failures: 2), _candidates);

    await tester.tap(find.text(_l10n.equipment_retypeOther_apply(2)));
    await tester.pumpAndSettle();

    expect(
      find.text(_l10n.equipment_retypeOther_failedSnackbar(2)),
      findsOneWidget,
    );
    expect(find.text(_l10n.diveLog_bulkDelete_undo), findsNothing);
    await tester.pump(const Duration(seconds: 6));
  });

  testWidgets('shows the empty state when nothing needs retyping', (
    tester,
  ) async {
    await _pump(tester, _FakeRetypeService(), const []);

    expect(find.text(_l10n.equipment_retypeOther_empty), findsOneWidget);
  });

  testWidgets('shows the empty state when there is no diver', (tester) async {
    await _pump(tester, _FakeRetypeService(), null);

    expect(find.text(_l10n.equipment_retypeOther_empty), findsOneWidget);
  });
}
