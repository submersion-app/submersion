import 'package:flutter/material.dart';

import 'package:submersion/core/domain/visibility/visibility_scale.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/utils/number_input.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/presentation/formatters/visibility_display.dart';
import 'package:submersion/features/dive_log/presentation/providers/visibility_input_mode_provider.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_detail/editing/dive_details_fields.dart';
import 'package:submersion/features/dive_log/presentation/widgets/visibility_input/visibility_entry.dart';
import 'package:submersion/features/dive_log/presentation/widgets/visibility_input/visibility_input.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/l10n_extension.dart';
import 'package:submersion/shared/widgets/forms/number_input_validation.dart';
import 'package:submersion/shared/widgets/record_editing/edit_session.dart';
import 'package:submersion/shared/widgets/record_editing/field_text_binding.dart';
import 'package:submersion/shared/widgets/record_editing/record_field_marks.dart';
import 'package:submersion/shared/widgets/record_editing/record_number_row.dart';
import 'package:submersion/shared/widgets/record_editing/reveal_answering.dart';
import 'package:submersion/shared/widgets/record_editing/text_keeping_caret.dart';

/// The visibility input of the Details card: a band or a measured distance,
/// bound to the sitting.
///
/// The sitting holds the visibility as one value ([diveVisibilityField]),
/// and whatever was set last is what is saved. The Range and Precise switch
/// only chooses which input is on show; it sets nothing. That is where this
/// differs from the dive form, in which the input showing at Save decides
/// what is written.
///
/// A distance is typed in the diver's depth unit. A number the row put on
/// show itself stands for the value behind it, so a visibility stored as
/// 12 m and shown as 39 ft is not rewritten by typing 39. Emptying the number means
/// no measurement: a dive stored with a range or a bucket goes back to it.
/// Text that is not a number, a negative one included, never reaches the
/// sitting, and holds the card open until it is fixed.
class DiveVisibilityRow extends ConsumerStatefulWidget {
  const DiveVisibilityRow({super.key, required this.session});

  final EditSession<Dive> session;

  @override
  ConsumerState<DiveVisibilityRow> createState() => _DiveVisibilityRowState();
}

