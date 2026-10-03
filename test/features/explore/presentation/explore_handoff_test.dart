import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/query/domain/query_node.dart';
import 'package:submersion/features/explore/presentation/explore_handoff.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/buddies/presentation/providers/buddy_query_providers.dart';
import 'package:submersion/features/dive_centers/presentation/providers/dive_center_query_providers.dart';
import 'package:submersion/features/dive_sites/presentation/providers/site_providers.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_providers.dart';
import 'package:submersion/features/explore/domain/query_model.dart';
import 'package:submersion/features/marine_life/presentation/providers/species_query_providers.dart';
import 'package:submersion/features/trips/presentation/providers/trip_providers.dart';

/// Explore's equipment answer goes through the equipment list's filter,
/// whose unset status hides retired and sold gear. A status the sentence
/// names must become that axis, or "my retired regulators" finds nothing.
void main() {
  ConditionNode status(String name) => ConditionNode(
    FieldPath(const ['status']),
    QueryOp.inList,
    ListValue([EnumValue(name)]),
  );
  final regulators = ConditionNode(
    FieldPath(const ['type']),
    QueryOp.inList,
    ListValue(const [EnumValue('regulator')]),
  );

  test('a named status becomes the status axis', () {
    final f = exploreEquipmentFilter(status('retired'));
    expect(f.status, EquipmentStatus.retired);
    expect(f.query, isNull);
  });

  test('beside other conditions it is lifted out of them', () {
    final f = exploreEquipmentFilter(AndNode([regulators, status('sold')]));
    expect(f.status, EquipmentStatus.sold);
    expect(f.query, regulators);
  });

  test('two other conditions stay joined once the status is lifted', () {
    final named = ConditionNode(
      FieldPath(const ['name']),
      QueryOp.contains,
      const StringValue('apeks'),
    );
    final f = exploreEquipmentFilter(
      AndNode([regulators, status('retired'), named]),
    );
    expect(f.status, EquipmentStatus.retired);
    expect(f.query, AndNode([regulators, named]));
  });

  test('no status keeps the default view and the whole query', () {
    final f = exploreEquipmentFilter(regulators);
    expect(f.status, isNull);
    expect(f.allStatuses, isFalse);
    expect(f.query, regulators);
  });

  test('no query keeps the default view', () {
    final f = exploreEquipmentFilter(null);
    expect(f.status, isNull);
    expect(f.allStatuses, isFalse);
    expect(f.query, isNull);
  });

  // The default view hides retired and sold gear (#636), so a status the
  // query decides on its own reads every status instead (#2590): otherwise
  // "retired or sold gear" found nothing and "gear that is not active" lost
  // its retired and sold items.
  test('a negated status stays in the query over every status', () {
    final not = NotNode(status('retired'));
    final f = exploreEquipmentFilter(not);
    expect(f.status, isNull);
    expect(f.allStatuses, isTrue);
    expect(f.query, not);
  });

  test('several statuses stay in the query over every status', () {
    final two = ConditionNode(
      FieldPath(const ['status']),
      QueryOp.inList,
      ListValue(const [EnumValue('retired'), EnumValue('sold')]),
    );
    final f = exploreEquipmentFilter(AndNode([regulators, two]));
    expect(f.status, isNull);
    expect(f.allStatuses, isTrue);
    expect(f.query, AndNode([regulators, two]));
  });

  // The default view also pins the legacy active flag, so a query on it
  // contradicts that view the same way.
  test('a query on the active flag reads every status', () {
    final inactive = ConditionNode(
      FieldPath(const ['active']),
      QueryOp.eq,
      const BoolValue(false),
    );
    final f = exploreEquipmentFilter(AndNode([regulators, inactive]));
    expect(f.status, isNull);
    expect(f.allStatuses, isTrue);
    expect(f.query, AndNode([regulators, inactive]));
  });

  // Free text and a scoped condition say nothing about the item's own
  // status (a scoped `status` would be another entity's), so they keep the
  // default view.
  test('free text or a scoped condition keeps the default view', () {
    final words = TextNode(const ['apeks']);
    final scoped = ScopedNode(
      FieldPath(const ['tags']),
      ConditionNode(
        FieldPath(const ['status']),
        QueryOp.eq,
        const StringValue('x'),
      ),
    );
    final f = exploreEquipmentFilter(AndNode([words, scoped]));
    expect(f.status, isNull);
    expect(f.allStatuses, isFalse);
    expect(f.query, AndNode([words, scoped]));
  });

  test('a status inside an Or reads every status', () {
    final either = OrNode([status('retired'), regulators]);
    final f = exploreEquipmentFilter(either);
    expect(f.status, isNull);
    expect(f.allStatuses, isTrue);
    expect(f.query, either);
  });

  group('writeSubjectHandoff', () {
    final refProbe = Provider<Ref>((ref) => ref);

    Ref refOf(ProviderContainer c) {
      final sub = c.listen(refProbe, (_, _) {});
      addTearDown(sub.close);
      return c.read(refProbe);
    }

    test('each subject writes its own list query and names its route', () {
      final c = ProviderContainer();
      addTearDown(c.dispose);
      final ref = refOf(c);
      final node = TextNode(['reef']);
      expect(writeSubjectHandoff(ref, ParsedSubject.sites, node), '/sites');
      expect(c.read(siteFilterProvider).query, node);
      expect(writeSubjectHandoff(ref, ParsedSubject.buddies, node), '/buddies');
      expect(c.read(buddyQueryProvider), node);
      expect(writeSubjectHandoff(ref, ParsedSubject.species, node), '/species');
      expect(c.read(seenSpeciesQueryProvider), node);
      expect(writeSubjectHandoff(ref, ParsedSubject.trips, node), '/trips');
      expect(c.read(tripFilterProvider).query, node);
      expect(
        writeSubjectHandoff(ref, ParsedSubject.centers, node),
        '/dive-centers',
      );
      expect(c.read(diveCenterQueryProvider), node);
      expect(
        writeSubjectHandoff(ref, ParsedSubject.equipment, node),
        '/equipment',
      );
      expect(
        c.read(equipmentFilterProvider).query,
        exploreEquipmentFilter(node).query,
      );
    });

    test('a dive sentence is not a subject handoff', () {
      final c = ProviderContainer();
      addTearDown(c.dispose);
      expect(
        () =>
            writeSubjectHandoff(refOf(c), ParsedSubject.dives, TextNode(['x'])),
        throwsStateError,
      );
    });
  });
}
