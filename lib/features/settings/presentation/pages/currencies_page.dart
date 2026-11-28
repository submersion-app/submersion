import 'package:flutter/foundation.dart' show listEquals;
import 'package:flutter/material.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/utils/currency.dart';
import 'package:submersion/core/utils/currency_catalog.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/features/settings/presentation/widgets/currency_picker.dart';
import 'package:submersion/l10n/l10n_extension.dart';

const _tilePadding = EdgeInsetsDirectional.only(start: 8, end: 16);

/// The drag handle's width in an enabled row.
const _handleWidth = 32.0;

/// One place for the diver's currencies (issue #4997): which ones every
/// currency picker lists first and in what order, and which one is the
/// default for new records.
///
/// The enabled currencies lead the page and can be dragged into order; the
/// rest of the ISO 4217 catalog follows, searchable, and a switch moves a
/// currency between the two. The default currency is always enabled.
class CurrenciesPage extends ConsumerStatefulWidget {
  const CurrenciesPage({super.key});

  @override
  ConsumerState<CurrenciesPage> createState() => _CurrenciesPageState();
}

class _CurrenciesPageState extends ConsumerState<CurrenciesPage> {
  String _query = '';

  SettingsNotifier get _notifier => ref.read(settingsProvider.notifier);

  void _setEnabled(List<String> codes) =>
      _notifier.setPreferredCurrencyCodes(codes);

  /// Makes [code] the default. A default shown enabled only because it is
  /// the default is stored first, so moving the star does not drop it.
  void _setDefault(String code, List<String> enabled) {
    if (!listEquals(enabled, ref.read(preferredCurrencyCodesProvider))) {
      _setEnabled(enabled);
    }
    _notifier.setDefaultCurrency(code);
  }

  void _reset(String defaultCode, List<String> enabled) {
    _setEnabled(
      currencyCodesWith(defaultCode, preferred: kDefaultPreferredCurrencyCodes),
    );
    final l10n = context.l10n;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(l10n.settings_currencies_resetDone),
          persist: false,
          duration: const Duration(seconds: 5),
          action: SnackBarAction(
            label: l10n.settings_currencies_undo,
            onPressed: () => _setEnabled(enabled),
          ),
        ),
      );
  }

  void _reorder(List<String> enabled, int oldIndex, int newIndex) {
    final updated = [...enabled];
    final code = updated.removeAt(oldIndex);
    updated.insert(newIndex, code);
    _setEnabled(updated);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final defaultCode = ref.watch(defaultCurrencyProvider);
    final enabled = currencyCodesWith(
      defaultCode,
      preferred: ref.watch(preferredCurrencyCodesProvider),
    );
    final others = [
      for (final code in allCurrencyCodesWith(
        defaultCode,
        preferred: enabled,
      ).skip(enabled.length))
        if (currencyMatchesQuery(code, _query)) code,
    ];

    Widget header(String text) => Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      child: Text(
        text,
        style: theme.textTheme.titleSmall?.copyWith(
          color: theme.colorScheme.primary,
          fontWeight: FontWeight.bold,
        ),
      ),
    );

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.settings_currencies_title),
        actions: [
          IconButton(
            key: const Key('currencies-reset'),
            icon: const Icon(Icons.restart_alt),
            tooltip: l10n.settings_currencies_reset,
            onPressed: () => _reset(defaultCode, enabled),
          ),
        ],
      ),
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(child: header(l10n.settings_currencies_enabled)),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Text(
                l10n.settings_currencies_enabledHint,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ),
          SliverReorderableList(
            itemCount: enabled.length,
            onReorderItem: (oldIndex, newIndex) =>
                _reorder(enabled, oldIndex, newIndex),
            itemBuilder: (context, index) {
              final code = enabled[index];
              return _EnabledCurrencyTile(
                key: ValueKey('currency-enabled-$code'),
                code: code,
                index: index,
                isDefault: code == defaultCode,
                onSetDefault: () => _setDefault(code, enabled),
                onDisable: () => _setEnabled([
                  for (final c in enabled)
                    if (c != code) c,
                ]),
              );
            },
          ),
          const SliverToBoxAdapter(child: Divider(height: 24)),
          SliverToBoxAdapter(child: header(l10n.settings_currencies_other)),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: TextField(
                key: const Key('currencies-search'),
                decoration: InputDecoration(
                  prefixIcon: const Icon(Icons.search),
                  hintText: l10n.currencyPicker_searchHint,
                ),
                onChanged: (value) => setState(() => _query = value),
              ),
            ),
          ),
          if (others.isEmpty)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Center(child: Text(l10n.currencyPicker_noMatches)),
              ),
            )
          else
            SliverList.builder(
              itemCount: others.length,
              itemBuilder: (context, index) {
                final code = others[index];
                void enable() => _setEnabled([...enabled, code]);
                final name = isoCurrencyName(code);
                // Laid out like an enabled row, with a gap where the drag
                // handle sits, so codes and switches line up down the page.
                return ListTile(
                  key: ValueKey('currency-other-$code'),
                  contentPadding: _tilePadding,
                  leading: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const SizedBox(width: _handleWidth),
                      CurrencySymbolBox(code: code),
                    ],
                  ),
                  title: Text(code),
                  subtitle: name == null ? null : Text(name),
                  trailing: Switch(value: false, onChanged: (_) => enable()),
                  onTap: enable,
                );
              },
            ),
          const SliverToBoxAdapter(child: SizedBox(height: 24)),
        ],
      ),
    );
  }
}

/// An enabled currency: a drag handle, its symbol, code and name, a star
/// that makes it the default, and a switch that disables it. The default
/// currency's switch is locked on.
class _EnabledCurrencyTile extends StatelessWidget {
  const _EnabledCurrencyTile({
    super.key,
    required this.code,
    required this.index,
    required this.isDefault,
    required this.onSetDefault,
    required this.onDisable,
  });

  final String code;
  final int index;
  final bool isDefault;
  final VoidCallback onSetDefault;
  final VoidCallback onDisable;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final name = isoCurrencyName(code);
    return Material(
      child: ListTile(
        contentPadding: _tilePadding,
        leading: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            ReorderableDragStartListener(
              index: index,
              child: const SizedBox(
                width: _handleWidth,
                child: Icon(Icons.drag_handle),
              ),
            ),
            CurrencySymbolBox(code: code),
          ],
        ),
        title: Text(code),
        subtitle: Text(
          [if (isDefault) l10n.settings_currencies_default, ?name].join(' · '),
          style: isDefault ? TextStyle(color: theme.colorScheme.primary) : null,
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              key: Key('currency-default-$code'),
              icon: Icon(
                isDefault ? Icons.star : Icons.star_border,
                color: isDefault ? theme.colorScheme.primary : null,
              ),
              tooltip: l10n.settings_currencies_setDefault,
              isSelected: isDefault,
              onPressed: isDefault ? null : onSetDefault,
            ),
            Switch(
              key: Key('currency-switch-$code'),
              value: true,
              onChanged: isDefault ? null : (_) => onDisable(),
            ),
          ],
        ),
      ),
    );
  }
}
