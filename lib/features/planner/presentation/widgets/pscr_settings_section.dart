import 'dart:async';

import 'package:flutter/material.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// pSCR ratio control for a passive semi-closed rebreather plan. The ratio is a
/// global equipment preference (Subsurface `pscr_ratio`): larger values add
/// more fresh gas and shrink the inspired-O2 drop.
class PscrSettingsSection extends ConsumerStatefulWidget {
  const PscrSettingsSection({super.key});

  @override
  ConsumerState<PscrSettingsSection> createState() =>
      _PscrSettingsSectionState();
}

class _PscrSettingsSectionState extends ConsumerState<PscrSettingsSection> {
  static const _debounceDelay = Duration(milliseconds: 300);

  late final TextEditingController _ratioController;
  final FocusNode _focusNode = FocusNode();
  Timer? _debounce;
  double? _pending;

  @override
  void initState() {
    super.initState();
    _ratioController = TextEditingController(
      text: _format(ref.read(pscrRatioProvider)),
    );
    // On blur, persist any pending edit immediately, then re-sync to the
    // authoritative (clamped) value.
    _focusNode.addListener(() {
      if (!_focusNode.hasFocus) {
        _flush();
        _syncFromProvider(ref.read(pscrRatioProvider));
      }
    });
  }

  @override
  void dispose() {
    _flush();
    _debounce?.cancel();
    _ratioController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  String _format(double ratio) => ratio.toStringAsFixed(0);

  /// Mirror [ratio] into the field unless the user is actively editing it, so
  /// external/async changes never clobber in-progress input.
  void _syncFromProvider(double ratio) {
    if (_focusNode.hasFocus) return;
    final text = _format(ratio);
    if (_ratioController.text != text) _ratioController.text = text;
  }

  void _onChanged(String text) {
    final parsed = double.tryParse(text);
    if (parsed == null || parsed <= 0) {
      // Invalid/empty input: drop any pending valid value and cancel the
      // debounce so an earlier edit can't flush after the user has cleared or
      // invalidated the field. The field re-syncs to the saved value on blur.
      _debounce?.cancel();
      _pending = null;
      return;
    }
    _pending = parsed;
    // Debounce persistence: a burst of keystrokes collapses to a single,
    // ordered save of the final value rather than overlapping writes.
    _debounce?.cancel();
    _debounce = Timer(_debounceDelay, _flush);
  }

  void _flush() {
    _debounce?.cancel();
    final value = _pending;
    if (value == null) return;
    _pending = null;
    ref.read(settingsProvider.notifier).setPscrRatio(value);
  }

  @override
  Widget build(BuildContext context) {
    // pscrRatio loads asynchronously (SharedPreferences) and can change
    // elsewhere; keep the field in sync when the diver is not editing it.
    ref.listen<double>(pscrRatioProvider, (_, next) => _syncFromProvider(next));

    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Row(
        children: [
          Expanded(
            child: TextFormField(
              controller: _ratioController,
              focusNode: _focusNode,
              decoration: InputDecoration(
                labelText: context.l10n.plannerCanvas_pscr_ratio,
                helperText: context.l10n.plannerCanvas_pscr_ratio_hint,
                isDense: true,
                border: const OutlineInputBorder(),
              ),
              keyboardType: const TextInputType.numberWithOptions(),
              onChanged: _onChanged,
            ),
          ),
        ],
      ),
    );
  }
}
