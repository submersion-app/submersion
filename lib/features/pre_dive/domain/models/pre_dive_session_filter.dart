import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart' show DateTimeRange;

import 'package:submersion/features/pre_dive/domain/entities/pre_dive_session.dart';

/// Facets for narrowing the pre-dive checklist session history.
///
/// Every facet is independent and an empty facet means "no restriction", so
/// the default instance passes everything through. Sessions are matched on the
/// snapshotted [PreDiveSession.templateName] rather than the template id:
/// sessions are audit history and outlive the templates they were run from.
class PreDiveSessionFilter extends Equatable {
  final Set<String> templateNames;
  final Set<PreDiveSessionStatus> statuses;
  final bool flaggedOnly;
  final DateTimeRange? dateRange;

  const PreDiveSessionFilter({
    this.templateNames = const {},
    this.statuses = const {},
    this.flaggedOnly = false,
    this.dateRange,
  });

  bool get hasActiveFilters =>
      templateNames.isNotEmpty ||
      statuses.isNotEmpty ||
      flaggedOnly ||
      dateRange != null;

  /// Narrows [sessions] to those matching every active facet.
  ///
  /// [stats] supplies the flag tallies, which live in an aggregate query
  /// rather than on the session row. A session missing from [stats] cannot be
  /// shown to be flagged, so `flaggedOnly` excludes it.
  List<PreDiveSession> apply(
    List<PreDiveSession> sessions,
    Map<String, PreDiveSessionStats> stats,
  ) {
    if (!hasActiveFilters) return sessions;
    return sessions.where((session) => _matches(session, stats)).toList();
  }

  bool _matches(
    PreDiveSession session,
    Map<String, PreDiveSessionStats> stats,
  ) {
    if (templateNames.isNotEmpty &&
        !templateNames.contains(session.templateName)) {
      return false;
    }
    if (statuses.isNotEmpty && !statuses.contains(session.status)) {
      return false;
    }
    if (flaggedOnly && !(stats[session.id]?.hasFlagged ?? false)) {
      return false;
    }
    final range = dateRange;
    if (range != null) {
      final startedAt = session.startedAt;
      // The picker yields whole days, so the end day is inclusive: a run that
      // started at 23:30 on the last selected day is still inside the range.
      final endOfLastDay = DateTime(
        range.end.year,
        range.end.month,
        range.end.day,
      ).add(const Duration(days: 1));
      final startOfFirstDay = DateTime(
        range.start.year,
        range.start.month,
        range.start.day,
      );
      if (startedAt.isBefore(startOfFirstDay) ||
          !startedAt.isBefore(endOfLastDay)) {
        return false;
      }
    }
    return true;
  }

  /// [clearDateRange] exists because a null [dateRange] argument is
  /// indistinguishable from an omitted one.
  PreDiveSessionFilter copyWith({
    Set<String>? templateNames,
    Set<PreDiveSessionStatus>? statuses,
    bool? flaggedOnly,
    DateTimeRange? dateRange,
    bool clearDateRange = false,
  }) {
    return PreDiveSessionFilter(
      templateNames: templateNames ?? this.templateNames,
      statuses: statuses ?? this.statuses,
      flaggedOnly: flaggedOnly ?? this.flaggedOnly,
      dateRange: clearDateRange ? null : (dateRange ?? this.dateRange),
    );
  }

  @override
  List<Object?> get props => [templateNames, statuses, flaggedOnly, dateRange];
}
