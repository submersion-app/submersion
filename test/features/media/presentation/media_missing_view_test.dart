import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/media/data/services/media_source_resolver_registry.dart';
import 'package:submersion/features/media/domain/entities/media_item.dart';
import 'package:submersion/features/media/domain/entities/media_library_filter.dart';
import 'package:submersion/features/media/domain/entities/media_source_type.dart';
import 'package:submersion/features/media/domain/services/media_source_resolver.dart';
import 'package:submersion/features/media/domain/value_objects/media_source_data.dart';
import 'package:submersion/features/media/domain/value_objects/media_source_metadata.dart';
import 'package:submersion/features/media/domain/value_objects/verify_result.dart';
import 'package:submersion/features/media/presentation/pages/media_missing_view.dart';
import 'package:submersion/features/media/presentation/providers/media_library_providers.dart';
import 'package:submersion/features/media/presentation/providers/media_resolver_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

class _UnavailableResolver implements MediaSourceResolver {
  @override
  MediaSourceType get sourceType => MediaSourceType.localFile;
  @override
  bool canResolveOnThisDevice(MediaItem item) => true;
  @override
  Future<MediaSourceData> resolve(MediaItem item) async =>
      const UnavailableData(kind: UnavailableKind.notFound);
  @override
  Future<MediaSourceData> resolveThumbnail(
    MediaItem item, {
    required Size target,
  }) => resolve(item);
  @override
  Future<MediaSourceMetadata?> extractMetadata(MediaItem item) async => null;
  @override
  Future<VerifyResult> verify(MediaItem item) async => VerifyResult.available;
}

class _SeededNotifier extends StateNotifier<MediaLibraryState>
    implements MediaLibraryNotifier {
  _SeededNotifier(super.state);

  @override
  Future<void> loadFirstPage() async {}

  @override
  Future<void> loadMore() async {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

MediaLibraryEntry entry(String id) => MediaLibraryEntry(
  item: MediaItem(
    id: id,
    mediaType: MediaType.photo,
    sourceType: MediaSourceType.localFile,
    filePath: '/gone/$id.jpg',
    localPath: '/gone/$id.jpg',
    isOrphaned: true,
    takenAt: DateTime(2026, 6, 1),
    createdAt: DateTime(2026, 6, 1),
    updatedAt: DateTime(2026, 6, 1),
  ),
);

void main() {
  Widget host(List<MediaLibraryEntry> entries) {
    return ProviderScope(
      overrides: [
        missingViewProvider.overrideWith(
          (ref) => _SeededNotifier(MediaLibraryState(entries: entries)),
        ),
        missingOfflineCountProvider.overrideWith((ref) async => 0),
        mediaSourceResolverRegistryProvider.overrideWithValue(
          MediaSourceResolverRegistry({
            MediaSourceType.localFile: _UnavailableResolver(),
          }),
        ),
      ],
      child: const MaterialApp(
        locale: Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(body: MediaMissingView()),
      ),
    );
  }

  testWidgets('empty missing view shows the localized empty state', (
    tester,
  ) async {
    await tester.pumpWidget(host(const []));
    await tester.pumpAndSettle();
    expect(find.text('No missing files'), findsOneWidget);
    expect(find.text('Repair...'), findsNothing);
  });

  testWidgets('repair history stays reachable with nothing missing', (
    tester,
  ) async {
    await tester.pumpWidget(host(const []));
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.history), findsOneWidget);
  });

  testWidgets('missing rows render with the Repair entry point', (
    tester,
  ) async {
    await tester.pumpWidget(host([entry('a'), entry('b')]));
    await tester.pumpAndSettle();
    expect(find.text('Repair...'), findsOneWidget);
  });
}
