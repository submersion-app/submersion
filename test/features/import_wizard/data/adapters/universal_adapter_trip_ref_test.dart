import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/features/import_wizard/data/adapters/universal_adapter.dart';
import 'package:submersion/features/import_wizard/domain/models/import_bundle.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/features/universal_import/data/models/import_enums.dart'
    as ui;
import 'package:submersion/features/universal_import/data/models/import_payload.dart';
import 'package:submersion/features/universal_import/data/services/payload_merger.dart';
import 'package:submersion/features/universal_import/presentation/providers/universal_import_providers.dart';

class _SettingsNotifier extends StateNotifier<AppSettings>
    implements SettingsNotifier {
  _SettingsNotifier() : super(const AppSettings());

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _ImportNotifier extends UniversalImportNotifier {
  _ImportNotifier(super.ref, ImportPayload payload) {
    state = state.copyWith(payload: payload);
  }
}

Future<ImportBundle> _bundle(WidgetTester tester, ImportPayload payload) async {
  late UniversalAdapter adapter;
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        universalImportNotifierProvider.overrideWith(
          (ref) => _ImportNotifier(ref, payload),
        ),
        settingsProvider.overrideWith((ref) => _SettingsNotifier()),
      ],
      child: MaterialApp(
        home: Consumer(
          builder: (context, ref, _) {
            adapter = UniversalAdapter(ref: ref);
            return const SizedBox.shrink();
          },
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return (await tester.runAsync(adapter.buildBundle))!;
}

Map<String, dynamic> _dive(int day, {String? tripRef, bool? sourceHasTrips}) =>
    {
      'dateTime': DateTime.utc(2026, 3, day, 10),
      'maxDepth': 20.0,
      'runtime': const Duration(minutes: 40),
      'tripRef': ?tripRef,
      PayloadMerger.sourceHasTripsKey: ?sourceHasTrips,
    };

void main() {
  group('UniversalAdapter trip references (#3022)', () {
    testWidgets('dives carry their trip ref and trips their ref and dates', (
      tester,
    ) async {
      final bundle = await _bundle(
        tester,
        ImportPayload(
          entities: {
            ui.ImportEntityType.trips: [
              {
                'uddfId': 't1',
                'name': 'Bonaire',
                'startDate': DateTime(2026, 3, 7),
                'endDate': DateTime(2026, 3, 14),
              },
              {
                'uddfId': 't2',
                'name': 'Curacao',
                'startDate': DateTime(2026, 3, 20),
              },
              // The importer creates no trip without a name.
              {'uddfId': 't3', 'name': ''},
            ],
            ui.ImportEntityType.dives: [
              _dive(8, tripRef: 't1'),
              _dive(21, tripRef: 't2'),
              _dive(25),
            ],
          },
        ),
      );

      final dives = bundle.groups[ImportEntityType.dives]!.items;
      final trips = bundle.groups[ImportEntityType.trips]!.items;
      expect(dives.map((d) => d.tripRef), ['t1', 't2', null]);
      // A single file says nothing per dive; the review asks its trip rows.
      expect(dives.map((d) => d.sourceHasTrips), [null, null, null]);
      expect(dives.map((d) => d.hasSourceTime), [true, true, true]);
      expect(trips.map((t) => t.tripRef), ['t1', 't2', 't3']);
      expect(trips[0].sourceTrip, (
        name: 'Bonaire',
        start: DateTime(2026, 3, 7),
        end: DateTime(2026, 3, 14),
      ));
      // A trip missing its end keeps the start it has.
      expect(trips[1].sourceTrip, (
        name: 'Curacao',
        start: DateTime(2026, 3, 20),
        end: null,
      ));
      expect(trips[2].sourceTrip, isNull);
      expect(dives[0].sourceTrip, isNull);
    });

    testWidgets('a single source leaves the per-dive flag unset', (
      tester,
    ) async {
      final bundle = await _bundle(
        tester,
        ImportPayload(
          entities: {
            ui.ImportEntityType.dives: [_dive(8)],
          },
        ),
      );

      final dive = bundle.groups[ImportEntityType.dives]!.items.single;
      expect(dive.tripRef, isNull);
      expect(dive.sourceHasTrips, isNull);
    });

    testWidgets('a merged batch dive follows its own file', (tester) async {
      final bundle = await _bundle(
        tester,
        ImportPayload(
          entities: {
            ui.ImportEntityType.trips: [
              {
                'uddfId': 't1',
                'name': 'Bonaire',
                'startDate': DateTime(2026, 3, 7),
                'endDate': DateTime(2026, 3, 14),
              },
            ],
            ui.ImportEntityType.dives: [
              _dive(8, tripRef: 't1', sourceHasTrips: true),
              _dive(9, sourceHasTrips: false),
            ],
          },
        ),
      );

      final dives = bundle.groups[ImportEntityType.dives]!.items;
      expect(dives.map((d) => d.sourceHasTrips), [true, false]);
    });
  });

  test('copyWith keeps the trip fields', () {
    final item = EntityItem(
      title: 'Bonaire',
      subtitle: '',
      tripRef: 't1',
      sourceHasTrips: true,
      hasSourceTime: false,
      sourceTrip: (
        name: 'Bonaire',
        start: DateTime(2026, 3, 7),
        end: DateTime(2026, 3, 14),
      ),
    );

    final moved = item.copyWith(
      target: const ImportTarget(key: 'diver:a', name: 'A', isNew: false),
    );

    expect(moved.tripRef, 't1');
    expect(moved.sourceHasTrips, isTrue);
    expect(moved.hasSourceTime, isFalse);
    expect(moved.sourceTrip, item.sourceTrip);
    expect(moved.target?.key, 'diver:a');
  });
}
