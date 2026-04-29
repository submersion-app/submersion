import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/media/data/services/local_files_diagnostics_service.dart';
import 'package:submersion/features/media/presentation/providers/media_resolver_providers.dart';

/// Stub diagnostics service used to drive the FutureProvider tests in this
/// file. We override `localFilesDiagnosticsServiceProvider` so the providers
/// under test resolve to this stub instead of touching the real DB / platform
/// channel.
class _StubDiagnosticsService implements LocalFilesDiagnosticsService {
  _StubDiagnosticsService({this.uriUsage = 0, this.diagnosis});

  final int uriUsage;
  final LocalFilesDiagnostics? diagnosis;

  @override
  Future<int> androidUriUsage() async => uriUsage;

  @override
  Future<LocalFilesDiagnostics> diagnose() async {
    return diagnosis ??
        const LocalFilesDiagnostics(total: 0, available: 0, unavailable: 0);
  }

  @override
  Future<int> reverifyAll() async => 0;

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName} should not be called');
}

void main() {
  test(
    'androidUriUsageProvider delegates to service.androidUriUsage',
    () async {
      final container = ProviderContainer(
        overrides: [
          localFilesDiagnosticsServiceProvider.overrideWithValue(
            _StubDiagnosticsService(uriUsage: 7),
          ),
        ],
      );
      addTearDown(container.dispose);

      final result = await container.read(androidUriUsageProvider.future);
      expect(result, 7);
    },
  );

  test('localFilesDiagnosticsProvider delegates to service.diagnose', () async {
    const expected = LocalFilesDiagnostics(
      total: 5,
      available: 3,
      unavailable: 2,
    );
    final container = ProviderContainer(
      overrides: [
        localFilesDiagnosticsServiceProvider.overrideWithValue(
          _StubDiagnosticsService(diagnosis: expected),
        ),
      ],
    );
    addTearDown(container.dispose);

    final result = await container.read(localFilesDiagnosticsProvider.future);
    expect(result, expected);
  });
}
