import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/domain/models/incoming_dive_data.dart';
import 'package:submersion/features/import_wizard/domain/adapters/import_source_adapter.dart';
import 'package:submersion/features/import_wizard/domain/models/duplicate_action.dart';
import 'package:submersion/features/import_wizard/domain/models/import_bundle.dart';
import 'package:submersion/features/import_wizard/domain/models/import_target_choice.dart';
import 'package:submersion/features/import_wizard/presentation/providers/import_trip_providers.dart';
import 'package:submersion/features/import_wizard/presentation/providers/import_wizard_providers.dart';
import 'package:submersion/features/trips/domain/entities/trip.dart';

class _Adapter implements ImportSourceAdapter {
  @override
  String get defaultTagName => 'Test Import';

  @override
  Set<DuplicateAction> get supportedDuplicateActions => const {
    DuplicateAction.skip,
    DuplicateAction.importAsNew,
  };

  @override
  Set<DuplicateAction> duplicateActionsFor(ImportEntityType type) =>
      supportedDuplicateActions;

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError(invocation.memberName.toString());
}

final _created = DateTime(2026, 1, 1);

Trip _trip(String name, DateTime start, DateTime end) => Trip(
  id: name,
  name: name,
  startDate: start,
  endDate: end,
  createdAt: _created,
  updatedAt: _created,
);

final _bonaire = _trip('Bonaire', DateTime(2026, 3, 7), DateTime(2026, 3, 14));
final _komodo = _trip('Komodo', DateTime(2026, 3, 7), DateTime(2026, 3, 14));

EntityItem _dive({ImportTarget? target, String? tripRef}) => EntityItem(
  title: 'dive',
  subtitle: '',
  diveData: IncomingDiveData(startTime: DateTime.utc(2026, 3, 10, 10)),
  target: target,
  tripRef: tripRef,
);

ImportBundle _bundle(
  List<EntityItem> dives, {
  List<EntityItem>? trips,
  ImportTargetChoice? targetChoice,
}) => ImportBundle(
  source: const ImportSourceInfo(
    type: ImportSourceType.universal,
    displayName: 'log.uddf',
  ),
  groups: {
    ImportEntityType.dives: EntityGroup(items: dives),
    if (trips != null) ImportEntityType.trips: EntityGroup(items: trips),
  },
  targetChoice: targetChoice,
);

void main() {
  /// Owner id -> trips; the active diver reads under null.
  late Map<String?, List<Trip>> tripsByOwner;
  late ProviderContainer container;
  late ImportWizardNotifier notifier;

  setUp(() {
    tripsByOwner = {
      null: [_bonaire],
      'other': [_komodo],
    };
    container = ProviderContainer(
      overrides: [
        importWizardNotifierProvider.overrideWith(
          (ref) => ImportWizardNotifier(_Adapter()),
        ),
        importOwnerTripsProvider.overrideWith(
          (ref, diverId) async => tripsByOwner[diverId] ?? const [],
        ),
      ],
    );
    addTearDown(container.dispose);
    notifier = container.read(importWizardNotifierProvider.notifier);
  });

  /// Reads the names once every owner's trips have loaded.
  Future<Map<int, String>> names() async {
    final sub = container.listen(importReviewTripNamesProvider, (_, _) {});
    addTearDown(sub.close);
    await container.pump();
    await Future<void>.delayed(Duration.zero);
    return container.read(importReviewTripNamesProvider);
  }

  test('activeDiverTripsName', () async {
    notifier.setBundle(_bundle([_dive()]));
    expect(await names(), {0: 'Bonaire'});
  });

  test('downloadForOtherDiverReadsTheirTrips', () async {
    notifier.setBundle(
      _bundle(
        [_dive()],
        targetChoice: const ImportTargetChoice(
          ownerDiverId: 'other',
          chosenDiverId: 'other',
        ),
      ),
    );
    expect(await names(), {0: 'Komodo'});
  });

  test('a multi-profile import reads each row target', () async {
    notifier.setBundle(
      _bundle([
        _dive(
          target: const ImportTarget(
            key: 'diver:other',
            name: 'Other',
            isNew: false,
          ),
        ),
      ]),
    );
    expect(await names(), {0: 'Komodo'});
  });

  test('newProfileRowsShowNoTrip', () async {
    notifier.setBundle(
      _bundle([
        _dive(
          target: const ImportTarget(key: 'new:Sam', name: 'Sam', isNew: true),
        ),
        _dive(),
      ]),
    );
    expect(await names(), {1: 'Bonaire'});
  });

  test('namesFollowSelectionChanges', () async {
    notifier.setBundle(
      _bundle(
        [_dive(tripRef: 'a')],
        trips: [
          EntityItem(
            title: 'Cozumel',
            subtitle: '',
            tripRef: 'a',
            sourceTrip: (
              name: 'Cozumel',
              start: DateTime(2026, 3, 9),
              end: DateTime(2026, 3, 11),
            ),
          ),
        ],
      ),
    );
    expect(await names(), {0: 'Cozumel'});

    notifier.toggleSelection(ImportEntityType.trips, 0);
    expect(await names(), {0: 'Bonaire'});

    notifier.toggleSelection(ImportEntityType.dives, 0);
    expect(await names(), isEmpty);
  });
}
