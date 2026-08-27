import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:submersion/core/constants/units.dart';
import 'package:submersion/core/utils/number_input.dart';
import 'package:submersion/features/dive_3d/domain/spatial/seascape_appearance.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// Opens the terrain-appearance editor for the seascape views.
void showTerrainAppearanceSheet(BuildContext context) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    // A scroll-controlled sheet grows to whatever its content asks for, and
    // this content is taller than a phone. Left alone it reached y=0, putting
    // the drag handle inside Android's notification-shade swipe zone -- so
    // pulling the sheet down opened the system shade instead of closing it,
    // and the sheet could not be dismissed at all (issue #1188). The safe
    // area keeps it clear of the status bar; the height cap leaves a strip of
    // scrim above it so tapping outside stays an obvious way out.
    useSafeArea: true,
    showDragHandle: true,
    constraints: BoxConstraints(
      maxHeight: MediaQuery.of(context).size.height * _maxHeightFraction,
    ),
    // The custom-level rows open a keypad. Without a viewInsets pad the sheet
    // keeps its full height, so the lower rows and the add button sit behind
    // the keyboard with no scroll extent left to bring them up (issue #1094).
    // Not redundant with useSafeArea: that inserts SafeArea(bottom: false),
    // so the sheet deliberately runs to the bottom edge of the screen. This
    // one supplies the bottom inset the outer one skips, keeping the last
    // control clear of the home indicator. Nothing is applied twice -- a
    // SafeArea strips the padding it consumes out of the MediaQuery, so the
    // horizontal insets are already zero by the time this one reads them.
    builder: (sheetContext) => SafeArea(
      child: Padding(
        key: const ValueKey('terrainAppearanceSheetInsets'),
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(sheetContext).viewInsets.bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _SheetHeader(onClose: () => Navigator.of(sheetContext).pop()),
            // Loose fit: the sheet still hugs short content, but a body
            // taller than the cap scrolls under the pinned header instead of
            // pushing it (and the close action) off the screen.
            const Flexible(
              child: SingleChildScrollView(child: TerrainAppearanceSheet()),
            ),
          ],
        ),
      ),
    ),
  );
}

/// Share of the screen the sheet may occupy at most.
const double _maxHeightFraction = 0.85;

/// Title plus an explicit way out. The drag handle alone is not enough on
/// Android, where a downward drag near the top edge belongs to the system.
class _SheetHeader extends StatelessWidget {
  final VoidCallback onClose;

  const _SheetHeader({required this.onClose});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 8, 8),
      child: Row(
        children: [
          Expanded(
            child: Text(
              context.l10n.dive3d_seascape_appearance,
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
          TextButton(
            key: const ValueKey('terrainAppearanceCloseButton'),
            onPressed: onClose,
            child: Text(context.l10n.common_action_close),
          ),
        ],
      ),
    );
  }
}

/// Issue #1065 knobs: ramp depth range, banded gradient, contour mode with
/// a custom level editor, line thickness, steep-wall angle. Every change
/// writes straight through SettingsNotifier (device-local persistence),
/// so both seascape pages and their providers react immediately.
class TerrainAppearanceSheet extends ConsumerWidget {
  const TerrainAppearanceSheet({super.key});

  static const List<int?> _palette = [
    null, // default ink
    0xFFEF4444,
    0xFFF97316,
    0xFFFDE047,
    0xFF10B981,
    0xFF3B82F6,
    0xFFA855F7,
  ];
  static const double _defaultRampMaxMeters = 40.0;

  /// Seed for a newly added custom level, in DISPLAY units: the editor rows
  /// read in the diver's unit, so a fixed metric seed would greet a feet
  /// diver with 32.8 rather than a round number.
  static const double _defaultNewLevelDisplay = 10.0;

  /// Vertical rhythm. The sheet stacks segmented buttons, switches, sliders
  /// and a row editor, each of which brings its own padding, so the gaps are
  /// named here to keep one consistent scale instead of ad-hoc spacers.
  static const _labelGap = SizedBox(height: 8);
  static const _controlGap = SizedBox(height: 16);
  static const _sectionRule = Divider(height: 40);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final appearance = ref.watch(
      settingsProvider.select((s) => s.seascapeAppearance),
    );
    final depthUnit = ref.watch(settingsProvider.select((s) => s.depthUnit));
    final unitInMeters = depthUnit == DepthUnit.feet ? 0.3048 : 1.0;
    final notifier = ref.read(settingsProvider.notifier);
    void update(SeascapeAppearance next) =>
        notifier.setSeascapeAppearance(next);

