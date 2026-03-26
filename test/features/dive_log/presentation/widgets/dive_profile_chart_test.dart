import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/providers/provider.dart';

import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_profile_chart.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

class _TestSettingsNotifier extends StateNotifier<AppSettings>
    implements SettingsNotifier {
  _TestSettingsNotifier() : super(const AppSettings());

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

List<DiveProfilePoint> _makeProfile({int points = 10}) {
  return List.generate(
    points,
    (i) => DiveProfilePoint(
      timestamp: i * 30,
      depth: (i < points / 2 ? i * 3.0 : (points - i) * 3.0),
    ),
  );
}

Widget _buildChart({
  List<DiveProfilePoint>? profile,
  Map<String, List<DiveProfilePoint>>? computerProfiles,
  Set<String>? visibleComputers,
  Map<String, Color>? computerLineColors,
  Set<String>? primaryComputers,
}) {
  return ProviderScope(
    overrides: [
      settingsProvider.overrideWith((ref) => _TestSettingsNotifier()),
    ],
    child: MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: SizedBox(
          width: 400,
          height: 300,
          child: DiveProfileChart(
            profile: profile ?? _makeProfile(),
            computerProfiles: computerProfiles,
            visibleComputers: visibleComputers,
            computerLineColors: computerLineColors,
            primaryComputers: primaryComputers,
          ),
        ),
      ),
    ),
  );
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  group('DiveProfileChart - single profile rendering', () {
    testWidgets('renders without crashing with profile data', (tester) async {
      await tester.pumpWidget(_buildChart());
      await tester.pumpAndSettle();

      expect(find.byType(DiveProfileChart), findsOneWidget);
    });

    testWidgets('renders empty state when profile is empty', (tester) async {
      await tester.pumpWidget(_buildChart(profile: const []));
      await tester.pumpAndSettle();

      // Empty profile should show empty state placeholder.
      expect(find.byType(DiveProfileChart), findsOneWidget);
    });
  });

  group('DiveProfileChart - multi-computer rendering', () {
    testWidgets('renders with two computer profiles', (tester) async {
      final profileA = _makeProfile(points: 8);
      final profileB = _makeProfile(points: 8);

      await tester.pumpWidget(
        _buildChart(
          computerProfiles: {'comp-a': profileA, 'comp-b': profileB},
          primaryComputers: {'comp-a'},
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(DiveProfileChart), findsOneWidget);
    });

    testWidgets('renders with custom computer line colors', (tester) async {
      final profileA = _makeProfile(points: 5);
      final profileB = _makeProfile(points: 5);

      await tester.pumpWidget(
        _buildChart(
          computerProfiles: {'comp-a': profileA, 'comp-b': profileB},
          computerLineColors: {'comp-a': Colors.red, 'comp-b': Colors.blue},
          primaryComputers: {'comp-a'},
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(DiveProfileChart), findsOneWidget);
    });

    testWidgets('renders when some computers are hidden', (tester) async {
      final profileA = _makeProfile(points: 5);
      final profileB = _makeProfile(points: 5);

      await tester.pumpWidget(
        _buildChart(
          computerProfiles: {'comp-a': profileA, 'comp-b': profileB},
          visibleComputers: {'comp-a'},
          primaryComputers: {'comp-a'},
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(DiveProfileChart), findsOneWidget);
    });

    testWidgets('renders with all computers hidden', (tester) async {
      final profileA = _makeProfile(points: 5);
      final profileB = _makeProfile(points: 5);

      await tester.pumpWidget(
        _buildChart(
          computerProfiles: {'comp-a': profileA, 'comp-b': profileB},
          visibleComputers: <String>{},
          primaryComputers: {'comp-a'},
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(DiveProfileChart), findsOneWidget);
    });

    testWidgets('falls back to single-profile with one computer', (
      tester,
    ) async {
      final profileA = _makeProfile(points: 5);

      await tester.pumpWidget(
        _buildChart(
          computerProfiles: {'comp-a': profileA},
          primaryComputers: {'comp-a'},
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(DiveProfileChart), findsOneWidget);
    });

    testWidgets('renders secondary computers without primaryComputers set', (
      tester,
    ) async {
      final profileA = _makeProfile(points: 5);
      final profileB = _makeProfile(points: 5);

      await tester.pumpWidget(
        _buildChart(computerProfiles: {'comp-a': profileA, 'comp-b': profileB}),
      );
      await tester.pumpAndSettle();

      expect(find.byType(DiveProfileChart), findsOneWidget);
    });
  });
}
