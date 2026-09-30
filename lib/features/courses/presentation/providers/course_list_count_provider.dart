import 'package:flutter/widgets.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/courses/presentation/providers/course_providers.dart';
import 'package:submersion/features/courses/presentation/providers/course_query_providers.dart';
import 'package:submersion/l10n/l10n_extension.dart';
import 'package:submersion/shared/models/list_entry_count.dart';
import 'package:submersion/shared/models/subtitle_text.dart';

/// The courses list's entry count (#2669): what the list shows against
/// what it holds with no filter. Null until the list loads.
final courseListCountProvider = Provider<ListEntryCount?>(
  (ref) => listEntryCount(
    shown: ref.watch(filteredCoursesProvider),
    isFiltered: ref.watch(courseFilterProvider).hasActiveFilters,
    total: () => ref.watch(courseListNotifierProvider),
  ),
);

/// The subtitle under the courses list's title: "12 courses", or
/// "3 of 12 courses" while a filter is active.
SubtitleText? courseListCountLabel(BuildContext context, WidgetRef ref) => ref
    .watch(courseListCountProvider)
    ?.subtitle(
      all: context.l10n.courses_list_count,
      filtered: context.l10n.courses_list_countFiltered,
      compactFiltered: context.l10n.common_listCount_shownOfTotal,
    );
