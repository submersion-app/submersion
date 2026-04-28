import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';

import 'package:submersion/features/media/data/repositories/media_repository.dart';
import 'package:submersion/features/media/data/resolvers/local_file_resolver.dart';
import 'package:submersion/features/media/data/services/local_files_diagnostics_service.dart';
import 'package:submersion/features/media/data/services/local_media_platform.dart';
import 'package:submersion/features/media/domain/entities/media_item.dart';
import 'package:submersion/features/media/domain/entities/media_source_type.dart';
import 'package:submersion/features/media/domain/value_objects/verify_result.dart';

import 'local_files_diagnostics_service_test.mocks.dart';

@GenerateMocks([MediaRepository, LocalFileResolver, LocalMediaPlatform])
void main() {
  late MockMediaRepository mockRepo;
  late MockLocalFileResolver mockResolver;
  late MockLocalMediaPlatform mockPlatform;
  late LocalFilesDiagnosticsService subject;

  setUp(() {
    mockRepo = MockMediaRepository();
    mockResolver = MockLocalFileResolver();
    mockPlatform = MockLocalMediaPlatform();
    subject = LocalFilesDiagnosticsService(
      repository: mockRepo,
      resolver: mockResolver,
      platform: mockPlatform,
    );
  });

  MediaItem item({
    String id = 'm1',
    bool isOrphaned = false,
    DateTime? lastVerifiedAt,
  }) {
    return MediaItem(
      id: id,
      mediaType: MediaType.photo,
      sourceType: MediaSourceType.localFile,
      isOrphaned: isOrphaned,
      lastVerifiedAt: lastVerifiedAt,
      takenAt: DateTime(2024),
      createdAt: DateTime(2024),
      updatedAt: DateTime(2024),
    );
  }

  group('diagnose', () {
    test(
      'returns total/available/unavailable counts based on isOrphaned flag',
      () async {
        when(mockRepo.getAllBySourceType(MediaSourceType.localFile)).thenAnswer(
          (_) async => [
            item(id: 'a', isOrphaned: false),
            item(id: 'b', isOrphaned: false),
            item(id: 'c', isOrphaned: true),
          ],
        );

        final result = await subject.diagnose();

        expect(result.total, 3);
        expect(result.available, 2);
        expect(result.unavailable, 1);
        // Read path must not invoke the resolver.
        verifyNever(mockResolver.verify(any));
      },
    );

    test('with empty repository returns zeros', () async {
      when(
        mockRepo.getAllBySourceType(MediaSourceType.localFile),
      ).thenAnswer((_) async => []);

      final result = await subject.diagnose();

      expect(result.total, 0);
      expect(result.available, 0);
      expect(result.unavailable, 0);
    });
  });

  group('reverifyAll', () {
    test(
      'updates lastVerifiedAt for every item and returns the number whose orphan status flipped',
      () async {
        final a = item(id: 'a', isOrphaned: false); // stays available
        final b = item(id: 'b', isOrphaned: false); // flips to orphan
        final c = item(id: 'c', isOrphaned: true); // flips to available
        final d = item(id: 'd', isOrphaned: true); // stays orphan
        when(
          mockRepo.getAllBySourceType(MediaSourceType.localFile),
        ).thenAnswer((_) async => [a, b, c, d]);

        when(
          mockResolver.verify(a),
        ).thenAnswer((_) async => VerifyResult.available);
        when(
          mockResolver.verify(b),
        ).thenAnswer((_) async => VerifyResult.notFound);
        when(
          mockResolver.verify(c),
        ).thenAnswer((_) async => VerifyResult.available);
        when(
          mockResolver.verify(d),
        ).thenAnswer((_) async => VerifyResult.notFound);
        when(mockRepo.updateMedia(any)).thenAnswer((_) async {});

        final flipped = await subject.reverifyAll();

        expect(flipped, 2);
        // Every item must be updated, with lastVerifiedAt populated.
        final captured = verify(
          mockRepo.updateMedia(captureAny),
        ).captured.cast<MediaItem>();
        expect(captured.length, 4);
        for (final updated in captured) {
          expect(updated.lastVerifiedAt, isNotNull);
        }
        // Verify orphan flags got written correctly.
        final byId = {for (final u in captured) u.id: u};
        expect(byId['a']!.isOrphaned, isFalse);
        expect(byId['b']!.isOrphaned, isTrue);
        expect(byId['c']!.isOrphaned, isFalse);
        expect(byId['d']!.isOrphaned, isTrue);
      },
    );

    test('on empty repository returns zero', () async {
      when(
        mockRepo.getAllBySourceType(MediaSourceType.localFile),
      ).thenAnswer((_) async => []);

      final flipped = await subject.reverifyAll();

      expect(flipped, 0);
      verifyNever(mockResolver.verify(any));
      verifyNever(mockRepo.updateMedia(any));
    });
  });

  group('androidUriUsage', () {
    // We don't test the Android-list-length branch: this suite runs on macOS
    // hosts, where the `Platform.isAndroid` short-circuit prevents the
    // platform mock from being consulted regardless of stub setup. See the
    // service's androidUriUsage doc comment for details.
    test('returns 0 on non-Android', () async {
      final result = await subject.androidUriUsage();

      expect(result, 0);
      verifyNever(mockPlatform.listPersistedUris());
    });
  });
}
