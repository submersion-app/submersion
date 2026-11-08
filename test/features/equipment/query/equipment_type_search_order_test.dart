import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/query/domain/query_subject.dart';
import 'package:submersion/core/query/presentation/query_value_editor.dart';
import 'package:submersion/features/equipment/presentation/utils/equipment_enum_display.dart';
import 'package:submersion/features/query/app_query_registry.dart';
import 'package:submersion/features/query/presentation/app_query_labels.dart';
import 'package:submersion/l10n/l10n_extension.dart';

import '../../../helpers/test_app.dart';

/// The equipment search lists types in the order the Add Equipment page
/// does (#4244): by localized label, not by when each type was added.
void main() {
  final typeField = appQueryRegistry
      .entityFor(QuerySubject.equipment)
      .field('type')!;

  for (final tag in ['en', 'fr', 'de']) {
    testWidgets('search type order matches the edit page in $tag', (
      tester,
    ) async {
      late List<String> searchOrder;
      late List<String> editOrder;
      await tester.pumpWidget(
        testApp(
          locale: Locale(tag),
          child: Builder(
            builder: (context) {
              searchOrder = enumOptions(typeField, AppQueryLabels(context));
              editOrder = [
                for (final t in EquipmentType.values.sortedByLocalizedName(
                  context.l10n,
                ))
                  t.name,
              ];
              return const SizedBox();
            },
          ),
        ),
      );
      expect(searchOrder, editOrder);
      // Guards the comparison: declaration order is not label order.
      expect(
        searchOrder,
        isNot([for (final t in EquipmentType.values) t.name]),
      );
    });
  }
}
