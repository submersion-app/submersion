import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/buddies/presentation/widgets/buddy_picker.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/presentation/pages/dive_edit_page.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_providers.dart';
import 'package:submersion/features/dive_roles/domain/entities/dive_role.dart';
import 'package:submersion/features/divers/data/repositories/diver_repository.dart';
import 'package:submersion/features/divers/domain/entities/diver.dart';
import 'package:submersion/features/tank_presets/presentation/providers/tank_preset_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../helpers/mock_providers.dart';
import '../../../../helpers/test_database.dart';

/// Issue #4458: the edit view's Me chip shows the dive's owner, which only
/// works if the editor hands the loaded dive's `diverId` to [BuddyPicker].
void main() {
  late DiveRepository dives;
  late String ownerId;

  setUp(() async {
    await setUpTestDatabase();
    dives = DiveRepository();
    final now = DateTime.now();
    ownerId = (await DiverRepository().createDiver(
      Diver(id: '', name: 'Owner', createdAt: now, updatedAt: now),
    )).id;
    await dives.createDive(
      Dive(
        id: 'owned',
        diverId: ownerId,
        dateTime: DateTime(2026, 9, 18, 9),
        diverRoleIds: const [DiveRole.rearGuardId],
      ),
    );
  });

  tearDown(() async => tearDownTestDatabase());

  Future<void> pumpEditor(WidgetTester tester, String? diveId) async {
    tester.view.physicalSize = const Size(1000, 6000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final base = await getBaseOverrides();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ...base.cast<Override>(),
          diveRepositoryProvider.overrideWithValue(dives),
          diveListNotifierProvider.overrideWith(
            (ref) => DiveListNotifier(dives, ref),
          ),
          customTankPresetsProvider.overrideWith((ref) async => []),
        ],
        child: MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(body: DiveEditPage(diveId: diveId, embedded: true)),
        ),
      ),
    );
    // The new-dive path starts a 10 s GPS capture, so pumpAndSettle never
    // returns; pump in bounded steps instead.
    Future<void> settle() async {
      for (var i = 0; i < 40; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }
    }

    await settle();

    // The Buddies section starts collapsed, and a collapsed section does not
    // mount its fields.
    await tester.tap(find.text('Buddies').first);
    await settle();
  }

  testWidgets("an existing dive's Me chip is for its owner", (tester) async {
    await pumpEditor(tester, 'owned');

    final picker = tester.widget<BuddyPicker>(find.byType(BuddyPicker));
    expect(picker.diveOwnerId, ownerId);
  });

  testWidgets("a new dive's Me chip is for the active diver", (tester) async {
    await pumpEditor(tester, null);

    final picker = tester.widget<BuddyPicker>(find.byType(BuddyPicker));
    expect(picker.diveOwnerId, isNull);
  });
}
