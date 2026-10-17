import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/services/shared_library/shared_library_models.dart';
import 'package:submersion/features/settings/domain/data_health/feature_health.dart';
import 'package:submersion/features/settings/domain/data_health/shared_library_health.dart';

void main() {
  LibraryHealthInput lib(
    String name, {
    String? lastError,
    bool rolesRejected = false,
    bool pendingRolesWaiting = false,
    bool readOnlyDetected = false,
    SharedLibraryRole listedRole = SharedLibraryRole.editor,
  }) => LibraryHealthInput(
    name: name,
    lastError: lastError,
    rolesRejected: rolesRejected,
    pendingRolesWaiting: pendingRolesWaiting,
    readOnlyDetected: readOnlyDetected,
    listedRole: listedRole,
  );

  void expectHealth(FeatureHealth h, HealthLevel level, HealthReason reason) {
    expect(h.feature, DataFeature.sharedLibraries);
    expect((h.level, h.reason), (level, reason));
  }

  test('no libraries is notSetUp', () {
    expectHealth(
      evaluateSharedLibraryHealth(const []),
      HealthLevel.notSetUp,
      HealthReason.notSetUp,
    );
  });

  test('all fine is healthy with the library count', () {
    final h = evaluateSharedLibraryHealth([lib('A'), lib('B')]);
    expectHealth(h, HealthLevel.healthy, HealthReason.ok);
    expect(h.count, 2);
  });

  test('lastError is failing with the library name', () {
    final h = evaluateSharedLibraryHealth([lib('Club Sites', lastError: 'x')]);
    expectHealth(h, HealthLevel.failing, HealthReason.librariesFailed);
    expect((h.name, h.count), ('Club Sites', 1));
  });

  test('two libraries with errors give count 2', () {
    final h = evaluateSharedLibraryHealth([
      lib('A', lastError: 'x'),
      lib('B'),
      lib('C', lastError: 'y'),
    ]);
    expectHealth(h, HealthLevel.failing, HealthReason.librariesFailed);
    expect((h.name, h.count), ('A', 2));
  });

  test('rolesRejected is attention editsHeld with name', () {
    final h = evaluateSharedLibraryHealth([
      lib('A'),
      lib('Club Sites', rolesRejected: true),
    ]);
    expectHealth(h, HealthLevel.attention, HealthReason.librariesEditsHeld);
    expect(h.name, 'Club Sites');
  });

  test('pending roles is attention', () {
    expectHealth(
      evaluateSharedLibraryHealth([lib('A', pendingRolesWaiting: true)]),
      HealthLevel.attention,
      HealthReason.librariesEditsHeld,
    );
  });

  test('editor with read-only storage is attention', () {
    expectHealth(
      evaluateSharedLibraryHealth([lib('A', readOnlyDetected: true)]),
      HealthLevel.attention,
      HealthReason.librariesEditsHeld,
    );
  });

  test('reader with read-only storage is healthy', () {
    expectHealth(
      evaluateSharedLibraryHealth([
        lib('A', readOnlyDetected: true, listedRole: SharedLibraryRole.reader),
      ]),
      HealthLevel.healthy,
      HealthReason.ok,
    );
  });

  test('failing outranks edits held', () {
    expectHealth(
      evaluateSharedLibraryHealth([
        lib('A', rolesRejected: true),
        lib('B', lastError: 'x'),
      ]),
      HealthLevel.failing,
      HealthReason.librariesFailed,
    );
  });
}
