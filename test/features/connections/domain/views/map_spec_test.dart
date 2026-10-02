import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/connections/domain/entities/connection_kind.dart';
import 'package:submersion/features/connections/domain/views/connection_presets.dart';
import 'package:submersion/features/connections/domain/views/kind_link.dart';
import 'package:submersion/features/connections/domain/views/map_spec.dart';

const _b = ConnectionKind.buddy;
const _s = ConnectionKind.site;
const _sp = ConnectionKind.species;
const _t = ConnectionKind.trip;

void main() {
  group('KindLink', () {
    test('is unordered and canonical', () {
      expect(KindLink(_s, _b), KindLink(_b, _s));
      expect(KindLink(_s, _b).a, _b);
      expect(KindLink(_s, _b).wire, 'buddy-site');
      expect(KindLink.parse('site-buddy'), KindLink(_b, _s));
      expect(KindLink.parse('buddy-unicorn'), isNull);
      expect(KindLink.parse(null), isNull);
      expect(KindLink(_b, _b).isSameKind, isTrue);
      expect(KindLink(_b, _s).touches(_s), isTrue);
      expect(KindLink(_b, _s).touches(_t), isFalse);
    });
  });

  group('MapSpec', () {
    test('ticking a kind links it to the kinds already on, not to itself', () {
      final spec = MapSpec.of({_b, _s}, {KindLink(_b, _s)}).withKind(_sp);
      expect(spec.kinds, {_b, _s, _sp});
      expect(spec.links, {
        KindLink(_b, _s),
        KindLink(_b, _sp),
        KindLink(_s, _sp),
      });
    });

    test('the first kind ticked gets no links', () {
      final spec = MapSpec.of(const {}, const {}).withKind(_b);
      expect(spec.kinds, {_b});
      expect(spec.links, isEmpty);
    });

    test('unticking a kind drops every link that touches it', () {
      final spec = MapSpec.of(
        {_b, _s, _sp},
        {KindLink(_b, _s), KindLink(_s, _sp), KindLink(_sp, _sp)},
      ).withoutKind(_sp);
      expect(spec.kinds, {_b, _s});
      expect(spec.links, {KindLink(_b, _s)});
    });

    test('toggleLink adds and removes, ignoring kinds that are off', () {
      final spec = MapSpec.of({_b, _s}, const {});
      final on = spec.toggleLink(KindLink(_b, _b));
      expect(on.links, {KindLink(_b, _b)});
      expect(on.toggleLink(KindLink(_b, _b)).links, isEmpty);
      expect(identical(spec.toggleLink(KindLink(_b, _t)), spec), isTrue);
    });

    test('withMinimum clamps to 1..10', () {
      final spec = MapSpec.of({_b}, const {});
      expect(spec.withMinimum(0).minSharedDives, 1);
      expect(spec.withMinimum(4).minSharedDives, 4);
      expect(spec.withMinimum(99).minSharedDives, 10);
    });

    test('possibleLinks lists every pair including same-kind, stably', () {
      final spec = MapSpec.of({_s, _b}, const {});
      expect(spec.possibleLinks, [
        KindLink(_b, _b),
        KindLink(_b, _s),
        KindLink(_s, _s),
      ]);
    });

    test('JSON round-trips and rejects unknown kinds', () {
      final spec = MapSpec.of({_b, _s}, {KindLink(_b, _s)}).withMinimum(3);
      expect(MapSpec.fromJson(spec.toJson()), spec);
      expect(
        MapSpec.fromJson({
          'kinds': ['buddy', 'unicorn'],
          'links': <String>[],
          'min': 1,
        }),
        isNull,
      );
      expect(MapSpec.fromJson('garbage'), isNull);
      expect(MapSpec.fromJson(null), isNull);
    });

    test('a link whose kinds are not on is dropped on construction', () {
      final spec = MapSpec(kinds: {_b}, links: {KindLink(_b, _s)});
      expect(spec.links, isEmpty);
    });
  });

  group('presets', () {
    test('nine presets in table order with the table kinds and links', () {
      expect(ConnectionPresets.all.map((p) => p.id), [
        'circle',
        'where',
        'trips',
        'life',
        'gear',
        'centers',
        'travel',
        'reef',
        'gearRoad',
      ]);
      final reef = ConnectionPresets.byId('reef')!;
      expect(reef.spec.kinds, {_s, _sp, ConnectionKind.diveType});
      expect(reef.spec.links, {
        KindLink(_s, _sp),
        KindLink(_sp, ConnectionKind.diveType),
        KindLink(_s, ConnectionKind.diveType),
      });
      expect(ConnectionPresets.byId('circle')!.spec.links, {KindLink(_b, _b)});
      expect(ConnectionPresets.byId('nope'), isNull);
      for (final p in ConnectionPresets.all) {
        expect(p.spec.minSharedDives, 1);
      }
    });
  });
}
