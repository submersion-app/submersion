import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/features/transmitters/data/repositories/transmitter_repository.dart';
import 'package:submersion/features/transmitters/data/services/transmitter_slot_matcher.dart';
import 'package:submersion/features/transmitters/domain/entities/transmitter.dart';
import 'package:submersion/features/transmitters/presentation/providers/transmitter_providers.dart';
import 'package:submersion/features/transmitters/presentation/widgets/transmitter_section.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../helpers/mock_providers.dart';

/// Answers the serial preview with fixed counts and records what each apply
/// was given.
class _Repo extends TransmitterRepository {
  _Repo(this.preview);

  final ApplyToExistingResult preview;
  final applied = <String, List<String>>{};

  @override
  Future<ApplyToExistingResult> previewApplyToExistingDives(
    Transmitter t, {
    Iterable<String> slotTankIds = const [],
  }) async => preview;

  @override
  Future<ApplyToExistingResult> applyToExistingDives(
    Transmitter t, {
    Iterable<String> slotTankIds = const [],
  }) async {
    applied[t.id] = slotTankIds.toList();
    return (
      tanksUpdated: preview.tanksUpdated + slotTankIds.length,
      divesUpdated: preview.divesUpdated + slotTankIds.length,
      mixesKept: 0,
    );
  }
}

/// Offers [computers] and resolves to [resolved] once [gate] completes.
class _Matcher extends TransmitterSlotMatcher {
  _Matcher({this.computers = const [], this.resolved = const [], this.gate});

  final List<SlotComputer> computers;
  final List<SlotCandidates> resolved;
  final Completer<void>? gate;

  @override
  Future<List<SlotComputer>> computersWithCandidates(Transmitter t) async =>
      computers;

  @override
  Future<List<SlotCandidates>> resolve(Transmitter t) async {
    await gate?.future;
    return resolved;
  }
}

/// A slot lookup that fails, as a closed database would.
class _FailingMatcher extends _Matcher {
  @override
  Future<List<SlotComputer>> computersWithCandidates(Transmitter t) =>
      Future.error(StateError('database closed'));
}

const _perdix = SlotComputer(computerId: 'c1', computerName: 'Perdix');

/// T2 fills cylinders a and b on two dives; T3 fills c on one.
const _perdixSlots = SlotCandidates(
  computer: _perdix,
  tankIdsBySlot: {
    2: ['a', 'b'],
    3: ['c'],
  },
  diveIdByTank: {'a': 'd1', 'b': 'd2', 'c': 'd1'},
);

