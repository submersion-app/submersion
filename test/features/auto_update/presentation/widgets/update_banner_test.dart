import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/auto_update/domain/entities/update_status.dart';
import 'package:submersion/features/auto_update/presentation/providers/update_providers.dart';
import 'package:submersion/features/auto_update/presentation/widgets/update_banner.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

void main() {
  late SharedPreferences prefs;

  setUp(() async {
    // Disable auto-update checks so the UpdateStatusNotifier constructor's
    // delayed timer callback returns immediately without reading more providers.
    SharedPreferences.setMockInitialValues({'auto_update_enabled': false});
    prefs = await SharedPreferences.getInstance();
  });

  Widget buildTestWidget(UpdateStatus status) {
    return ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        updateServiceProvider.overrideWith((ref) async => null),
        updateStatusProvider.overrideWith(
          (ref) => UpdateStatusNotifier(ref)..state = status,
        ),
      ],
      child: const MaterialApp(
        home: Scaffold(
          body: Column(
            children: [
              UpdateBanner(),
              Expanded(child: Placeholder()),
            ],
          ),
        ),
      ),
    );
  }

  group('UpdateBanner', () {
    testWidgets('shows nothing when UpToDate', (tester) async {
      await tester.pumpWidget(buildTestWidget(const UpToDate()));
      // Advance past the 5-second delayed timer in UpdateStatusNotifier.
      await tester.pump(const Duration(seconds: 6));

      expect(find.byType(MaterialBanner), findsNothing);
    });

    testWidgets('shows banner when UpdateAvailable', (tester) async {
      await tester.pumpWidget(
        buildTestWidget(
          const UpdateAvailable(
            version: '1.2.0',
            downloadUrl: 'https://example.com/update',
          ),
        ),
      );
      await tester.pump(const Duration(seconds: 6));

      expect(find.textContaining('1.2.0'), findsOneWidget);
    });

    testWidgets('shows banner when ReadyToInstall', (tester) async {
      await tester.pumpWidget(
        buildTestWidget(
          const ReadyToInstall(version: '1.2.0', localPath: '/tmp/update'),
        ),
      );
      await tester.pump(const Duration(seconds: 6));

      expect(find.textContaining('1.2.0'), findsOneWidget);
    });

    testWidgets('can be dismissed', (tester) async {
      await tester.pumpWidget(
        buildTestWidget(
          const UpdateAvailable(
            version: '1.2.0',
            downloadUrl: 'https://example.com/update',
          ),
        ),
      );
      await tester.pump(const Duration(seconds: 6));

      final dismissButton = find.byIcon(Icons.close);
      expect(dismissButton, findsOneWidget);

      await tester.tap(dismissButton);
      await tester.pump();

      expect(find.textContaining('1.2.0'), findsNothing);
    });
  });
}
