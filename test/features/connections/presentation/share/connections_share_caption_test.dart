import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/connections/domain/entities/connection_graph.dart';
import 'package:submersion/features/connections/domain/entities/connection_kind.dart';
import 'package:submersion/features/connections/domain/entities/connection_node.dart';
import 'package:submersion/features/connections/domain/entities/node_ref.dart';
import 'package:submersion/features/connections/domain/views/connection_presets.dart';
import 'package:submersion/features/connections/domain/views/connections_view_state.dart';
import 'package:submersion/features/connections/presentation/share/connections_share_caption.dart';
import 'package:submersion/features/dive_log/domain/models/dive_filter_state.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/arb/app_localizations_en.dart';

void main() {
  final l10n = AppLocalizationsEn();
  const units = UnitFormatter(AppSettings());
  const ana = NodeRef(ConnectionKind.buddy, 'ana');
  const graph = ConnectionGraph(
    nodes: [ConnectionNode(ref: ana, label: 'Ana', diveCount: 3)],
    edges: [],
  );

  ConnectionsShareCaption caption(
    ConnectionsViewState view, {
    DiveFilterState filter = const DiveFilterState(),
    Map<String, String> saved = const {},
    ({int first, int last})? span = (first: 2009, last: 2026),
  }) => ConnectionsShareCaption.of(
    l10n: l10n,
    units: units,
    view: view,
    graph: graph,
    filter: filter,
    span: span,
    savedMapNames: saved,
  );

  test('a preset map is named by its preset, over all dives', () {
    final c = caption(ConnectionsViewState.initial);
    expect(c.title, 'Dive circle');
    expect(c.details, 'All dives, 2009 to 2026. 1 nodes and 0 connections');
  });

  test('around mode names the centre', () {
    final c = caption(ConnectionsViewState.initial.centreOn(ana));
    expect(c.title, 'Around Ana');
  });

  test('a saved map uses its name, a custom map says so', () {
    final spec = ConnectionPresets.byId('where')!.spec;
    expect(
      caption(
        ConnectionsViewState.initial.applySavedMap('m1', spec),
        saved: {'m1': 'Bonaire crew'},
      ).title,
      'Bonaire crew',
    );
    expect(
      caption(ConnectionsViewState.initial.showMap(spec)).title,
      'Custom map',
    );
  });

  test('a date filter shows its range through the unit formatter', () {
    final filter = DiveFilterState(
      startDate: DateTime(2014, 1, 1),
      endDate: DateTime(2019, 12, 31),
    );
    final c = caption(ConnectionsViewState.initial, filter: filter);
    final range = units.formatDateRange(
      filter.startDate,
      filter.endDate,
      l10n: l10n,
    );
    expect(c.details, '$range. 1 nodes and 0 connections');
  });

  test('with no dives the details are the counts alone', () {
    expect(
      caption(ConnectionsViewState.initial, span: null).details,
      '1 nodes and 0 connections',
    );
  });
}
