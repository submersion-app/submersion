import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';

import 'package:submersion/core/constants/certification_levels.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/certification_agencies/domain/agency_colors.dart';
import 'package:submersion/features/certification_agencies/domain/entities/custom_certification_agency.dart';
import 'package:submersion/features/certification_agencies/domain/entities/custom_certification_level.dart';

final _slug = RegExp(r'^[a-z][A-Za-z0-9]*$');

/// True for an id shaped like a built-in enum name (a newer build's
/// built-in this build does not know), false for a UUID.
bool looksLikeSlug(String id) => _slug.hasMatch(id);

/// One agency as every screen sees it: a built-in, a custom row, or a
/// fallback for an id nothing here knows (issue #690).
class AgencyEntry extends Equatable {
  final String id;
  final String name;
  final Color primaryColor;
  final Color secondaryColor;
  final bool isFallback;
  final CertificationAgency? builtIn;
  final CustomCertificationAgency? custom;

  const AgencyEntry({
    required this.id,
    required this.name,
    required this.primaryColor,
    required this.secondaryColor,
    this.isFallback = false,
    this.builtIn,
    this.custom,
  });

  bool get isBuiltIn => builtIn != null;
  bool get isSlugFallback => isFallback && looksLikeSlug(id);

  /// English text for interchange (UDDF, CSV, PDF): the built-in display
  /// name, the custom name, the slug, or "Unknown agency".
  String get interchangeName {
    final b = builtIn;
    if (b != null) return b.displayName;
    if (isFallback && !isSlugFallback) return 'Unknown agency';
    return name;
  }

  @override
  List<Object?> get props => [
    id,
    name,
    primaryColor,
    secondaryColor,
    isFallback,
  ];
}

/// One certification (level) as every screen sees it: a built-in, a custom
/// row, or a fallback for an unknown id (issue #690).
class LevelEntry extends Equatable {
  final String id;
  final String name;
  final String? agencyId;
  final bool isProgression;
  final bool isFallback;
  final CertificationLevel? builtIn;
  final CustomCertificationLevel? custom;

  const LevelEntry({
    required this.id,
    required this.name,
    this.agencyId,
    this.isProgression = false,
    this.isFallback = false,
    this.builtIn,
    this.custom,
  });

  bool get isBuiltIn => builtIn != null;
  bool get isSlugFallback => isFallback && looksLikeSlug(id);

  /// Custom and fallback levels never qualify as instructor grades.
  bool get isInstructorLevel => builtIn?.isInstructorLevel ?? false;

  /// English text for interchange: the built-in display name, the custom
  /// name, the slug, or "Unknown certification".
  String get interchangeName {
    final b = builtIn;
    if (b != null) return b.displayName;
    if (isFallback && !isSlugFallback) return 'Unknown certification';
    return name;
  }

  @override
  List<Object?> get props => [id, name, agencyId, isProgression, isFallback];
}

/// Built-in agencies and levels merged with custom rows (issue #690).
///
/// Holds every custom row, so any stored id resolves whether or not the
/// viewer can see it, and filters the pickers to what [viewerDiverId] can
/// see: own rows and shared ones. A level under a custom agency follows that
/// agency's visibility.
class CertificationCatalog {
  CertificationCatalog({
    List<CustomCertificationAgency> agencies = const [],
    List<CustomCertificationLevel> levels = const [],
    this.viewerDiverId,
  }) : _agencies = {for (final a in agencies) a.id: a},
       _levels = {for (final l in levels) l.id: l};

  /// Built-ins only, for code with no custom rows to hand.
  static final CertificationCatalog builtInOnly = CertificationCatalog();

  final String? viewerDiverId;
  final Map<String, CustomCertificationAgency> _agencies;
  final Map<String, CustomCertificationLevel> _levels;

  CustomCertificationAgency? customAgency(String id) => _agencies[id];
  CustomCertificationLevel? customLevel(String id) => _levels[id];

  bool _agencyVisible(CustomCertificationAgency a) =>
      a.isShared || a.diverId == viewerDiverId;

  bool _levelVisible(CustomCertificationLevel l) {
    final parent = _agencies[l.agencyId];
    if (parent != null) return _agencyVisible(parent);
    return l.isShared || l.diverId == viewerDiverId;
  }

  /// True when the viewer owns the custom agency [id].
  bool canEditAgency(String id) {
    final a = _agencies[id];
    return a != null && viewerDiverId != null && a.diverId == viewerDiverId;
  }

  /// True when the viewer owns the custom level [id].
  bool canEditLevel(String id) {
    final l = _levels[id];
    return l != null && viewerDiverId != null && l.diverId == viewerDiverId;
  }

  AgencyEntry _builtInAgency(CertificationAgency a) => AgencyEntry(
    id: a.name,
    name: a.displayName,
    primaryColor: a.primaryColor,
    secondaryColor: a.secondaryColor,
    builtIn: a,
  );

  AgencyEntry _customAgency(CustomCertificationAgency a) {
    final primary = Color(a.colorArgb);
    return AgencyEntry(
      id: a.id,
      name: a.name,
      primaryColor: primary,
      secondaryColor: secondaryAgencyColor(primary),
      custom: a,
    );
  }

  /// Picker order: built-ins in enum order, visible custom agencies by name,
  /// then Other.
  List<AgencyEntry> get agencies {
    final custom = _agencies.values.where(_agencyVisible).toList()
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    return [
      for (final a in CertificationAgency.values)
        if (a != CertificationAgency.other) _builtInAgency(a),
      for (final a in custom) _customAgency(a),
      _builtInAgency(CertificationAgency.other),
    ];
  }

