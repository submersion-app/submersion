import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/connections/domain/entities/connection_kind.dart';
import 'package:submersion/features/connections/domain/entities/node_ref.dart';
import 'package:submersion/features/connections/domain/views/connection_presets.dart';
import 'package:submersion/features/connections/domain/views/connections_view_state.dart';
import 'package:submersion/features/connections/domain/views/kind_link.dart';

const _jane = NodeRef(ConnectionKind.buddy, 'jane');

void main() {
  test('initial is the Dive circle preset in map mode', () {
    final s = ConnectionsViewState.initial;
    expect(s.mode, ConnectionsMode.map);
    expect(s.presetId, 'circle');
    expect(s.mapSpec, ConnectionPresets.byId('circle')!.spec);
    expect(s.aroundKinds, kDefaultAroundKinds);
    expect(s.hops, 1);
    expect(s.focus, isNull);
  });

  test('default around kinds are the six common ones', () {
    expect(kDefaultAroundKinds, {
      ConnectionKind.buddy,
      ConnectionKind.site,
      ConnectionKind.trip,
      ConnectionKind.species,
      ConnectionKind.equipment,
      ConnectionKind.diveCenter,
    });
  });

  test('editing a preset clears it and remembers where it came from', () {
    final edited = ConnectionsViewState.initial
        .applyPreset(ConnectionPresets.byId('travel')!)
        .editMap(
          ConnectionPresets.byId('travel')!.spec.toggleLink(
            KindLink(ConnectionKind.buddy, ConnectionKind.site),
          ),
        );
    expect(edited.presetId, isNull);
    expect(edited.editedFromPresetId, 'travel');
    final again = edited.applyPreset(ConnectionPresets.byId('reef')!);
    expect(again.presetId, 'reef');
    expect(again.editedFromPresetId, isNull);
  });

  test('applying a saved map selects it and clears preset marks', () {
    final s = ConnectionsViewState.initial.applySavedMap(
      'm1',
      ConnectionPresets.byId('where')!.spec,
    );
    expect(s.savedMapId, 'm1');
    expect(s.presetId, isNull);
    expect(s.editedFromPresetId, isNull);
    expect(s.mode, ConnectionsMode.map);
  });

  test('centreOn switches to around mode', () {
    final s = ConnectionsViewState.initial.centreOn(_jane);
    expect(s.mode, ConnectionsMode.around);
    expect(s.focus, _jane);
    expect(s.isAroundWithoutFocus, isFalse);
    expect(
      ConnectionsViewState.initial
          .withMode(ConnectionsMode.around)
          .isAroundWithoutFocus,
      isTrue,
    );
  });

  test('hops clamp to 1..3', () {
    expect(ConnectionsViewState.initial.withHops(0).hops, 1);
    expect(ConnectionsViewState.initial.withHops(3).hops, 3);
    expect(ConnectionsViewState.initial.withHops(7).hops, 3);
  });

  test('JSON round-trips; garbage parses to null', () {
    final s = ConnectionsViewState.initial
        .centreOn(_jane)
        .withHops(2)
        .withAroundKinds({ConnectionKind.buddy, ConnectionKind.tag});
    expect(ConnectionsViewState.fromJson(s.toJson()), s);
    expect(ConnectionsViewState.fromJson('nope'), isNull);
    expect(ConnectionsViewState.fromJson({'mode': 'sideways'}), isNull);
  });

  test('legacy lens values migrate', () {
    expect(ConnectionsViewState.fromLegacyLens('where').presetId, 'where');
    final custom = ConnectionsViewState.fromLegacyLens('custom:equipment:trip');
    expect(custom.presetId, isNull);
    expect(custom.mapSpec.kinds, {
      ConnectionKind.equipment,
      ConnectionKind.trip,
    });
    expect(custom.mapSpec.links, {
      KindLink(ConnectionKind.equipment, ConnectionKind.trip),
    });
    expect(
      ConnectionsViewState.fromLegacyLens(
        'custom:equipment:equipment',
      ).mapSpec.links,
      {KindLink(ConnectionKind.equipment, ConnectionKind.equipment)},
    );
    expect(
      ConnectionsViewState.fromLegacyLens(null),
      ConnectionsViewState.initial,
    );
    expect(
      ConnectionsViewState.fromLegacyLens('x:y'),
      ConnectionsViewState.initial,
    );
  });

  test('an empty set of Around kinds survives a round trip', () {
    final s = ConnectionsViewState.initial.withAroundKinds({});
    expect(ConnectionsViewState.fromJson(s.toJson())!.aroundKinds, isEmpty);
    final legacy = s.toJson()..remove('aroundKinds');
    expect(
      ConnectionsViewState.fromJson(legacy)!.aroundKinds,
      kDefaultAroundKinds,
      reason: 'a view stored before the field existed gets the defaults',
    );
  });

  group('withSavedMaps', () {
    final a = ConnectionPresets.byId('travel')!.spec;
    final b = ConnectionPresets.byId('reef')!.spec;
    final onSaved = ConnectionsViewState.initial.applySavedMap('bon', a);

    test('follows an edit made elsewhere to the applied map', () {
      final next = onSaved.withSavedMaps({'bon': b});
      expect(next.mapSpec, b);
      expect(next.savedMapId, 'bon');
    });

    test('turns the view custom when the applied map is gone', () {
      final next = onSaved.withSavedMaps(const {});
      expect(next.savedMapId, isNull);
      expect(next.presetId, isNull);
      expect(next.mapSpec, a, reason: 'what is on screen stays');
    });

    test('leaves a view on a preset or an unchanged map alone', () {
      expect(
        identical(
          ConnectionsViewState.initial.withSavedMaps(const {}),
          ConnectionsViewState.initial,
        ),
        isTrue,
      );
      expect(identical(onSaved.withSavedMaps({'bon': a}), onSaved), isTrue);
    });
  });

  test(
    'withHopsParam applies a readable hops parameter and ignores the rest',
    () {
      final base = ConnectionsViewState.initial;
      expect(base.withHopsParam('2').hops, 2);
      expect(base.withHopsParam('9').hops, 3, reason: 'clamped like withHops');
      expect(identical(base.withHopsParam('many'), base), isTrue);
      expect(identical(base.withHopsParam(null), base), isTrue);
    },
  );
}
