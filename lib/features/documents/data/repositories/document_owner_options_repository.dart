import 'package:drift/drift.dart';

import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/core/util/wall_clock_utc.dart';
import 'package:submersion/features/certifications/domain/certification_title.dart';
import 'package:submersion/features/documents/domain/entities/document.dart';

/// One record a document can be filed under, as the owner picker lists it.
class DocumentOwnerOption {
  final String id;

  /// The record's name; a dive's number (`#12`), empty for an unnumbered
  /// dive, which the picker labels by its date instead.
  final String label;

  /// A dive's own name, else its site; a piece of gear's make.
  final String? subtitle;

  /// Dives and trips: the wall clock, formatted where it is shown.
  final DateTime? date;

  /// Certifications only: what the title is made from. [label] is the stored
  /// name, empty for a certification with no custom title, so the picker
  /// titles it from these instead (issue #3366).
  final CertificationTitleFields? certification;

  const DocumentOwnerOption(
    this.id,
    this.label, {
    this.subtitle,
    this.date,
    this.certification,
  });

  /// A dive as a document owner (#3391): its number, told apart by its own
  /// name or else its site, and its wall-clock date. The picker, the
  /// document form and the documents list all describe a dive from this.
  factory DocumentOwnerOption.dive(
    String id, {
    required int? number,
    required String? name,
    required String? site,
    required int dateTimeMillis,
  }) {
    String? text(String? v) => v?.trim().isEmpty ?? true ? null : v!.trim();
    return DocumentOwnerOption(
      id,
      number == null ? '' : '#$number',
      subtitle: text(name) ?? text(site),
      date: wallClockUtcFromMillis(dateTimeMillis),
    );
  }

  /// The label and subtitle on one line (`#12 · Salt Pier`), without the
  /// date; empty when there is neither.
  String get name => [if (label.isNotEmpty) label, ?subtitle].join(' · ');
}

/// The records of one owner kind a diver can file a document under.
///
/// Club library sites (#3324) are left out: their rows belong to another
/// library, so a personal document filed under one would sync a link that
/// other devices may not have.
class DocumentOwnerOptionsRepository {
  AppDatabase get _db => DatabaseService.instance.database;

  /// The table of each named owner kind (every kind but personal and dive).
  static const Map<DocumentOwnerKind, String> _tables = {
    DocumentOwnerKind.site: 'dive_sites',
    DocumentOwnerKind.trip: 'trips',
    DocumentOwnerKind.equipment: 'equipment',
    DocumentOwnerKind.course: 'courses',
    DocumentOwnerKind.certification: 'certifications',
    DocumentOwnerKind.buddy: 'buddies',
    DocumentOwnerKind.diveCenter: 'dive_centers',
  };

  Future<List<DocumentOwnerOption>> optionsFor(
    DocumentOwnerKind kind, {
    required String diverId,
  }) async {
    if (kind == DocumentOwnerKind.personal) return const [];
    if (kind == DocumentOwnerKind.dive) return _dives(diverId);
    final table = _tables[kind]!;
    final libraryFilter = kind == DocumentOwnerKind.site
        ? 'AND shared_library_id IS NULL '
        : '';
    // Trips read best latest first; everything else alphabetically.
    final trip = kind == DocumentOwnerKind.trip;
    final gear = kind == DocumentOwnerKind.equipment;
    final cert = kind == DocumentOwnerKind.certification;
    // What tells two same-named records apart: a trip's dates (a "Bonaire"
    // every year), a piece of gear's make.
    final extra = trip
        ? ', start_date'
        : gear
        ? ', brand, model'
        : cert
        ? ', agency, level'
        : '';
    final order = trip
        ? 'start_date DESC, name COLLATE NOCASE'
        : 'name COLLATE NOCASE';
    final rows = await _db
        .customSelect(
          'SELECT id, name$extra FROM $table WHERE diver_id = ? '
          '${libraryFilter}ORDER BY $order',
          variables: [Variable.withString(diverId)],
        )
        .get();
    String? make(QueryRow r) {
      final parts = [
        for (final c in ['brand', 'model'])
          if (r.readNullable<String>(c)?.trim() case final v? when v.isNotEmpty)
            v,
      ];
      return parts.isEmpty ? null : parts.join(' ');
    }

    return [
      for (final r in rows)
        DocumentOwnerOption(
          r.read<String>('id'),
          r.read<String>('name'),
          subtitle: gear ? make(r) : null,
          date: trip
              ? DateTime.fromMillisecondsSinceEpoch(r.read<int>('start_date'))
              : null,
          certification: cert ? _certificationFields(r) : null,
        ),
    ];
  }

  /// The columns [_diveOption] reads, from `dives d` joined to its site `s`.
  static const _diveColumns =
      'd.id, d.dive_number, d.name, d.dive_date_time, s.name AS site '
      'FROM dives d LEFT JOIN dive_sites s ON s.id = d.site_id';

  static DocumentOwnerOption _diveOption(QueryRow r) =>
      DocumentOwnerOption.dive(
        r.read<String>('id'),
        number: r.readNullable<int>('dive_number'),
        name: r.readNullable<String>('name'),
        site: r.readNullable<String>('site'),
        dateTimeMillis: r.read<int>('dive_date_time'),
      );

  static CertificationTitleFields _certificationFields(QueryRow r) => (
    name: r.read<String>('name'),
    agency: r.read<String>('agency'),
    level: r.readNullable<String>('level'),
  );

  /// The title fields of certification [id]; null when it no longer exists.
  Future<CertificationTitleFields?> certificationFieldsFor(String id) async {
    final row = await _db
        .customSelect(
          'SELECT name, agency, level FROM certifications WHERE id = ?',
          variables: [Variable.withString(id)],
        )
        .getSingleOrNull();
    return row == null ? null : _certificationFields(row);
  }

  Future<List<DocumentOwnerOption>> _dives(String diverId) async {
    final rows = await _db
        .customSelect(
          'SELECT $_diveColumns '
          'WHERE d.diver_id = ? ORDER BY d.dive_date_time DESC',
          variables: [Variable.withString(diverId)],
        )
        .get();
    return [for (final r in rows) _diveOption(r)];
  }

  /// [owner]'s record as the picker would list it, for the document form;
  /// null for personal or a record that no longer exists. Only a dive has
  /// a subtitle and a date here.
  Future<DocumentOwnerOption?> optionFor(DocumentOwner owner) async {
    final id = owner.id;
    if (id == null) return null;
    if (owner.kind == DocumentOwnerKind.dive) {
      final row = await _db
          .customSelect(
            'SELECT $_diveColumns WHERE d.id = ?',
            variables: [Variable.withString(id)],
          )
          .getSingleOrNull();
      return row == null ? null : _diveOption(row);
    }
    final row = await _db
        .customSelect(
          'SELECT name FROM ${_tables[owner.kind]} WHERE id = ?',
          variables: [Variable.withString(id)],
        )
        .getSingleOrNull();
    return row == null
        ? null
        : DocumentOwnerOption(id, row.read<String>('name'));
  }
}
