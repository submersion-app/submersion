import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/settings/presentation/conflicts/conflict_comparison.dart';
import 'package:submersion/features/settings/presentation/conflicts/conflict_device_labels.dart';
import 'package:submersion/features/settings/presentation/conflicts/conflict_field.dart';
import 'package:submersion/features/settings/presentation/conflicts/widgets/conflict_comparison_view.dart';
import 'package:submersion/features/settings/presentation/conflicts/widgets/conflict_difference_list.dart';
import 'package:submersion/features/settings/presentation/conflicts/widgets/conflict_text_diff.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

const _devices = ConflictDeviceLabels(local: 'Pixel 8', remote: 'Windows PC');

FieldDifference _diff(
  String key,
  Object local,
  Object remote, {
  FieldKind kind = FieldKind.shortText,
}) => FieldDifference(
  key: key,
  label: key,
  kind: kind,
  localValue: local,
  remoteValue: remote,
  localDisplay: '$local',
  remoteDisplay: '$remote',
);

Future<void> _pump(
  WidgetTester tester,
  ConflictComparison c, {
  double width = 700,
}) async {
  await tester.binding.setSurfaceSize(Size(width, 1200));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    MaterialApp(
      locale: const Locale('en'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: SingleChildScrollView(
          child: ConflictComparisonView(
            comparison: c,
            devices: _devices,
            localModified: '2 hours ago',
            remoteModified: '5 hours ago',
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  final differing = ConflictComparison(
    state: ConflictComparisonState.differing,
    differences: [_diff('Water temp', '26 C', '27 C')],
    unchanged: const [
      ShownField(key: 'name', label: 'Name', display: 'Blue Hole'),
      ShownField(key: 'maxDepth', label: 'Max depth', display: '31.4m'),
    ],
  );

  testWidgets('says which device changed it when', (tester) async {
    await _pump(tester, differing);
    expect(find.textContaining('Pixel 8'), findsWidgets);
    expect(find.textContaining('2 hours ago'), findsOneWidget);
    expect(find.textContaining('5 hours ago'), findsOneWidget);
  });

  testWidgets('wide layout shows a table with device headers', (tester) async {
    await _pump(tester, differing);
    expect(find.text('What differs (1)'), findsOneWidget);
    expect(find.byType(Table), findsOneWidget);
    expect(find.text('Pixel 8'), findsOneWidget);
    expect(find.text('Windows PC'), findsOneWidget);
    expect(find.text('26 C'), findsOneWidget);
    expect(find.text('27 C'), findsOneWidget);
  });

  testWidgets('narrow layout stacks each field', (tester) async {
    await _pump(tester, differing, width: 360);
    expect(find.byType(Table), findsNothing);
    expect(find.text('26 C'), findsOneWidget);
    expect(find.text('27 C'), findsOneWidget);
  });

  testWidgets('unchanged fields are collapsed until expanded', (tester) async {
    await _pump(tester, differing);
    expect(find.text('2 fields are the same'), findsOneWidget);
    expect(find.text('Blue Hole'), findsNothing);
    await tester.tap(find.text('2 fields are the same'));
    await tester.pumpAndSettle();
    expect(find.text('Blue Hole'), findsOneWidget);
  });

  testWidgets('long text is highlighted word by word', (tester) async {
    await _pump(
      tester,
      ConflictComparison(
        state: ConflictComparisonState.differing,
        differences: [
          _diff(
            'Notes',
            'Saw a turtle.',
            'Saw two turtles.',
            kind: FieldKind.longText,
          ),
        ],
      ),
    );
    expect(find.byType(ConflictTextDiff), findsNWidgets(2));
    expect(
      find.text('Highlighted words appear only in that version.'),
      findsOneWidget,
    );
  });

  testWidgets('whitespace-only text differences say so', (tester) async {
    await _pump(
      tester,
      ConflictComparison(
        state: ConflictComparisonState.differing,
        differences: [
          _diff('Notes', 'One two', 'One  two', kind: FieldKind.longText),
        ],
      ),
    );
    expect(find.text('Only spacing or line breaks differ.'), findsOneWidget);
  });

  testWidgets('a difference too fine to display says so', (tester) async {
    // 30.04 m and 30.0 m both round to 30.0m; without the note the diver sees
    // a listed difference with the same value on both sides.
    await _pump(
      tester,
      const ConflictComparison(
        state: ConflictComparisonState.differing,
        differences: [
          FieldDifference(
            key: 'maxDepth',
            label: 'Max depth',
            kind: FieldKind.depth,
            localValue: 30.04,
            remoteValue: 30.0,
            localDisplay: '30.0m',
            remoteDisplay: '30.0m',
          ),
        ],
      ),
    );
    expect(
      find.text('The difference is finer than this display shows.'),
      findsOneWidget,
    );
  });

  testWidgets('a short text differing only in spacing says so', (tester) async {
    await _pump(
      tester,
      ConflictComparison(
        state: ConflictComparisonState.differing,
        differences: [_diff('Name', 'Blue Hole', 'Blue Hole ')],
      ),
    );
    expect(find.text('Only spacing or line breaks differ.'), findsOneWidget);
  });

  testWidgets('a long device name wraps in the narrow layout', (tester) async {
    await tester.binding.setSurfaceSize(const Size(360, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: ConflictDifferenceList(
            differences: [_diff('Water temp', '26 C', '27 C')],
            devices: const ConflictDeviceLabels(
              local: "Eric's MacBook Pro (Work, 16-inch, 2023) in the office",
              remote: 'Windows PC',
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text('26 C'), findsOneWidget);
  });

  testWidgets('a remote deletion is a banner over the local values', (
    tester,
  ) async {
    await _pump(
      tester,
      const ConflictComparison(
        state: ConflictComparisonState.remoteDeleted,
        survivingValues: [
          ShownField(key: 'name', label: 'Name', display: 'Blue Hole'),
        ],
      ),
    );
    expect(find.text('Windows PC deleted this record.'), findsOneWidget);
    expect(find.text('Blue Hole'), findsOneWidget);
    expect(find.textContaining('What differs'), findsNothing);
  });

  testWidgets('a local deletion names this device', (tester) async {
    await _pump(
      tester,
      const ConflictComparison(state: ConflictComparisonState.localDeleted),
    );
    expect(find.text('Pixel 8 deleted this record.'), findsOneWidget);
  });

  testWidgets('same content says nothing is lost', (tester) async {
    await _pump(
      tester,
      const ConflictComparison(state: ConflictComparisonState.sameContent),
    );
    expect(
      find.textContaining('Either choice keeps everything'),
      findsOneWidget,
    );
  });
}
