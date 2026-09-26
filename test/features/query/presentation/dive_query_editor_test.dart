import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/units.dart';
import 'package:submersion/core/query/domain/query_node.dart';
import 'package:submersion/core/query/domain/query_subject.dart';
import 'package:submersion/features/query/data/query_name_index.dart';
import 'package:submersion/features/query/presentation/dive_query_editor.dart';
import 'package:submersion/features/query/presentation/providers/query_name_index_provider.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/l10n_extension.dart';

import '../../../helpers/mock_providers.dart';
import '../../../helpers/test_app.dart';

void main() {
  testWidgets('parses in the diver units against the app registry and names', (
    tester,
  ) async {
    QueryNode? value;
    await tester.pumpWidget(
      testApp(
        locale: const Locale('en'),
        overrides: [
          settingsProvider.overrideWith(
            (ref) => MockSettingsNotifier(
              const AppSettings(depthUnit: DepthUnit.feet),
            ),
          ),
          queryNameIndexProvider.overrideWith(
            (ref) async => const QueryNameIndex({
              QuerySubject.sites: [RefValue('s1', 'Salt Pier')],
            }),
          ),
        ],
        child: SingleChildScrollView(
          child: DiveQueryEditor(value: null, onChanged: (n) => value = n),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byType(TextField).first,
      'depth > 100 site = "Salt Pier"',
    );
    await tester.pump();
    final and = value! as AndNode;
    expect(and.children, hasLength(2));
    final depth = and.children[0] as ConditionNode;
    expect(depth.path, FieldPath(['depth']));
    expect((depth.value! as NumberValue).value, closeTo(30.48, 0.001));
    expect(
      and.children[1],
      ConditionNode(
        FieldPath(['site']),
        QueryOp.eq,
        const RefValue('s1', 'Salt Pier'),
      ),
    );
    await tester.pumpWidget(
      testApp(
        locale: const Locale('en'),
        overrides: [
          settingsProvider.overrideWith(
            (ref) => MockSettingsNotifier(
              const AppSettings(depthUnit: DepthUnit.feet),
            ),
          ),
          queryNameIndexProvider.overrideWith(
            (ref) async => const QueryNameIndex({
              QuerySubject.sites: [RefValue('s1', 'Salt Pier')],
            }),
          ),
        ],
        child: SingleChildScrollView(
          child: DiveQueryEditor(value: value, onChanged: (n) => value = n),
        ),
      ),
    );
    await tester.tap(find.text('Builder'));
    await tester.pumpAndSettle();
    expect(find.text('Max depth'), findsOneWidget);
    expect(find.text('ft'), findsOneWidget);
  });

  testWidgets('a parse error shows in the diver language', (tester) async {
    await tester.pumpWidget(
      testApp(
        locale: const Locale('de'),
        overrides: [
          queryNameIndexProvider.overrideWith(
            (ref) async => QueryNameIndex.empty,
          ),
        ],
        child: SingleChildScrollView(
          child: DiveQueryEditor(value: null, onChanged: (_) {}),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, 'rating > 3m');
    await tester.pump();
    final l10n = l10nForLocaleTag('de');
    expect(find.text(l10n.query_error_noUnitAllowed('rating')), findsOneWidget);
  });
}
