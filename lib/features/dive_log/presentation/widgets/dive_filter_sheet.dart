import 'package:flutter/material.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:go_router/go_router.dart';

import 'package:submersion/core/utils/number_input.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/l10n/l10n_extension.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_computer_providers.dart';
import 'package:submersion/features/dive_sites/presentation/providers/site_providers.dart';
import 'package:submersion/features/dive_types/presentation/dive_type_display.dart';
import 'package:submersion/features/dive_types/presentation/providers/dive_type_providers.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/features/tags/presentation/providers/tag_providers.dart';
import 'package:submersion/features/buddies/presentation/providers/buddy_providers.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_providers.dart';
import 'package:submersion/features/dive_log/presentation/widgets/weekday_filter_selector.dart';
import 'package:submersion/shared/widgets/app_date_picker.dart';

/// Filter sheet for dive list
class DiveFilterSheet extends ConsumerStatefulWidget {
  /// Identifies the resize grip at the top of the sheet, so tests can drive it
  /// the way a diver does with a pointer.
  static const gripKey = ValueKey<String>('dive_filter_sheet_grip');

  final WidgetRef ref;
  final StateProvider<DiveFilterState> filterProvider;

  // `diveFilterProvider` is a `final` top-level variable, not `const`, so it
  // cannot be used as a parameter's default value (Dart requires those to be
  // compile-time constants). Instead the parameter is nullable and defaults
  // to null, then the initializer list resolves it to `diveFilterProvider`,
  // preserving a non-nullable `filterProvider` field for the rest of the
  // class to use. This also means the constructor can no longer be `const`,
  // but no call site ever invoked it as `const` (they all pass a runtime
  // `ref`), so this is not an observable behavior change.
  DiveFilterSheet({
    super.key,
    required this.ref,
    StateProvider<DiveFilterState>? filterProvider,
  }) : filterProvider = filterProvider ?? diveFilterProvider;

  @override
  ConsumerState<DiveFilterSheet> createState() => _DiveFilterSheetState();
}

class _DiveFilterSheetState extends ConsumerState<DiveFilterSheet> {
  // Sheet extents, as a fraction of the available height.
  static const double _minSheetSize = 0.5;
  static const double _initialSheetSize = 0.7;
  static const double _maxSheetSize = 0.95;

  final _sheetController = DraggableScrollableController();

  late final FocusNode _buddyFocusNode;
  late DateTime? _startDate;
  late DateTime? _endDate;
  late String? _diveTypeId;
  late String? _siteId;
  late double? _minDepth;
  late double? _maxDepth;
  late bool _favoritesOnly;
  late List<String> _selectedTagIds;
  late List<int> _selectedWeekdays;

  // v1.5 filters
  late String? _buddyNameFilter;
  late bool _noBuddyOnly;
  late double? _minO2Percent;
  late double? _maxO2Percent;
  late int? _minRating;
  late int? _minDurationMinutes;
  late int? _maxDurationMinutes;
  late String? _computerId;
  double? _suitThicknessMin;
  double? _suitThicknessMax;

  final _minDepthController = TextEditingController();
  final _maxDepthController = TextEditingController();
  final _buddyNameController = TextEditingController();
  final _minDurationController = TextEditingController();
  final _maxDurationController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _buddyFocusNode = FocusNode();
    final filter = widget.ref.read(widget.filterProvider);
    _startDate = filter.startDate;
    _endDate = filter.endDate;
    _diveTypeId = filter.diveTypeId;
    _siteId = filter.siteId;
    _minDepth = filter.minDepth;
    _maxDepth = filter.maxDepth;
    _favoritesOnly = filter.favoritesOnly ?? false;
    _selectedTagIds = List.from(filter.tagIds);
    _selectedWeekdays = List.from(filter.weekdays);
    // Depth bounds live in meters; the fields show and accept the diver's
    // configured depth unit.
    final units = UnitFormatter(widget.ref.read(settingsProvider));
    _minDepthController.text = _minDepth == null
        ? ''
        : formatRoundedForInput(units.convertDepth(_minDepth!), 0);
    _maxDepthController.text = _maxDepth == null
        ? ''
        : formatRoundedForInput(units.convertDepth(_maxDepth!), 0);

