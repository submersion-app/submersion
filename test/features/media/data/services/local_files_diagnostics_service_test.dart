import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';

import 'package:submersion/features/media/data/repositories/media_repository.dart';
import 'package:submersion/features/media/data/resolvers/local_file_resolver.dart';
import 'package:submersion/features/media/data/services/local_files_diagnostics_service.dart';
import 'package:submersion/features/media/data/services/local_media_platform.dart';
import 'package:submersion/features/media/domain/entities/media_item.dart';
import 'package:submersion/features/media/domain/entities/media_source_type.dart';

import 'local_files_diagnostics_service_test.mocks.dart';

@GenerateMocks([MediaRepository, LocalFileResolver, LocalMediaPlatform])
void main() {
  late MockMediaRepository mockRepo;
  late MockLocalMediaPlatform mockPlatform;
  late LocalFilesDiagnosticsService subject;

  setUp(() {
    mockRepo = MockMediaRepository();
    mockPlatform = MockLocalMediaPlatform();
    subject = LocalFilesDiagnosticsService(
      repository: mockRepo,
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
        // Read path reports the persisted flag and never touches the
        // filesystem. Verification lives in MediaVerificationSweep, which
        // this service deliberately does not depend on.
        verifyNever(mockRepo.updateMedia(any));
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

  group('LocalFilesDiagnostics equality (Equatable)', () {
    test('two instances with same fields are equal', () {
      const a = LocalFilesDiagnostics(total: 3, available: 2, unavailable: 1);
      const b = LocalFilesDiagnostics(total: 3, available: 2, unavailable: 1);
      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
    });

    test('instances with different fields are not equal', () {
      const a = LocalFilesDiagnostics(total: 3, available: 2, unavailable: 1);
      const b = LocalFilesDiagnostics(total: 3, available: 1, unavailable: 2);
      expect(a, isNot(equals(b)));
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
