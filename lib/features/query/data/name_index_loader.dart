import 'package:drift/drift.dart';

import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/query/domain/query_subject.dart';
import 'package:submersion/core/query/names/name_index.dart';
import 'package:submersion/features/equipment/domain/constants/equipment_attribute_catalog.dart';
import 'package:submersion/features/equipment/presentation/utils/equipment_attribute_l10n.dart';
import 'package:submersion/features/marine_life/presentation/species_name_lookup.dart';
import 'package:submersion/features/query/app_query_registry.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

/// Loads the one [NameIndex] Explore and the typed language share (#2365):
/// every visible row by its registry name, the alternate labels a sentence
/// may use, places and attribute choices. Legacy buddy names are Explore's
/// alone and load beside it, so a dive write never reloads this (#2641).
class NameIndexLoader {
  NameIndexLoader(this._db);

  final AppDatabase _db;

  /// The subjects a relation can point at by name.
  static const refSubjects = [
    QuerySubject.sites,
    QuerySubject.siteTypes,
    QuerySubject.trips,
    QuerySubject.centers,
    QuerySubject.computers,
    QuerySubject.courses,
    QuerySubject.buddies,
    QuerySubject.tags,
    QuerySubject.diveTypes,
    QuerySubject.equipment,
    QuerySubject.species,
    // A buddy's certification is a ref (`buddies.certifications`).
    QuerySubject.certifications,
  ];

  /// The columns read beside the name, for alternates and places.
  static const _extra = {
    QuerySubject.sites: ['country', 'region', 'island', 'city'],
    QuerySubject.species: ['scientific_name', 'is_built_in'],
    QuerySubject.equipment: ['brand', 'model'],
  };

  /// The place columns in rank order: country 0, region 1, island 2, city 3.
  static const _placeColumns = ['country', 'region', 'island', 'city'];

  /// The tables a change tick must follow: the ref tables, the share
  /// table that makes another diver's equipment visible, and the hides that
  /// take a shared trip or site out of one diver's view (#2594).
  static Set<String> get tables => {
    for (final s in refSubjects) appQueryRegistry.entityFor(s).table,
    'equipment_shares',
    'trip_hides',
    'site_hides',
    // Custom certification agencies and levels (issue #690).
    'custom_certification_agencies',
    'custom_certification_levels',
  };

  Future<NameIndex> load({
    String? diverId,
    required AppLocalizations l10n,
  }) async {
    // Independent reads: issue them together, as the database serves them
    // in turn anyway, and keep the subjects' order for the entries.
    final rowsBySubject = await Future.wait([
      for (final s in refSubjects) _rows(s, diverId),
    ]);
    final entries = <NameEntry>[];
    var siteRows = const <QueryRow>[];
    for (var i = 0; i < refSubjects.length; i++) {
      final subject = refSubjects[i];
      final rows = rowsBySubject[i];
      if (subject == QuerySubject.sites) siteRows = rows;
      for (final row in rows) {
        entries.addAll(_rowEntries(subject, row, l10n));
      }
    }
    entries.addAll(_places(siteRows));
    entries.addAll(await _customCertificationEntries(diverId));
    entries.addAll(_attributeChoices(l10n));
    final seen = <String>{};
    return NameIndex([
      for (final e in entries)
        if (seen.add('${e.subject.name}|${e.label}|${e.identity}')) e,
    ]);
  }

  /// The custom certification agencies and levels [diverId] can see (issue
  /// #690): own rows and shared ones; a level under a custom agency follows
  /// the agency. With no diver, only shared rows. Name-only subjects: they
  /// resolve typed agency and level values, never a query root.
  Future<List<NameEntry>> _customCertificationEntries(String? diverId) async {
    final visibleAgency = diverId == null
        ? 'a.is_shared = 1'
        : '(a.diver_id = ?1 OR a.is_shared = 1)';
    final visibleLevel = diverId == null
        ? 'l.is_shared = 1'
        : '(l.diver_id = ?1 OR l.is_shared = 1)';
    final variables = [if (diverId != null) Variable<String>(diverId)];
    final agencies = await _db
        .customSelect(
          'SELECT a.id, a.name FROM custom_certification_agencies a '
          'WHERE $visibleAgency',
          variables: variables,
        )
        .get();
    final levels = await _db
        .customSelect(
          'SELECT l.id, l.name FROM custom_certification_levels l '
          'LEFT JOIN custom_certification_agencies a ON a.id = l.agency_id '
          'WHERE (a.id IS NOT NULL AND $visibleAgency) '
          'OR (a.id IS NULL AND $visibleLevel)',
          variables: variables,
        )
        .get();
    NameEntry entry(QuerySubject subject, QueryRow row) => NameEntry(
      subject: subject,
      label: row.read<String>('name'),
      ids: [row.read<String>('id')],
      target: NameTarget.row,
      primary: true,
    );
    return [
      for (final row in agencies)
        entry(QuerySubject.certificationAgencies, row),
      for (final row in levels) entry(QuerySubject.certificationLevels, row),
    ];
  }

