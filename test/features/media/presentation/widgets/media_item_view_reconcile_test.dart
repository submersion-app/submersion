import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/media/data/repositories/media_repository.dart';
import 'package:submersion/features/media/data/services/media_source_resolver_registry.dart';
import 'package:submersion/features/media/domain/entities/media_item.dart';
import 'package:submersion/features/media/domain/entities/media_source_type.dart';
import 'package:submersion/features/media/domain/services/media_source_resolver.dart';
import 'package:submersion/features/media/domain/value_objects/media_source_data.dart';
import 'package:submersion/features/media/domain/value_objects/media_source_metadata.dart';
import 'package:submersion/features/media/domain/value_objects/verify_result.dart';
import 'package:submersion/features/media/presentation/providers/media_providers.dart';
import 'package:submersion/features/media/presentation/providers/media_resolver_providers.dart';
import 'package:submersion/features/media/presentation/widgets/media_item_view.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

/// A 1x1 transparent PNG, so Image.memory has something it can decode.
final Uint8List _png = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8/5+hHgAHggJ/PchI7wAAAABJRU5ErkJggg==',
);

class _FixedResolver implements MediaSourceResolver {
  _FixedResolver(this.data);

  final MediaSourceData data;

  @override
  MediaSourceType get sourceType => MediaSourceType.platformGallery;

  @override
  bool canResolveOnThisDevice(MediaItem item) => true;

  @override
  Future<MediaSourceData> resolve(MediaItem item) async => data;

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

/// Records markVerified calls and refuses every other member, so a write the
/// reconciler was not supposed to make shows up as a failure rather than as
/// a silently accepted no-op.
class _CapturingRepository implements MediaRepository {
  final List<({String id, bool isOrphaned})> writes = [];

  @override
  Future<void> markVerified(
    String id, {
    required bool isOrphaned,
    required DateTime verifiedAt,
  }) async => writes.add((id: id, isOrphaned: isOrphaned));

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName} is not stubbed');
}

MediaItem _item({bool isOrphaned = false}) => MediaItem(
  id: 'x',
  mediaType: MediaType.photo,
  sourceType: MediaSourceType.platformGallery,
  isOrphaned: isOrphaned,
  takenAt: DateTime.utc(2026, 1, 1),
  createdAt: DateTime.utc(2026, 1, 1),
  updatedAt: DateTime.utc(2026, 1, 1),
);

Future<void> _pump(
  WidgetTester tester, {
  required MediaSourceData data,
  required MediaRepository repository,
  bool isOrphaned = false,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        mediaSourceResolverRegistryProvider.overrideWithValue(
          MediaSourceResolverRegistry({
            MediaSourceType.platformGallery: _FixedResolver(data),
          }),
        ),
        mediaRepositoryProvider.overrideWithValue(repository),
      ],
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 140,
              height: 140,
              child: MediaItemView(
                item: _item(isOrphaned: isOrphaned),
                thumbnail: true,
              ),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('a notFound resolution orphans the row', (tester) async {
    final repository = _CapturingRepository();

    await _pump(
      tester,
      data: const UnavailableData(kind: UnavailableKind.notFound),
      repository: repository,
    );

    expect(repository.writes, [(id: 'x', isOrphaned: true)]);
  });

  testWidgets('a successful resolution clears a stale orphan flag', (
    tester,
  ) async {
    final repository = _CapturingRepository();

    await _pump(
      tester,
      data: BytesData(bytes: _png, servedFrom: ServedFrom.platformGallery),
      repository: repository,
      isOrphaned: true,
    );

    expect(repository.writes, [(id: 'x', isOrphaned: false)]);
  });

  testWidgets('a healthy row that resolves writes nothing', (tester) async {
    // The steady state. Every MediaRepository write calls markRecordPending,
    // so a write here would queue one pending sync row per thumbnail that
    // scrolled into view.
    final repository = _CapturingRepository();

    await _pump(
      tester,
      data: BytesData(bytes: _png, servedFrom: ServedFrom.platformGallery),
      repository: repository,
    );

    expect(repository.writes, isEmpty);
  });

  // A revoked photo permission makes EVERY gallery tile fail at once, so a
  // write on this path would orphan a whole library and sync the claim.
  testWidgets('an accessDenied resolution never orphans', (tester) async {
    final repository = _CapturingRepository();

    await _pump(
      tester,
      data: const UnavailableData(kind: UnavailableKind.accessDenied),
      repository: repository,
    );

    expect(repository.writes, isEmpty);
  });

  // The availability work's own constraint: a fetch that outlived its time
  // budget must not permanently mark a diver's photo dead.
  testWidgets('a stillFetching resolution never orphans', (tester) async {
    final repository = _CapturingRepository();

    await _pump(
      tester,
      data: const UnavailableData(kind: UnavailableKind.stillFetching),
      repository: repository,
    );

    expect(repository.writes, isEmpty);
  });

  testWidgets('an already-orphaned row that stays missing writes nothing', (
    tester,
  ) async {
    final repository = _CapturingRepository();

    await _pump(
      tester,
      data: const UnavailableData(kind: UnavailableKind.notFound),
      repository: repository,
      isOrphaned: true,
    );

    expect(repository.writes, isEmpty);
  });
}