    String depthText(double meters) =>
        '${_formatDisplay(meters / unitInMeters)} ${depthUnit.symbol}';

    final rampMax = appearance.rampMaxDepthMeters;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l10n.dive3d_seascape_appearance_surface),
          _labelGap,
          SegmentedButton<SeascapeSurfaceMode>(
            key: const ValueKey('seascapeSurfaceModeSegments'),
            segments: [
              ButtonSegment(
                value: SeascapeSurfaceMode.depth,
                label: Text(l10n.dive3d_seascape_appearance_surfaceDepth),
              ),
              ButtonSegment(
                value: SeascapeSurfaceMode.imagery,
                label: Text(l10n.dive3d_seascape_appearance_surfaceImagery),
              ),
              ButtonSegment(
                value: SeascapeSurfaceMode.blend,
                label: Text(l10n.dive3d_seascape_appearance_surfaceBlend),
              ),
            ],
            selected: {appearance.surfaceMode},
            onSelectionChanged: (sel) =>
                update(appearance.copyWith(surfaceMode: sel.single)),
          ),
          _controlGap,
          SwitchListTile(
            key: const ValueKey('seascapeRampRangeSwitch'),
            contentPadding: EdgeInsets.zero,
            title: Text(l10n.dive3d_seascape_appearance_rampRange),
            value: rampMax != null,
            onChanged: (on) => update(
              on
                  ? appearance.copyWith(
                      rampMaxDepthMeters: _defaultRampMaxMeters,
                    )
                  : appearance.copyWith(clearRampMax: true),
            ),
          ),
          if (rampMax != null)
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(l10n.dive3d_seascape_appearance_rampMax),
              subtitle: Slider(
                key: const ValueKey('seascapeRampMaxSlider'),
                min: 5,
                max: 200,
                value: (rampMax / unitInMeters).clamp(5.0, 200.0),
                onChanged: (v) => update(
                  appearance.copyWith(
                    rampMaxDepthMeters: v.roundToDouble() * unitInMeters,
                  ),
                ),
              ),
              trailing: Text(depthText(rampMax)),
            ),
          SwitchListTile(
            key: const ValueKey('seascapeBandedSwitch'),
            contentPadding: EdgeInsets.zero,
            title: Text(l10n.dive3d_seascape_appearance_banded),
            value: appearance.rampBanded,
            onChanged: (on) => update(appearance.copyWith(rampBanded: on)),
          ),
          _sectionRule,
          Text(l10n.dive3d_seascape_appearance_contours),
          _labelGap,
          SegmentedButton<SeascapeContourMode>(
            key: const ValueKey('seascapeContourModeSegments'),
            segments: [
              ButtonSegment(
                value: SeascapeContourMode.auto,
                label: Text(l10n.dive3d_seascape_appearance_contourAuto),
              ),
              ButtonSegment(
                value: SeascapeContourMode.custom,
                label: Text(l10n.dive3d_seascape_appearance_contourCustom),
              ),
            ],
            selected: {appearance.contourMode},
            onSelectionChanged: (sel) =>
                update(appearance.copyWith(contourMode: sel.single)),
          ),
          if (appearance.contourMode == SeascapeContourMode.custom) ...[
            _labelGap,
            for (var i = 0; i < appearance.customLevels.length; i++)
              _LevelRow(
                key: ValueKey('seascapeLevelRow$i'),
                index: i,
                level: appearance.customLevels[i],
                unitInMeters: unitInMeters,
                unitSymbol: depthUnit.symbol,
                notifier: notifier,
              ),
            TextButton.icon(
              key: const ValueKey('seascapeAddLevelButton'),
              icon: const Icon(Icons.add),
              label: Text(l10n.dive3d_seascape_appearance_addLevel),
              onPressed: () => update(
                appearance.copyWith(
                  customLevels: [
                    ...appearance.customLevels,
                    SeascapeContourLevel(
                      depthMeters: _defaultNewLevelDisplay * unitInMeters,
                    ),
                  ],
                ),
              ),
            ),
          ],
          _sectionRule,
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(l10n.dive3d_seascape_appearance_wallAngle),
            subtitle: Slider(
              key: const ValueKey('seascapeWallAngleSlider'),
              min: 5,
              max: 90,
              divisions: 85,
              value: appearance.wallAngleDeg.clamp(5.0, 90.0),
              onChanged: (v) =>
                  update(appearance.copyWith(wallAngleDeg: v.roundToDouble())),
            ),
            trailing: Text('${appearance.wallAngleDeg.round()}°'),
          ),
          Text(
            l10n.dive3d_seascape_appearance_wallAngleNote,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}

