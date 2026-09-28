import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/query/domain/query_node.dart';
import 'package:submersion/core/query/units/unit_prefs.dart';
import 'package:submersion/features/dive_sites/query/site_query_entity.dart';
import 'package:submersion/features/query/data/query_name_index.dart';
import 'package:submersion/features/query/presentation/dive_query_chips.dart';
import 'package:submersion/features/query/presentation/dive_query_editor.dart';
import 'package:submersion/features/query/presentation/providers/query_name_index_provider.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

import '../../../helpers/mock_providers.dart';
import '../../../helpers/test_app.dart';

/// One editor for any entity (#2365 PR 3): the root decides the fields.
void main() {
  testWidgets('parses against the entity it is given', (tester) async {
    QueryNode? value;
    await tester.pumpWidget(
      testApp(
        locale: const Locale('en'),
        overrides: [
          settingsProvider.overrideWith((ref) => MockSettingsNotifier()),
          queryNameIndexProvider.overrideWith(
            (ref) async => QueryNameIndex.empty,
          ),
        ],
        child: SingleChildScrollView(
          child: EntityQueryEditor(
            root: siteQueryEntity,
            value: null,
            onChanged: (n) => value = n,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byType(TextField).first,
      'difficulty = advanced',
    );
    await tester.pump();
    expect(
      value,
      ConditionNode(
        FieldPath(['difficulty']),
        QueryOp.eq,
        const EnumValue('advanced'),
      ),
    );

    // A dive field is not a site field: the text fails and nothing commits.
    await tester.enterText(find.byType(TextField).first, 'weights:none');
    await tester.pump();
    expect(find.textContaining('weights'), findsWidgets);
    expect(value, isA<ConditionNode>());
  });

  test('chip labels print against the entity they are given', () {
    final labels = entityQueryChipLabels(
      siteQueryEntity,
      AndNode([
        ConditionNode(
          FieldPath(['difficulty']),
          QueryOp.eq,
          const EnumValue('advanced'),
        ),
        ConditionNode(FieldPath(['coordinates']), QueryOp.isSet, null),
      ]),
      kMetricPrefs,
    );
    expect(labels, ['difficulty = advanced', 'coordinates:any']);
  });
}
