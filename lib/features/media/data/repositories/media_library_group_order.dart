import 'package:drift/drift.dart';

import 'package:submersion/core/constants/sort_options.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/features/media/domain/entities/media_library_grouping.dart';

/// One leading ORDER BY key of a grouped library page (issue #4268).
///
/// The library groups the rows it has loaded, so a grouped page orders by
/// the group first: every group then arrives in one run and is whole once
/// the page holding its last row is read. The keyset cursor has to carry
/// these keys too, or a page boundary inside a group would compare only the
/// sort key and skip or repeat rows of the next group.
///
/// Every key is total (never NULL), for the reason given at the repository's
/// cursor predicate.
class LibraryGroupKey<T extends Comparable<dynamic>> {
  LibraryGroupKey(this.expression, {required this.descending});

  final Expression<T> expression;
  final bool descending;

  OrderingTerm get ordering => OrderingTerm(
    expression: expression,
    mode: descending ? OrderingMode.desc : OrderingMode.asc,
  );

  /// The row's value for this key, from a query that selected [expression].
  Object readFrom(TypedResult row) => row.read(expression)!;

  Expression<bool> equalTo(Object value) => expression.equals(value as T);

  /// Rows that come after [value] in this key's order.
  Expression<bool> after(Object value) => descending
      ? expression.isSmallerThanValue(value as T)
      : expression.isBiggerThanValue(value as T);
}

/// The leading keys for [grouping], or none for an ungrouped page.
///
/// Day grouping under a date sort needs none either: date order already
/// keeps each day in one run, and a leading key would stop the date sort
/// using its index (`idx_media_library`).
///
/// [dateDescending] is the direction groups follow: newest first unless the
/// diver sorts by date ascending, whatever field the rows inside a group
/// are sorted by. [dateKey] is the library's own date key, so a day here is
/// the day `groupByTimeline` files the row under. [dives], [attachedSites]
/// and [equipment] are the tables the page joins on the row's own dive,
/// site and equipment links.
List<LibraryGroupKey> libraryGroupKeys(
  MediaLibraryGrouping grouping, {
  required AppDatabase db,
  required MediaSortField sortField,
  required bool dateDescending,
  required Expression<int> dateKey,
  required $DivesTable dives,
  required $DiveSitesTable attachedSites,
  required $EquipmentTable equipment,
}) {
  final m = db.media;
  switch (grouping) {
    case MediaLibraryGrouping.none:
      return const [];
    case MediaLibraryGrouping.day:
      if (sortField == MediaSortField.dateTaken) return const [];
      // Wall-clock-as-UTC millis, so whole days are the calendar days the
      // timeline shows, with no zone involved. SQLite's integer division
      // truncates toward zero, which would put the last day of 1969 and the
      // first of 1970 under one key, so the key counts days from a point far
      // enough back that no date key is before it.
      return [
        LibraryGroupKey<int>(
          (dateKey + const Constant(_dayKeyOffsetMillis)) /
              const Constant(Duration.millisecondsPerDay),
          descending: dateDescending,
        ),
      ];
    case MediaLibraryGrouping.dive:
      // groupByDive's precedence: a row goes under its dive, else its site,
      // else its equipment item, else Unlinked, which it renders last.
      final isDive = m.diveId.isNotNull();
      final isSite = m.siteId.isNotNull();
      final isEquipment = m.equipmentId.isNotNull();
      return [
        LibraryGroupKey<int>(
          CaseWhenExpression<int>(
            cases: [
              CaseWhen(isDive, then: const Constant(0)),
              CaseWhen(isSite, then: const Constant(1)),
              CaseWhen(isEquipment, then: const Constant(2)),
            ],
            orElse: const Constant(3),
          ),
          descending: false,
        ),
        // Dives by their date. Nothing else joins a dive, so every other
        // group ties here.
        LibraryGroupKey<int>(
          coalesce<int>([dives.diveDateTime, const Constant(0)]),
          descending: dateDescending,
        ),
        // Site and equipment groups by name. A dive row can carry a site
        // link of its own, so the name applies only to the group kinds that
        // use it, or one dive's rows would split by it.
        LibraryGroupKey<String>(
          CaseWhenExpression<String>(
            cases: [
              CaseWhen(isDive, then: const Constant('')),
              CaseWhen(
                isSite,
                then: coalesce<String>([
                  attachedSites.name,
                  const Constant(''),
                ]),
              ),
              CaseWhen(
                isEquipment,
                then: coalesce<String>([equipment.name, const Constant('')]),
              ),
            ],
            orElse: const Constant(''),
          ).collate(Collate.noCase),
          descending: false,
        ),
        // Keeps two dives on the same date, or two sites of one name, apart.
        LibraryGroupKey<String>(
          coalesce<String>([
            m.diveId,
            m.siteId,
            m.equipmentId,
            const Constant(''),
          ]),
          descending: false,
        ),
      ];
  }
}

/// 200,000 days, about 547 years: day keys start in the 15th century, well
/// before any photo's date.
const int _dayKeyOffsetMillis = 200000 * Duration.millisecondsPerDay;

/// Whether grouped pages list the newest group first for [direction] of a
/// sort on [field].
bool groupsNewestFirst(MediaSortField field, SortDirection direction) =>
    field != MediaSortField.dateTaken || direction == SortDirection.descending;
