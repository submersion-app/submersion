import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:local_auth/local_auth.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';

import 'package:submersion/core/services/security/biometric_service.dart';
import 'biometric_service_test.mocks.dart';

@GenerateNiceMocks([MockSpec<LocalAuthentication>()])
void main() {
  test('authenticate returns false instead of throwing', () async {
    final mock = MockLocalAuthentication();
    when(
      mock.authenticate(
        localizedReason: anyNamed('localizedReason'),
        authMessages: anyNamed('authMessages'),
        biometricOnly: anyNamed('biometricOnly'),
        sensitiveTransaction: anyNamed('sensitiveTransaction'),
        persistAcrossBackgrounding: anyNamed('persistAcrossBackgrounding'),
      ),
    ).thenThrow(PlatformException(code: 'NotAvailable'));
    final svc = BiometricService(auth: mock);
    expect(await svc.authenticate(reason: 'test'), false);
  });

  test('authenticate passes through success', () async {
    final mock = MockLocalAuthentication();
    when(
      mock.authenticate(
        localizedReason: anyNamed('localizedReason'),
        authMessages: anyNamed('authMessages'),
        biometricOnly: anyNamed('biometricOnly'),
        sensitiveTransaction: anyNamed('sensitiveTransaction'),
        persistAcrossBackgrounding: anyNamed('persistAcrossBackgrounding'),
      ),
    ).thenAnswer((_) async => true);
    final svc = BiometricService(auth: mock);
    expect(await svc.authenticate(reason: 'test'), true);
  });

  test('isAvailable false when device unsupported', () async {
    final mock = MockLocalAuthentication();
    when(mock.isDeviceSupported()).thenAnswer((_) async => false);
    when(mock.canCheckBiometrics).thenAnswer((_) async => true);
    // platformSupported pinned: without it this test's result depends on the
    // host OS (passes on macOS, fails on CI's Linux runners).
    final svc = BiometricService(auth: mock, platformSupported: true);
    expect(await svc.isAvailable(), false);
  });

  test('isAvailable true when supported and biometrics enrolled', () async {
    final mock = MockLocalAuthentication();
    when(mock.isDeviceSupported()).thenAnswer((_) async => true);
    when(mock.canCheckBiometrics).thenAnswer((_) async => true);
    final svc = BiometricService(auth: mock, platformSupported: true);
    expect(await svc.isAvailable(), true);
  });

  test('isAvailable false on an unsupported platform without asking the '
      'plugin (Linux has no local_auth backend)', () async {
    final mock = MockLocalAuthentication();
    when(mock.isDeviceSupported()).thenAnswer((_) async => true);
    when(mock.canCheckBiometrics).thenAnswer((_) async => true);
    final svc = BiometricService(auth: mock, platformSupported: false);
    expect(await svc.isAvailable(), false);
    verifyNever(mock.isDeviceSupported());
  });
}
