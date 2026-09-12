import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
import 'package:submersion/features/equipment/presentation/utils/child_installed_text.dart';
import 'package:submersion/features/equipment/presentation/utils/equipment_enum_display.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// The details row on a part's page naming the item it is installed in
/// (`parentEquipmentId`, the link the host's children card lists from the
/// other side), tappable to open it. While the part is fitted it carries
/// the install age; once retired it reads "Was installed in", since the
/// part keeps its parent id after a replace.
///
/// Deliberately not the assemblies wording (issue #1487): "Part of" and
/// "Components" belong to ComponentsCard.
class InstalledInRow extends StatelessWidget {
  /// The part whose page this is.
  final EquipmentItem part;

  /// The item [part] is installed in, already resolved; the page shows no
  /// row at all when the parent id names nothing.
  final EquipmentItem host;

  final UnitFormatter units;

  const InstalledInRow({
    super.key,
    required this.part,
    required this.host,
    required this.units,
  });

  /// Whether the row carries the install date, so the page can drop the
  /// plain install-date spec row rather than show the date twice.
  static bool showsInstallAge(EquipmentItem part, EquipmentItem? host) =>
      host != null && part.isFitted;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final age = showsInstallAge(part, host)
        ? childInstalledText(l10n, units, part)
        : null;
    // Its own node: the Details card merges every child into one semantics
    // node, which read this link run together with the other rows and gave
    // it no tap of its own. The node's label is the row's visible text,
    // already localized, tensed and carrying the host's status, so no
    // custom label repeats it.
    return Semantics(
      container: true,
      button: true,
      child: InkWell(
        key: const ValueKey('equipment-detail-installed-in'),
        onTap: () => context.push('/equipment/${host.id}'),
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    part.isFitted
                        ? l10n.equipment_detail_installedInLabel
                        : l10n.equipment_detail_wasInstalledInLabel,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Flexible(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Flexible(
                          child: Text(
                            _hostLabel(l10n),
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: theme.colorScheme.primary,
                            ),
                            textAlign: TextAlign.end,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Icon(
                          Icons.chevron_right,
                          size: 18,
                          color: theme.colorScheme.primary,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              if (age != null)
                Text(
                  age,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  textAlign: TextAlign.end,
                ),
            ],
          ),
        ),
      ),
    );
  }

  /// The host's name, with its status when it is out of service.
  String _hostLabel(AppLocalizations l10n) {
    if (host.isFitted) return host.name;
    // A legacy row can be inactive under a non-terminal status; it is out
    // of service all the same, and reads as retired like the header chip.
    final status =
        host.status == EquipmentStatus.retired ||
            host.status == EquipmentStatus.sold
        ? host.status.localizedName(l10n)
        : l10n.equipment_detail_retiredChip;
    return l10n.equipment_detail_parentWithStatus(host.name, status);
  }
}
