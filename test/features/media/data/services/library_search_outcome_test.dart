import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/media/data/services/asset_resolution_service.dart';
import 'package:submersion/features/media/data/services/library_search_outcome.dart';
import 'package:submersion/features/media/domain/value_objects/media_source_data.dart';

/// What a library search for a file that stopped reading comes to (media
/// sync program spec 6.3). A search that could not look is inconclusive,
/// never "found nothing": the caller turns nothing into notFound.
void main() {
  Future<Uint8List?> bytesFor(String id) async =>
      id == 'B-1' ? Uint8List.fromList([1]) : null;

  test('a search that could not look stays inconclusive', () async {
    final outcome = await librarySearchOutcome(
      const ResolutionResult(status: ResolutionStatus.accessDenied),
      bytesFor,
    );

    final data = outcome! as UnavailableData;
    expect(data.kind, UnavailableKind.accessDenied);
    expect(data.limitedAccess, isFalse);
  });

  test('a limited search stays inconclusive, flagged limited', () async {
    final outcome = await librarySearchOutcome(
      const ResolutionResult(
        status: ResolutionStatus.accessDenied,
        limitedAccess: true,
      ),
      bytesFor,
    );

    expect((outcome! as UnavailableData).limitedAccess, isTrue);
  });

  test('a search that looked and found nothing is null', () async {
    expect(
      await librarySearchOutcome(
        const ResolutionResult(status: ResolutionStatus.unavailable),
        bytesFor,
      ),
      isNull,
    );
  });

  test('a found photo that reads is served', () async {
    final outcome = await librarySearchOutcome(
      const ResolutionResult(
        localAssetId: 'B-1',
        status: ResolutionStatus.resolved,
      ),
      bytesFor,
    );

    expect((outcome! as BytesData).bytes, [1]);
  });

  test('a found photo that does not read is null', () async {
    expect(
      await librarySearchOutcome(
        const ResolutionResult(
          localAssetId: 'B-9',
          status: ResolutionStatus.resolved,
        ),
        bytesFor,
      ),
      isNull,
    );
  });
}
