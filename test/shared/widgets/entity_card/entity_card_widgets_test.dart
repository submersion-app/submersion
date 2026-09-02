import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';
import 'package:submersion/shared/constants/entity_field.dart';
import 'package:submersion/shared/models/entity_card_view_config.dart';
import 'package:submersion/shared/widgets/entity_card/card_slot_resolver.dart';
import 'package:submersion/shared/widgets/entity_card/entity_card_extra_fields.dart';
import 'package:submersion/shared/widgets/entity_card/entity_card_stat.dart';

import '../../../helpers/test_app.dart';

typedef _Entity = ({String name, double? depth, String notes});

enum _Field implements EntityField {
  title,
  depth,
  notes;

  @override
  String get name => toString().split('.').last;
  @override
  String get displayName => name;
  @override
  String get shortLabel => switch (this) {
    _Field.title => 'Name',
    _Field.depth => 'Depth',
    _Field.notes => 'Notes',
  };
  @override
  IconData? get icon => this == _Field.depth ? Icons.water : null;
  @override
  double get defaultWidth => 100;
  @override
  double get minWidth => 50;
  @override
  bool get sortable => false;
  @override
  String get categoryName => 'test';
  @override
  String localizedDisplayName(AppLocalizations l10n) => shortLabel;
  @override
  String localizedShortLabel(AppLocalizations l10n) => shortLabel;
  @override
  bool get isRightAligned => false;
}

class _Adapter extends EntityFieldAdapter<_Entity, _Field> {
  @override
  List<_Field> get allFields => _Field.values;
  @override
  Map<String, List<_Field>> get fieldsByCategory => {'test': _Field.values};
  @override
  dynamic extractValue(_Field field, _Entity entity) => switch (field) {
    _Field.title => entity.name,
    _Field.depth => entity.depth,
    _Field.notes => entity.notes,
  };
  @override
  String formatValue(_Field field, dynamic value, UnitFormatter units) =>
      switch (field) {
        _Field.title => value as String,
        _Field.depth => units.formatDepth(value as double, decimals: 0),
        // Mirrors BuddyFieldAdapter: a non-null but empty String formats to
        // the placeholder, which a table cell wants and a card must not show.
        _Field.notes => (value as String).isEmpty ? '--' : value,
      };
  @override
  _Field fieldFromName(String name) =>
      _Field.values.firstWhere((f) => f.name == name);
}

void main() {
  const units = UnitFormatter(AppSettings());
  final adapter = _Adapter();

  group('resolveCardSlot', () {
    test('returns the configured field or the fallback', () {
      const slots = [
        EntityCardSlotConfig(slotId: 'stat1', field: _Field.depth),
      ];
      expect(resolveCardSlot(slots, 'stat1', _Field.title), _Field.depth);
      expect(resolveCardSlot(slots, 'stat2', _Field.title), _Field.title);
    });
  });

  group('EntityCardStat', () {
    testWidgets('renders icon and formatted value', (tester) async {
      await tester.pumpWidget(
        testApp(
          child: EntityCardStat<_Entity, _Field>(
            adapter: adapter,
            entity: (name: 'Reef', depth: 18.0, notes: 'Nice'),
            field: _Field.depth,
            units: units,
            color: Colors.black,
          ),
        ),
      );

      expect(find.byIcon(Icons.water), findsOneWidget);
      expect(find.text('18m'), findsOneWidget);
    });

    testWidgets('renders nothing for a null value', (tester) async {
      await tester.pumpWidget(
        testApp(
          child: EntityCardStat<_Entity, _Field>(
            adapter: adapter,
            entity: (name: 'Reef', depth: null, notes: 'Nice'),
            field: _Field.depth,
            units: units,
            color: Colors.black,
          ),
        ),
      );

      expect(find.byIcon(Icons.water), findsNothing);
      expect(find.byType(Text), findsNothing);
    });

    testWidgets('renders nothing when the value formats to a placeholder', (
      tester,
    ) async {
      await tester.pumpWidget(
        testApp(
          child: EntityCardStat<_Entity, _Field>(
            adapter: adapter,
            entity: (name: 'Reef', depth: 18.0, notes: ''),
            field: _Field.notes,
            units: units,
            color: Colors.black,
          ),
        ),
      );

      expect(find.text('--'), findsNothing);
      expect(find.byType(Text), findsNothing);
    });

    testWidgets('renders nothing when the value formats to an empty string', (
      tester,
    ) async {
      await tester.pumpWidget(
        testApp(
          child: EntityCardStat<_Entity, _Field>(
            adapter: adapter,
            entity: (name: '', depth: 18.0, notes: 'Nice'),
            field: _Field.title,
            units: units,
            color: Colors.black,
          ),
        ),
      );

      expect(find.byType(Text), findsNothing);
    });

    testWidgets('a formatter override replaces the adapter formatting', (
      tester,
    ) async {
      await tester.pumpWidget(
        testApp(
          child: EntityCardStat<_Entity, _Field>(
            adapter: adapter,
            entity: (name: 'Reef', depth: 18.0, notes: 'Nice'),
            field: _Field.depth,
            units: units,
            color: Colors.black,
            formatter: (field, value) => 'deep',
          ),
        ),
      );

      expect(find.text('deep'), findsOneWidget);
    });
  });

  group('EntityCardExtraFields', () {
    testWidgets('renders label: value pairs and skips nulls', (tester) async {
      await tester.pumpWidget(
        testApp(
          child: EntityCardExtraFields<_Entity, _Field>(
            adapter: adapter,
            entity: (name: 'Reef', depth: null, notes: 'Nice'),
            fields: const [_Field.title, _Field.depth],
            units: units,
            labelColor: Colors.grey,
            valueColor: Colors.black,
          ),
        ),
      );

      expect(find.text('Name: '), findsOneWidget);
      expect(find.text('Reef'), findsOneWidget);
      expect(find.text('Depth: '), findsNothing);
    });

    testWidgets('skips a field whose value formats to a placeholder', (
      tester,
    ) async {
      await tester.pumpWidget(
        testApp(
          child: EntityCardExtraFields<_Entity, _Field>(
            adapter: adapter,
            entity: (name: 'Reef', depth: 18.0, notes: ''),
            fields: const [_Field.title, _Field.notes],
            units: units,
            labelColor: Colors.grey,
            valueColor: Colors.black,
          ),
        ),
      );

      expect(find.text('Name: '), findsOneWidget);
      expect(find.text('Notes: '), findsNothing);
      expect(find.text('--'), findsNothing);
    });

    testWidgets('skips a field whose value formats to an empty string', (
      tester,
    ) async {
      await tester.pumpWidget(
        testApp(
          child: EntityCardExtraFields<_Entity, _Field>(
            adapter: adapter,
            entity: (name: '', depth: 18.0, notes: 'Nice'),
            fields: const [_Field.title, _Field.notes],
            units: units,
            labelColor: Colors.grey,
            valueColor: Colors.black,
          ),
        ),
      );

      expect(find.text('Name: '), findsNothing);
      expect(find.text('Notes: '), findsOneWidget);
    });

    testWidgets('renders nothing when every field is blank', (tester) async {
      await tester.pumpWidget(
        testApp(
          child: EntityCardExtraFields<_Entity, _Field>(
            adapter: adapter,
            entity: (name: '', depth: null, notes: ''),
            fields: const [_Field.title, _Field.depth, _Field.notes],
            units: units,
            labelColor: Colors.grey,
            valueColor: Colors.black,
          ),
        ),
      );

      expect(find.byType(Text), findsNothing);
      expect(find.byType(Wrap), findsNothing);
    });
  });
}