  /// The visible rows of [subject]: id, registry name and the extra
  /// columns. Visibility is the typed loader's rule set, unchanged.
  Future<List<QueryRow>> _rows(QuerySubject subject, String? diverId) {
    final entity = appQueryRegistry.entityFor(subject);
    final nameSql = entity.field('name')!.sql.replaceAll('{r}', 't');
    final extra = [
      for (final c in _extra[subject] ?? const <String>[]) ', t.$c AS $c',
    ].join();
    final scope = entity.diverScopeColumn;
    final visible = <String>[];
    final variables = <Variable<Object>>[];
    if (scope != null) {
      if (diverId != null) {
        visible.add('t.$scope = ?');
        variables.add(Variable<String>(diverId));
      }
      visible.add('t.$scope IS NULL');
      switch (subject) {
        case QuerySubject.sites || QuerySubject.trips:
          visible.add('t.is_shared = 1');
        case QuerySubject.equipment when diverId != null:
          visible.add(
            't.${entity.idColumn} IN (SELECT equipment_id '
            'FROM equipment_shares WHERE diver_id = ?)',
          );
          variables.add(Variable<String>(diverId));
        default:
          break;
      }
    }
    // A profile's hidden shared trips and sites (issue #2594) leave its
    // name completion, as they leave its lists.
    final hides = diverId == null
        ? null
        : switch (subject) {
            QuerySubject.trips => (table: 'trip_hides', column: 'trip_id'),
            QuerySubject.sites => (table: 'site_hides', column: 'site_id'),
            _ => null,
          };
    if (hides != null) variables.add(Variable<String>(diverId));
    final clauses = [
      if (visible.isNotEmpty) '(${visible.join(' OR ')})',
      if (hides != null)
        't.${entity.idColumn} NOT IN '
            '(SELECT ${hides.column} FROM ${hides.table} WHERE diver_id = ?)',
    ];
    final where = clauses.isEmpty ? '' : 'WHERE ${clauses.join(' AND ')}';
    return _db
        .customSelect(
          'SELECT t.${entity.idColumn} AS id, $nameSql AS label$extra '
          'FROM ${entity.table} t $where ORDER BY label',
          variables: variables,
        )
        .get();
  }

  /// Places: every non-empty country, region, island and city of a visible
  /// site. One label merges across sites and columns, keeping the lowest
  /// column rank, the union of site ids and every column it came from.
  static List<NameEntry> _places(List<QueryRow> sites) {
    final ids = <String, Set<String>>{};
    final ranks = <String, int>{};
    final fields = <String, Set<String>>{};
    for (final row in sites) {
      final id = row.read<String>('id');
      for (var rank = 0; rank < _placeColumns.length; rank++) {
        final column = _placeColumns[rank];
        final label = row.read<String?>(column)?.trim();
        if (label == null || label.isEmpty) continue;
        ids.putIfAbsent(label, () => {}).add(id);
        fields.putIfAbsent(label, () => {}).add(column);
        final existing = ranks[label];
        if (existing == null || rank < existing) ranks[label] = rank;
      }
    }
    return [
      for (final label in ranks.keys)
        NameEntry(
          subject: QuerySubject.sites,
          label: label,
          ids: ids[label]!.toList(),
          target: NameTarget.sitePlace,
          rank: ranks[label]!,
          placeFields: [
            for (final c in _placeColumns)
              if (fields[label]!.contains(c)) c,
          ],
        ),
    ];
  }

  /// Every choice of every curated choice attribute, by its localized
  /// label, so "trilaminate" lowers to a condition.
  static List<NameEntry> _attributeChoices(AppLocalizations l10n) => [
    for (final type in EquipmentType.values)
      for (final def in EquipmentAttributeCatalog.attributesFor(type))
        if (def.kind == AttributeKind.choice)
          for (final choice in def.choiceKeys)
            NameEntry(
              subject: QuerySubject.equipment,
              label: attributeChoiceLabel(l10n, def.key, choice),
              ids: const [],
              target: NameTarget.attrChoice,
              rank: 2,
              attrKey: def.key,
              attrChoice: choice,
            ),
  ];

  /// One row's entries: its registry name (the primary, when it has one)
  /// and the alternate labels a sentence may use for it. A row with no name
  /// still keeps its alternates, so an item saved without a name is found by
  /// its brand and model.
  ///
  /// Ranks, for sentences: a row's own name is 0, except a species'. Built-in
  /// species rank ahead of custom ones, as Explore ranked them: a built-in's
  /// localized name is its rank-0 label (an alternate, the stored name then
  /// ranking 1), and where the two agree (English) the stored name itself is
  /// rank 0.
  static Iterable<NameEntry> _rowEntries(
    QuerySubject subject,
    QueryRow row,
    AppLocalizations l10n,
  ) sync* {
    final id = row.read<String>('id');
    final label = row.read<String?>('label') ?? '';
    final species = subject == QuerySubject.species;
    final builtIn = species && (row.read<int?>('is_built_in') ?? 0) == 1;
    final localized = builtIn ? builtInSpeciesName(l10n, id) : null;
    final distinctLocalized = localized != null && localized != label;
    if (label.isNotEmpty) {
      yield NameEntry(
        subject: subject,
        label: label,
        ids: [id],
        target: rowTargetFor(subject),
        rank: !species || (builtIn && !distinctLocalized) ? 0 : 1,
        primary: true,
      );
    }
    switch (subject) {
      case QuerySubject.species:
        if (distinctLocalized) {
          yield NameEntry(
            subject: subject,
            label: localized,
            ids: [id],
            target: NameTarget.speciesId,
          );
        }
        final sci = row.read<String?>('scientific_name');
        if (sci != null && sci.isNotEmpty) {
          yield NameEntry(
            subject: subject,
            label: sci,
            ids: [id],
            target: NameTarget.speciesId,
            rank: 2,
          );
        }
      case QuerySubject.equipment:
        final brandModel = [
          row.read<String?>('brand'),
          row.read<String?>('model'),
        ].whereType<String>().where((s) => s.isNotEmpty).join(' ');
        if (brandModel.isNotEmpty && brandModel != label) {
          yield NameEntry(
            subject: subject,
            label: brandModel,
            ids: [id],
            target: NameTarget.equipmentId,
            rank: 1,
          );
        }
      default:
        break;
    }
  }
}