class _DiveVisibilityRowState extends ConsumerState<DiveVisibilityRow>
    with
        RevealAnswering<DiveVisibilityRow>,
        RecordFieldMarks<Dive, DiveVisibilityRow> {
  late UnitFormatter _units = ref.read(unitFormatterProvider);
  late VisibilityInputMode _mode =
      widget.session.valueOf(diveVisibilityField).naturalMode ??
      ref.read(visibilityInputModeProvider);

  /// The text binding, made when the row first needs it. Never made on the
  /// way out: a row that goes before it has built must not start listening
  /// to a sitting that may already have ended.
  FieldTextBinding<Dive, StoredVisibility>? _bound;

  FieldTextBinding<Dive, StoredVisibility> get _binding => _bound ??= _bind();

  /// The distance whose number this row last put on show itself: the one it
  /// opened with, or one that arrived from elsewhere since. Null when that
  /// was no distance, or the diver has only typed.
  double? _onShowMeters;

  @override
  String get markCardId => diveVisibilityField.cardId;

  @override
  String get markFieldId => diveVisibilityField.id;

  FieldTextBinding<Dive, StoredVisibility> _bind() {
    return FieldTextBinding<Dive, StoredVisibility>(
      session: widget.session,
      field: diveVisibilityField,
      format: _show,
      parse: _parse,
      onUnreadableChanged: reportUnreadable,
    );
  }

  /// The text for a value this row is about to put on show.
  String _show(StoredVisibility value) {
    _onShowMeters = value.meters;
    return _format(value);
  }

  /// The measured distance in the diver's unit, or nothing when the dive
  /// has none. No decimals, as the dive form shows it.
  String _format(StoredVisibility value) {
    final meters = value.meters;
    if (meters == null) return '';
    return formatFixedForInput(_units.convertDepth(meters), 0);
  }

  /// The number the row shows for a distance of [meters].
  double? _shownNumber(double meters) =>
      switch (readNumber(_format(StoredVisibility(meters: meters)))) {
        NumberValue(:final value) => value,
        NumberBlank() || NumberInvalid() => null,
      };

  FieldInput<StoredVisibility> _parse(String text) {
    final session = widget.session;
    final current = session.valueOf(diveVisibilityField);
    final stored = StoredVisibility.of(session.stored);
    switch (readNumber(text, allowNegative: false)) {
      case NumberBlank():
        // An empty field while the sitting holds no measurement is no
        // change. Emptying one means no measurement.
        return FieldValue(
          current.meters == null
              ? current
              : visibilityWithNoMeasurement(stored),
        );
      case NumberInvalid():
        return const FieldUnreadable();
      case NumberValue(value: final typed):
        return FieldValue(
          StoredVisibility(
            meters: storedValueOfTyped(
              typed,
              onShow: _onShowMeters,
              stored: stored.meters,
              shownNumber: _shownNumber,
              fromDisplay: _units.depthToMeters,
            ),
          ),
        );
    }
  }

  void _setMode(VisibilityInputMode mode) {
    if (mode == _mode) return;
    // Text that is not a number was never a value, and once its input is
    // off screen there is nothing left to fix: show the sitting's value
    // again, which also withdraws the mark.
    if (_binding.isUnreadable) {
      _binding.controller.replaceTextKeepingCaret(
        _show(widget.session.valueOf(diveVisibilityField)),
      );
    }
    setState(() => _mode = mode);
  }

  /// What the sitting holds that the input on show cannot say: the band a
  /// distance falls in, the range a chip stands for, the range or bucket
  /// the dive keeps, or, in Range, a measured distance. No chip can show
  /// that last one, and it is what Save will write.
  String? _caption(
    StoredVisibility value,
    VisibilityBand? band,
    VisibilityScale scale,
    UnitFormatter units,
  ) {
    final meters = value.meters;
    if (_mode == VisibilityInputMode.range && meters != null) {
      return formatMeasuredVisibility(meters, scale, context.l10n, units);
    }
    return visibilityEntryCaption(
      mode: _mode,
      preciseMeters: meters,
      band: band,
      preciseTouched: false,
      rangeTouched: false,
      original: value,
      scale: scale,
      l10n: context.l10n,
      units: units,
    );
  }

  @override
  void didUpdateWidget(DiveVisibilityRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.session == widget.session) return;
    // Another sitting: its own text, and the input its own value opens in.
    withdrawMark();
    _bound?.dispose();
    _bound = null;
    _mode = widget.session.valueOf(diveVisibilityField).naturalMode ?? _mode;
  }

  @override
  void dispose() {
    _bound?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // The unit the number is typed in can change underneath the row.
    ref.listen(unitFormatterProvider, (_, units) {
      _units = units;
      _bound?.resync();
    });
    final units = ref.watch(unitFormatterProvider);
    final scale = ref.watch(settingsProvider.select((s) => s.visibilityScale));
    final session = widget.session;
    return ListenableBuilder(
      listenable: session,
      builder: (context, _) {
        final value = session.valueOf(diveVisibilityField);
        final range = value.range;
        // The chip whose range the sitting holds. A range stored under
        // another scale matches none, and shows as the caption instead.
        final band = range == null ? null : scale.bandMatching(range);
        return VisibilityInput(
          mode: _mode,
          onModeChanged: _setMode,
          controller: _binding.controller,
          depthSymbol: units.depthSymbol,
          inputValidator: numberValidator(context, allowNegative: false),
          // The binding listens to the controller itself.
          onPreciseChanged: (_) {},
          band: band,
          onBandChanged: (picked) => session.set(
            diveVisibilityField,
            visibilityForBand(picked, scale),
          ),
          caption: _caption(value, band, scale, units),
        );
      },
    );
  }
}
