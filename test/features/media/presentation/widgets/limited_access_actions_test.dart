import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/media/data/repositories/local_asset_cache_repository.dart';
import 'package:submersion/features/media/data/services/asset_resolution_service.dart';
import 'package:submersion/features/media/data/services/photo_access_actions.dart';
import 'package:submersion/features/media/presentation/providers/photo_access_providers.dart';
import 'package:submersion/features/media/presentation/providers/resolved_asset_providers.dart';
import 'package:submersion/features/media/presentation/widgets/limited_access_actions.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../helpers/fake_photo_picker_service.dart';

class _RecordingActions implements PhotoAccessActions {
  final calls = <String>[];
  Object? error;

  @override
  Future<void> openSettings() async {
    calls.add('settings');
    if (error != null) throw error!;
  }

  @override
  Future<void> chooseMorePhotos() async {
    calls.add('choose');
    if (error != null) throw error!;
  }
}

/// Counts how often the shared gallery queries were dropped.
class _CountingResolution extends AssetResolutionService {
  _CountingResolution()
    : super(
        cacheRepository: LocalAssetCacheRepository(),
        photoPickerService: FakePhotoPickerService(),
      );

  int forgets = 0;

  @override
  void forgetGalleryQueries() => forgets++;
}

/// A photo outside the user's limited selection offers the two ways back:
/// full access in the system settings, or adding it to the selection
/// (media sync program spec 6.3).
void main() {
  late _RecordingActions actions;
  late _CountingResolution resolution;
  late int changes;

  setUp(() {
    actions = _RecordingActions();
    resolution = _CountingResolution();
    changes = 0;
  });

  Future<void> pump(WidgetTester tester) => tester.pumpWidget(
    ProviderScope(
      overrides: [
        photoAccessActionsProvider.overrideWithValue(actions),
        assetResolutionServiceProvider.overrideWithValue(resolution),
      ],
      child: MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(body: LimitedAccessActions(onChanged: () => changes++)),
      ),
    ),
  );

  // Opening the settings returns at once, while the user is still there:
  // the refresh waits until they come back to the app.
  testWidgets('Allow full access refreshes when the user returns', (
    tester,
  ) async {
    await pump(tester);

    await tester.tap(find.text('Allow full access'));
    await tester.pumpAndSettle();
    expect(actions.calls, ['settings']);
    expect(changes, 0, reason: 'the user is still in the settings');

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();

    expect(changes, 1);
    expect(resolution.forgets, 1);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    expect(changes, 1, reason: 'one refresh per trip to the settings');
  });

  testWidgets('settings that fail to open refresh at once', (tester) async {
    actions.error = StateError('no settings');
    await pump(tester);

    await tester.tap(find.text('Allow full access'));
    await tester.pumpAndSettle();

    expect(changes, 1);
  });

  testWidgets('Choose photo again opens the selection, then refreshes', (
    tester,
  ) async {
    await pump(tester);

    await tester.tap(find.text('Choose photo again'));
    await tester.pumpAndSettle();

    expect(actions.calls, ['choose']);
    expect(changes, 1);
    expect(
      resolution.forgets,
      1,
      reason: 'the selection changed under the same permission',
    );
  });

  // A platform that cannot open the sheet (an older OS) must not surface
  // an exception from a button.
  testWidgets('a failing action is contained, and still refreshes', (
    tester,
  ) async {
    actions.error = StateError('unsupported');
    await pump(tester);

    await tester.tap(find.text('Choose photo again'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(changes, 1);
  });
}
