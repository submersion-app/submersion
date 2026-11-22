import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/theme/app_theme_registry.dart';
import 'package:submersion/features/buddies/data/repositories/buddy_repository.dart';
import 'package:submersion/features/buddies/data/services/buddy_edit_save_service.dart';
import 'package:submersion/features/buddies/domain/entities/buddy.dart';
import 'package:submersion/features/buddies/presentation/editing/buddy_new_sitting.dart';
import 'package:submersion/features/buddies/presentation/pages/buddy_detail_page.dart';
import 'package:submersion/features/buddies/presentation/providers/buddy_providers.dart';
import 'package:submersion/features/certifications/domain/entities/certification.dart';
import 'package:submersion/features/certifications/presentation/providers/certification_providers.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_location.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_location_providers.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_providers.dart';
import 'package:submersion/features/media/presentation/providers/media_people_providers.dart';

import '../../../../helpers/mock_providers.dart';
import '../../../../helpers/test_app.dart';

/// The buddy the page shows, as stored: Alex, with a phone and nothing
/// else.
final alex = Buddy(
  id: 'b1',
  diverId: 'd1',
  name: 'Alex',
  phone: '555',
  createdAt: DateTime(2020),
  updatedAt: DateTime(2020),
);

/// Records each save the page asks for, stores its result where the page
/// reads the buddy from, and can fail or refuse.
class FakeBuddySave implements BuddyEditSaveService {
  FakeBuddySave(this.stored);

  final StateController<Buddy?> stored;

  final calls = <({Buddy after, Set<String> cards})>[];

  /// Thrown from the save, as the real one throws a refused link.
  Object? throwing;

  /// Whether to run the held writes a save is given.
  bool runHeld = true;

  Completer<void>? gate;

  @override
  Future<({Buddy before, Buddy after})?> save({
    required String buddyId,
    required Buddy Function(Buddy stored) apply,
    required Iterable<String> changedCardIds,
    Future<void> Function()? alsoWrite,
    bool alsoWriteIsAChange = false,
  }) async {
    if (throwing case final error?) throw error;
    await gate?.future;
    final before = stored.state!;
    final after = apply(before);
    calls.add((after: after, cards: changedCardIds.toSet()));
    if (runHeld) await alsoWrite?.call();
    stored.state = after;
    return (before: before, after: after);
  }

  /// Each new buddy the page asked to create, failed ones included.
  final creates = <({Buddy buddy, Set<String> cards})>[];

  @override
  Future<Buddy> create({
    required Buddy buddy,
    required Iterable<String> changedCardIds,
    Future<void> Function()? alsoWrite,
  }) async {
    creates.add((buddy: buddy, cards: changedCardIds.toSet()));
    if (throwing case final error?) throw error;
    if (runHeld) await alsoWrite?.call();
    return buddy;
  }
}

class BuddyPageHarness {
  BuddyPageHarness(this.save, this.stored);

  final FakeBuddySave save;
  final StateController<Buddy?> stored;
}

final _storedProvider = StateProvider<Buddy?>((ref) => alex);

/// Pumps the buddy page, its calculated sections empty.
Future<BuddyPageHarness> pumpBuddyPage(
  WidgetTester tester, {
  Brightness brightness = Brightness.light,
  Buddy? buddy,
  bool openUnlocked = false,
  bool embedded = false,
  Size size = const Size(700, 1600),
  VoidCallback? onSittingEnded,
  List<Certification> certifications = const [],
  List<Object> extraOverrides = const [],
}) async {
  final shown = buddy ?? alex;
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final overrides = await getBaseOverrides();
  late BuddyPageHarness harness;
  final page = BuddyDetailPage(
    buddyId: shown.id,
    openUnlocked: openUnlocked,
    embedded: embedded,
    onSittingEnded: onSittingEnded,
  );
  await tester.pumpWidget(
    testApp(
      overrides: [
        ...overrides,
        _storedProvider.overrideWith((ref) => shown),
        buddyByIdProvider(
          shown.id,
        ).overrideWith((ref) async => ref.watch(_storedProvider)),
        buddyStatsProvider(
          shown.id,
        ).overrideWith((ref) async => const BuddyStats(totalDives: 3)),
        diveIdsForBuddyProvider(shown.id).overrideWith((ref) async => const []),
        divesForBuddyProvider(shown.id).overrideWith((ref) async => const []),
        buddyCertificationsProvider(
          shown.id,
        ).overrideWith((ref) async => certifications),
        mediaForBuddyProvider(shown.id).overrideWith((ref) async => const []),
        allEquipmentProvider.overrideWith((ref) async => const []),
        currentEquipmentLocationsProvider.overrideWith(
          (ref) async => const <String, EquipmentLocation>{},
        ),
        buddyEditSaveServiceProvider.overrideWith((ref) {
          final save = FakeBuddySave(ref.watch(_storedProvider.notifier));
          harness = BuddyPageHarness(save, ref.watch(_storedProvider.notifier));
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
    tester.element(find.byType(BuddyDetailPage)),
  );
  container.read(buddyEditSaveServiceProvider);
  return harness;
}

/// What a test of a new buddy's page pumped: the fake save, and how the
/// page ended.
class NewBuddyHarness {
  late FakeBuddySave save;
  Object? popped;
  bool poppedAtAll = false;
  final createdIds = <String>[];
  int cancelled = 0;
}

/// Pumps a new buddy's page (issue #4527, phase 3, plan 11) with [seed]: a
/// full page pushed over a launcher, or the pane's ([embedded]). Needs the
/// test database: the cards read nothing for an id not stored.
Future<NewBuddyHarness> pumpNewBuddyPage(
  WidgetTester tester, {
  NewBuddySeed? seed,
  bool embedded = false,
  Brightness brightness = Brightness.light,
  Size size = const Size(700, 1600),
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final overrides = await getBaseOverrides();
  final harness = NewBuddyHarness();
  final page = BuddyDetailPage.newBuddy(
    seed: seed,
    embedded: embedded,
    onCreated: harness.createdIds.add,
    onCreateCancelled: () => harness.cancelled++,
  );
  await tester.pumpWidget(
    testApp(
      overrides: [
        ...overrides,
        validatedCurrentDiverIdProvider.overrideWith((ref) async => 'd1'),
        allEquipmentProvider.overrideWith((ref) async => const []),
        currentEquipmentLocationsProvider.overrideWith(
          (ref) async => const <String, EquipmentLocation>{},
        ),
        buddyEditSaveServiceProvider.overrideWith(
          (ref) =>
              harness.save = FakeBuddySave(ref.watch(_storedProvider.notifier)),
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
    tester.element(find.byType(BuddyDetailPage)),
  ).read(buddyEditSaveServiceProvider);
  return harness;
}
