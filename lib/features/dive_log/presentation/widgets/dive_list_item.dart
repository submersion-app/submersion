import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:submersion/core/constants/dive_field.dart';
import 'package:submersion/core/constants/list_view_mode.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/domain/entities/dive_summary.dart';
import 'package:submersion/features/dive_log/presentation/pages/dive_list_page.dart'
    show DiveListTile;
import 'package:submersion/features/dive_log/presentation/providers/view_config_providers.dart';
import 'package:submersion/features/dive_log/presentation/widgets/compact_dive_list_tile.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

/// Renders a single dive in a list according to the active [ListViewMode] and
/// card configuration, so every dive list honours the same display settings.
///
/// This is the single source of truth for "how a dive row looks" — the Dives
/// tab and the home screen's Recent dives both use it, which is what keeps the
/// home list in sync with the list settings (issue #506).
class DiveListItem extends ConsumerWidget {
  /// Summary used for slot/field extraction (title, date, stats, extra fields).
  final DiveSummary summary;

  /// Full dive, when available, for fields not on [DiveSummary] (tanks, SAC,
  /// buddy, weights). Enables the detailed card's configurable extra fields.
  final Dive? fullDive;

  /// Display number for the leading badge (caller resolves any fallback).
  final int diveNumber;

  /// Value/range for attribute-based card coloring.
  final double? colorValue;
  final double? minValueInList;
  final double? maxValueInList;
  final Color? gradientStartColor;
  final Color? gradientEndColor;

  /// Card margin override (detailed tile only).
  final EdgeInsetsGeometry? margin;

  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  /// Selection / highlight state (defaults suit read-only lists like Recent).
  final bool isSelectionMode;
  final bool isSelected;
  final bool isHighlighted;

  const DiveListItem({
    super.key,
    required this.summary,
    required this.diveNumber,
    this.fullDive,
    this.colorValue,
    this.minValueInList,
    this.maxValueInList,
    this.gradientStartColor,
    this.gradientEndColor,
    this.margin,
    this.onTap,
    this.onLongPress,
    this.isSelectionMode = false,
    this.isSelected = false,
    this.isHighlighted = false,
  });

  static DiveField _slotField(
    List<CardSlotConfig> slots,
    String slotId,
    DiveField defaultField,
  ) {
    for (final slot in slots) {
      if (slot.slotId == slotId) return slot.field;
    }
    return defaultField;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final viewMode = ref.watch(diveListViewModeProvider);

    // Outside selection mode a highlighted/master-selected row reads as
    // selected, mirroring the Dives tab.
    final resolvedSelected = isSelectionMode
        ? isSelected
        : (isSelected || isHighlighted);

    final duration = summary.runtime ?? summary.bottomTime;

    switch (viewMode) {
      case ListViewMode.compact:
        final slots = ref.watch(compactCardConfigProvider).slots;
        return CompactDiveListTile(
          diveId: summary.id,
          diveNumber: diveNumber,
          dateTime: summary.dateTime,
          siteName: summary.siteName,
          maxDepth: summary.maxDepth,
          duration: duration,
          isSelectionMode: isSelectionMode,
          isSelected: resolvedSelected,
          colorValue: colorValue,
          minValueInList: minValueInList,
          maxValueInList: maxValueInList,
          gradientStartColor: gradientStartColor,
          gradientEndColor: gradientEndColor,
          summary: summary,
          titleField: _slotField(slots, 'title', DiveField.siteName),
          dateField: _slotField(slots, 'date', DiveField.dateTime),
          stat1Field: _slotField(slots, 'stat1', DiveField.maxDepth),
          stat2Field: _slotField(slots, 'stat2', DiveField.bottomTime),
          onTap: onTap,
          onLongPress: onLongPress,
        );
      case ListViewMode.detailed:
      case ListViewMode.dense:
      case ListViewMode.table:
        return DiveListTile(
          diveId: summary.id,
          diveNumber: diveNumber,
          dateTime: summary.dateTime,
          siteName: summary.siteName,
          siteLocation: summary.siteLocation,
          maxDepth: summary.maxDepth,
          duration: duration,
          waterTemp: summary.waterTemp,
          rating: summary.rating,
          isFavorite: summary.isFavorite,
          tags: summary.tags,
          isSelectionMode: isSelectionMode,
          isSelected: resolvedSelected,
          colorValue: colorValue,
          minValueInList: minValueInList,
          maxValueInList: maxValueInList,
          gradientStartColor: gradientStartColor,
          gradientEndColor: gradientEndColor,
          siteLatitude: summary.siteLatitude,
          siteLongitude: summary.siteLongitude,
          margin: margin,
          onTap: onTap,
          onLongPress: onLongPress,
          summary: summary,
          fullDive: fullDive,
        );
    }
  }
}
