import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/built_ins/built_in_catalog.dart';
import 'package:submersion/features/pre_dive/domain/entities/pre_dive_checklist_template.dart';
import 'package:submersion/features/pre_dive/presentation/pages/pre_dive_templates_page.dart';
import 'package:submersion/features/pre_dive/presentation/providers/pre_dive_providers.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/shared/widgets/built_in_show_column.dart';

import '../../../../helpers/mock_providers.dart';
import '../../../../helpers/test_app.dart';

/// Settings > Pre-Dive Checklists hide switches (issue #401).
void main() {
  final now = DateTime.fromMillisecondsSinceEpoch(1700000000000);
  final templates = [
    PreDiveChecklistTemplate(
      id: 'builtin-predive-bwraf',
      name: 'BWRAF Buddy Check',
      isBuiltIn: true,
      builtinKey: 'builtin-predive-bwraf',
      createdAt: now,
      updatedAt: now,
    ),
    PreDiveChecklistTemplate(
      id: 'custom-1',
      name: 'My checks',
      createdAt: now,
      updatedAt: now,
    ),
  ];
  final bwrafKey = builtInShowSwitchKey(
    BuiltInCatalog.preDiveTemplates,
    'builtin-predive-bwraf',
  );

  late MockSettingsNotifier settings;

  setUp(() => settings = MockSettingsNotifier());

  Future<void> pump(WidgetTester tester) async {
    await tester.pumpWidget(
      testApp(
        locale: const Locale('en'),
        overrides: [
          preDiveTemplatesProvider.overrideWith((ref) async => templates),
          settingsProvider.overrideWith((ref) => settings),
        ],
        child: const PreDiveTemplatesPage(),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('the Show label sits over the built-in row switch', (
    tester,
  ) async {
    await pump(tester);
    final label = find.text('Show');
    expect(label, findsOneWidget);
    expect(find.byKey(bwrafKey), findsOneWidget);
    expect(
      tester.getCenter(label).dx,
      moreOrLessEquals(tester.getCenter(find.byKey(bwrafKey)).dx, epsilon: 0.5),
    );
    expect(
      find.byKey(
        builtInShowSwitchKey(BuiltInCatalog.preDiveTemplates, 'custom-1'),
      ),
      findsNothing,
    );
  });

  testWidgets('switching a built-in off hides it and dims its row', (
    tester,
  ) async {
    await pump(tester);
    await tester.tap(find.byKey(bwrafKey));
    await tester.pumpAndSettle();
    expect(settings.state.hiddenBuiltIns(BuiltInCatalog.preDiveTemplates), {
      'builtin-predive-bwraf',
    });
    final tile = tester.widget<ListTile>(
      find.ancestor(of: find.byKey(bwrafKey), matching: find.byType(ListTile)),
    );
    final context = tester.element(find.byKey(bwrafKey));
    expect(tile.textColor, Theme.of(context).disabledColor);
  });

  testWidgets(
    'the Show label lines up on desktop too',
    variant: const TargetPlatformVariant({
      TargetPlatform.macOS,
      TargetPlatform.windows,
      TargetPlatform.linux,
    }),
    (tester) async {
      await pump(tester);
      expect(
        tester.getCenter(find.text('Show')).dx,
        moreOrLessEquals(
          tester.getCenter(find.byKey(bwrafKey)).dx,
          epsilon: 0.5,
        ),
      );
    },
  );
}
