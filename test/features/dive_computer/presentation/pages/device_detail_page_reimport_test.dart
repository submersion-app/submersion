import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_computer/presentation/pages/device_detail_page.dart';
import 'package:submersion/features/dive_log/domain/entities/dive_computer.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_computer_providers.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../helpers/mock_providers.dart';

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

DiveComputer _makeReimportComputer({
  String id = 'dc-1',
  String name = 'Perdix 2',
  String? fingerprint,
}) {
  final now = DateTime(2026, 1, 1);
  return DiveComputer(
    id: id,
    name: name,
    manufacturer: 'Shearwater',
    model: 'Perdix 2',
    createdAt: now,
    updatedAt: now,
    lastDiveFingerprint: fingerprint,
  );
}

class _MockDiveComputerNotifier
    extends StateNotifier<AsyncValue<List<DiveComputer>>>
    implements DiveComputerNotifier {
  _MockDiveComputerNotifier() : super(const AsyncValue.data(<DiveComputer>[]));

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

Widget _buildTestWidget({required DiveComputer computer}) {
  final router = GoRouter(
    initialLocation: '/dive-computers/${computer.id}',
    routes: [
      GoRoute(
        path: '/dives',
        builder: (context, state) =>
            const Scaffold(body: Text('DIVES_LIST_PAGE')),
      ),
      GoRoute(
        path: '/dive-computers/:id',
        builder: (context, state) =>
            DeviceDetailPage(computerId: state.pathParameters['id']!),
        routes: [
          GoRoute(
            path: 'download',
            builder: (context, state) =>
                const Scaffold(body: Text('DOWNLOAD_PAGE')),
          ),
        ],
      ),
    ],
  );

  return ProviderScope(
    overrides: [
      settingsProvider.overrideWith((ref) => MockSettingsNotifier()),
      diveComputerNotifierProvider.overrideWith(
        (ref) => _MockDiveComputerNotifier(),
      ),
      diveComputerByIdProvider(
        computer.id,
      ).overrideWith((ref) async => computer),
    ],
    child: MaterialApp.router(
      routerConfig: router,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
    ),
  );
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  group('Re-import button visibility', () {
    testWidgets('hidden when lastDiveFingerprint is null', (tester) async {
      final computer = _makeReimportComputer(fingerprint: null);
      await tester.pumpWidget(_buildTestWidget(computer: computer));
      await tester.pumpAndSettle();

      expect(find.text('Re-import all dives'), findsNothing);
    });

    testWidgets('visible when lastDiveFingerprint is non-null', (tester) async {
      final computer = _makeReimportComputer(fingerprint: 'abc123');
      await tester.pumpWidget(_buildTestWidget(computer: computer));
      await tester.pumpAndSettle();

      await tester.scrollUntilVisible(find.text('Re-import all dives'), 200);
      expect(find.text('Re-import all dives'), findsOneWidget);
    });
  });

  group('Confirmation dialog', () {
    testWidgets('opens on button tap with expected copy', (tester) async {
      final computer = _makeReimportComputer(fingerprint: 'abc123');
      await tester.pumpWidget(_buildTestWidget(computer: computer));
      await tester.pumpAndSettle();

      await tester.scrollUntilVisible(find.text('Re-import all dives'), 200);
      await tester.tap(find.text('Re-import all dives'));
      await tester.pumpAndSettle();

      expect(find.text('Re-import all dives?'), findsOneWidget);
      expect(find.textContaining('Perdix 2'), findsWidgets);
      expect(find.text('Cancel'), findsOneWidget);
      expect(find.text('Continue'), findsOneWidget);
    });

    testWidgets('Cancel dismisses without navigation', (tester) async {
      final computer = _makeReimportComputer(fingerprint: 'abc123');
      await tester.pumpWidget(_buildTestWidget(computer: computer));
      await tester.pumpAndSettle();

      await tester.scrollUntilVisible(find.text('Re-import all dives'), 200);
      await tester.tap(find.text('Re-import all dives'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(find.text('Re-import all dives?'), findsNothing);
      await tester.scrollUntilVisible(find.text('Re-import all dives'), 200);
      expect(find.text('Re-import all dives'), findsOneWidget);
    });

    testWidgets('Continue navigates to download page with forceFull=true', (
      tester,
    ) async {
      final computer = _makeReimportComputer(fingerprint: 'abc123');
      await tester.pumpWidget(_buildTestWidget(computer: computer));
      await tester.pumpAndSettle();

      await tester.scrollUntilVisible(find.text('Re-import all dives'), 200);
      await tester.tap(find.text('Re-import all dives'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();

      expect(find.text('DOWNLOAD_PAGE'), findsOneWidget);
    });
  });
}
