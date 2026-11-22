import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/providers/location_service_provider.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/services/location_service.dart';
import 'package:submersion/core/theme/app_theme_registry.dart';
import 'package:submersion/features/dive_centers/data/services/dive_center_edit_save_service.dart';
import 'package:submersion/features/dive_centers/domain/entities/dive_center.dart';
import 'package:submersion/features/dive_centers/presentation/pages/dive_center_detail_page.dart';
import 'package:submersion/features/dive_centers/presentation/providers/dive_center_providers.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';

import '../../../../helpers/mock_providers.dart';
import '../../../../helpers/test_app.dart';

/// The centre the page shows, as stored: Reef Divers in Dahab, with a
/// website and no coordinates.
final reefDivers = DiveCenter(
  id: 'dc1',
  diverId: 'd1',
  name: 'Reef Divers',
  city: 'Dahab',
  website: 'reef.example',
  createdAt: DateTime(2020),
  updatedAt: DateTime(2020),
);

/// Records each save the page asks for and stores its result where the
/// page reads the centre from.
class FakeDiveCenterSave implements DiveCenterEditSaveService {
  FakeDiveCenterSave(this.stored);

  final StateController<DiveCenter?> stored;
  final calls = <({DiveCenter after, Set<String> cards})>[];
  bool runHeld = true;

  @override
  Future<({DiveCenter before, DiveCenter after})?> save({
    required String centerId,
    required DiveCenter Function(DiveCenter stored) apply,
    required Iterable<String> changedCardIds,
    Future<void> Function()? alsoWrite,
    bool alsoWriteIsAChange = false,
  }) async {
    final before = stored.state!;
    final after = apply(before);
    calls.add((after: after, cards: changedCardIds.toSet()));
    if (runHeld) await alsoWrite?.call();
    stored.state = after;
    return (before: before, after: after);
  }

  /// Each new centre the page asked to create, failed ones included.
  final creates = <({DiveCenter center, Set<String> cards})>[];

  /// Thrown from a create.
  Object? failCreate;

  @override
  Future<DiveCenter> create({
    required DiveCenter center,
    required Iterable<String> changedCardIds,
    Future<void> Function()? alsoWrite,
  }) async {
    creates.add((center: center, cards: changedCardIds.toSet()));
    if (failCreate case final error?) throw error;
    if (runHeld) await alsoWrite?.call();
    return center;
  }
}

/// Answers an address lookup with [found] once [answer] completes, or
/// with nothing.
class FakeLocations extends Fake implements LocationService {
  FakeLocations({this.found, this.foundFor = const {}});

  final LocationResult? found;

  /// What each address finds, where it differs from [found].
  final Map<String, LocationResult> foundFor;
  final answer = Completer<void>();
  final asked = <String>[];

  @override
  Future<LocationResult?> forwardGeocode(String address) async {
    asked.add(address);
    await answer.future;
    return foundFor[address] ?? found;
  }
}

class DiveCenterPageHarness {
  DiveCenterPageHarness(this.save, this.stored);

  final FakeDiveCenterSave save;
  final StateController<DiveCenter?> stored;
}

final _storedProvider = StateProvider<DiveCenter?>((ref) => reefDivers);

/// Pumps the dive centre page.
Future<DiveCenterPageHarness> pumpDiveCenterPage(
  WidgetTester tester, {
  Brightness brightness = Brightness.light,
  DiveCenter? center,
  bool openUnlocked = false,
  bool embedded = false,
  Size size = const Size(700, 1600),
  VoidCallback? onSittingEnded,
  LocationService? locations,
  List<Object> extraOverrides = const [],
}) async {
  final shown = center ?? reefDivers;
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final overrides = await getBaseOverrides();
  late DiveCenterPageHarness harness;
  final page = DiveCenterDetailPage(
    centerId: shown.id,
    openUnlocked: openUnlocked,
    embedded: embedded,
    onSittingEnded: onSittingEnded,
  );
  await tester.pumpWidget(
    testApp(
      overrides: [
        ...overrides,
        _storedProvider.overrideWith((ref) => shown),
        diveCenterByIdProvider(
          shown.id,
        ).overrideWith((ref) async => ref.watch(_storedProvider)),
        diveCenterDiveCountProvider(shown.id).overrideWith((ref) async => 0),
        if (locations != null)
          locationServiceProvider.overrideWithValue(locations),
        diveCenterEditSaveServiceProvider.overrideWith((ref) {
          final save = FakeDiveCenterSave(ref.watch(_storedProvider.notifier));
          harness = DiveCenterPageHarness(
            save,
            ref.watch(_storedProvider.notifier),
          );
          return save;
        }),
        ...extraOverrides,
      ],
      child: Theme(
        data: AppThemeRegistry.resolveTheme(
          AppThemeRegistry.presets.first,
          brightness,
        ),
        child: embedded ? Scaffold(body: page) : page,
      ),
    ),
  );
  await tester.pumpAndSettle();
  final container = ProviderScope.containerOf(
    tester.element(find.byType(DiveCenterDetailPage)),
  );
  container.read(diveCenterEditSaveServiceProvider);
  return harness;
}

/// What a test of a new dive centre's page pumped: the fake save, and how
/// the page ended.
class NewDiveCenterHarness {
  late FakeDiveCenterSave save;
  Object? popped;
  bool poppedAtAll = false;
  final createdIds = <String>[];
}

/// Pumps a new dive centre's page (issue #4527, phase 3, plan 11): a full
/// page pushed over a launcher, or the pane's ([embedded]). Needs the test
/// database: the cards read nothing for an id not stored.
Future<NewDiveCenterHarness> pumpNewDiveCenterPage(
  WidgetTester tester, {
  bool embedded = false,
  LocationService? locations,
  Brightness brightness = Brightness.light,
  Size size = const Size(700, 1600),
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final overrides = await getBaseOverrides();
  final harness = NewDiveCenterHarness();
  final page = DiveCenterDetailPage.newDiveCenter(
    embedded: embedded,
    onCreated: harness.createdIds.add,
  );
  await tester.pumpWidget(
    testApp(
      overrides: [
        ...overrides,
        validatedCurrentDiverIdProvider.overrideWith((ref) async => 'd1'),
        if (locations != null)
          locationServiceProvider.overrideWithValue(locations),
        diveCenterEditSaveServiceProvider.overrideWith(
          (ref) => harness.save = FakeDiveCenterSave(
            ref.watch(_storedProvider.notifier),
          ),
        ),
      ],
      child: Theme(
        data: AppThemeRegistry.resolveTheme(
          AppThemeRegistry.presets.first,
          brightness,
        ),
        child: embedded
            ? Scaffold(body: page)
            : Builder(
                builder: (context) => Scaffold(
                  body: TextButton(
                    onPressed: () async {
                      final result = await Navigator.of(
                        context,
                      ).push(MaterialPageRoute<Object?>(builder: (_) => page));
                      harness
                        ..poppedAtAll = true
                        ..popped = result;
                    },
                    child: const Text('open'),
                  ),
                ),
              ),
      ),
    ),
  );
  if (!embedded) await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
  ProviderScope.containerOf(
    tester.element(find.byType(DiveCenterDetailPage)),
  ).read(diveCenterEditSaveServiceProvider);
  return harness;
}