    // v1.5 filters
    _buddyNameFilter = filter.buddyNameFilter;
    _buddyNameController.text = _buddyNameFilter ?? '';
    _noBuddyOnly = filter.noBuddyOnly ?? false;
    _minO2Percent = filter.minO2Percent;
    _maxO2Percent = filter.maxO2Percent;
    _minRating = filter.minRating;
    _minDurationMinutes = filter.minBottomTimeMinutes;
    _maxDurationMinutes = filter.maxBottomTimeMinutes;
    _computerId = filter.computerId;
    if (filter.equipmentAttrKey == 'thickness_mm') {
      _suitThicknessMin = filter.equipmentAttrMin;
      _suitThicknessMax = filter.equipmentAttrMax;
    }
    _minDurationController.text = _minDurationMinutes?.toString() ?? '';
    _maxDurationController.text = _maxDurationMinutes?.toString() ?? '';
  }

  @override
  void dispose() {
    _sheetController.dispose();
    _buddyFocusNode.dispose();
    _minDepthController.dispose();
    _maxDepthController.dispose();
    _buddyNameController.dispose();
    _minDurationController.dispose();
    _maxDurationController.dispose();
    super.dispose();
  }

  /// Suit thickness can be fractional (e.g. 2.5 mm), so keep decimals rather
  /// than truncating with toStringAsFixed(0); integers still render cleanly.
  /// Rendered in the diver's locale to match [_parseThicknessBound].
  String _formatThicknessBound(double? value) {
    if (value == null) return '';
    return formatDecimalForInput(value);
  }

  /// Parse a user-entered thickness bound in the diver's locale. Empty or
  /// invalid input clears the bound. A blanket replaceAll(',', '.') would
  /// misread the en_US thousands separator, turning "1,250" into 1.25 (#1091).
  double? _parseThicknessBound(String value) => parseUserDecimal(value);

  @override
  Widget build(BuildContext context) {
    final sites = ref.watch(sitesProvider);
    final settings = ref.watch(settingsProvider);
    final units = UnitFormatter(settings);

    // The form is several screens tall, so the chrome -- grip, title, close
    // and the Clear All / Apply actions -- sits OUTSIDE the scrolling field
    // list. Kept inside it, the actions were the last children of a lazy
    // ListView roughly a thousand pixels below the fold: never built, never
    // reachable, and on desktop indistinguishable from a sheet clipped by the
    // bottom of the window (#989). This mirrors SiteFilterSheet and
    // PreDiveSessionFilterSheet, which were already built this way.
    return DraggableScrollableSheet(
      controller: _sheetController,
      initialChildSize: _initialSheetSize,
      minChildSize: _minSheetSize,
      maxChildSize: _maxSheetSize,
      expand: false,
      builder: (context, scrollController) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
          ),
          child: Column(
            children: [
              _buildGrip(context),
              _buildHeader(context),
              const Divider(height: 1),
              Expanded(
                child: Scrollbar(
                  controller: scrollController,
                  // Desktop draws no thumb until a scroll gesture starts, so
                  // nothing told the diver the form continued past the fold.
                  thumbVisibility: true,
                  child: ListView(
                    controller: scrollController,
                    padding: const EdgeInsets.all(16),
                    children: [
                      // Link to advanced search
                      Align(
                        alignment: AlignmentDirectional.centerStart,
                        child: TextButton.icon(
                          onPressed: () {
                            // push, not go: this sheet also opens from Statistics, and
                            // `go` into the `/dives` child route would rebuild the
                            // stack as [dive list, search] and discard the section --
                            // and its filters -- the user opened the sheet from. It
                            // would also leave system back with nothing to pop and
                            // close the app (#647).
                            //
                            // The router is captured BEFORE the pop: after it, this
                            // sheet's context is deactivated and cannot be looked up
                            // through.
                            //
                            // The target filter travels with the push so the advanced
                            // form edits the same filter this sheet does, instead of
                            // always hijacking the dive list's (#1079).
                            final router = GoRouter.of(context);
                            Navigator.of(context).pop();
                            router.push(
                              '/dives/search',
                              extra: widget.filterProvider,
                            );
                          },
                          icon: const Icon(Icons.manage_search, size: 18),
                          label: Text(context.l10n.diveLog_search_appBar),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Date Range Section
                      Text(
                        context.l10n.diveLog_filter_sectionDateRange,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        children: [
                          _datePresetChip(
                            context,
                            context.l10n.diveLog_filter_presetAllTime,
                            () {
                              setState(() {
                                _startDate = null;
                                _endDate = null;
                              });
                            },
                          ),
                          _datePresetChip(
                            context,
                            context.l10n.diveLog_filter_presetThisYear,
                            () {
                              final now = DateTime.now();
                              setState(() {
                                _startDate = DateTime(now.year, 1, 1);
                                _endDate = DateTime(
                                  now.year,
                                  now.month,
                                  now.day,
                                );
                              });
                            },
                          ),
                          _datePresetChip(
                            context,
                            context.l10n.diveLog_filter_presetLast12Months,
                            () {
                              final now = DateTime.now();
                              setState(() {
                                _startDate = DateTime(
                                  now.year - 1,
                                  now.month,
                                  now.day,
                                );
                                _endDate = DateTime(
                                  now.year,
                                  now.month,
                                  now.day,
                                );
                              });
                            },
                          ),
                          _datePresetChip(
                            context,
                            context.l10n.diveLog_filter_presetLastYear,
                            () {
                              final now = DateTime.now();
                              setState(() {
                                _startDate = DateTime(now.year - 1, 1, 1);
                                _endDate = DateTime(now.year - 1, 12, 31);
                              });
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () =>
                                  _selectDate(context, isStart: true),
                              icon: const Icon(Icons.calendar_today, size: 18),
                              label: Text(
                                _startDate != null
                                    ? units.formatDate(_startDate)
                                    : context.l10n.diveLog_filter_startDate,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(context.l10n.diveLog_filter_dateSeparator),
                          const SizedBox(width: 8),
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () =>
                                  _selectDate(context, isStart: false),
                              icon: const Icon(Icons.calendar_today, size: 18),
                              label: Text(
                                _endDate != null
                                    ? units.formatDate(_endDate)
                                    : context.l10n.diveLog_filter_endDate,
                              ),
                            ),
                          ),
                        ],
                      ),
                      if (_startDate != null || _endDate != null)
                        Align(
                          alignment: AlignmentDirectional.centerEnd,
                          child: TextButton(
                            onPressed: () {
                              setState(() {
                                _startDate = null;
                                _endDate = null;
                              });
                            },
                            child: Text(context.l10n.diveLog_filter_clearDates),
                          ),
                        ),
                      const SizedBox(height: 24),

                      // Weekday Section. ANDs with the date range above: when
                      // both are set, only dives inside the range AND on one
                      // of these weekdays match.
                      Text(
                        context.l10n.diveLog_filter_sectionWeekdays,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 8),
                      WeekdayFilterSelector(
                        selectedWeekdays: _selectedWeekdays,
                        onChanged: (weekdays) {
                          setState(() => _selectedWeekdays = weekdays);
                        },
                      ),
                      if (_selectedWeekdays.isNotEmpty)
                        Align(
                          alignment: AlignmentDirectional.centerEnd,
                          child: TextButton(
                            onPressed: () {
                              setState(() => _selectedWeekdays = []);
                            },
                            child: Text(
                              context.l10n.diveLog_filter_clearWeekdays,
                            ),
                          ),
                        ),
                      const SizedBox(height: 24),

                      // Dive Type Section
                      Text(
                        context.l10n.diveLog_filter_sectionDiveType,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 8),
                      Consumer(
                        builder: (context, ref, child) {
                          final diveTypesAsync = ref.watch(diveTypesProvider);
                          return diveTypesAsync.when(
                            loading: () => const LinearProgressIndicator(),
                            error: (e, st) => Text(
                              context.l10n.diveLog_listPage_errorLoading(e),
                            ),
                            data: (diveTypes) =>
                                DropdownButtonFormField<String?>(
                                  initialValue: _diveTypeId,
                                  decoration: InputDecoration(
                                    hintText:
                                        context.l10n.diveLog_filter_allTypes,
                                    prefixIcon: const Icon(Icons.category),
                                  ),
                                  items: [
                                    DropdownMenuItem(
                                      value: null,
                                      child: Text(
                                        context.l10n.diveLog_filter_allTypes,
                                      ),
                                    ),
                                    ...diveTypes.map((type) {
                                      return DropdownMenuItem(
                                        value: type.id,
                                        child: Text(
                                          type.localizedName(context.l10n),
                                        ),
                                      );
                                    }),
                                  ],
                                  onChanged: (value) {
                                    setState(() => _diveTypeId = value);
                                  },
                                ),
                          );
                        },
                      ),
                      const SizedBox(height: 24),

                      // Site Section
                      Text(
                        context.l10n.diveLog_filter_sectionDiveSite,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 8),
                      sites.when(
                        data: (siteList) => DropdownButtonFormField<String?>(
                          initialValue: _siteId,
                          decoration: InputDecoration(
                            hintText: context.l10n.diveLog_filter_allSites,
                            prefixIcon: const Icon(Icons.location_on),
                          ),
                          items: [
                            DropdownMenuItem(
                              value: null,
                              child: Text(context.l10n.diveLog_filter_allSites),
                            ),
                            ...siteList.map((site) {
                              return DropdownMenuItem(
                                value: site.id,
                                child: Text(site.name),
                              );
                            }),
                          ],
                          onChanged: (value) {
                            setState(() => _siteId = value);
                          },
                        ),
                        loading: () => const LinearProgressIndicator(),
                        error: (_, _) =>
                            Text(context.l10n.diveLog_filter_errorLoadingSites),
                      ),
                      const SizedBox(height: 24),

                      // Dive Computer Section
                      Text(
                        context.l10n.diveLog_filter_sectionDiveComputer,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 8),
                      Consumer(
                        builder: (context, ref, child) {
                          final computersAsync = ref.watch(
                            allDiveComputersProvider,
                          );
                          return computersAsync.when(
                            loading: () => const LinearProgressIndicator(),
                            error: (_, _) => Text(
                              context.l10n.transfer_computers_errorLoading,
                            ),
                            data: (computers) {
                              // Every registered computer is offered. The list used to
                              // be restricted to computers carrying a serial number,
                              // which hid every device whose firmware never reports one
                              // (issue #1064); attribution rides the computer id, which
                              // is always present.
                              if (computers.isEmpty) {
                                return Text(
                                  context
                                      .l10n
                                      .diveLog_filter_noComputersRegistered,
                                  style: Theme.of(context).textTheme.bodySmall
                                      ?.copyWith(
                                        color: Theme.of(
                                          context,
                                        ).colorScheme.onSurfaceVariant,
                                      ),
                                );
                              }
                              // Reset to null if the saved computer is no longer known
                              // (deleted since the filter was set).
                              final validId =
                                  computers.any((c) => c.id == _computerId)
                                  ? _computerId
                                  : null;
                              if (validId != _computerId) {
                                _computerId = validId;
                              }
                              return DropdownButtonFormField<String?>(
                                initialValue: validId,
                                decoration: InputDecoration(
                                  hintText:
                                      context.l10n.diveLog_filter_allComputers,
                                  prefixIcon: const Icon(Icons.watch),
                                ),
                                items: [
                                  DropdownMenuItem(
                                    value: null,
                                    child: Text(
                                      context.l10n.diveLog_filter_allComputers,
                                    ),
                                  ),
                                  ...computers.map(
                                    (c) => DropdownMenuItem(
                                      value: c.id,
                                      child: Text(c.displayName),
                                    ),
                                  ),
                                ],
                                onChanged: (value) {
                                  setState(() => _computerId = value);
                                },
                              );
                            },
                          );
                        },
                      ),
                      const SizedBox(height: 24),

                      // Depth Range Section
                      Text(
                        context.l10n.diveLog_filter_sectionDepthRangeUnit(
                          units.depthSymbol,
                        ),
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _minDepthController,
                              decoration: InputDecoration(
                                labelText: context.l10n.diveLog_filter_min,
                                prefixIcon: const Icon(Icons.arrow_downward),
                                suffixText: units.depthSymbol,
                              ),
                              keyboardType: TextInputType.number,
                              onChanged: (value) {
                                final entered = parseUserDecimal(value);
                                _minDepth = entered == null
                                    ? null
                                    : units.depthToMeters(entered);
                              },
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: TextField(
                              controller: _maxDepthController,
                              decoration: InputDecoration(
                                labelText: context.l10n.diveLog_filter_max,
                                prefixIcon: const Icon(Icons.arrow_downward),
                                suffixText: units.depthSymbol,
                              ),
                              keyboardType: TextInputType.number,
                              onChanged: (value) {
                                final entered = parseUserDecimal(value);
                                _maxDepth = entered == null
                                    ? null
                                    : units.depthToMeters(entered);
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),

                      // Favorites Section
                      SwitchListTile(
                        title: Text(context.l10n.diveLog_filter_favoritesOnly),
                        subtitle: Text(
                          context.l10n.diveLog_filter_showOnlyFavorites,
                        ),
                        secondary: Icon(
                          Icons.favorite,
                          color: _favoritesOnly ? Colors.red : null,
                        ),
                        value: _favoritesOnly,
                        onChanged: (value) {
                          setState(() => _favoritesOnly = value);
                        },
                      ),
                      const SizedBox(height: 24),

                      // Suit Thickness Section (equipment-attribute axis)
                      Text(
                        context.l10n.diveLog_filter_sectionSuitThickness,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              initialValue: _formatThicknessBound(
                                _suitThicknessMin,
                              ),
                              decoration: InputDecoration(
                                labelText:
                                    context.l10n.diveLog_filter_thicknessMin,
                              ),
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                    decimal: true,
                                  ),
                              onChanged: (value) => setState(
                                () => _suitThicknessMin = _parseThicknessBound(
                                  value,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: TextFormField(
                              initialValue: _formatThicknessBound(
                                _suitThicknessMax,
                              ),
                              decoration: InputDecoration(
                                labelText:
                                    context.l10n.diveLog_filter_thicknessMax,
                              ),
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                    decimal: true,
                                  ),
                              onChanged: (value) => setState(
                                () => _suitThicknessMax = _parseThicknessBound(
                                  value,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),

                      // Tags Section
                      Text(
                        context.l10n.diveLog_filter_sectionTags,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 8),
                      ref
                          .watch(tagListNotifierProvider)
                          .when(
                            data: (allTags) {
                              if (allTags.isEmpty) {
                                return Text(
                                  context.l10n.diveLog_filter_noTagsYet,
                                  style: const TextStyle(
                                    fontStyle: FontStyle.italic,
                                  ),
                                );
                              }
                              return Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: allTags.map((tag) {
                                  final isSelected = _selectedTagIds.contains(
                                    tag.id,
                                  );
                                  return FilterChip(
                                    label: Text(tag.name),
                                    selected: isSelected,
                                    selectedColor: tag.color.withValues(
                                      alpha: 0.3,
                                    ),
                                    checkmarkColor: tag.color,
                                    side: BorderSide(
                                      color: isSelected
                                          ? tag.color
                                          : Colors.grey.shade300,
                                    ),
                                    onSelected: (selected) {
                                      setState(() {
                                        if (selected) {
                                          _selectedTagIds.add(tag.id);
                                        } else {
                                          _selectedTagIds.remove(tag.id);
                                        }
                                      });
                                    },
                                  );
                                }).toList(),
                              );
                            },
                            loading: () => const CircularProgressIndicator(),
                            error: (_, _) => Text(
                              context.l10n.diveLog_filter_errorLoadingTags,
                            ),
                          ),
                      const SizedBox(height: 24),

                      // Buddy Name Filter Section
                      Text(
                        context.l10n.diveLog_filter_sectionBuddy,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 8),
                      LayoutBuilder(
                        builder: (context, _) {
                          final buddiesAsync = ref.watch(allBuddiesProvider);
                          final allBuddyNames =
                              buddiesAsync.valueOrNull
                                  ?.map((b) => b.name)
                                  .toSet()
                                  .toList() ??
                              const <String>[];

                          return RawAutocomplete<String>(
                            textEditingController: _buddyNameController,
                            focusNode: _buddyFocusNode,
                            optionsBuilder:
                                (TextEditingValue textEditingValue) {
                                  final text = textEditingValue.text;
                                  final parts = text
                                      .split(',')
                                      .map((e) => e.trim())
                                      .toList();
                                  final currentBuddies = parts.length > 1
                                      ? parts
                                            .sublist(0, parts.length - 1)
                                            .map((e) => e.toLowerCase())
                                            .toSet()
                                      : <String>{};

                                  final buddyNames = allBuddyNames
                                      .where(
                                        (name) => !currentBuddies.contains(
                                          name.toLowerCase(),
                                        ),
                                      )
                                      .toList();

                                  if (text.isEmpty) {
                                    return [];
                                  }

                                  final lastPart = text
                                      .split(',')
                                      .last
                                      .trim()
                                      .toLowerCase();

                                  if (lastPart.isEmpty) {
                                    return buddyNames;
                                  }

                                  return buddyNames.where((String option) {
                                    return option.toLowerCase().contains(
                                      lastPart,
                                    );
                                  }).toList();
                                },
                            onSelected: (String selection) {
                              final text = _buddyNameFilter ?? '';
                              final parts = text.split(',');
                              String newText;
                              if (parts.length > 1 || text.contains(',')) {
                                parts.removeLast();
                                final prefix = parts.join(',');
                                newText = prefix.trim().isEmpty
                                    ? selection
                                    : '${prefix.trim()}, $selection';
                              } else {
                                newText = selection;
                              }

                              _buddyNameController.text = newText;
                              _buddyNameController.selection =
                                  TextSelection.collapsed(
                                    offset: newText.length,
                                  );

                              setState(() {
                                _buddyNameFilter = newText;
                                _noBuddyOnly = false;
                              });
                            },
                            fieldViewBuilder:
                                (
                                  context,
                                  textEditingController,
                                  focusNode,
                                  onFieldSubmitted,
                                ) {
                                  return TextField(
                                    controller: textEditingController,
                                    focusNode: focusNode,
                                    decoration: InputDecoration(
                                      labelText:
                                          context.l10n.diveLog_filter_buddyName,
                                      hintText:
                                          context.l10n.diveLog_filter_buddyHint,
                                      prefixIcon: const Icon(Icons.person),
                                    ),
                                    onChanged: (value) {
                                      setState(() {
                                        _buddyNameFilter = value.isEmpty
                                            ? null
                                            : value;
                                        if (value.isNotEmpty) {
                                          _noBuddyOnly = false;
                                        }
                                      });
                                    },
                                    // Commits the highlighted suggestion when the
                                    // options list is open; a no-op otherwise, so
                                    // free-text entry still submits normally.
                                    onSubmitted: (_) => onFieldSubmitted(),
                                  );
                                },
                            optionsViewBuilder: (context, onSelected, options) {
                              return Align(
                                alignment: Alignment.topLeft,
                                child: Material(
                                  elevation: 4.0,
                                  child: ConstrainedBox(
                                    constraints: const BoxConstraints(
                                      maxHeight: 200,
                                    ),
                                    child: ListView.builder(
                                      padding: EdgeInsets.zero,
                                      shrinkWrap: true,
                                      itemCount: options.length,
                                      itemBuilder:
                                          (BuildContext context, int index) {
                                            final String option = options
                                                .elementAt(index);
                                            return ListTile(
                                              title: Text(option),
                                              onTap: () => onSelected(option),
                                            );
                                          },
                                    ),
                                  ),
                                ),
                              );
                            },
                          );
                        },
                      ),
                      const SizedBox(height: 8),
                      // Mutually exclusive with the buddy name filter above: a
                      // dive either has a buddy to search for, or has none.
                      SwitchListTile(
                        title: Text(context.l10n.diveLog_filter_noBuddyOnly),
                        subtitle: Text(
                          context.l10n.diveLog_filter_showOnlyNoBuddy,
                        ),
                        secondary: const Icon(Icons.person_off),
                        value: _noBuddyOnly,
                        onChanged: (value) {
                          setState(() {
                            _noBuddyOnly = value;
                            if (value) {
                              _buddyNameFilter = null;
                              _buddyNameController.clear();
                            }
                          });
                        },
                      ),
                      const SizedBox(height: 24),

                      // Gas Mix (O2%) Filter Section
                      Text(
                        context.l10n.diveLog_filter_sectionGasMix,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          ChoiceChip(
                            label: Text(context.l10n.diveLog_filter_gasAll),
                            selected:
                                _minO2Percent == null && _maxO2Percent == null,
                            onSelected: (selected) {
                              if (selected) {
                                setState(() {
                                  _minO2Percent = null;
                                  _maxO2Percent = null;
                                });
                              }
                            },
                          ),
                          ChoiceChip(
                            label: Text(context.l10n.diveLog_filter_gasAir),
                            selected:
                                _minO2Percent == 20 && _maxO2Percent == 22,
                            onSelected: (selected) {
                              if (selected) {
                                setState(() {
                                  _minO2Percent = 20;
                                  _maxO2Percent = 22;
                                });
                              }
                            },
                          ),
                          ChoiceChip(
                            label: Text(context.l10n.diveLog_filter_gasNitrox),
                            selected:
                                _minO2Percent == 22 && _maxO2Percent == null,
                            onSelected: (selected) {
                              if (selected) {
                                setState(() {
                                  _minO2Percent = 22;
                                  _maxO2Percent = null;
                                });
                              }
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),

                      // Rating Filter Section
                      Text(
                        context.l10n.diveLog_filter_sectionMinRating,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: List.generate(5, (index) {
                          final rating = index + 1;
                          final isSelected =
                              _minRating != null && rating <= _minRating!;
                          return IconButton(
                            icon: Icon(
                              isSelected ? Icons.star : Icons.star_border,
                              color: isSelected ? Colors.amber : null,
                              size: 32,
                            ),
                            tooltip: context.l10n
                                .diveSites_edit_rating_starTooltip(rating),
                            onPressed: () {
                              setState(() {
                                if (_minRating == rating) {
                                  _minRating = null; // Tap same star to clear
                                } else {
                                  _minRating = rating;
                                }
                              });
                            },
                          );
                        }),
                      ),
                      if (_minRating != null)
                        Align(
                          alignment: AlignmentDirectional.centerStart,
                          child: TextButton(
                            onPressed: () => setState(() => _minRating = null),
                            child: Text(
                              context.l10n.diveLog_filter_clearRating,
                            ),
                          ),
                        ),
                      const SizedBox(height: 24),

                      // Duration Range Filter Section
                      Text(
                        context.l10n.diveLog_filter_sectionDuration,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _minDurationController,
                              decoration: InputDecoration(
                                labelText: context.l10n.diveLog_filter_min,
                                prefixIcon: const Icon(Icons.timer),
                                suffixText:
                                    context.l10n.units_profileMetric_min,
                              ),
                              keyboardType: TextInputType.number,
                              onChanged: (value) {
                                _minDurationMinutes = parseUserInt(value);
                              },
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: TextField(
                              controller: _maxDurationController,
                              decoration: InputDecoration(
                                labelText: context.l10n.diveLog_filter_max,
                                prefixIcon: const Icon(Icons.timer),
                                suffixText:
                                    context.l10n.units_profileMetric_min,
                              ),
                              keyboardType: TextInputType.number,
                              onChanged: (value) {
                                _maxDurationMinutes = parseUserInt(value);
                              },
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const Divider(height: 1),
              _buildActions(context),
            ],
          ),
        );
      },
    );
  }

  /// Resize grip. Vertical drags on it move the sheet extent directly, in
  /// both directions.
  ///
  /// [DraggableScrollableSheet] only converts a drag into a resize when the
  /// drag reaches its inner scrollable while that list sits at offset zero,
  /// and Flutter's desktop scroll behaviour leaves the mouse out of
  /// `dragDevices` entirely. Between them, a macOS diver could shrink the
  /// sheet but never grow it back (#989).
  Widget _buildGrip(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return MouseRegion(
      cursor: SystemMouseCursors.resizeUpDown,
      child: GestureDetector(
        key: DiveFilterSheet.gripKey,
        behavior: HitTestBehavior.opaque,
        onVerticalDragUpdate: _resizeSheet,
        child: Semantics(
          label: context.l10n.diveLog_filter_resizeGrip,
          child: SizedBox(
            height: 28,
            width: double.infinity,
            child: Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _resizeSheet(DragUpdateDetails details) {
    if (!_sheetController.isAttached) return;
    // Dragging up gives a negative dy and has to grow the sheet, so the delta
    // is subtracted rather than added.
    final delta = _sheetController.pixelsToSize(details.delta.dy);
    _sheetController.jumpTo(
      (_sheetController.size - delta).clamp(_minSheetSize, _maxSheetSize),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsetsDirectional.only(start: 16, end: 4),
      child: Row(
        children: [
          // Expanded, not spaceBetween: a long localized title would otherwise
          // overflow the row instead of wrapping.
          Expanded(
            child: Text(
              context.l10n.diveLog_filter_title,
              style: Theme.of(context).textTheme.headlineSmall,
            ),
          ),
          IconButton(
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.close),
            tooltip: context.l10n.diveLog_filter_tooltip_close,
          ),
        ],
      ),
    );
  }

  Widget _buildActions(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: () {
                  widget.ref.read(widget.filterProvider.notifier).state =
                      const DiveFilterState();
                  Navigator.of(context).pop();
                },
                child: Text(context.l10n.diveLog_filter_clearAll),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: FilledButton(
                onPressed: _applyFilters,
                child: Text(context.l10n.diveLog_filter_apply),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _datePresetChip(
    BuildContext context,
    String label,
    VoidCallback onTap,
  ) {
    return ActionChip(
      label: Text(label, style: const TextStyle(fontSize: 12)),
      onPressed: onTap,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      visualDensity: VisualDensity.compact,
    );
  }

  Future<void> _selectDate(
    BuildContext context, {
    required bool isStart,
  }) async {
    final initialDate = isStart ? _startDate : _endDate;
    final firstDate = DateTime(1950);
    final lastDate = DateTime.now().add(const Duration(days: 365));

    final picked = await showAppDatePicker(
      context: context,
      initialDate: initialDate ?? DateTime.now(),
      firstDate: firstDate,
      lastDate: lastDate,
    );

    if (picked != null) {
      setState(() {
        if (isStart) {
          _startDate = picked;
        } else {
          _endDate = picked;
        }
      });
    }
  }

  void _applyFilters() {
    widget.ref.read(widget.filterProvider.notifier).state = DiveFilterState(
      startDate: _startDate,
      endDate: _endDate,
      diveTypeId: _diveTypeId,
      siteId: _siteId,
      minDepth: _minDepth,
      maxDepth: _maxDepth,
      favoritesOnly: _favoritesOnly ? true : null,
      tagIds: _selectedTagIds,
      weekdays: _selectedWeekdays,
      // v1.5 filters
      buddyNameFilter: _buddyNameFilter,
      noBuddyOnly: _noBuddyOnly ? true : null,
      minO2Percent: _minO2Percent,
      maxO2Percent: _maxO2Percent,
      minRating: _minRating,
      minBottomTimeMinutes: _minDurationMinutes,
      maxBottomTimeMinutes: _maxDurationMinutes,
      computerId: _computerId,
      equipmentAttrKey: (_suitThicknessMin != null || _suitThicknessMax != null)
          ? 'thickness_mm'
          : null,
      equipmentAttrMin: _suitThicknessMin,
      equipmentAttrMax: _suitThicknessMax,
    );
    Navigator.of(context).pop();
  }
}
