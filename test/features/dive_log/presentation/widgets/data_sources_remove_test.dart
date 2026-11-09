import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/dive_log/domain/entities/dive_data_source.dart';
import 'package:submersion/features/dive_log/presentation/widgets/data_sources_section.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

import '../../../../helpers/test_app.dart';

const _units = UnitFormatter(AppSettings());

DiveDataSource _source(String id, {required bool isPrimary}) {
  final now = DateTime(2026, 3, 20, 10, 0);
  return DiveDataSource(
    id: id,
    diveId: 'dive-1',
    computerId: 'comp-$id',
    isPrimary: isPrimary,
    computerModel: 'Perdix $id',
    maxDepth: 30.0,
    duration: 3000,
    entryTime: now,
    exitTime: now.add(const Duration(minutes: 50)),
    importedAt: now,
    createdAt: now,
  );
}

Widget _section(
  List<DiveDataSource> sources, {
  void Function(String id)? onRemove,
}) => testApp(
  child: SingleChildScrollView(
    child: DataSourcesSection(
      dataSources: sources,
      diveCreatedAt: DateTime(2026, 3, 20, 10, 0),
      diveId: 'dive-1',
      units: _units,
      onSetPrimary: (_) {},
      onRemove: onRemove,
    ),
  ),
);

/// Remove source on the dive's Data Sources section (issue #4393).
void main() {
  testWidgets('Remove source is offered for each source when there are two', (
    tester,
  ) async {
    String? removed;
    await tester.pumpWidget(
      _section([
        _source('a', isPrimary: true),
        _source('b', isPrimary: false),
      ], onRemove: (id) => removed = id),
    );
    await tester.pumpAndSettle();

    final menus = find.byIcon(Icons.more_vert);
    expect(menus, findsNWidgets(2));
    await tester.tap(menus.first);
    await tester.pumpAndSettle();
    expect(find.text('Remove source'), findsOneWidget);

    await tester.tap(find.text('Remove source'));
    await tester.pumpAndSettle();
    expect(removed, 'a');
  });

  testWidgets('Remove source is not offered for a lone source', (tester) async {
    await tester.pumpWidget(
      _section([_source('a', isPrimary: true)], onRemove: (_) {}),
    );
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.more_vert), findsNothing);
    expect(find.text('Remove source'), findsNothing);
  });
}
