import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_repository_provider.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/l10n/l10n_extension.dart';
import 'package:submersion/core/utils/log_failure.dart';

/// Modal dive picker used by "Move to dive" and inbox linking. Resolves to
/// the chosen dive id, or null on dismiss.
Future<String?> showDivePickerSheet(BuildContext context) {
  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    builder: (_) => const _DivePickerSheet(),
  );
}

class _DivePickerSheet extends ConsumerStatefulWidget {
  const _DivePickerSheet();

  @override
  ConsumerState<_DivePickerSheet> createState() => _DivePickerSheetState();
}

class _DivePickerSheetState extends ConsumerState<_DivePickerSheet> {
  List<Dive>? _dives;
  String _query = '';

  @override
  void initState() {
    super.initState();
    logFailure(_load(), _DivePickerSheetState, 'load');
  }

  Future<void> _load() async {
    final dives = await ref
        .read(diveRepositoryProvider)
        .getAllDives(diverId: ref.read(currentDiverIdProvider));
    if (mounted) setState(() => _dives = dives);
  }

  String _label(Dive dive) {
    final parts = <String>[
      if (dive.diveNumber != null) '#${dive.diveNumber}',
      if (dive.name != null && dive.name!.isNotEmpty)
        dive.name!
      else if (dive.site?.name != null)
        dive.site!.name,
    ];
    return parts.join(' ');
  }

  bool _matches(Dive dive) {
    if (_query.isEmpty) return true;
    final q = _query.toLowerCase();
    return (dive.diveNumber?.toString().contains(q) ?? false) ||
        (dive.name?.toLowerCase().contains(q) ?? false) ||
        (dive.site?.name.toLowerCase().contains(q) ?? false);
  }

  @override
  Widget build(BuildContext context) {
    final locale = Localizations.localeOf(context).toString();
    final dives = _dives;
    final visible = dives?.where(_matches).toList();

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: SizedBox(
          height: MediaQuery.of(context).size.height * 0.7,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
                child: Text(
                  context.l10n.media_divePicker_title,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 4,
                ),
                child: TextField(
                  autofocus: false,
                  decoration: InputDecoration(
                    prefixIcon: const Icon(Icons.search),
                    hintText: context.l10n.media_divePicker_search,
                    isDense: true,
                  ),
                  onChanged: (value) => setState(() => _query = value),
                ),
              ),
              Expanded(
                child: visible == null
                    ? const Center(child: CircularProgressIndicator())
                    : ListView.builder(
                        itemCount: visible.length,
                        itemBuilder: (context, index) {
                          final dive = visible[index];
                          return ListTile(
                            title: Text(_label(dive)),
                            subtitle: Text(
                              DateFormat.yMMMd(locale).format(dive.dateTime),
                            ),
                            onTap: () => Navigator.of(context).pop(dive.id),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
