import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/dive_computer/domain/entities/downloaded_dive.dart';
import 'package:submersion/features/dive_computer/presentation/providers/download_providers.dart';

void main() {
  group('DownloadState errorCode', () {
    test('copyWith stores errorCode alongside errorMessage', () {
      const state = DownloadState();
      final updated = state.copyWith(
        phase: DownloadPhase.error,
        errorCode: 'connect_failed',
        errorMessage: 'No USB serial ports found',
      );

      expect(updated.errorCode, 'connect_failed');
      expect(updated.errorMessage, 'No USB serial ports found');
      expect(updated.phase, DownloadPhase.error);
    });

    test('copyWith preserves errorCode when not overridden', () {
      final state = const DownloadState().copyWith(
        errorCode: 'connect_failed',
        errorMessage: 'test',
      );
      final updated = state.copyWith(phase: DownloadPhase.error);

      expect(updated.errorCode, 'connect_failed');
      expect(updated.errorMessage, 'test');
    });

    test('clearError clears both errorCode and errorMessage', () {
      final state = const DownloadState().copyWith(
        errorCode: 'connect_failed',
        errorMessage: 'test',
      );
      final cleared = state.copyWith(clearError: true);

      expect(cleared.errorCode, isNull);
      expect(cleared.errorMessage, isNull);
    });
  });
}
