import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:submersion/features/divers/domain/entities/diver.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/import_wizard/presentation/widgets/diver_mapping_step.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/features/universal_import/data/models/diver_target.dart';
import 'package:submersion/features/universal_import/data/models/import_payload.dart';
import 'package:submersion/features/universal_import/data/models/source_diver.dart';
import 'package:submersion/features/universal_import/presentation/providers/universal_import_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

const _ann = 'macdive:ann';
const _bo = 'macdive:bo';

final _me = Diver(
  id: 'me',
  name: 'Me',
  createdAt: DateTime(2026),
  updatedAt: DateTime(2026),
);

void main() {
  late ProviderContainer container;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        allDiversProvider.overrideWith((ref) async => [_me]),
      ],
    );
    final notifier = container.read(universalImportNotifierProvider.notifier);
    notifier.state = notifier.state.copyWith(
      payload: const ImportPayload(
        entities: {},
        sourceDivers: [
          SourceDiver(key: _bo, name: 'Bo Ray', diveCount: 3),
          SourceDiver(
            key: _ann,
            name: 'Ann Lee',
            diveCount: 5,
            certificationCount: 2,
          ),
          SourceDiver(key: SourceDiver.unownedKey, name: '', diveCount: 1),
        ],
      ),
      diverMapping: const {
        _ann: ExistingDiverTarget('me'),
        _bo: NewDiverTarget(_bo),
        SourceDiver.unownedKey: ExistingDiverTarget('me'),
      },
    );
  });

  tearDown(() => container.dispose());

  Future<void> pump(WidgetTester tester) async {
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
          locale: Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(body: DiverMappingStep()),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('lists each diver with counts and the current choice', (
    tester,
  ) async {
    await pump(tester);

    expect(
      find.textContaining('This logbook has dives for 2 divers'),
      findsOneWidget,
    );
    expect(find.text('Ann Lee'), findsOneWidget);
    expect(find.text('5 dives · 2 certifications'), findsOneWidget);
    expect(find.text('Bo Ray'), findsOneWidget);
    expect(find.text('3 dives'), findsOneWidget);
    expect(find.text('Dives with no diver'), findsOneWidget);
    expect(find.text('Create new profile "Bo Ray"'), findsOneWidget);
    // Ann (busiest) is listed before Bo.
    expect(
      tester.getTopLeft(find.text('Ann Lee')).dy,
      lessThan(tester.getTopLeft(find.text('Bo Ray')).dy),
    );
  });

  testWidgets('choosing a target updates the mapping', (tester) async {
    await pump(tester);

    await tester.tap(find.byKey(const ValueKey('diver_target_$_ann')));
    await tester.pumpAndSettle();
    await tester.tap(find.text("Don't import").last);
    await tester.pumpAndSettle();

    expect(
      container.read(universalImportNotifierProvider).diverMapping[_ann],
      const SkipDiverTarget(),
    );
  });

  testWidgets('the no-diver row cannot create a profile', (tester) async {
    await pump(tester);

    await tester.tap(
      find.byKey(const ValueKey('diver_target_${SourceDiver.unownedKey}')),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('Create new profile ""'), findsNothing);
  });
}
