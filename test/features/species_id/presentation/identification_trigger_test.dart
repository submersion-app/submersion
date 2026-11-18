import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/constants/feature_flags.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';
import 'package:submersion/features/media/domain/entities/media_item.dart';
import 'package:submersion/features/media/domain/entities/species_tag_chip.dart';
import 'package:submersion/features/media/presentation/providers/species_media_providers.dart';
import 'package:submersion/features/species_id/presentation/providers/species_id_providers.dart';
import 'package:submersion/features/species_id/presentation/widgets/identification_trigger.dart';

import '../../media/presentation/support/media_widget_harness.dart';
import 'species_id_fakes.dart';

void main() {
  late RecordingIdentificationService service;
  var chips = <SpeciesTagChip>[];

  setUp(() {
    marineLifeIdEnabled = true;
    service = RecordingIdentificationService();
    chips = [];
  });
  tearDown(resetMarineLifeIdEnabled);

  Widget host(MediaItem item, {GeoPoint? location}) => ProviderScope(
    overrides: [
      mediaIdentificationServiceProvider.overrideWithValue(service),
      mediaTagChipsProvider.overrideWith((ref, id) async => chips),
    ],
    child: Directionality(
      textDirection: TextDirection.ltr,
      child: IdentificationTrigger(item: item, location: location),
    ),
  );

  MediaItem photo(String id) => testMediaItem(id: id);

  testWidgets('asks after the photo has been shown a moment', (tester) async {
    await tester.pumpWidget(
      host(photo('p1'), location: const GeoPoint(12.1, -68.3)),
    );
    await tester.pump(const Duration(milliseconds: 399));
    expect(service.requested, isEmpty);
    await tester.pump(const Duration(milliseconds: 2));
    expect(service.requested, ['p1']);
    expect(service.locations.single, const GeoPoint(12.1, -68.3));
  });

  testWidgets('a photo swiped past is never asked for', (tester) async {
    await tester.pumpWidget(host(photo('p1')));
    await tester.pump(const Duration(milliseconds: 200));
    await tester.pumpWidget(host(photo('p2')));
    await tester.pump(const Duration(milliseconds: 401));
    expect(service.requested, ['p2']);
    expect(service.cancelled, contains('p1'));
  });

  testWidgets('a photo is asked for once while the viewer is open', (
    tester,
  ) async {
    for (final id in ['p1', 'p2', 'p1']) {
      await tester.pumpWidget(host(photo(id)));
      await tester.pump(const Duration(milliseconds: 401));
    }
    expect(service.requested, ['p1', 'p2']);
  });

  testWidgets('a photo whose request was dropped is asked for again when it '
      'comes back', (tester) async {
    service.requestsWait = true;
    for (final id in ['p1', 'p2', 'p1']) {
      await tester.pumpWidget(host(photo(id)));
      await tester.pump(const Duration(milliseconds: 401));
    }
    expect(service.requested, ['p1', 'p2', 'p1']);
  });

  testWidgets('a location that arrives later is passed on', (tester) async {
    await tester.pumpWidget(host(photo('p1')));
    await tester.pump(const Duration(milliseconds: 401));
    const site = GeoPoint(12.1, -68.3);
    await tester.pumpWidget(host(photo('p1'), location: site));
    await tester.pumpWidget(host(photo('p1'), location: site));
    await tester.pump(const Duration(milliseconds: 401));
    expect(service.requested, ['p1', 'p1']);
    expect(service.locations, [null, site]);
  });

  testWidgets('closing the viewer drops the photo\'s waiting request', (
    tester,
  ) async {
    service.requestsWait = true;
    await tester.pumpWidget(host(photo('p1')));
    await tester.pump(const Duration(milliseconds: 401));
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          mediaIdentificationServiceProvider.overrideWithValue(service),
          mediaTagChipsProvider.overrideWith((ref, id) async => chips),
        ],
        child: const SizedBox.shrink(),
      ),
    );
    expect(service.cancelled, ['p1']);
  });

  testWidgets('a video is asked for after the dwell (issue #4675)', (
    tester,
  ) async {
    await tester.pumpWidget(
      host(testMediaItem(id: 'v1', mediaType: MediaType.video)),
    );
    await tester.pump(const Duration(milliseconds: 399));
    expect(service.requested, isEmpty);
    await tester.pump(const Duration(milliseconds: 2));
    expect(service.requested, ['v1']);
  });

  testWidgets('a video is asked for again when the app comes back', (
    tester,
  ) async {
    await tester.pumpWidget(
      host(testMediaItem(id: 'v1', mediaType: MediaType.video)),
    );
    await tester.pump(const Duration(milliseconds: 401));
    expect(service.requested, ['v1']);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    expect(service.requested, ['v1', 'v1']);
  });

  testWidgets('losing focus without going to the background asks nothing', (
    tester,
  ) async {
    await tester.pumpWidget(
      host(testMediaItem(id: 'v1', mediaType: MediaType.video)),
    );
    await tester.pump(const Duration(milliseconds: 401));
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    expect(service.requested, ['v1']);
  });

  group('a page over the viewer', () {
    final navigator = GlobalKey<NavigatorState>();

    Widget app(MediaItem item) => ProviderScope(
      overrides: [
        mediaIdentificationServiceProvider.overrideWithValue(service),
        mediaTagChipsProvider.overrideWith((ref, id) async => chips),
      ],
      child: MaterialApp(
        navigatorKey: navigator,
        home: Scaffold(body: IdentificationTrigger(item: item)),
      ),
    );

    testWidgets('stops the video\'s scan, and coming back asks again', (
      tester,
    ) async {
      service.requestsWait = true;
      await tester.pumpWidget(
        app(testMediaItem(id: 'v1', mediaType: MediaType.video)),
      );
      await tester.pump(const Duration(milliseconds: 401));
      expect(service.requested, ['v1']);
      unawaited(
        navigator.currentState!.push(
          MaterialPageRoute<void>(builder: (_) => const Scaffold()),
        ),
      );
      await tester.pumpAndSettle();
      expect(service.cancelled, ['v1']);
      navigator.currentState!.pop();
      await tester.pumpAndSettle();
      await tester.pump(const Duration(milliseconds: 401));
      expect(service.requested, ['v1', 'v1']);
    });

    testWidgets('a location arriving while covered does not start the scan', (
      tester,
    ) async {
      service.requestsWait = true;
      final video = testMediaItem(id: 'v1', mediaType: MediaType.video);
      Widget located(GeoPoint? at) => ProviderScope(
        overrides: [
          mediaIdentificationServiceProvider.overrideWithValue(service),
          mediaTagChipsProvider.overrideWith((ref, id) async => chips),
        ],
        child: MaterialApp(
          navigatorKey: navigator,
          home: Scaffold(
            body: IdentificationTrigger(item: video, location: at),
          ),
        ),
      );
      await tester.pumpWidget(located(null));
      await tester.pump(const Duration(milliseconds: 401));
      unawaited(
        navigator.currentState!.push(
          MaterialPageRoute<void>(builder: (_) => const Scaffold()),
        ),
      );
      await tester.pumpAndSettle();
      await tester.pumpWidget(located(const GeoPoint(12, -68)));
      await tester.pump();
      expect(service.requested, ['v1']);
    });

    testWidgets('a sheet over it leaves the scan running', (tester) async {
      service.requestsWait = true;
      await tester.pumpWidget(
        app(testMediaItem(id: 'v1', mediaType: MediaType.video)),
      );
      await tester.pump(const Duration(milliseconds: 401));
      unawaited(
        showModalBottomSheet<void>(
          context: navigator.currentContext!,
          builder: (_) => const SizedBox(height: 100),
        ),
      );
      await tester.pumpAndSettle();
      expect(service.cancelled, isEmpty);
    });
  });

  testWidgets('a document is not asked for', (tester) async {
    await tester.pumpWidget(
      host(testMediaItem(id: 'd1', mediaType: MediaType.document)),
    );
    await tester.pump(const Duration(milliseconds: 401));
    expect(service.requested, isEmpty);
  });

  testWidgets('switched off, nothing is asked for', (tester) async {
    marineLifeIdEnabled = false;
    await tester.pumpWidget(host(photo('p1')));
    await tester.pump(const Duration(milliseconds: 401));
    expect(service.requested, isEmpty);
  });

  testWidgets('a change to the photo\'s tags reconciles its decisions', (
    tester,
  ) async {
    await tester.pumpWidget(host(photo('p1')));
    await tester.pump(const Duration(milliseconds: 401));
    final container = ProviderScope.containerOf(
      tester.element(find.byType(IdentificationTrigger)),
    );
    chips = [
      const SpeciesTagChip(
        speciesId: 'sp_queen_parrotfish',
        storedName: 'Queen Parrotfish',
        category: SpeciesCategory.fish,
        isBuiltIn: true,
      ),
    ];
    container.invalidate(mediaTagChipsProvider('p1'));
    await tester.pump();
    await tester.pump();
    expect(service.reconciled, contains('p1'));
  });
}