  /// The agency [id] names. Never null: an unknown id resolves to a
  /// fallback entry, and a null id (possible on buddies) to Other.
  AgencyEntry agency(String? id) {
    if (id == null) return _builtInAgency(CertificationAgency.other);
    final builtIn = CertificationAgency.fromId(id);
    if (builtIn != null) return _builtInAgency(builtIn);
    final custom = _agencies[id];
    if (custom != null) return _customAgency(custom);
    return AgencyEntry(
      id: id,
      name: id,
      primaryColor: CertificationAgency.other.primaryColor,
      secondaryColor: CertificationAgency.other.secondaryColor,
      isFallback: true,
    );
  }

  LevelEntry _builtInLevel(CertificationLevel l, {bool progression = false}) =>
      LevelEntry(
        id: l.name,
        name: l.displayName,
        isProgression: progression,
        builtIn: l,
      );

  LevelEntry _customLevel(CustomCertificationLevel l) => LevelEntry(
    id: l.id,
    name: l.name,
    agencyId: l.agencyId,
    isProgression: l.isProgression,
    custom: l,
  );

  /// The level [id] names. Never null: an unknown id resolves to a fallback.
  LevelEntry level(String id) {
    final builtIn = CertificationLevel.fromId(id);
    if (builtIn != null) return _builtInLevel(builtIn);
    final custom = _levels[id];
    if (custom != null) return _customLevel(custom);
    return LevelEntry(id: id, name: id, isFallback: true);
  }

  List<CustomCertificationLevel> _customRungs(
    String agencyId, {
    required bool visibleOnly,
  }) =>
      _levels.values
          .where((l) => l.agencyId == agencyId && l.isProgression)
          .where((l) => !visibleOnly || _levelVisible(l))
          .toList()
        ..sort((a, b) {
          final byOrder = a.sortOrder.compareTo(b.sortOrder);
          return byOrder != 0 ? byOrder : a.name.compareTo(b.name);
        });

  /// The agency's ranked ladder: its built-in rungs, then the visible custom
  /// rungs in sort order. A custom agency has no built-in rungs.
  List<LevelEntry> ladderFor(String? agencyId) {
    final builtIn = _builtInLadder(agencyId);
    return [
      for (final l in builtIn) _builtInLevel(l, progression: true),
      if (agencyId != null)
        for (final l in _customRungs(agencyId, visibleOnly: true))
          _customLevel(l),
    ];
  }

  /// Built-in specialties not on the ladder, then the agency's visible
  /// custom specialties by name. A custom agency has no built-ins here.
  List<LevelEntry> specialtiesFor(String? agencyId) {
    final custom = agencyId == null
        ? <CustomCertificationLevel>[]
        : (_levels.values
              .where((l) => l.agencyId == agencyId && !l.isProgression)
              .where(_levelVisible)
              .toList()
            ..sort(
              (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
            ));
    return [
      if (!_isCustomAgency(agencyId))
        for (final l in CertificationLevelCatalog.specialtiesFor(
          CertificationAgency.fromId(agencyId),
        ))
          _builtInLevel(l),
      for (final l in custom) _customLevel(l),
    ];
  }

  /// Ladder, specialties, then [ensure] when it is set, not Other and not
  /// already listed, then Other. Mirrors CertificationLevelCatalog.levelsFor.
  List<LevelEntry> levelsFor(String? agencyId, {String? ensure}) {
    final result = [...ladderFor(agencyId), ...specialtiesFor(agencyId)];
    if (ensure != null &&
        ensure != CertificationLevel.other.name &&
        !result.any((e) => e.id == ensure)) {
      result.add(level(ensure));
    }
    result.add(_builtInLevel(CertificationLevel.other));
    return result;
  }

  /// Rank for primaryCertification: the index in the agency's built-in
  /// ladder, then built-in length plus position among ALL the agency's
  /// custom rungs, so visibility never changes a rank. -1 for null,
  /// specialties and unknown ids.
  int rankOf(String? agencyId, String? levelId) {
    if (levelId == null) return -1;
    final builtIn = _builtInLadder(agencyId);
    final builtInLevel = CertificationLevel.fromId(levelId);
    if (builtInLevel != null) return builtIn.indexOf(builtInLevel);
    if (agencyId == null) return -1;
    final rungs = _customRungs(agencyId, visibleOnly: false);
    final i = rungs.indexWhere((l) => l.id == levelId);
    return i < 0 ? -1 : builtIn.length + i;
  }

  /// The text an export writes for agency [id] (issue #690): a built-in's
  /// enum name (round-trips unchanged), a custom agency's name (its id means
  /// nothing to another app), or the raw id when nothing here knows it.
  String agencyExportText(String id) => _agencies[id]?.name ?? id;

  /// The text an export writes for level [id], by the same rules.
  String levelExportText(String id) => _levels[id]?.name ?? id;

  /// The viewer's own custom levels of [agencyId], for the editor.
  List<CustomCertificationLevel> ownCustomLevelsOf(String agencyId) => _levels
      .values
      .where((l) => l.agencyId == agencyId && l.diverId == viewerDiverId)
      .toList();

  bool _isCustomAgency(String? agencyId) =>
      agencyId != null &&
      CertificationAgency.fromId(agencyId) == null &&
      _agencies.containsKey(agencyId);

  /// A custom agency has no built-in ladder; an unknown or null agency
  /// behaves like Other, as CertificationLevelCatalog.ladderFor does.
  List<CertificationLevel> _builtInLadder(String? agencyId) =>
      _isCustomAgency(agencyId)
      ? const []
      : CertificationLevelCatalog.ladderFor(
          CertificationAgency.fromId(agencyId),
        );
}
