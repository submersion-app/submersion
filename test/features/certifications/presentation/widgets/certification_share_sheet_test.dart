import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:share_plus_platform_interface/share_plus_platform_interface.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/certifications/domain/certification_title.dart';
import 'package:submersion/features/certifications/domain/entities/certification.dart';
import 'package:submersion/features/certifications/presentation/services/certification_file_names.dart';
import 'package:submersion/features/certifications/presentation/widgets/certification_share_sheet.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

import '../../../../helpers/fake_path_provider.dart';
import '../../../../helpers/mock_providers.dart';
import '../../../../helpers/test_app.dart';

/// The images are written to the temporary directory before sharing.
class _FakePathProvider extends PathProviderPlatform
    with MockPlatformInterfaceMixin {
  _FakePathProvider(this.tempPath);
  final String tempPath;

  @override
  Future<String?> getTemporaryPath() async => tempPath;
}

/// Records what reached the share sheet.
class _FakeSharePlatform extends SharePlatform {
  final List<ShareParams> calls = [];

  @override
  Future<ShareResult> share(ShareParams params) async {
    calls.add(params);
    return const ShareResult('ok', ShareResultStatus.success);
  }
}

void main() {
  final platform = _FakeSharePlatform();
  late Directory temp;

  // The harness pins a forwarder that looks the platform up on every share
  // (test/helpers/late_bound_share_platform.dart), so the fake comes out
  // again when this file is done.
  late SharePlatform originalSharePlatform;
  setUpAll(() {
    originalSharePlatform = SharePlatform.instance;
    SharePlatform.instance = platform;
  });
  tearDownAll(() => SharePlatform.instance = originalSharePlatform);

  setUp(() {
    temp = Directory.systemTemp.createTempSync('certification_share_test');
    useFakePathProvider(_FakePathProvider(temp.path));
    platform.calls.clear();
  });
  tearDown(() => temp.deleteSync(recursive: true));

  final now = DateTime(2026, 8, 9);
  final cert = Certification(
    id: 'cert-1',
    name: 'Plongée Épave',
    agency: CertificationAgency.cmas.name,
    issueDate: DateTime(2018, 3, 14),
    createdAt: now,
    updatedAt: now,
  );

  /// Opens the sheet on a route of its own (it pops itself before sharing),
  /// taps [option], and waits for the share: rendering the image is real
  /// engine work, so it runs outside the fake clock.
  Future<ShareParams> share(WidgetTester tester, String option) async {
    await tester.pumpWidget(
      testApp(
        locale: const Locale('en'),
        overrides: [
          settingsProvider.overrideWith((ref) => MockSettingsNotifier()),
        ],
        child: Builder(
          builder: (context) => TextButton(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => Scaffold(
                  body: CertificationShareSheet(
                    certification: cert,
                    diverName: 'Ana Silva',
                  ),
                ),
              ),
            ),
            child: const Text('open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.tap(find.text(option));
    // The export began in the test's fake-async zone, so each slice of real
    // time is followed by a pump that delivers what completed in it.
    for (var i = 0; i < 200 && platform.calls.isEmpty; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 25)),
      );
      await tester.pump();
    }
    await tester.pumpAndSettle();
    expect(platform.calls, hasLength(1));
    return platform.calls.single;
  }

  testWidgets('the card is shared under its Unicode file name', (tester) async {
    final params = await share(tester, 'Share as Card');
    final expected = p.join(
      temp.path,
      certificationImageFileName(
        certificationTitle(cert),
        CertificationImage.card,
      ),
    );
    expect(params.files!.single.path, expected);
    expect(p.basename(expected), contains('Plongée_Épave'));
    expect(File(expected).existsSync(), isTrue);
  });

  testWidgets('the certificate is shared under its own file name', (
    tester,
  ) async {
    final params = await share(tester, 'Share as Certificate');
    final expected = p.join(
      temp.path,
      certificationImageFileName(
        certificationTitle(cert),
        CertificationImage.certificate,
      ),
    );
    expect(params.files!.single.path, expected);
    expect(File(expected).existsSync(), isTrue);
  });
}
