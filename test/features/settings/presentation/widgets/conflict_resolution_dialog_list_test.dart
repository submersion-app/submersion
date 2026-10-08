import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/services/sync/sync_service.dart';
import 'package:submersion/features/settings/presentation/providers/sync_providers.dart';
import 'package:submersion/features/settings/presentation/widgets/conflict_resolution_dialog.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../helpers/mock_providers.dart';

/// The Resolve Conflicts dialog works from the conflicts as they are now
/// (#2943). The list used to be cached for the life of the app, so a
/// reopened dialog offered conflicts already resolved and hid ones a later
/// sync raised; and a list that shrank under an open dialog indexed past its
/// end.
void main() {
  SyncConflict conflict(String id, String name) => SyncConflict(
    entityType: 'diveSites',
    recordId: id,
    localData: {'id': id, 'name': name},
    remoteData: {'id': id, 'name': name},
    localModified: DateTime(2026, 3, 28),
    remoteModified: DateTime(2026, 3, 29),
  );

  final reef = conflict('site-a', 'Reef');
  final wall = conflict('site-b', 'Wall');

  /// Pumps a page whose button opens the dialog, as the Cloud Sync page
  /// does; the dialog reads [current] each time the list loads.
  Future<void> pumpHost(
    WidgetTester tester,
    List<SyncConflict> Function() current,
  ) async {
    final base = await getBaseOverrides();
    await tester.binding.setSurfaceSize(const Size(600, 1200));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ...base,
          conflictsProvider.overrideWith((ref) async => current()),
        ],
        child: MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => showDialog<void>(
                  context: context,
                  builder: (_) => const ConflictResolutionDialog(),
                ),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> openDialog(WidgetTester tester) async {
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  Finder titled(String name) => find.descendant(
    of: find.byType(ConflictResolutionDialog),
    matching: find.text(name),
  );

  testWidgets('a reopened dialog shows the conflicts as they are now', (
    tester,
  ) async {
    var conflicts = [reef];
    await pumpHost(tester, () => conflicts);

    await openDialog(tester);
    expect(titled('Reef'), findsWidgets);
    await tester.tap(find.byTooltip('Close conflict dialog'));
    await tester.pumpAndSettle();

    // Resolved elsewhere, and a later sync raised a different conflict.
    conflicts = [wall];
    await openDialog(tester);

    expect(titled('Wall'), findsWidgets);
    expect(titled('Reef'), findsNothing);
  });

  testWidgets('a list that shrinks while the last card is open shows the '
      'new last card', (tester) async {
    var conflicts = [reef, wall];
    await pumpHost(tester, () => conflicts);
    await openDialog(tester);
    await tester.tap(find.byTooltip('Next conflict'));
    await tester.pumpAndSettle();
    expect(titled('Wall'), findsWidgets);

    conflicts = [reef];
    ProviderScope.containerOf(
      tester.element(find.byType(ConflictResolutionDialog)),
    ).invalidate(conflictsProvider);
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(titled('Reef'), findsWidgets);
    expect(titled('Wall'), findsNothing);
  });
}