/// Depth in the diver's unit, trimmed to a whole number when it is one and
/// written with the diver's decimal separator so the field can be read back
/// (#1091).
String _formatDisplay(double display) => formatRoundedForInput(display, 1);

/// One custom contour level. Stateful because the depth box owns a controller:
/// a decimal keypad offers no submit key, so the row commits when the field
/// loses focus and again if the sheet is dismissed with an edit still pending
/// (issue #1094 — typed levels used to be discarded outright).
///
/// Every mutation reads the CURRENT appearance out of the container rather
/// than a value captured at build time, so a commit that lands after the row
/// is gone cannot resurrect a level the diver just deleted.
class _LevelRow extends StatefulWidget {
  final int index;
  final SeascapeContourLevel level;
  final double unitInMeters;
  final String unitSymbol;
  final SettingsNotifier notifier;

  const _LevelRow({
    super.key,
    required this.index,
    required this.level,
    required this.unitInMeters,
    required this.unitSymbol,
    required this.notifier,
  });

  @override
  State<_LevelRow> createState() => _LevelRowState();
}

class _LevelRowState extends State<_LevelRow> {
  late final TextEditingController _controller;
  late final FocusNode _focusNode;

  /// Captured once so a commit deferred past disposal still has a live handle
  /// to read the settings from; `listen: false` because this runs outside
  /// build. The app-level container outlives the sheet.
  late final ProviderContainer _container;

  double get _display => widget.level.depthMeters / widget.unitInMeters;

  /// Null once the scope is gone. The disposal commit runs during teardown,
  /// which in tests can land after the container has been torn down, and
  /// reading a disposed container throws. Disposing a container disposes its
  /// notifiers too, so the notifier's mounted flag is the public proxy for
  /// "is this container still readable".
  SeascapeAppearance? get _appearance => widget.notifier.mounted
      ? _container.read(settingsProvider).seascapeAppearance
      : null;

  @override
  void initState() {
    super.initState();
    _container = ProviderScope.containerOf(context, listen: false);
    _controller = TextEditingController(text: _formatDisplay(_display));
    _focusNode = FocusNode()..addListener(_onFocusChange);
  }

  @override
  void didUpdateWidget(covariant _LevelRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Rows are keyed by index, so a deleted row shifts its neighbours up and a
    // unit switch restates every level. Re-seed whenever the value this row
    // represents actually moved; mid-typing it never does, so this cannot
    // clobber the diver's keystrokes.
    final wasDisplay = oldWidget.level.depthMeters / oldWidget.unitInMeters;
    if ((wasDisplay - _display).abs() > 1e-9) {
      _controller.text = _formatDisplay(_display);
    }
  }

  @override
  void dispose() {
    _focusNode.removeListener(_onFocusChange);
    final pending = _pendingAppearance();
    if (pending != null) {
      // Unmounting runs inside a state-locked finalizeTree, so notifying
      // Riverpod here directly would trip markNeedsBuild. Land it after.
      final notifier = widget.notifier;
      scheduleMicrotask(() {
        if (notifier.mounted) notifier.setSeascapeAppearance(pending);
      });
    }
    _focusNode.dispose();
    _controller.dispose();
    super.dispose();
  }

