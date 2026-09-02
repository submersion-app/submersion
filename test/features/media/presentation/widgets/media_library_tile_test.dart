import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:submersion/features/media/data/services/media_serving_recorder.dart';
import 'package:submersion/features/media/domain/entities/media_item.dart';
import 'package:submersion/features/media/domain/entities/media_library_filter.dart';
import 'package:submersion/features/media/domain/entities/media_source_type.dart';
import 'package:submersion/features/media/presentation/providers/media_provenance_providers.dart';
import 'package:submersion/features/media/presentation/providers/media_serving_providers.dart';
import 'package:submersion/features/media/presentation/widgets/media_library_grid.dart';
import 'package:submersion/features/media/presentation/widgets/media_status_badge.dart';
import 'package:submersion/features/media_store/presentation/providers/media_store_providers.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

import '../../../../helpers/l10n_test_helpers.dart';
import '../../../../helpers/mock_providers.dart';

MediaLibraryEntry _entry({bool missing = false, bool uploaded = false}) =>
    MediaLibraryEntry(
      item: MediaItem(
        id: 'm1',
        mediaType: MediaType.photo,
        sourceType: MediaSourceType.platformGallery,
        platformAssetId: 'asset-1',
        isOrphaned: missing,
        lastVerifiedAt: DateTime.utc(2026),
        remoteUploadedAt: uploaded ? DateTime.utc(2026, 7) : null,
        takenAt: DateTime(2026, 3, 12),
        createdAt: DateTime(2026, 3, 12),
        updatedAt: DateTime(2026, 3, 12),
      ),
    );

void main() {
  late String? previousDefaultLocale;

  setUp(() {
    previousDefaultLocale = Intl.defaultLocale;
    Intl.defaultLocale = 'en_US';
  });

  tearDown(() {
    Intl.defaultLocale = previousDefaultLocale;
  });

  /// Counter as a mutable list so one pump is enough: a record would
  /// snapshot the value at return time and never observe a later gesture.
  Future<List<int>> pump(
    WidgetTester tester,
    MediaLibraryEntry entry, {
    bool selected = false,
    bool isSelectionMode = false,
  }) async {
    final counts = [0]; // taps
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          mediaStoreAttachedProvider.overrideWith((ref) async => true),
          mediaQueueFactsProvider.overrideWith((ref, id) => Stream.value(null)),
          mediaStoreIdentityProvider.overrideWith((ref) async => null),
          currentDeviceIdProvider.overrideWith((ref) async => 'dev-a'),
          mediaServingRecorderProvider.overrideWithValue(
            MediaServingRecorder(),
          ),
          settingsProvider.overrideWith((ref) => MockSettingsNotifier()),
        ],
        child: localizedMaterialApp(
          locale: const Locale('en'),
          home: Scaffold(
            body: SizedBox(
              width: 140,
              height: 140,
              child: MediaLibraryTile(
                entry: entry,
                selected: selected,
                isSelectionMode: isSelectionMode,
                onTap: () => counts[0]++,
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return counts;
  }

  testWidgets('an unhealthy entry renders the status badge', (tester) async {
    await pump(tester, _entry(missing: true));

    expect(find.byType(MediaStatusBadge), findsOneWidget);
    expect(find.byKey(const Key('media-status-badge')), findsOneWidget);
  });

  testWidgets('a healthy backed-up entry renders no badge glyph', (
    tester,
  ) async {
    await pump(tester, _entry(uploaded: true));

    expect(find.byKey(const Key('media-status-badge')), findsNothing);
  });

  // Selection must not regress: the tile's tap is what toggles a checked
  // item, and the status badge sits in the same Stack.
  testWidgets('a tap reaches the callback', (tester) async {
    final counts = await pump(tester, _entry(uploaded: true));

    await tester.tap(find.byType(MediaLibraryTile));
    await tester.pumpAndSettle();

    expect(counts[0], 1);
  });

  // Long-press enters selection nowhere in the app. With the handler gone
  // there is no upper duration bound on TapGestureRecognizer, so a hold
  // resolves as an ordinary tap on release -- it must not be silently
  // swallowed, and it must not do anything a tap would not.
  testWidgets('a hold resolves as an ordinary tap, selecting nothing', (
    tester,
  ) async {
    final counts = await pump(tester, _entry(uploaded: true));

    await tester.longPress(find.byType(MediaLibraryTile));
    await tester.pumpAndSettle();

    expect(counts[0], 1, reason: 'the hold fell through to onTap');
    expect(find.byIcon(Icons.check_circle), findsNothing);
  });

  testWidgets('the selection check still renders when selected', (
    tester,
  ) async {
    await pump(tester, _entry(uploaded: true), selected: true);

    expect(find.byIcon(Icons.check_circle), findsOneWidget);
  });

  /// The scrim drawn over unchecked tiles while the mode is active.
  Finder dimScrim() => find.byWidgetPredicate(
    (widget) => widget is Container && widget.color == _dimColor,
  );

  // Selection mode can be active with nothing checked, which is what the
  // Select control produces. Without the scrim that state is invisible: the
  // grid looks exactly as it does outside the mode, and the next tap does
  // something the user did not expect.
  testWidgets('an unchecked tile dims while selection mode is active', (
    tester,
  ) async {
    await pump(tester, _entry(uploaded: true), isSelectionMode: true);

    expect(dimScrim(), findsOneWidget);
  });

  testWidgets('a checked tile is not dimmed', (tester) async {
    await pump(
      tester,
      _entry(uploaded: true),
      isSelectionMode: true,
      selected: true,
    );

    expect(dimScrim(), findsNothing);
  });

  testWidgets('nothing dims outside selection mode', (tester) async {
    await pump(tester, _entry(uploaded: true));

    expect(dimScrim(), findsNothing);
  });
}

/// Kept in step with the tile's own scrim colour.
final Color _dimColor = Colors.black.withValues(alpha: 0.3);