/// The apply dialog's slot matching (issue #4347).
void main() {
  final key = Transmitter(
    id: 'k1',
    transmitterSerial: '4A21F',
    label: 'Sidemount left',
    role: TankRole.sidemountLeft,
    volumeL: 10,
    transmitterEquipmentId: 'tx-gear',
    createdAt: DateTime(2026),
    updatedAt: DateTime(2026),
  );

  Future<void> openApply(
    WidgetTester tester, {
    required _Repo repo,
    required _Matcher matcher,
    bool settle = true,
  }) async {
    tester.view.physicalSize = const Size(900, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final router = GoRouter(
      initialLocation: '/equipment/tx-gear',
      routes: [
        GoRoute(
          path: '/equipment/:id',
          builder: (_, s) => Scaffold(
            body: SingleChildScrollView(
              child: TransmitterSection(equipmentId: s.pathParameters['id']!),
            ),
          ),
        ),
      ],
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          settingsProvider.overrideWith((ref) => MockSettingsNotifier()),
          transmittersForEquipmentProvider(
            'tx-gear',
          ).overrideWith((ref) async => [key]),
          transmitterRepositoryProvider.overrideWithValue(repo),
          transmitterSlotMatcherProvider.overrideWithValue(matcher),
        ],
        child: MaterialApp.router(
          routerConfig: router,
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Apply to existing dives'));
    if (settle) {
      await tester.pumpAndSettle();
    } else {
      // The progress bar never settles while the files are read.
      for (var i = 0; i < 5; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
    }
  }

  const someSerial = (tanksUpdated: 1, divesUpdated: 1, mixesKept: 0);
  const noSerial = (tanksUpdated: 0, divesUpdated: 0, mixesKept: 0);

  Future<void> pickSlot(WidgetTester tester, String option) async {
    await tester.tap(find.text("Don't match by slot"));
    await tester.pumpAndSettle();
    await tester.tap(find.text(option).last);
    await tester.pumpAndSettle();
  }

  testWidgets("shows today's content when no computer has slot candidates", (
    tester,
  ) async {
    await openApply(tester, repo: _Repo(someSerial), matcher: _Matcher());

    expect(find.textContaining('1 cylinders on 1 dives'), findsOneWidget);
    expect(find.textContaining('Slot on'), findsNothing);
  });

  testWidgets('shows a slot row per computer, reading files until resolved', (
    tester,
  ) async {
    final gate = Completer<void>();
    await openApply(
      tester,
      repo: _Repo(someSerial),
      matcher: _Matcher(
        computers: [_perdix],
        resolved: [_perdixSlots],
        gate: gate,
      ),
      settle: false,
    );

    expect(find.text('Slot on Perdix'), findsOneWidget);
    expect(find.text('Reading imported files'), findsOneWidget);

    gate.complete();
    await tester.pumpAndSettle();

    expect(find.text('Reading imported files'), findsNothing);
    expect(find.text("Don't match by slot"), findsOneWidget);
  });

  testWidgets('each slot shows its dive count and an empty slot is disabled', (
    tester,
  ) async {
    await openApply(
      tester,
      repo: _Repo(someSerial),
      matcher: _Matcher(computers: [_perdix], resolved: [_perdixSlots]),
    );

    await tester.tap(find.text("Don't match by slot"));
    await tester.pumpAndSettle();

    expect(find.text('T2: 2 dives'), findsOneWidget);
    expect(find.text('T3: 1 dive'), findsOneWidget);
    final empty = tester.widget<DropdownMenuItem<int?>>(
      find.ancestor(
        of: find.text('T1: 0 dives'),
        matching: find.byType(DropdownMenuItem<int?>),
      ),
    );
    expect(empty.enabled, isFalse);
    // Drawn muted, so it does not read as a choice.
    final emptyText = tester.widget<Text>(find.text('T1: 0 dives').last);
    final theme = Theme.of(tester.element(find.text('T1: 0 dives').last));
    expect(emptyText.style?.color, theme.disabledColor);
  });

  testWidgets('picking a slot updates the summary', (tester) async {
    await openApply(
      tester,
      repo: _Repo(someSerial),
      matcher: _Matcher(computers: [_perdix], resolved: [_perdixSlots]),
    );

    await pickSlot(tester, 'T2: 2 dives');

    expect(find.text('Dives filled by serial: 1, by slot: 2'), findsOneWidget);
  });

  testWidgets("confirming applies the chosen slot's cylinders to the key", (
    tester,
  ) async {
    final repo = _Repo(someSerial);
    await openApply(
      tester,
      repo: repo,
      matcher: _Matcher(computers: [_perdix], resolved: [_perdixSlots]),
    );

    await pickSlot(tester, 'T2: 2 dives');
    await tester.tap(find.widgetWithText(FilledButton, 'Apply'));
    await tester.pumpAndSettle();

    expect(repo.applied, {
      'k1': ['a', 'b'],
    });
    expect(find.text('Updated 3 cylinders on 3 dives'), findsOneWidget);
  });

  testWidgets('opens with slot rows when the serial matches nothing', (
    tester,
  ) async {
    await openApply(
      tester,
      repo: _Repo(noSerial),
      matcher: _Matcher(computers: [_perdix], resolved: [_perdixSlots]),
    );

    expect(find.text('Apply to existing dives?'), findsOneWidget);
    expect(find.text('Slot on Perdix'), findsOneWidget);
    final apply = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Apply'),
    );
    expect(apply.onPressed, isNull);

    await pickSlot(tester, 'T3: 1 dive');

    final enabled = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Apply'),
    );
    expect(enabled.onPressed, isNotNull);
  });

  testWidgets('says nothing needs the setup when both routes are empty', (
    tester,
  ) async {
    await openApply(tester, repo: _Repo(noSerial), matcher: _Matcher());

    expect(find.text("No cylinder needs this transmitter's setup"), findsOne);
    expect(find.text('Apply to existing dives?'), findsNothing);
  });

  testWidgets('a failed slot lookup still offers the serial apply', (
    tester,
  ) async {
    await openApply(
      tester,
      repo: _Repo(someSerial),
      matcher: _FailingMatcher(),
    );

    expect(find.textContaining('1 cylinders on 1 dives'), findsOneWidget);
    expect(find.textContaining('Slot on'), findsNothing);
  });
}