  void _onFocusChange() {
    if (_focusNode.hasFocus || !mounted) return;
    final pending = _pendingAppearance();
    if (pending != null) {
      widget.notifier.setSeascapeAppearance(pending);
    } else {
      // Unparseable or non-positive: put the stored level back on screen
      // rather than leaving a number that will never be adopted.
      _controller.text = _formatDisplay(_display);
    }
  }

  /// The appearance this row's box would produce, or null when the text is
  /// unusable or already matches what is stored.
  SeascapeAppearance? _pendingAppearance() {
    // Read in the diver's locale, matching _formatDisplay. A blanket
    // replaceAll(',', '.') would misread the en_US thousands separator,
    // turning "1,250" into 1.25 (#1091).
    final typed = parseUserDecimal(_controller.text);
    if (typed == null || !typed.isFinite || typed <= 0) return null;
    final appearance = _appearance;
    if (appearance == null || widget.index >= appearance.customLevels.length) {
      return null;
    }
    final current = appearance.customLevels[widget.index];
    // Compare in DISPLAY space at the precision the box actually shows. The
    // box renders one decimal, so 30 m reads as "98.4" ft and parsing that
    // back gives 29.99232 m; a metres comparison would call that an edit and
    // shave the level a little on every blur and every dismissal.
    if (_formatDisplay(current.depthMeters / widget.unitInMeters) ==
        _formatDisplay(typed)) {
      return null;
    }
    final meters = typed * widget.unitInMeters;
    return appearance.copyWith(
      customLevels: _replace(
        appearance,
        SeascapeContourLevel(depthMeters: meters, colorArgb: current.colorArgb),
      ),
    );
  }

  List<SeascapeContourLevel> _replace(
    SeascapeAppearance appearance,
    SeascapeContourLevel? next,
  ) => [
    for (var i = 0; i < appearance.customLevels.length; i++)
      if (i != widget.index) appearance.customLevels[i] else ?next,
  ];

  void _write(SeascapeContourLevel? next) {
    final appearance = _appearance;
    if (appearance == null || widget.index >= appearance.customLevels.length) {
      return;
    }
    widget.notifier.setSeascapeAppearance(
      appearance.copyWith(customLevels: _replace(appearance, next)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      // The boxes carry their own border, so without this the rows read as
      // one dense block rather than a list.
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          SizedBox(
            width: 120,
            child: TextField(
              key: ValueKey('seascapeLevelField${widget.index}'),
              controller: _controller,
              focusNode: _focusNode,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              textInputAction: TextInputAction.done,
              // The bare number read as ambiguous between metres and feet
              // (issue #1094); the box now carries the diver's own unit.
              decoration: InputDecoration(suffixText: widget.unitSymbol),
              onTapOutside: (_) => _focusNode.unfocus(),
              onEditingComplete: _focusNode.unfocus,
              onSubmitted: (_) => _focusNode.unfocus(),
            ),
          ),
          const SizedBox(width: 12),
          // Expanded rather than a trailing Spacer: the "default ink" entry is a
          // translated phrase, and a Spacer cannot give back space once the row
          // is full, so a long translation used to overflow a phone row.
          Expanded(
            child: DropdownButton<int?>(
              key: ValueKey('seascapeLevelColor${widget.index}'),
              value: widget.level.colorArgb,
              isExpanded: true,
              items: [
                for (final c in TerrainAppearanceSheet._palette)
                  DropdownMenuItem(
                    value: c,
                    child: c == null
                        ? Text(
                            context
                                .l10n
                                .dive3d_seascape_appearance_defaultColor,
                            overflow: TextOverflow.ellipsis,
                          )
                        : CircleAvatar(radius: 8, backgroundColor: Color(c)),
                  ),
              ],
              onChanged: (c) => _write(
                SeascapeContourLevel(
                  depthMeters: widget.level.depthMeters,
                  colorArgb: c,
                ),
              ),
            ),
          ),
          IconButton(
            key: ValueKey('seascapeLevelRemove${widget.index}'),
            icon: const Icon(Icons.delete_outline),
            onPressed: () {
              // Drop focus first so the row being removed cannot commit its old
              // text back over the shifted list on the way out.
              _focusNode.unfocus();
              _write(null);
            },
          ),
        ],
      ),
    );
  }
}
