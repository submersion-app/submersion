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
}

/// Answers an address lookup with [found] once [answer] completes, or
/// with nothing.
class FakeLocations extends Fake implements LocationService {
  FakeLocations({this.found});

  final LocationResult? found;
  final answer = Completer<void>();
  final asked = <String>[];

  @override
  Future<LocationResult?> forwardGeocode(String address) async {
    asked.add(address);
    await answer.future;
    return found;
  }
}

class DiveCenterPageHarness {
  DiveCenterPageHarness(this.save, this.stored);

  final FakeDiveCenterSave save;
  final StateController<DiveCenter?> stored;
}

final _storedProvider = StateProvider<DiveCenter?>((ref) => reefDivers);

/// Pumps the dive centre page with the phase 3 switch on (unless
/// [unlockEditing] is false).
Future<DiveCenterPageHarness> pumpDiveCenterPage(
  WidgetTester tester, {
  Brightness brightness = Brightness.light,
  DiveCenter? center,
  bool unlockEditing = true,
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
    unlockEditing: unlockEditing,
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
