import 'package:flutter/material.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/equipment/domain/constants/equipment_attribute_catalog.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_attribute.dart';
import 'package:submersion/features/equipment/domain/entities/other_gear_retype.dart';
import 'package:submersion/features/equipment/presentation/other_gear_retype_actions.dart';
import 'package:submersion/features/equipment/presentation/providers/other_gear_retype_providers.dart';
import 'package:submersion/features/equipment/presentation/utils/equipment_attribute_units.dart';
import 'package:submersion/features/equipment/presentation/utils/equipment_enum_display.dart';
import 'package:submersion/features/equipment/presentation/widgets/service_status_indicator.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// Settings > Data Tools > Retype gear marked Other (#1886): gives gear that
/// earlier imports stored as Other the type its name states, after the diver
/// reviews each item, with Undo.
class RetypeOtherGearPage extends ConsumerStatefulWidget {
  const RetypeOtherGearPage({super.key});

  @override
  ConsumerState<RetypeOtherGearPage> createState() =>
      _RetypeOtherGearPageState();
}

class _RetypeOtherGearPageState extends ConsumerState<RetypeOtherGearPage> {
  /// Equipment ids the diver unticked.
  Set<String> _excluded = const {};
  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final candidatesAsync = ref.watch(otherGearRetypeCandidatesProvider);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.equipment_retypeOther_title)),
      body: candidatesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) =>
            _message(l10n.equipment_retypeOther_errorLoading('$error')),
        data: (candidates) => candidates == null || candidates.isEmpty
            ? _message(l10n.equipment_retypeOther_empty)
            : _content(candidates),
      ),
    );
  }

  Widget _message(String text) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Text(text, textAlign: TextAlign.center),
    ),
  );

  Widget _content(List<RetypeCandidate> candidates) {
    final l10n = context.l10n;
    final units = UnitFormatter(ref.watch(settingsProvider));
    final selected = [
      for (final c in candidates)
        if (!_excluded.contains(c.item.id)) c,
    ];
    final allSelected = selected.length == candidates.length;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(16, 12, 8, 4),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  l10n.equipment_retypeOther_intro,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ),
              TextButton(
                onPressed: () => setState(
                  () => _excluded = allSelected
                      ? {for (final c in candidates) c.item.id}
                      : const {},
                ),
                child: Text(
                  allSelected
                      ? l10n.equipment_retypeOther_deselectAll
                      : l10n.equipment_retypeOther_selectAll,
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            itemCount: candidates.length,
            itemBuilder: (context, i) {
              final candidate = candidates[i];
              final id = candidate.item.id;
              return CheckboxListTile(
                key: ValueKey(id),
                controlAffinity: ListTileControlAffinity.leading,
                value: !_excluded.contains(id),
                onChanged: (value) => setState(
                  () => _excluded = (value ?? false)
                      ? {
                          for (final other in _excluded)
                            if (other != id) other,
                        }
                      : {..._excluded, id},
                ),
                title: Text(candidate.item.name),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(_proposal(candidate, units)),
                    ServiceStatusIndicatorFor(
                      equipmentId: candidate.item.id,
                      density: ServiceIndicatorDensity.compact,
                    ),
                  ],
                ),
              );
            },
          ),
        ),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: selected.isEmpty || _busy
                    ? null
                    : () => _retype(selected),
                child: Text(l10n.equipment_retypeOther_apply(selected.length)),
              ),
            ),
          ),
        ),
      ],
    );
  }

  /// "Becomes Wetsuit", or "Becomes Wetsuit, 7 mm" when retyping also writes
  /// the thickness, formatted as the item's detail page shows it.
  String _proposal(RetypeCandidate candidate, UnitFormatter units) {
    final l10n = context.l10n;
    final type = candidate.type.localizedName(l10n);
    final thickness = candidate.thickness;
    if (thickness == null) return l10n.equipment_retypeOther_becomes(type);
    final shown = formatAttributeValue(
      EquipmentAttribute.curated(
        equipmentId: candidate.item.id,
        key: EquipmentAttrKeys.thicknessMm,
        valueText: thickness,
      ),
      EquipmentAttributeCatalog.defFor(EquipmentAttrKeys.thicknessMm),
      units,
      l10n,
    );
    return l10n.equipment_retypeOther_becomesWithThickness(type, shown);
  }

  Future<void> _retype(List<RetypeCandidate> selected) async {
    final l10n = context.l10n;
    final messenger = ScaffoldMessenger.of(context);
    final container = ProviderScope.containerOf(context, listen: false);
    setState(() => _busy = true);
    await applyOtherGearRetype(
      container: container,
      messenger: messenger,
      l10n: l10n,
      candidates: selected,
    );
    if (!mounted) return;
    setState(() {
      _busy = false;
      _excluded = const {};
    });
  }
}
